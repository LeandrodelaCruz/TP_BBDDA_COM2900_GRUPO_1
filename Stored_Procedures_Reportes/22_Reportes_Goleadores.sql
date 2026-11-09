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
    Reportes de goleadores. Los tres retornan un unico campo XML.
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
    EXEC (N'CREATE SCHEMA reportes AUTHORIZATION dbo;');
GO

/* ---------------------------------------------------------------
   1. Goleadores por seleccion
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Goleadores_Por_Seleccion
AS
BEGIN
    SET NOCOUNT ON;

    WITH goles_jugador AS
    (
        SELECT i.id_jugador, COUNT(*) AS goles
        FROM dbo.Incidencia i
        WHERE i.tipo IN ('GOL', 'GOL DE PENAL')
          AND i.periodo <> 'PENALES'
        GROUP BY i.id_jugador
    )
    SELECT (
        SELECT s.pais AS [@pais],
               (SELECT COALESCE(SUM(gj.goles), 0)
                FROM goles_jugador gj
                JOIN dbo.Jugador jx ON jx.id_jugador = gj.id_jugador
                WHERE jx.id_seleccion = s.id_seleccion) AS [@total_goles],
               (SELECT j.nombre + N' ' + j.apellido AS [@jugador],
                       gj.goles                    AS [@goles]
                FROM goles_jugador gj
                JOIN dbo.Jugador j ON j.id_jugador = gj.id_jugador
                WHERE j.id_seleccion = s.id_seleccion
                ORDER BY gj.goles DESC, j.apellido, j.nombre
                FOR XML PATH('Goleador'), TYPE) AS [Goleadores]
        FROM dbo.Seleccion s
        WHERE EXISTS (SELECT 1 FROM goles_jugador gj
                      JOIN dbo.Jugador jx ON jx.id_jugador = gj.id_jugador
                      WHERE jx.id_seleccion = s.id_seleccion)
        ORDER BY s.pais
        FOR XML PATH('Seleccion'), ROOT('Goleadores_Por_Seleccion'), TYPE
    ) AS reporte_xml;
END;
GO

/* ---------------------------------------------------------------
   2. Goleadores por fase
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Goleadores_Por_Fase
AS
BEGIN
    SET NOCOUNT ON;

    WITH goles_fase AS
    (
        SELECT p.fase, i.id_jugador, COUNT(*) AS goles
        FROM dbo.Incidencia i
        JOIN dbo.Partido p ON p.id_partido = i.id_partido
        WHERE i.tipo IN ('GOL', 'GOL DE PENAL')
          AND i.periodo <> 'PENALES'
        GROUP BY p.fase, i.id_jugador
    )
    SELECT (
        SELECT f.fase AS [@fase],
               (SELECT j.nombre + N' ' + j.apellido AS [@jugador],
                       s.pais                       AS [@seleccion],
                       gf.goles                     AS [@goles]
                FROM goles_fase gf
                JOIN dbo.Jugador j ON j.id_jugador = gf.id_jugador
                JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
                WHERE gf.fase = f.fase
                ORDER BY gf.goles DESC, j.apellido, j.nombre
                FOR XML PATH('Goleador'), TYPE) AS [Goleadores]
        FROM (SELECT DISTINCT fase FROM goles_fase) f
        ORDER BY f.fase
        FOR XML PATH('Fase'), ROOT('Goleadores_Por_Fase'), TYPE
    ) AS reporte_xml;
END;
GO

/* ---------------------------------------------------------------
   3. Goleadores del torneo
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Goleadores_Por_Torneo
AS
BEGIN
    SET NOCOUNT ON;

    WITH goles_jugador AS
    (
        SELECT i.id_jugador, COUNT(*) AS goles
        FROM dbo.Incidencia i
        WHERE i.tipo IN ('GOL', 'GOL DE PENAL')
          AND i.periodo <> 'PENALES'
        GROUP BY i.id_jugador
    )
    SELECT (
        SELECT j.nombre + N' ' + j.apellido AS [@jugador],
               s.pais                       AS [@seleccion],
               gj.goles                     AS [@goles]
        FROM goles_jugador gj
        JOIN dbo.Jugador j ON j.id_jugador = gj.id_jugador
        JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
        ORDER BY gj.goles DESC, j.apellido, j.nombre
        FOR XML PATH('Goleador'), ROOT('Goleadores_Torneo'), TYPE
    ) AS reporte_xml;
END;
GO
