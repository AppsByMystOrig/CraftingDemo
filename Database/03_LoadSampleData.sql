/*
    03_LoadSampleData.sql
    Loads the sample "Ashfall Chronicles" game: the same Emberforged Longsword
    recipe the app currently hardcodes in SampleRecipeRepository.cs.

    Loads only once: if the game is already present, nothing is changed.
    On a fresh database the Longsword recipe gets RecipeId 1, which is the
    id the app asks for today.
*/
USE CraftingDemo;
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

IF EXISTS (SELECT 1 FROM dbo.Game WHERE GameKey = 'ashfall')
BEGIN
    PRINT 'Sample game ''ashfall'' is already loaded; nothing changed.';
    RETURN;
END

BEGIN TRANSACTION;

INSERT dbo.Game (GameKey, Name)
VALUES ('ashfall', N'Ashfall Chronicles');

DECLARE @GameId int = SCOPE_IDENTITY();

INSERT dbo.Item (GameId, Name)
SELECT @GameId, v.Name
FROM (VALUES
    -- Crafted items
    (N'Emberforged Longsword'),
    (N'Ember Steel Ingot'),
    (N'Hardened Leather Grip'),
    (N'Cured Leather'),
    (N'Linen Thread'),
    (N'Fire Rune'),
    -- Base materials (no recipe produces them)
    (N'Iron Ore'),
    (N'Emberstone'),
    (N'Coal'),
    (N'Raw Hide'),
    (N'Tanning Salt'),
    (N'Flax Fiber'),
    (N'Rune Dust')
) AS v (Name);

-- ORDER BY fixes the identity order, so the Longsword is RecipeId 1 on a fresh database.
INSERT dbo.Recipe (OutputItemId, OutputQuantity)
SELECT i.ItemId, v.OutputQuantity
FROM (VALUES
    (1, N'Emberforged Longsword', 1),
    (2, N'Ember Steel Ingot',     1),
    (3, N'Hardened Leather Grip', 1),
    (4, N'Cured Leather',         1),
    (5, N'Linen Thread',          1),
    (6, N'Fire Rune',             1)
) AS v (Seq, ItemName, OutputQuantity)
JOIN dbo.Item AS i ON i.GameId = @GameId AND i.Name = v.ItemName
ORDER BY v.Seq;

-- Quantities are per single craft of the recipe.
INSERT dbo.RecipeIngredient (RecipeId, IngredientItemId, Quantity, SortOrder)
SELECT r.RecipeId, ingredient.ItemId, v.Quantity, v.SortOrder
FROM (VALUES
    (N'Emberforged Longsword', N'Ember Steel Ingot',     3, 1),
    (N'Emberforged Longsword', N'Hardened Leather Grip', 1, 2),
    (N'Emberforged Longsword', N'Fire Rune',             1, 3),

    (N'Ember Steel Ingot',     N'Iron Ore',              2, 1),
    (N'Ember Steel Ingot',     N'Emberstone',            1, 2),
    (N'Ember Steel Ingot',     N'Coal',                  1, 3),

    (N'Hardened Leather Grip', N'Cured Leather',         2, 1),
    (N'Hardened Leather Grip', N'Linen Thread',          1, 2),

    (N'Cured Leather',         N'Raw Hide',              1, 1),
    (N'Cured Leather',         N'Tanning Salt',          1, 2),

    (N'Linen Thread',          N'Flax Fiber',            3, 1),

    (N'Fire Rune',             N'Emberstone',            2, 1),
    (N'Fire Rune',             N'Rune Dust',             1, 2)
) AS v (RecipeItemName, IngredientName, Quantity, SortOrder)
JOIN dbo.Item AS crafted ON crafted.GameId = @GameId AND crafted.Name = v.RecipeItemName
JOIN dbo.Recipe AS r ON r.OutputItemId = crafted.ItemId
JOIN dbo.Item AS ingredient ON ingredient.GameId = @GameId AND ingredient.Name = v.IngredientName;

COMMIT TRANSACTION;

PRINT 'Sample game ''ashfall'' loaded.';
GO
