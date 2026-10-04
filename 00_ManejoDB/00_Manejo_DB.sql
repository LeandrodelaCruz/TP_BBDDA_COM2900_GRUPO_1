/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Script auxiliar para recrear la base MundialDB desde cero.
    ADVERTENCIA: elimina completamente la base de datos y todos sus objetos/datos.
*/

USE master;
GO

IF DB_ID(N'MundialDB') IS NOT NULL
BEGIN
    ALTER DATABASE MundialDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MundialDB;
END;
GO

CREATE DATABASE MundialDB;
GO

ALTER DATABASE MundialDB SET MULTI_USER;
GO

SELECT name, state_desc, user_access_desc
FROM sys.databases
WHERE name = N'MundialDB';
GO

USE MundialDB;
GO
