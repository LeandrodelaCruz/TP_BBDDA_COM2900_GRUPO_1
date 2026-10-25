/*
    Crea el esquema utilizado por los Stored Procedures ABM.
    Las tablas permanecen en el esquema dbo.
*/
USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'abm') IS NULL
    EXEC(N'CREATE SCHEMA abm AUTHORIZATION dbo');
GO
