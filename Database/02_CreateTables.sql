/*
    02_CreateTables.sql
    Recipe data model. Safe to re-run: each table is created only if missing.

    Game              One row per game. GameKey is what the app passes in.
    Item              Every item in a game, craftable or not.
    Recipe            How to craft one item. OutputQuantity is the yield per craft.
    RecipeIngredient  The items (and how many) one craft of a recipe consumes.

    An item is a base material when no recipe produces it; that is derived in
    the stored procedures rather than stored, so it cannot get out of step.
*/
USE CraftingDemo;
GO

IF OBJECT_ID(N'dbo.Game', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Game
    (
        GameId  int           IDENTITY(1, 1) NOT NULL,
        GameKey varchar(50)   NOT NULL,
        Name    nvarchar(100) NOT NULL,

        CONSTRAINT PK_Game PRIMARY KEY (GameId),
        CONSTRAINT UQ_Game_GameKey UNIQUE (GameKey)
    );
END
GO

IF OBJECT_ID(N'dbo.Item', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Item
    (
        ItemId int           IDENTITY(1, 1) NOT NULL,
        GameId int           NOT NULL,
        Name   nvarchar(100) NOT NULL,

        CONSTRAINT PK_Item PRIMARY KEY (ItemId),
        CONSTRAINT FK_Item_Game FOREIGN KEY (GameId) REFERENCES dbo.Game (GameId),
        CONSTRAINT UQ_Item_GameId_Name UNIQUE (GameId, Name)
    );
END
GO

IF OBJECT_ID(N'dbo.Recipe', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Recipe
    (
        RecipeId       int NOT NULL IDENTITY(1, 1),
        OutputItemId   int NOT NULL,
        OutputQuantity int NOT NULL CONSTRAINT DF_Recipe_OutputQuantity DEFAULT (1),

        CONSTRAINT PK_Recipe PRIMARY KEY (RecipeId),
        CONSTRAINT FK_Recipe_Item FOREIGN KEY (OutputItemId) REFERENCES dbo.Item (ItemId),
        -- One recipe per item for now; drop this to allow alternative recipes.
        CONSTRAINT UQ_Recipe_OutputItemId UNIQUE (OutputItemId),
        CONSTRAINT CK_Recipe_OutputQuantity CHECK (OutputQuantity > 0)
    );
END
GO

IF OBJECT_ID(N'dbo.RecipeIngredient', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.RecipeIngredient
    (
        RecipeId         int NOT NULL,
        IngredientItemId int NOT NULL,
        Quantity         int NOT NULL,
        SortOrder        int NOT NULL,

        CONSTRAINT PK_RecipeIngredient PRIMARY KEY (RecipeId, IngredientItemId),
        CONSTRAINT FK_RecipeIngredient_Recipe FOREIGN KEY (RecipeId)
            REFERENCES dbo.Recipe (RecipeId) ON DELETE CASCADE,
        CONSTRAINT FK_RecipeIngredient_Item FOREIGN KEY (IngredientItemId)
            REFERENCES dbo.Item (ItemId),
        CONSTRAINT UQ_RecipeIngredient_RecipeId_SortOrder UNIQUE (RecipeId, SortOrder),
        CONSTRAINT CK_RecipeIngredient_Quantity CHECK (Quantity > 0),
        CONSTRAINT CK_RecipeIngredient_SortOrder CHECK (SortOrder BETWEEN 1 AND 9999)
    );

    CREATE INDEX IX_RecipeIngredient_IngredientItemId
        ON dbo.RecipeIngredient (IngredientItemId);
END
GO
