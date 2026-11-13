/*
    LastCaretaker/02_CreateRequirements.sql
    Creates dbo.Requirements: what each recipe needs. One recipe has one or more
    rows, one per required item. Safe to re-run: created only if missing.

    No primary key (by design). Instead:
      - a unique clustered index on (RecipeItemID, RequiredItemID): each
        recipe's rows are stored together, and an item can be listed only
        once per recipe
      - foreign keys: both item columns must exist in dbo.Recipe (ItemID)
      - Quantity must be greater than 0
      - a recipe cannot require itself
*/
USE tlccDB;
GO

IF OBJECT_ID(N'dbo.Requirements', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.Requirements
    (
        RecipeItemID   int NOT NULL,   -- the recipe being made (dbo.Recipe.ItemID)
        RequiredItemID int NOT NULL,   -- an item it requires (dbo.Recipe.ItemID)
        Quantity       int NOT NULL CONSTRAINT DF_Requirements_Quantity DEFAULT (1),

        CONSTRAINT FK_Requirements_RecipeItem FOREIGN KEY (RecipeItemID)
            REFERENCES dbo.Recipe (ItemID),
        CONSTRAINT FK_Requirements_RequiredItem FOREIGN KEY (RequiredItemID)
            REFERENCES dbo.Recipe (ItemID),
        CONSTRAINT CK_Requirements_Quantity CHECK (Quantity > 0),
        CONSTRAINT CK_Requirements_NotSelf CHECK (RecipeItemID <> RequiredItemID)
    );

    PRINT N'dbo.Requirements created.';
END
ELSE
    PRINT N'dbo.Requirements already exists.';
GO

-- Replaces the earlier non-unique index from the first version of this script.
IF EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Requirements') AND name = N'IX_Requirements_RecipeItemID')
    DROP INDEX IX_Requirements_RecipeItemID ON dbo.Requirements;

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID(N'dbo.Requirements') AND name = N'CIX_Requirements_Recipe_Required')
BEGIN
    CREATE UNIQUE CLUSTERED INDEX CIX_Requirements_Recipe_Required
        ON dbo.Requirements (RecipeItemID, RequiredItemID);
    PRINT N'Unique clustered index on (RecipeItemID, RequiredItemID) created.';
END
GO
