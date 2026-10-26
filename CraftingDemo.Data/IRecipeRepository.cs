namespace CraftingDemo.Data;

/// <summary>
/// Data access boundary for recipes. Implementations return results that are already
/// expanded, extended and consolidated; callers only display them.
/// Each running copy of the app serves one game, so there is no game parameter.
/// </summary>
public interface IRecipeRepository
{
    /// <returns>The breakdown, or <c>null</c> if the recipe is unknown.</returns>
    Task<RecipeBreakdown?> GetRecipeBreakdownAsync(
        int recipeId, int quantity, CancellationToken cancellationToken = default);
}
