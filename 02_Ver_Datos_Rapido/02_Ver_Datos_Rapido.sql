/*
    Script auxiliar de consulta rápida.
    No modifica datos.
*/

--Creacion de procedimientos 

USE MundialDB;
GO

SELECT name
FROM sys.procedures
WHERE name LIKE 'sp_Validar_%'
ORDER BY name;
GO

--Creacion de 25 procedimientos

USE MundialDB;
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

USE MundialDB;
GO

SELECT * FROM dbo.Anunciante;
SELECT * FROM dbo.Region;
SELECT * FROM dbo.Sede;
SELECT * FROM dbo.Seleccion;
SELECT * FROM dbo.Arbitro;