namespace CraftingDemo.Data;

/// <summary>
/// Data access boundary for recipes. Implementations return results that are already
/// expanded, extended and consolidated; callers only display them.
/// </summary>
public interface IRecipeRepository
{
    /// <param name="gameKey">Identifies the game, and eventually which database to query.</param>
    /// <returns>The breakdown, or <c>null</c> if the game or recipe is unknown.</returns>
    Task<RecipeBreakdown?> GetRecipeBreakdownAsync(
        string gameKey, int recipeId, int quantity, CancellationToken cancellationToken = default);
}
