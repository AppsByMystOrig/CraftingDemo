namespace CraftingDemo.Data;

/// <summary>
/// Hardcoded stand-in for the SQL Server stored procedures. Both lists below are written
/// out by hand for a craft quantity of 1, the way the procedures would return them; nothing
/// here walks the recipe tree or sums materials. Scaling by quantity is the only arithmetic,
/// and it goes away when the real procedure takes the quantity as a parameter.
/// </summary>
public sealed class SampleRecipeRepository : IRecipeRepository
{
    public const int SampleRecipeId = 1;

    private static readonly RecipeIngredientRow[] Ingredients =
    [
        new(0, "Emberforged Longsword", 1, false),
        new(1, "Ember Steel Ingot", 3, false),
        new(2, "Iron Ore", 6, true),
        new(2, "Emberstone", 3, true),
        new(2, "Coal", 3, true),
        new(1, "Hardened Leather Grip", 1, false),
        new(2, "Cured Leather", 2, false),
        new(3, "Raw Hide", 2, true),
        new(3, "Tanning Salt", 2, true),
        new(2, "Linen Thread", 1, false),
        new(3, "Flax Fiber", 3, true),
        new(1, "Fire Rune", 1, false),
        new(2, "Emberstone", 2, true),
        new(2, "Rune Dust", 1, true),
    ];

    private static readonly BaseMaterialTotal[] BaseMaterials =
    [
        new("Iron Ore", 6),
        new("Emberstone", 5),
        new("Coal", 3),
        new("Flax Fiber", 3),
        new("Raw Hide", 2),
        new("Tanning Salt", 2),
        new("Rune Dust", 1),
    ];

    // The sample game has one recipe; a real search runs in dbo.SearchRecipes.
    public Task<IReadOnlyList<RecipeSummary>> SearchRecipesAsync(
        string searchText, CancellationToken cancellationToken = default)
    {
        const string name = "Emberforged Longsword";
        IReadOnlyList<RecipeSummary> results = name.Contains(searchText.Trim(), StringComparison.OrdinalIgnoreCase)
            ? [new RecipeSummary(SampleRecipeId, name)]
            : [];
        return Task.FromResult(results);
    }

    public Task<RecipeBreakdown?> GetRecipeBreakdownAsync(
        int recipeId, int quantity, CancellationToken cancellationToken = default)
    {
        if (recipeId != SampleRecipeId)
        {
            return Task.FromResult<RecipeBreakdown?>(null);
        }

        var breakdown = new RecipeBreakdown(
            "Ashfall Chronicles",
            "Emberforged Longsword",
            quantity,
            [.. Ingredients.Select(row => row with { Quantity = row.Quantity * quantity })],
            [.. BaseMaterials.Select(total => total with { Quantity = total.Quantity * quantity })]);

        return Task.FromResult<RecipeBreakdown?>(breakdown);
    }
}
