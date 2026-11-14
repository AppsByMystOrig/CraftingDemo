/*
    LastCaretaker/04_CreateAppLogin.sql
    Creates the SQL login the running app uses for tlccDB.
    The login may only EXECUTE stored procedures in dbo; it has no direct
    access to the tables (the procedures reach them through ownership chaining).

    Before running:
      1. Replace <choose a strong password> below with the real password.
         Record it on your worksheet; it goes in the app's connection string
         on the server (/etc/games/lastcaretaker.env, never in this repository).
      2. Do not save the file with the real password in it.

    Run on the production server after tlccDB has been restored there.
    Safe to re-run: the login and user are created only if missing, and the
    permission grant is idempotent. If the restored database already holds a
    tlc_app user (e.g. copied from another server), it is re-linked to this
    server's login.
*/
USE master;

DECLARE @Login    sysname       = N'tlc_app';
DECLARE @Password nvarchar(128) = N'<choose a strong password>';

IF @Password LIKE N'<%'
    THROW 50000, N'Replace the password placeholder before running this script.', 1;

IF SUSER_ID(@Login) IS NULL
BEGIN
    DECLARE @CreateLogin nvarchar(max) =
        N'CREATE LOGIN ' + QUOTENAME(@Login)
        + N' WITH PASSWORD = ' + QUOTENAME(@Password, N'''')
        + N', CHECK_POLICY = ON, DEFAULT_DATABASE = tlccDB;';
    EXEC (@CreateLogin);
    PRINT N'Login ' + @Login + N' created.';
END
ELSE
    PRINT N'Login ' + @Login + N' already exists; password not changed.';

USE tlccDB;

IF USER_ID(@Login) IS NULL
BEGIN
    DECLARE @CreateUser nvarchar(max) =
        N'CREATE USER ' + QUOTENAME(@Login) + N' FOR LOGIN ' + QUOTENAME(@Login) + N';';
    EXEC (@CreateUser);
END
ELSE IF NOT EXISTS (SELECT 1 FROM sys.database_principals AS d
                    JOIN sys.server_principals AS s ON s.sid = d.sid
                    WHERE d.name = @Login AND s.name = @Login)
BEGIN
    -- The user came with the restore but belongs to another server's login.
    DECLARE @Relink nvarchar(max) =
        N'ALTER USER ' + QUOTENAME(@Login) + N' WITH LOGIN = ' + QUOTENAME(@Login) + N';';
    EXEC (@Relink);
    PRINT N'User ' + @Login + N' re-linked to this server''s login.';
END

DECLARE @Grant nvarchar(max) = N'GRANT EXECUTE ON SCHEMA::dbo TO ' + QUOTENAME(@Login) + N';';
EXEC (@Grant);

PRINT N'User ' + @Login + N' can run the procedures in tlccDB.dbo and nothing else.';
GO
