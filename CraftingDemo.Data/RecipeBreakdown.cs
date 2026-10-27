namespace CraftingDemo.Data;

/// <summary>
/// One row of the expanded ingredient list, in display order.
/// <see cref="Level"/> is the recursion depth (0 = the crafted item itself) and
/// <see cref="Quantity"/> is already extended for the requested craft quantity.
/// </summary>
public sealed record RecipeIngredientRow(int Level, string ItemName, int Quantity, bool IsBaseMaterial);

/// <summary>A craftable item found by a recipe search.</summary>
public sealed record RecipeSummary(int RecipeId, string Name);

/// <summary>A base material and the consolidated total needed across the whole recipe.</summary>
public sealed record BaseMaterialTotal(string ItemName, int Quantity);

/// <summary>Everything the recipe page needs for one recipe at one craft quantity.</summary>
public sealed record RecipeBreakdown(
    string GameName,
    string RecipeName,
    int Quantity,
    IReadOnlyList<RecipeIngredientRow> Ingredients,
    IReadOnlyList<BaseMaterialTotal> BaseMaterials);
