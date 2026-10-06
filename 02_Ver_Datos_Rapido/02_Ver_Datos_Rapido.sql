/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04
    Script auxiliar de consulta rápida.
    No modifica datos.
*/

--Creacion de tablas

USE MUNDIALDEFUTBOL;
GO

SELECT TABLE_NAME
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;
GO

--Creacion de validaciones

USE MUNDIALDEFUTBOL;
GO

SELECT name
FROM sys.procedures
WHERE name LIKE 'sp_Validar_%'
ORDER BY name;
GO

--Creacion de 25 ABM

USE MUNDIALDEFUTBOL;
GO

SELECT name
FROM sys.procedures
WHERE name LIKE 'sp_Anunciante_%'
   OR name LIKE 'sp_Region_%'
   OR name LIKE 'sp_Sede_%'
   OR name LIKE 'sp_Seleccion_%'
   OR name LIKE 'sp_Arbitro_%'
ORDER BY name;

--Ver tablas

USE MUNDIALDEFUTBOL;
GO

SELECT * FROM dbo.Anunciante;
SELECT * FROM dbo.Region;
SELECT * FROM dbo.Sede;
SELECT * FROM dbo.Seleccion;
SELECT * FROM dbo.Arbitro;