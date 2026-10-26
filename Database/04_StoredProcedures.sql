/*
    04_StoredProcedures.sql
    Stored procedures the app calls. Safe to re-run (CREATE OR ALTER).
*/
USE CraftingDemo;
GO

/*
    dbo.GetRecipeBreakdown
    Everything the recipe page shows, for one recipe at one craft quantity.
    This replaces SampleRecipeRepository: recursion, quantity maths and the
    base-material totals all happen here.

    Returns three result sets (all empty if the game or recipe is not found):
      1. Header       GameName, RecipeName, Quantity                (0 or 1 row)
      2. Ingredients  Level, ItemName, Quantity, IsBaseMaterial     (display order)
      3. Base totals  ItemName, Quantity                            (largest first)

    Quantities are totals for the whole craft. Each intermediate is crafted
    CEILING(needed / OutputQuantity) times, and its ingredients scale by that
    number of crafts. Rounding is per branch: if the same intermediate appears
    in two branches, each branch rounds up on its own.
*/
CREATE OR ALTER PROCEDURE dbo.GetRecipeBreakdown
    @GameKey  varchar(50),
    @RecipeId int,
    @Quantity int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Quantity IS NULL OR @Quantity < 1
        THROW 50001, N'@Quantity must be 1 or more.', 1;

    CREATE TABLE #Tree
    (
        SortPath       varchar(900)  NOT NULL,
        Level          int           NOT NULL,
        ItemId         int           NOT NULL,
        ItemName       nvarchar(100) NOT NULL,
        Quantity       int           NOT NULL,
        IsBaseMaterial bit           NOT NULL
    );

    WITH Tree AS
    (
        -- Level 0: the item being crafted.
        SELECT
            CAST(0 AS int)                                               AS Level,
            r.OutputItemId                                               AS ItemId,
            CAST(@Quantity AS int)                                       AS Quantity,
            CAST('' AS varchar(900))                                     AS SortPath,
            CAST('/' + CAST(r.OutputItemId AS varchar(10)) + '/' AS varchar(900)) AS ItemPath
        FROM dbo.Recipe AS r
        JOIN dbo.Item AS i ON i.ItemId = r.OutputItemId
        JOIN dbo.Game AS g ON g.GameId = i.GameId
        WHERE r.RecipeId = @RecipeId
          AND g.GameKey = @GameKey

        UNION ALL

        -- Each ingredient of anything on the previous level that has a recipe.
        SELECT
            t.Level + 1,
            ri.IngredientItemId,
            CAST(CEILING(CAST(t.Quantity AS decimal(19, 4)) / r.OutputQuantity) * ri.Quantity AS int),
            CAST(t.SortPath + RIGHT('0000' + CAST(ri.SortOrder AS varchar(4)), 4) AS varchar(900)),
            CAST(t.ItemPath + CAST(ri.IngredientItemId AS varchar(10)) + '/' AS varchar(900))
        FROM Tree AS t
        JOIN dbo.Recipe AS r ON r.OutputItemId = t.ItemId
        JOIN dbo.RecipeIngredient AS ri ON ri.RecipeId = r.RecipeId
        -- Guard against bad data: never descend into an item already on this branch.
        WHERE t.ItemPath NOT LIKE '%/' + CAST(ri.IngredientItemId AS varchar(10)) + '/%'
    )
    INSERT #Tree (SortPath, Level, ItemId, ItemName, Quantity, IsBaseMaterial)
    SELECT
        t.SortPath,
        t.Level,
        t.ItemId,
        i.Name,
        t.Quantity,
        CASE WHEN EXISTS (SELECT 1 FROM dbo.Recipe AS r WHERE r.OutputItemId = t.ItemId)
             THEN 0 ELSE 1 END
    FROM Tree AS t
    JOIN dbo.Item AS i ON i.ItemId = t.ItemId
    OPTION (MAXRECURSION 100);

    -- 1. Header
    SELECT
        g.Name     AS GameName,
        i.Name     AS RecipeName,
        @Quantity  AS Quantity
    FROM dbo.Recipe AS r
    JOIN dbo.Item AS i ON i.ItemId = r.OutputItemId
    JOIN dbo.Game AS g ON g.GameId = i.GameId
    WHERE r.RecipeId = @RecipeId
      AND g.GameKey = @GameKey;

    -- 2. Ingredients, depth-first in recipe order
    SELECT Level, ItemName, Quantity, IsBaseMaterial
    FROM #Tree
    ORDER BY SortPath;

    -- 3. Base material totals, consolidated across the whole tree
    SELECT ItemName, SUM(Quantity) AS Quantity
    FROM #Tree
    WHERE IsBaseMaterial = 1
      AND Level > 0
    GROUP BY ItemId, ItemName
    ORDER BY SUM(Quantity) DESC, ItemName;
END
GO
