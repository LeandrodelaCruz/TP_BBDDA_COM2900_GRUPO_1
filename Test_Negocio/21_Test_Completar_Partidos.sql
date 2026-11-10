/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comision: Com: 01-2900
    Grupo 01:
    - Caro, Nicolas Dario
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodriguez Elias Uriel

    Descripcion:
    Test de negocio.Completar_Partidos. Ejecuta la carga sobre todos los
    partidos pendientes (con resultado_final y sin incidencias ni
    sustituciones) y muestra el resultado de cada partido. Los registros
    NO se borran.

    Requisitos previos:
      - Los partidos tienen resultado_final cargado y 11 titulares por
        seleccion.

    Uso: EXEC test.Completar_Partidos_Test;
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'test') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO

CREATE OR ALTER PROCEDURE test.Completar_Partidos_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST COMPLETAR PARTIDOS =====';

    /* ------------------------------------------------------------------
       1. Ejecutar la carga sobre todos los partidos pendientes.
          Devuelve partidos_simulados / partidos_con_error y el detalle
          por partido.
    ------------------------------------------------------------------ */
    EXEC negocio.Completar_Partidos;
END;
GO

EXEC test.Completar_Partidos_Test;
GO
