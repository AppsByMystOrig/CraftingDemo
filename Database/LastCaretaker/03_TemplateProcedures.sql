/*
    LastCaretaker/03_TemplateProcedures.sql
    The two procedures the CraftingDemo app calls, for tlccDB's current layout:
    dbo.Recipe (one row per item), dbo.ItemType, dbo.Requirements.
    Replaces the procedures of the same names from 01_TemplateProcedures.sql,
    which was written for the earlier layout. Change script: it only creates (or
    updates) these two procedures; no tables or data are touched.
    Safe to re-run (CREATE OR ALTER).

    App settings for this game:
      RecipeDatabase:SearchProcedure    = dbo.usp_SearchRecipes
      RecipeDatabase:BreakdownProcedure = dbo.usp_GetRecipeBreakdown

    Rules:
      - A recipe is an item that has rows in dbo.Requirements.
      - An item with no requirement rows is a base item: it ends its branch and is
        counted in the totals. That covers raw materials, and also any part whose
        requirements haven't been entered yet, so a part showing in the totals
        marks missing data.
      - Recipe.ItemAmount is how many one craft makes: each item is crafted
        CEILING(needed / ItemAmount) times and its requirements scale by that.
      - Requirements have no stored order, so they are listed alphabetically.
*/
USE tlccDB;
GO

/*
    dbo.usp_SearchRecipes
    Items that have requirements entered and whose name contains the search text;
    alphabetical; at most 50. Empty search lists the first 50.
    %, _ and [ in the search text are matched literally.

    Returns: RecipeId (the item's ItemID), RecipeName (the item's name)
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
        r.ItemID   AS RecipeId,
        r.ItemName AS RecipeName
    FROM dbo.Recipe AS r
    WHERE r.ItemName LIKE @Pattern
      AND EXISTS (SELECT 1 FROM dbo.Requirements AS q WHERE q.RecipeItemID = r.ItemID)
    ORDER BY r.ItemName;
END
GO

/*
    dbo.usp_GetRecipeBreakdown
    Everything the recipe page shows, for one item at one craft quantity.

    Returns three result sets (all empty if the item is not found):
      1. Header       RecipeName, Quantity                          (0 or 1 row)
      2. Ingredients  Level, ItemName, Quantity, IsBaseMaterial     (parent, then its requirements)
      3. Base totals  ItemName, Quantity                            (largest first)
*/
CREATE OR ALTER PROCEDURE dbo.usp_GetRecipeBreakdown
    @RecipeId int,
    @Quantity int
AS
BEGIN
    SET NOCOUNT ON;

    IF @Quantity IS NULL OR @Quantity < 1
        THROW 50001, N'@Quantity must be 1 or more.', 1;

    -- Every item: how many one craft makes, and whether its requirements exist.
    CREATE TABLE #Item
    (
        ItemID          int            NOT NULL PRIMARY KEY,
        Yield           decimal(18, 4) NOT NULL,
        HasRequirements bit            NOT NULL
    );

    INSERT #Item (ItemID, Yield, HasRequirements)
    SELECT r.ItemID,
           CASE WHEN r.ItemAmount > 0 THEN r.ItemAmount ELSE 1 END,
           CASE WHEN EXISTS (SELECT 1 FROM dbo.Requirements AS q WHERE q.RecipeItemID = r.ItemID) THEN 1 ELSE 0 END
    FROM dbo.Recipe AS r;

    -- Each item's requirements, numbered alphabetically for display order.
    CREATE TABLE #Need
    (
        RecipeItemID   int NOT NULL,
        RequiredItemID int NOT NULL,
        Quantity       int NOT NULL,
        Seq            int NOT NULL
    );

    INSERT #Need (RecipeItemID, RequiredItemID, Quantity, Seq)
    SELECT q.RecipeItemID, q.RequiredItemID, q.Quantity,
           ROW_NUMBER() OVER (PARTITION BY q.RecipeItemID ORDER BY r.ItemName, q.RequiredItemID)
    FROM dbo.Requirements AS q
    JOIN dbo.Recipe AS r ON r.ItemID = q.RequiredItemID;

    CREATE TABLE #Tree
    (
        SortPath nvarchar(1000) NOT NULL,
        Level    int            NOT NULL,
        ItemID   int            NOT NULL,
        Quantity decimal(28, 4) NOT NULL,
        IsBase   bit            NOT NULL
    );

    WITH Tree AS
    (
        -- Level 0: the item being crafted.
        SELECT
            CAST(0 AS int)                                                      AS Level,
            i.ItemID                                                            AS ItemID,
            i.Yield                                                             AS Yield,
            CAST(@Quantity AS decimal(28, 4))                                   AS Quantity,
            CAST(0 AS bit)                                                      AS IsBase,
            CAST(N'' AS nvarchar(1000))                                         AS SortPath,
            CAST(N'/' + CAST(i.ItemID AS nvarchar(10)) + N'/' AS nvarchar(1000)) AS ItemPath
        FROM #Item AS i
        WHERE i.ItemID = @RecipeId

        UNION ALL

        -- Requirements of each item that has some.
        SELECT
            t.Level + 1,
            n.RequiredItemID,
            c.Yield,
            CAST(CEILING(t.Quantity / t.Yield) * n.Quantity AS decimal(28, 4)),
            CAST(CASE WHEN c.HasRequirements = 1 THEN 0 ELSE 1 END AS bit),
            CAST(t.SortPath + RIGHT(N'0000' + CAST(n.Seq AS nvarchar(4)), 4) AS nvarchar(1000)),
            CAST(t.ItemPath + CAST(n.RequiredItemID AS nvarchar(10)) + N'/' AS nvarchar(1000))
        FROM Tree AS t
        JOIN #Need AS n ON n.RecipeItemID = t.ItemID
        JOIN #Item AS c ON c.ItemID = n.RequiredItemID
        -- Guard against bad data: never descend into an item already on this branch.
        WHERE t.ItemPath NOT LIKE N'%/' + CAST(n.RequiredItemID AS nvarchar(10)) + N'/%'
    )
    INSERT #Tree (SortPath, Level, ItemID, Quantity, IsBase)
    SELECT SortPath, Level, ItemID, Quantity, IsBase
    FROM Tree
    OPTION (MAXRECURSION 100);

    -- 1. Header
    SELECT r.ItemName AS RecipeName, @Quantity AS Quantity
    FROM dbo.Recipe AS r
    WHERE r.ItemID = @RecipeId;

    -- 2. Ingredients, each item followed by its own requirements
    SELECT t.Level, r.ItemName, t.Quantity, t.IsBase AS IsBaseMaterial
    FROM #Tree AS t
    JOIN dbo.Recipe AS r ON r.ItemID = t.ItemID
    ORDER BY t.SortPath;

    -- 3. Base totals, consolidated across the whole tree
    SELECT r.ItemName, SUM(t.Quantity) AS Quantity
    FROM #Tree AS t
    JOIN dbo.Recipe AS r ON r.ItemID = t.ItemID
    WHERE t.IsBase = 1
    GROUP BY t.ItemID, r.ItemName
    ORDER BY SUM(t.Quantity) DESC, r.ItemName;
END
GO
