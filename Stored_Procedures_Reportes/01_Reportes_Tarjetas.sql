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
   0. Vistas para Power BI (consultables como tablas)
   Mismo criterio de conteo que los procedimientos de este archivo.
   --------------------------------------------------------------- */
CREATE OR ALTER VIEW reportes.v_Tarjetas_Por_Jugador
AS
    SELECT j.id_jugador,
           j.nombre + N' ' + j.apellido AS jugador,
           s.id_seleccion,
           s.pais AS seleccion,
           j.apellido,
           j.nombre,
           SUM(CASE WHEN i.tipo = 'AMONESTACION' THEN 1 ELSE 0 END) AS amarillas,
           SUM(CASE WHEN i.tipo = 'EXPULSION'    THEN 1 ELSE 0 END) AS rojas
    FROM dbo.Incidencia i
    JOIN dbo.Jugador j   ON j.id_jugador = i.id_jugador
    JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
    WHERE i.tipo IN ('AMONESTACION', 'EXPULSION')
    GROUP BY j.id_jugador, j.nombre, j.apellido, s.id_seleccion, s.pais;
GO

CREATE OR ALTER VIEW reportes.v_Tarjetas_Por_Seleccion
AS
    SELECT s.id_seleccion,
           s.pais AS seleccion,
           COALESCE(SUM(tj.amarillas), 0) AS amarillas,
           COALESCE(SUM(tj.rojas), 0)     AS rojas
    FROM dbo.Seleccion s
    LEFT JOIN reportes.v_Tarjetas_Por_Jugador tj ON tj.id_seleccion = s.id_seleccion
    GROUP BY s.id_seleccion, s.pais;
GO

/* ---------------------------------------------------------------
   1. Tarjetas por seleccion
   --------------------------------------------------------------- */
CREATE OR ALTER PROCEDURE reportes.Tarjetas_Por_Seleccion
AS
BEGIN
    SET NOCOUNT ON;

    SELECT ts.seleccion,
           ts.amarillas,
           ts.rojas
    FROM reportes.v_Tarjetas_Por_Seleccion ts
    WHERE ts.amarillas > 0 OR ts.rojas > 0
    ORDER BY ts.rojas DESC, ts.amarillas DESC, ts.seleccion;
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
    )
    SELECT tj.id_jugador,
           tj.seleccion,
           tj.jugador,
           tj.amarillas,
           tj.rojas,
           sd.id_partido_amarilla_1,
           sd.id_partido_amarilla_2,
           sd.id_partido_cumplimiento AS partido_suspendido,
           CASE WHEN sd.id_partido_amarilla_2 IS NULL THEN NULL
                WHEN sd.resultado_cumplimiento IS NULL THEN N'ACTIVA'
                ELSE N'CUMPLIDA' END AS estado_suspension
    FROM reportes.v_Tarjetas_Por_Jugador tj
    LEFT JOIN suspension_detalle sd ON sd.id_jugador = tj.id_jugador
    WHERE tj.amarillas > 0 OR tj.rojas > 0
    ORDER BY tj.seleccion, tj.rojas DESC, tj.amarillas DESC, tj.apellido, tj.nombre, sd.id_partido_amarilla_2;
END;
GO
