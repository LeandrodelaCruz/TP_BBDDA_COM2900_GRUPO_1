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
    Test de negocio.Simular_Partido con un partido real.
    Le pasas un id_partido, se simula el partido (incidencias y sustituciones
    cargadas con abm.Incidencia_Alta y abm.Sustitucion_Alta) y se muestra
    el resultado. Los registros NO se borran.

    Requisitos previos:
      - El partido existe, tiene resultado_final 'N-N' y 11 titulares
        cargados para ambas selecciones.
      - El partido no tiene incidencias ni sustituciones previas.

    Uso: cambiar el valor de @id_partido al final del script.
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'test') IS NULL
    EXEC (N'CREATE SCHEMA test');
GO

CREATE OR ALTER PROCEDURE test.Simular_Partido_Test
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST SIMULAR PARTIDO =====';
    PRINT 'Partido: ' + CAST(@id_partido AS VARCHAR(10));

    /* ------------------------------------------------------------------
       1. Datos del partido antes de simular.
    ------------------------------------------------------------------ */
    SELECT p.id_partido, p.fase, p.resultado_final,
           s1.pais AS local, s2.pais AS visitante
    FROM dbo.Partido p
    JOIN dbo.Seleccion s1 ON s1.id_seleccion = p.id_seleccion_1
    JOIN dbo.Seleccion s2 ON s2.id_seleccion = p.id_seleccion_2
    WHERE p.id_partido = @id_partido;

    /* ------------------------------------------------------------------
       2. Simular (carga incidencias y sustituciones).
    ------------------------------------------------------------------ */
    EXEC negocio.Simular_Partido @id_partido = @id_partido;

    /* ------------------------------------------------------------------
       3. Incidencias cargadas, en orden cronologico.
    ------------------------------------------------------------------ */
    PRINT '--- Incidencias ---';
    SELECT i.minuto, i.periodo, i.tipo,
           j.nombre + N' ' + j.apellido AS jugador,
           s.pais AS seleccion,
           jr.nombre + N' ' + jr.apellido AS involucrado,
           i.motivo
    FROM dbo.Incidencia i
    JOIN dbo.Jugador j ON j.id_jugador = i.id_jugador
    JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
    LEFT JOIN dbo.Jugador jr ON jr.id_jugador = i.id_jugador_involucrado
    WHERE i.id_partido = @id_partido
    ORDER BY i.minuto, i.id_incidencia;

    /* ------------------------------------------------------------------
       4. Sustituciones cargadas, en orden cronologico.
    ------------------------------------------------------------------ */
    PRINT '--- Sustituciones ---';
    SELECT su.minuto, su.periodo, su.numero_ventana,
           sa.nombre + N' ' + sa.apellido AS sale,
           en.nombre + N' ' + en.apellido AS entra,
           se.pais AS seleccion,
           su.motivo
    FROM dbo.Sustitucion su
    JOIN dbo.Jugador sa ON sa.id_jugador = su.id_jugador_sale
    JOIN dbo.Jugador en ON en.id_jugador = su.id_jugador_entra
    JOIN dbo.Seleccion se ON se.id_seleccion = sa.id_seleccion
    WHERE su.id_partido = @id_partido
    ORDER BY su.minuto, su.id_sustitucion;

    /* ------------------------------------------------------------------
       5. Verificaciones.
    ------------------------------------------------------------------ */
    IF EXISTS (SELECT 1 FROM dbo.Incidencia
               WHERE id_partido = @id_partido AND tipo IN ('AMONESTACION', 'EXPULSION'))
        PRINT 'OK - Hay al menos una AMONESTACION o EXPULSION.';
    ELSE
        PRINT 'ERROR - No hay AMONESTACION ni EXPULSION.';

    SELECT
        (SELECT COUNT(*) FROM dbo.Incidencia WHERE id_partido = @id_partido) AS total_incidencias,
        (SELECT COUNT(*) FROM dbo.Sustitucion WHERE id_partido = @id_partido) AS total_sustituciones;
END;
GO

/* Cambiar por el id_partido a simular */
EXEC test.Simular_Partido_Test @id_partido = 1;
GO
