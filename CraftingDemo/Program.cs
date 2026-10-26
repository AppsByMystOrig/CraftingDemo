using CraftingDemo.Components;
using CraftingDemo.Data;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// Recipe data comes from SQL Server, or from hardcoded sample data when
// RecipeDatabase:UseSampleData is true (handy without a database).
var recipeDatabase = builder.Configuration.GetSection("RecipeDatabase");
if (recipeDatabase.GetValue<bool>("UseSampleData"))
{
    builder.Services.AddScoped<IRecipeRepository, SampleRecipeRepository>();
}
else
{
    var configuration = builder.Configuration;
    var defaultName = recipeDatabase["ConnectionStringName"] ?? "CraftingDemo";

    // A game with its own entry under ConnectionStrings (named by its game key)
    // uses that database; every other game uses the default one.
    builder.Services.AddSingleton(new SqlRecipeRepositoryOptions(
        gameKey => configuration.GetConnectionString(gameKey)
            ?? configuration.GetConnectionString(defaultName)
            ?? throw new InvalidOperationException($"Connection string '{defaultName}' is not configured."),
        recipeDatabase["BreakdownProcedure"] ?? "dbo.GetRecipeBreakdown"));
    builder.Services.AddScoped<IRecipeRepository, SqlRecipeRepository>();
}

var app = builder.Build();

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}
app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
app.UseHttpsRedirection();

app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
