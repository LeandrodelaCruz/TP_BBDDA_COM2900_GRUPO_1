/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 26/10/2026

    Descripción:
    Crea el esquema importacion para contener los Stored Procedures
    correspondientes a los procesos de importación masiva.
*/

USE MUNDIALDEFUTBOL;
GO

IF NOT EXISTS (
    SELECT 1
    FROM sys.schemas
    WHERE name = N'importacion'
)
BEGIN
    EXEC(N'CREATE SCHEMA importacion');
END;
GO
