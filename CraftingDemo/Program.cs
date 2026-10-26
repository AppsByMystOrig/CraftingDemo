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
    // Each running copy of the app serves one game from that game's own database.
    // On a server, set these per copy, e.g. ConnectionStrings__GameDatabase and
    // Game__DisplayName as environment variables; Nginx routes each game's URL to its copy.
    builder.Services.AddSingleton(new SqlRecipeRepositoryOptions(
        builder.Configuration["Game:DisplayName"]
            ?? throw new InvalidOperationException("Game:DisplayName is not configured."),
        builder.Configuration.GetConnectionString("GameDatabase")
            ?? throw new InvalidOperationException("Connection string 'GameDatabase' is not configured."),
        recipeDatabase["BreakdownProcedure"] ?? "dbo.GetRecipeBreakdown"));
    builder.Services.AddScoped<IRecipeRepository, SqlRecipeRepository>();
}

var app = builder.Build();

// When Nginx serves this game under a path such as /ashfall, set PathBase to it
// (e.g. environment variable PathBase=/ashfall). Nginx passes the path through
// unchanged; this strips it before routing and puts it back on every link.
var pathBase = app.Configuration["PathBase"];
if (!string.IsNullOrEmpty(pathBase))
{
    app.UsePathBase(pathBase);
}

// Configure the HTTP request pipeline.
if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error", createScopeForErrors: true);
    // The default HSTS value is 30 days. You may want to change this for production scenarios, see https://aka.ms/aspnetcore-hsts.
    app.UseHsts();
}
app.UseStatusCodePagesWithReExecute("/not-found", createScopeForStatusCodePages: true);
app.UseHttpsRedirection();

// Explicit so routing runs after UsePathBase and after the re-executing
// error/status-code middleware above.
app.UseRouting();
app.UseAntiforgery();

app.MapStaticAssets();
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.Run();
