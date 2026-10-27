/*
    06_SearchRecipes.sql
    Adds dbo.SearchRecipes, used by the recipe picker. Change script: it only
    creates (or updates) a procedure, so existing data is untouched.
    Safe to re-run (CREATE OR ALTER).

    The app's login already has EXECUTE on the dbo schema (script 05), so it
    can call this procedure with no further permission changes.
*/
USE CraftingDemo;
GO

/*
    dbo.SearchRecipes
    Craftable items (items that have a recipe) whose name contains the search
    text, alphabetically, at most 50. Base materials are not returned.
    An empty search lists the first 50 craftable items.

    The search text is matched literally: %, _ and [ are escaped so they are
    not treated as LIKE wildcards.

    Returns: RecipeId, RecipeName
*/
CREATE OR ALTER PROCEDURE dbo.SearchRecipes
    @SearchText nvarchar(100)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Text nvarchar(100) = LTRIM(RTRIM(ISNULL(@SearchText, N'')));

    -- Escape [ first, since the other replacements add brackets.
    DECLARE @Pattern nvarchar(400) =
        N'%' + REPLACE(REPLACE(REPLACE(@Text, N'[', N'[[]'), N'%', N'[%]'), N'_', N'[_]') + N'%';

    SELECT TOP (50)
        r.RecipeId,
        i.Name AS RecipeName
    FROM dbo.Recipe AS r
    JOIN dbo.Item AS i ON i.ItemId = r.OutputItemId
    WHERE i.Name LIKE @Pattern
    ORDER BY i.Name;
END
GO
