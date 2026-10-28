/*
    LastCaretaker/01_TemplateProcedures.sql
    Adds the two procedures the CraftingDemo app calls, reading tlccDB's own
    tables. Change script: it only creates (or updates) these two procedures;
    no tables, data or existing procedures are touched.
    Safe to re-run (CREATE OR ALTER).

    App settings for this game:
      RecipeDatabase:SearchProcedure    = dbo.usp_SearchRecipes
      RecipeDatabase:BreakdownProcedure = dbo.usp_GetRecipeBreakdown

    How tlccDB maps to what the app shows:
      - Base materials are items with ItemType = 'Material'.
      - An item may have several recipes; when expanding an ingredient, the
        recipe named 'Default' is used, otherwise the lowest RecipeID
        (the same choice usp_GetCraftingRequirements makes).
      - Ingredients have no stored order, so each recipe's ingredients are
        listed alphabetically.
      - Quantities are decimals (e.g. litres), returned as decimal(28,4).
*/
USE tlccDB;
GO

/*
    dbo.usp_SearchRecipes
    Recipes whose item name (or, for non-default recipes, recipe name) contains
    the search text; alphabetical; at most 50. Empty search lists the first 50.
    %, _ and [ in the search text are matched literally.

    Returns: RecipeId, RecipeName (the item name, plus the recipe name in
    brackets when it is not 'Default').
*/
CREATE OR ALTER PROCEDURE dbo.usp_SearchRecipes
    @SearchText nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Text nvarchar(100) = LTRIM(RTRIM(ISNULL(@SearchText, N'')));
    DECLARE @Pattern nvarchar(400) =
        N'%' + REPLACE(REPLACE(REPLACE(@Text, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

    SELECT TOP (50)
        r.RecipeID AS RecipeId,
        CASE WHEN r.RecipeName IN (N'Default', i.ItemName) THEN i.ItemName
             ELSE i.ItemName + N' (' + r.RecipeName + N')' END AS RecipeName
    FROM dbo.Recipe AS r
    JOIN dbo.Item AS i ON i.ItemID = r.ItemID
    WHERE i.ItemName LIKE @Pattern
       OR (r.RecipeName <> N'Default' AND r.RecipeName LIKE @Pattern)
    ORDER BY RecipeName;
END
GO

/*
    dbo.usp_GetRecipeBreakdown
    Everything the recipe page shows, for one recipe at one craft quantity.

    Returns three result sets (all empty if the recipe is not found):
      1. Header       RecipeName, Quantity                          (0 or 1 row)
      2. Ingredients  Level, ItemName, Quantity, IsBaseMaterial     (parent, then its children)
      3. Base totals  ItemName, Quantity                            (largest first)

    Each craftable item is crafted CEILING(needed / OutputQuantity) times and
    its ingredients scale by that number of crafts, as in
    usp_GetCraftingRequirements. Materials are never expanded.
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetRecipeBreakdown
    @RecipeId int,
    @Quantity int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Quantity IS NULL OR @Quantity < 1
        THROW 50001, N'@Quantity must be 1 or more.', 1;

    -- The recipe used to expand each craftable item (none for materials).
    CREATE TABLE #Chosen
    (
        ItemID         int            NOT NULL PRIMARY KEY,
        RecipeID       int            NULL,
        OutputQuantity decimal(18, 4) NULL,
        IsMaterial     bit            NOT NULL
    );

    INSERT #Chosen (ItemID, RecipeID, OutputQuantity, IsMaterial)
    SELECT i.ItemID, c.RecipeID, c.OutputQuantity,
           CASE WHEN i.ItemType = 'Material' THEN 1 ELSE 0 END
    FROM dbo.Item AS i
    LEFT JOIN
    (
        SELECT r.ItemID, r.RecipeID, r.OutputQuantity,
               ROW_NUMBER() OVER (PARTITION BY r.ItemID
                                  ORDER BY CASE WHEN r.RecipeName = N'Default' THEN 0 ELSE 1 END, r.RecipeID) AS Pick
        FROM dbo.Recipe AS r
    ) AS c ON c.ItemID = i.ItemID AND c.Pick = 1 AND i.ItemType <> 'Material';

    -- Each recipe's ingredients, numbered alphabetically for display order.
    CREATE TABLE #Ingredient
    (
        RecipeID         int            NOT NULL,
        IngredientItemID int            NOT NULL,
        Quantity         decimal(18, 4) NOT NULL,
        Seq              int            NOT NULL
    );

    INSERT #Ingredient (RecipeID, IngredientItemID, Quantity, Seq)
    SELECT ri.RecipeID, ri.IngredientItemID, ri.Quantity,
           ROW_NUMBER() OVER (PARTITION BY ri.RecipeID ORDER BY i.ItemName)
    FROM dbo.RecipeIngredient AS ri
    JOIN dbo.Item AS i ON i.ItemID = ri.IngredientItemID;

    CREATE TABLE #Tree
    (
        SortPath   varchar(900)   NOT NULL,
        Level      int            NOT NULL,
        ItemID     int            NOT NULL,
        Quantity   decimal(28, 4) NOT NULL,
        IsMaterial bit            NOT NULL
    );

    WITH Tree AS
    (
        -- Level 0: the item being crafted, with the recipe that was picked.
        SELECT
            CAST(0 AS int)                                                    AS Level,
            r.ItemID                                                          AS ItemID,
            r.RecipeID                                                        AS RecipeID,
            r.OutputQuantity                                                  AS OutputQuantity,
            CAST(@Quantity AS decimal(28, 4))                                 AS Quantity,
            CAST(0 AS bit)                                                    AS IsMaterial,
            CAST('' AS varchar(900))                                          AS SortPath,
            CAST('/' + CAST(r.ItemID AS varchar(10)) + '/' AS varchar(900))   AS ItemPath
        FROM dbo.Recipe AS r
        WHERE r.RecipeID = @RecipeId

        UNION ALL

        -- Ingredients of each item that has a recipe to expand.
        SELECT
            t.Level + 1,
            ing.IngredientItemID,
            c.RecipeID,
            c.OutputQuantity,
            CAST(CEILING(t.Quantity / t.OutputQuantity) * ing.Quantity AS decimal(28, 4)),
            c.IsMaterial,
            CAST(t.SortPath + RIGHT('0000' + CAST(ing.Seq AS varchar(4)), 4) AS varchar(900)),
            CAST(t.ItemPath + CAST(ing.IngredientItemID AS varchar(10)) + '/' AS varchar(900))
        FROM Tree AS t
        JOIN #Ingredient AS ing ON ing.RecipeID = t.RecipeID
        JOIN #Chosen AS c ON c.ItemID = ing.IngredientItemID
        -- Guard against bad data: never descend into an item already on this branch.
        WHERE t.ItemPath NOT LIKE '%/' + CAST(ing.IngredientItemID AS varchar(10)) + '/%'
    )
    INSERT #Tree (SortPath, Level, ItemID, Quantity, IsMaterial)
    SELECT SortPath, Level, ItemID, Quantity, IsMaterial
    FROM Tree
    OPTION (MAXRECURSION 100);

    -- 1. Header
    SELECT
        CASE WHEN r.RecipeName IN (N'Default', i.ItemName) THEN i.ItemName
             ELSE i.ItemName + N' (' + r.RecipeName + N')' END AS RecipeName,
        @Quantity AS Quantity
    FROM dbo.Recipe AS r
    JOIN dbo.Item AS i ON i.ItemID = r.ItemID
    WHERE r.RecipeID = @RecipeId;

    -- 2. Ingredients, each parent followed by its own ingredients
    SELECT t.Level, i.ItemName, t.Quantity, t.IsMaterial AS IsBaseMaterial
    FROM #Tree AS t
    JOIN dbo.Item AS i ON i.ItemID = t.ItemID
    ORDER BY t.SortPath;

    -- 3. Base material totals, consolidated across the whole tree
    SELECT i.ItemName, SUM(t.Quantity) AS Quantity
    FROM #Tree AS t
    JOIN dbo.Item AS i ON i.ItemID = t.ItemID
    WHERE t.IsMaterial = 1
    GROUP BY i.ItemID, i.ItemName
    ORDER BY SUM(t.Quantity) DESC, i.ItemName;
END
GO
