/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comision: Com: 01-2900
    Grupo 01:
    - Caro, Nicolas Dario
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodriguez Elias Uriel

    Fecha: 03/11/2026

    Descripcion:
    Test de importacion.Importar_Incidencia_CSV.
    Ejecuta la importacion desde match_events.csv y verifica que se
    registren las incidencias esperadas: goles, asistencias, tarjetas,
    penales y revisiones VAR.

    Requisitos previos:
      - Tener cargadas las tablas dbo.Partido, dbo.Seleccion y dbo.Jugador.
      - Tener el archivo Archivos_Importacion/match_events.csv.
      - Tener el ABM abm.Incidencia_Alta y la tabla dbo.Incidencia
        con los tipos extendidos.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Importar_Incidencia_CSV_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST IMPORTAR INCIDENCIA CSV =====';

    /* ------------------------------------------------------------------
       1. Contar incidencias previas.
    ------------------------------------------------------------------ */
    DECLARE @previas INT = (SELECT COUNT(*) FROM dbo.Incidencia);
    PRINT 'Incidencias previas: ' + CAST(@previas AS VARCHAR(10));

    /* ------------------------------------------------------------------
       2. Ejecutar la importacion desde el CSV.
    ------------------------------------------------------------------ */
    EXEC importacion.Importar_Incidencia_CSV
        @archivo = N'C:\Users\elias\Downloads\TP BDA\TP_BBDDA_COM2900_GRUPO_1\Archivos_Importacion\match_events.csv';

    /* ------------------------------------------------------------------
       3. Verificar que se hayan insertado incidencias.
    ------------------------------------------------------------------ */
    DECLARE @total INT = (SELECT COUNT(*) FROM dbo.Incidencia);
    DECLARE @insertadas INT = @total - @previas;

    IF @insertadas > 0
        PRINT 'OK - Se importaron ' + CAST(@insertadas AS VARCHAR(10)) + ' incidencias.';
    ELSE
        PRINT 'ERROR - No se importo ninguna incidencia.';

    /* ------------------------------------------------------------------
       4. Verificar distribucion por tipo.
    ------------------------------------------------------------------ */
    SELECT
        tipo,
        COUNT(*) AS cantidad
    FROM dbo.Incidencia
    GROUP BY tipo
    ORDER BY tipo;

    /* ------------------------------------------------------------------
       5. Verificar que los goles tengan asistencia cuando corresponda.
    ------------------------------------------------------------------ */
    SELECT
        'Goles con asistencia' AS concepto,
        COUNT(*) AS cantidad
    FROM dbo.Incidencia
    WHERE tipo = 'GOL'
      AND id_jugador_involucrado IS NOT NULL

    UNION ALL

    SELECT
        'Goles sin asistencia' AS concepto,
        COUNT(*) AS cantidad
    FROM dbo.Incidencia
    WHERE tipo = 'GOL'
      AND id_jugador_involucrado IS NULL;

    /* ------------------------------------------------------------------
       6. Segunda ejecucion: debe actualizar / ignorar duplicados
       sin generar registros repetidos. Se espera que la cantidad total
       no se duplique.
    ------------------------------------------------------------------ */
    EXEC importacion.Importar_Incidencia_CSV
        @archivo = N'C:\Users\elias\Downloads\TP BDA\TP_BBDDA_COM2900_GRUPO_1\Archivos_Importacion\match_events.csv';

    DECLARE @total_despues INT = (SELECT COUNT(*) FROM dbo.Incidencia);

    IF @total_despues = @total
        PRINT 'OK - La segunda ejecucion no genero duplicados.';
    ELSE
        PRINT 'ADVERTENCIA - La segunda ejecucion cambio la cantidad de incidencias.';

    SELECT @total AS total_despues_segunda_ejecucion;
END;
GO

EXEC test.Importar_Incidencia_CSV_Test;
GO
