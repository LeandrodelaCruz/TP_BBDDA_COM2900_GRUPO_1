/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Script auxiliar para recrear la base MundialDB desde cero.
    ADVERTENCIA: elimina completamente la base de datos y todos sus objetos/datos.
*/

USE master;
GO

IF DB_ID(N'MUNDIALDEFUTBOL') IS NOT NULL
BEGIN
    ALTER DATABASE MUNDIALDEFUTBOL SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE MUNDIALDEFUTBOL;
END;
GO

CREATE DATABASE MUNDIALDEFUTBOL;
GO

ALTER DATABASE MUNDIALDEFUTBOL SET MULTI_USER;
GO

SELECT name, state_desc, user_access_desc
FROM sys.databases
WHERE name = N'MUNDIALDEFUTBOL';
GO
---
