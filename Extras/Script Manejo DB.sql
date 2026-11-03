	/*
	Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodr�guez, El�as Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026
	*/

-- Primero, cambiar a otra base de datos
USE master;
GO

-- Por si la sesión quedó con una transacción abierta
IF @@TRANCOUNT > 0
    ROLLBACK TRANSACTION;
GO

SET IMPLICIT_TRANSACTIONS OFF;
GO

PRINT 'RECREANDO BASE MUNDIALDEFUTBOL';

GO

IF DB_ID(N'MUNDIALDEFUTBOL') IS NOT NULL
BEGIN
    PRINT 'La base existe. Cerrando conexiones...';

    ALTER DATABASE MUNDIALDEFUTBOL
        SET SINGLE_USER WITH ROLLBACK IMMEDIATE;

    PRINT 'Eliminando base...';

    DROP DATABASE MUNDIALDEFUTBOL;
END;
GO

PRINT 'Creando base MUNDIALDEFUTBOL...';

CREATE DATABASE MUNDIALDEFUTBOL;
GO


USE MUNDIALDEFUTBOL;
GO

PRINT 'BASE CREADA CORRECTAMENTE';

GO

-- verificamo
SELECT
    name,
    state_desc,
    user_access_desc
FROM sys.databases
WHERE name = N'MUNDIALDEFUTBOL';
GO

-- Aca nos tiene que mostrar vacio
SELECT
    COUNT(*) AS cantidad_tablas
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

SELECT
    COUNT(*) AS cantidad_stored_procedures
FROM sys.procedures;
GO