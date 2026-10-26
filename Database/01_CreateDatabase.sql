/*
    01_CreateDatabase.sql
    Creates the CraftingDemo database if it does not already exist.
    Run order: 01 -> 02 -> 03 -> 04.

    Template note: a new app changes the database name here and in the USE
    statement at the top of each of the other scripts.
*/
IF DB_ID(N'CraftingDemo') IS NULL
BEGIN
    CREATE DATABASE CraftingDemo;
END
GO
