using System.Data;
using Microsoft.Data.SqlClient;

namespace CraftingDemo.Data;

/// <summary>The game this copy of the app serves, and where its recipes live.</summary>
/// <param name="GameName">Display name shown on the page; the database does not store it.</param>
/// <param name="ConnectionString">The game's own database.</param>
/// <param name="BreakdownProcedure">Stored procedure that returns a <see cref="RecipeBreakdown"/>.</param>
/// <param name="SearchProcedure">Stored procedure that returns matching <see cref="RecipeSummary"/> rows.</param>
public sealed record SqlRecipeRepositoryOptions(
    string GameName,
    string ConnectionString,
    string BreakdownProcedure = "dbo.GetRecipeBreakdown",
    string SearchProcedure = "dbo.SearchRecipes");

/// <summary>
/// Reads recipes from SQL Server. The stored procedures do all searching, recursion,
/// quantity maths and aggregation; this class only maps their result sets.
/// </summary>
public sealed class SqlRecipeRepository(SqlRecipeRepositoryOptions options) : IRecipeRepository
{
    public async Task<IReadOnlyList<RecipeSummary>> SearchRecipesAsync(
        string searchText, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(options.ConnectionString);
        await using var command = new SqlCommand(options.SearchProcedure, connection)
        {
            CommandType = CommandType.StoredProcedure,
        };
        command.Parameters.Add("@SearchText", SqlDbType.NVarChar, 100).Value = searchText;

        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        var recipes = new List<RecipeSummary>();
        int recipeId = reader.GetOrdinal("RecipeId"),
            recipeName = reader.GetOrdinal("RecipeName");
        while (await reader.ReadAsync(cancellationToken))
        {
            recipes.Add(new RecipeSummary(reader.GetInt32(recipeId), reader.GetString(recipeName)));
        }

        return recipes;
    }

    public async Task<RecipeBreakdown?> GetRecipeBreakdownAsync(
        int recipeId, int quantity, CancellationToken cancellationToken = default)
    {
        await using var connection = new SqlConnection(options.ConnectionString);
        await using var command = new SqlCommand(options.BreakdownProcedure, connection)
        {
            CommandType = CommandType.StoredProcedure,
        };
        command.Parameters.Add("@RecipeId", SqlDbType.Int).Value = recipeId;
        command.Parameters.Add("@Quantity", SqlDbType.Int).Value = quantity;

        await connection.OpenAsync(cancellationToken);
        await using var reader = await command.ExecuteReaderAsync(cancellationToken);

        // 1. Header: no row means the recipe was not found.
        if (!await reader.ReadAsync(cancellationToken))
        {
            return null;
        }

        var recipeName = reader.GetString(reader.GetOrdinal("RecipeName"));

        // 2. Ingredient rows.
        await reader.NextResultAsync(cancellationToken);
        var ingredients = new List<RecipeIngredientRow>();
        int level = reader.GetOrdinal("Level"),
            itemName = reader.GetOrdinal("ItemName"),
            rowQuantity = reader.GetOrdinal("Quantity"),
            isBaseMaterial = reader.GetOrdinal("IsBaseMaterial");
        while (await reader.ReadAsync(cancellationToken))
        {
            ingredients.Add(new RecipeIngredientRow(
                reader.GetInt32(level),
                reader.GetString(itemName),
                reader.GetInt32(rowQuantity),
                reader.GetBoolean(isBaseMaterial)));
        }

        // 3. Base-material totals.
        await reader.NextResultAsync(cancellationToken);
        var baseMaterials = new List<BaseMaterialTotal>();
        int totalName = reader.GetOrdinal("ItemName"),
            totalQuantity = reader.GetOrdinal("Quantity");
        while (await reader.ReadAsync(cancellationToken))
        {
            baseMaterials.Add(new BaseMaterialTotal(
                reader.GetString(totalName),
                reader.GetInt32(totalQuantity)));
        }

        return new RecipeBreakdown(options.GameName, recipeName, quantity, ingredients, baseMaterials);
    }
}
