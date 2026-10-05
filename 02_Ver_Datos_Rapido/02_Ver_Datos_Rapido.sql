/*
    Script auxiliar de consulta rápida.
    No modifica datos.
*/

USE MundialDB;
GO

SELECT TOP (10) * FROM dbo.Anunciante ORDER BY id_anunciante DESC;
SELECT TOP (10) * FROM dbo.Region ORDER BY id_region DESC;
SELECT TOP (10) * FROM dbo.Sede ORDER BY id_sede DESC;
SELECT TOP (10) * FROM dbo.Seleccion ORDER BY id_seleccion DESC;
SELECT TOP (10) * FROM dbo.Arbitro ORDER BY id_arbitro DESC;
GO

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