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
    Reportes de tarjetas. Ambos retornan un unico campo XML.
      - reportes.Tarjetas_Por_Seleccion : amarillas y rojas por seleccion.
      - reportes.Tarjetas_Por_Jugador   : amarillas y rojas por jugador, con
                                          el detalle de suspensiones por
                                          acumulacion.

    Criterio de conteo:
      - Amarilla  = incidencia 'AMONESTACION'.
      - Roja      = incidencia 'EXPULSION'.
      - Una segunda amarilla genera AMONESTACION + EXPULSION (ver
        negocio.Simular_Partido), por lo que cuenta en ambas columnas.

    Criterio de suspension por acumulacion:
      - Se consideran los partidos en los que participo cada jugador
        (Formacion_Jugador), ordenados por horario_local.
      - Si el jugador recibe amarilla en dos partidos contiguos de los que
        participo, queda suspendido para el partido siguiente de los que
        participa.
      - Estado: 'ACTIVA' si ese partido todavia no tiene resultado_final (o no
        existe), 'CUMPLIDA' si ya se jugo.

    Ejemplo:
    EXEC reportes.Tarjetas_Por_Seleccion;
    EXEC reportes.Tarjetas_Por_Jugador;
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO

/* ---------------------------------------------------------------
   1. Tarjetas por seleccion
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Tarjetas_Por_Seleccion
AS
BEGIN
    SET NOCOUNT ON;

    WITH tarjetas_seleccion AS
    (
        SELECT j.id_seleccion,
               SUM(CASE WHEN i.tipo = 'AMONESTACION' THEN 1 ELSE 0 END) AS amarillas,
               SUM(CASE WHEN i.tipo = 'EXPULSION'    THEN 1 ELSE 0 END) AS rojas
        FROM dbo.Incidencia i
        JOIN dbo.Jugador j ON j.id_jugador = i.id_jugador
        WHERE i.tipo IN ('AMONESTACION', 'EXPULSION')
        GROUP BY j.id_seleccion
    )
    SELECT (
        SELECT s.pais AS [@pais],
               ts.amarillas AS [@amarillas],
               ts.rojas     AS [@rojas]
        FROM tarjetas_seleccion ts
        JOIN dbo.Seleccion s ON s.id_seleccion = ts.id_seleccion
        ORDER BY ts.rojas DESC, ts.amarillas DESC, s.pais
        FOR XML PATH('Seleccion'), ROOT('Tarjetas_Por_Seleccion'), TYPE
    ) AS reporte_xml;
END;
GO

/* ---------------------------------------------------------------
   2. Tarjetas por jugador, con suspensiones activas por acumulacion
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Tarjetas_Por_Jugador
AS
BEGIN
    SET NOCOUNT ON;

    -- Partidos de cada jugador, numerados en orden cronologico.
    WITH participaciones AS
    (
        SELECT fj.id_jugador, p.id_partido, p.horario_local, p.resultado_final,
               ROW_NUMBER() OVER (PARTITION BY fj.id_jugador
                                  ORDER BY p.horario_local, p.id_partido) AS nro
        FROM dbo.Formacion_Jugador fj
        JOIN dbo.Formacion f ON f.id_formacion = fj.id_formacion
        JOIN dbo.Partido p   ON p.id_partido = f.id_partido
    ),
    -- Partidos en los que el jugador recibio amarilla (una vez por partido).
    amarillas_partido AS
    (
        SELECT pa.id_jugador, pa.nro
        FROM participaciones pa
        WHERE EXISTS (SELECT 1 FROM dbo.Incidencia i
                      WHERE i.id_partido = pa.id_partido
                        AND i.id_jugador = pa.id_jugador
                        AND i.tipo = 'AMONESTACION')
    ),
    -- Dos amarillas en partidos contiguos (nro y nro+1) => suspension para
    -- el partido siguiente (nro+2) de los que participa el jugador.
    suspensiones AS
    (
        SELECT a1.id_jugador, a2.nro + 1 AS nro_cumplimiento,
               a1.nro AS nro_amarilla_1, a2.nro AS nro_amarilla_2
        FROM amarillas_partido a1
        JOIN amarillas_partido a2
          ON a2.id_jugador = a1.id_jugador
         AND a2.nro = a1.nro + 1
    ),
    suspension_detalle AS
    (
        SELECT s.id_jugador,
               pc.id_partido AS id_partido_cumplimiento,
               pc.resultado_final AS resultado_cumplimiento,
               pa1.id_partido AS id_partido_amarilla_1,
               pa2.id_partido AS id_partido_amarilla_2
        FROM suspensiones s
        JOIN participaciones pa1 ON pa1.id_jugador = s.id_jugador AND pa1.nro = s.nro_amarilla_1
        JOIN participaciones pa2 ON pa2.id_jugador = s.id_jugador AND pa2.nro = s.nro_amarilla_2
        LEFT JOIN participaciones pc ON pc.id_jugador = s.id_jugador AND pc.nro = s.nro_cumplimiento
    ),
    tarjetas_jugador AS
    (
        SELECT j.id_jugador,
               SUM(CASE WHEN i.tipo = 'AMONESTACION' THEN 1 ELSE 0 END) AS amarillas,
               SUM(CASE WHEN i.tipo = 'EXPULSION'    THEN 1 ELSE 0 END) AS rojas
        FROM dbo.Jugador j
        JOIN dbo.Incidencia i ON i.id_jugador = j.id_jugador
        WHERE i.tipo IN ('AMONESTACION', 'EXPULSION')
        GROUP BY j.id_jugador
    )
    SELECT (
        SELECT s.pais AS [@seleccion],
               (SELECT j.nombre + N' ' + j.apellido AS [@jugador],
                       tj.amarillas                 AS [@amarillas],
                       tj.rojas                     AS [@rojas],
                       (SELECT sd.id_partido_amarilla_1 AS [@partido_amarilla_1],
                               sd.id_partido_amarilla_2 AS [@partido_amarilla_2],
                               sd.id_partido_cumplimiento AS [@partido_suspendido],
                               CASE WHEN sd.resultado_cumplimiento IS NULL
                                    THEN N'ACTIVA' ELSE N'CUMPLIDA' END AS [@estado]
                        FROM suspension_detalle sd
                        WHERE sd.id_jugador = j.id_jugador
                        ORDER BY sd.id_partido_amarilla_2
                        FOR XML PATH('Suspension'), TYPE) AS [Suspensiones]
                FROM tarjetas_jugador tj
                JOIN dbo.Jugador j ON j.id_jugador = tj.id_jugador
                WHERE j.id_seleccion = s.id_seleccion
                  AND (tj.amarillas > 0 OR tj.rojas > 0)
                ORDER BY tj.rojas DESC, tj.amarillas DESC, j.apellido, j.nombre
                FOR XML PATH('Jugador'), TYPE) AS [Jugadores]
        FROM dbo.Seleccion s
        WHERE EXISTS (SELECT 1 FROM tarjetas_jugador tj
                      JOIN dbo.Jugador j ON j.id_jugador = tj.id_jugador
                      WHERE j.id_seleccion = s.id_seleccion)
        ORDER BY s.pais
        FOR XML PATH('Seleccion'), ROOT('Tarjetas_Por_Jugador'), TYPE
    ) AS reporte_xml;
END;
GO
