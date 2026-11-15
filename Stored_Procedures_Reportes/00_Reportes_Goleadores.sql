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
    Reportes de goleadores. Los tres devuelven filas leidas de las vistas reportes.v_Goles_*.
      - reportes.Goleadores_Por_Seleccion : goleadores agrupados por seleccion.
      - reportes.Goleadores_Por_Fase      : goleadores agrupados por fase.
      - reportes.Goleadores_Por_Torneo    : goleadores de todo el torneo.

    Criterio de conteo:
      - Cuentan los tipos 'GOL' y 'GOL DE PENAL'.
      - Se excluye la tanda de penales (periodo 'PENALES').
      - 'GOL EN CONTRA' no suma al goleador: el tanto se atribuye a la
        seleccion rival y no al jugador que lo marco.

    Ejemplo:
    EXEC reportes.Goleadores_Por_Seleccion;
    EXEC reportes.Goleadores_Por_Fase;
    EXEC reportes.Goleadores_Por_Torneo;
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO

/* ---------------------------------------------------------------
   0. Vistas para Power BI (consultables como tablas)
   Mismo criterio de conteo que los procedimientos de este archivo.
   --------------------------------------------------------------- */
CREATE OR ALTER VIEW reportes.v_Goles_Por_Jugador
AS
    SELECT i.id_jugador,
           j.nombre + N' ' + j.apellido AS jugador,
           s.id_seleccion,
           s.pais AS seleccion,
           j.apellido,
           j.nombre,
           COUNT(*) AS goles
    FROM dbo.Incidencia i
    JOIN dbo.Jugador j   ON j.id_jugador = i.id_jugador
    JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
    WHERE i.tipo IN ('GOL', 'GOL DE PENAL')
      AND i.periodo <> 'PENALES'
    GROUP BY i.id_jugador, j.nombre, j.apellido, s.id_seleccion, s.pais;
GO

CREATE OR ALTER VIEW reportes.v_Goles_Por_Seleccion
AS
    SELECT s.id_seleccion,
           s.pais AS seleccion,
           COALESCE(SUM(gj.goles), 0) AS total_goles
    FROM dbo.Seleccion s
    LEFT JOIN reportes.v_Goles_Por_Jugador gj ON gj.id_seleccion = s.id_seleccion
    GROUP BY s.id_seleccion, s.pais;
GO

CREATE OR ALTER VIEW reportes.v_Goles_Por_Fase
AS
    SELECT p.fase,
           COUNT(*) AS goles
    FROM dbo.Incidencia i
    JOIN dbo.Partido p ON p.id_partido = i.id_partido
    WHERE i.tipo IN ('GOL', 'GOL DE PENAL')
      AND i.periodo <> 'PENALES'
    GROUP BY p.fase;
GO

CREATE OR ALTER VIEW reportes.v_Goles_Por_Fase_Jugador
AS
    SELECT p.fase,
           i.id_jugador,
           j.nombre + N' ' + j.apellido AS jugador,
           j.apellido,
           j.nombre,
           s.id_seleccion,
           s.pais AS seleccion,
           COUNT(*) AS goles
    FROM dbo.Incidencia i
    JOIN dbo.Partido p   ON p.id_partido = i.id_partido
    JOIN dbo.Jugador j   ON j.id_jugador = i.id_jugador
    JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
    WHERE i.tipo IN ('GOL', 'GOL DE PENAL')
      AND i.periodo <> 'PENALES'
    GROUP BY p.fase, i.id_jugador, j.nombre, j.apellido, s.id_seleccion, s.pais;
GO

/* ---------------------------------------------------------------
   1. Goleadores por seleccion
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Goleadores_Por_Seleccion
AS
BEGIN
    SET NOCOUNT ON;

    SELECT gs.seleccion,
           gs.total_goles,
           gj.jugador,
           gj.goles
    FROM reportes.v_Goles_Por_Seleccion gs
    JOIN reportes.v_Goles_Por_Jugador gj ON gj.id_seleccion = gs.id_seleccion
    WHERE gs.total_goles > 0
    ORDER BY gs.seleccion, gj.goles DESC, gj.apellido, gj.nombre;
END;
GO

/* ---------------------------------------------------------------
   2. Goleadores por fase
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Goleadores_Por_Fase
AS
BEGIN
    SET NOCOUNT ON;

    SELECT gf.fase,
           gf.jugador,
           gf.seleccion,
           gf.goles
    FROM reportes.v_Goles_Por_Fase_Jugador gf
    ORDER BY gf.fase, gf.goles DESC, gf.apellido, gf.nombre;
END;
GO

/* ---------------------------------------------------------------
   3. Goleadores del torneo
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Goleadores_Por_Torneo
AS
BEGIN
    SET NOCOUNT ON;

    SELECT gj.jugador,
           gj.seleccion,
           gj.goles
    FROM reportes.v_Goles_Por_Jugador gj
    ORDER BY gj.goles DESC, gj.apellido, gj.nombre;
END;
GO
