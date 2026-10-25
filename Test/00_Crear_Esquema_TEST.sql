/*
    Crea el esquema utilizado por los procedimientos de testing.
    Las tablas permanecen en dbo y los ABM se encuentran en abm.
*/
USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'test') IS NULL
    EXEC(N'CREATE SCHEMA test AUTHORIZATION dbo');
GO
