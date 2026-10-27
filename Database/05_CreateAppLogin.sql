/*
    05_CreateAppLogin.sql
    Creates the SQL login the running app uses for this game's database.
    The login may only EXECUTE stored procedures in dbo; it has no direct
    access to the tables (the procedures reach them through ownership chaining).

    Before running:
      1. Replace <choose a strong password> below with the real password.
         Record it on your worksheet; it goes in the app's connection string
         on the server (an environment variable, never in this repository).
      2. Do not save the file with the real password in it.

    Run after 01-04. Safe to re-run: the login and user are created only if
    missing, and the permission grant is idempotent.

    Template note: a new game changes @Login and the database name in USE below.
*/
USE master;

DECLARE @Login    sysname       = N'ashfall_app';
DECLARE @Password nvarchar(128) = N'<choose a strong password>';

IF @Password LIKE N'<%'
    THROW 50000, N'Replace the password placeholder before running this script.', 1;

IF SUSER_ID(@Login) IS NULL
BEGIN
    DECLARE @CreateLogin nvarchar(max) =
        N'CREATE LOGIN ' + QUOTENAME(@Login)
        + N' WITH PASSWORD = ' + QUOTENAME(@Password, N'''')
        + N', CHECK_POLICY = ON, DEFAULT_DATABASE = CraftingDemo;';
    EXEC (@CreateLogin);
    PRINT N'Login ' + @Login + N' created.';
END
ELSE
    PRINT N'Login ' + @Login + N' already exists; password not changed.';

USE CraftingDemo;

IF USER_ID(@Login) IS NULL
BEGIN
    DECLARE @CreateUser nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login) + N';';
    EXEC (@CreateUser);
END

DECLARE @Grant nvarchar(max) = N'GRANT EXECUTE ON SCHEMA::dbo TO ' + QUOTENAME(@Login) + N';';
EXEC (@Grant);

PRINT N'User ' + @Login + N' can run the procedures in CraftingDemo.dbo and nothing else.';
GO
