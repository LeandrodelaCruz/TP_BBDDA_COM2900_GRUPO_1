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
    Script de testing COMPLETO para todos los procedimientos de Sancion Arbitral
    Incluye borrado inicial, datos de prueba y pruebas exitosas/validaciones fallidas.
    Cada caso de prueba define sus variables dentro de su propio lote (GO) para poder
    ejecutarse individualmente o corriendo todo el archivo.
    
    PROCEDIMIENTOS A PROBAR:
    - Sancion_Arbitral_Alta (con validaciones)
    - Sancion_Arbitral_GetById
    - Sancion_Arbitral_GetByArbitro
    - Sancion_Arbitral_GetByPartido
    - Sancion_Arbitral_Modificacion
    - Sancion_Arbitral_Baja
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Sancion_Arbitral_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores ===';

    -- 1. Eliminar sanciones de prueba (dependen de partido y arbitro)
    DELETE FROM dbo.Sancion_Arbitral
    WHERE id_partido IN (
        SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB'
    )
    OR id_arbitro IN (
        SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion'
    );

    -- 2. Eliminar designaciones de prueba (dependen de partido y arbitro)
    DELETE FROM dbo.Designacion_Arbitral
    WHERE id_partido IN (
        SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB'
    )
    OR id_arbitro IN (
        SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion'
    );

    -- 3. Eliminar el partido de prueba
    DELETE FROM dbo.Partido
    WHERE resultado_final = N'TEST-SANCION-ARB';

    -- 5. Eliminar arbitros de prueba
    DELETE FROM dbo.Arbitro
    WHERE apellido = N'Test Sancion';

    -- 6. Eliminar la sede de prueba
    DELETE FROM dbo.Sede
    WHERE nombre_estadio = N'Estadio Testing Sancion';

    -- 7. Finalmente, eliminar las selecciones de prueba
    DELETE FROM dbo.Seleccion
    WHERE pais LIKE N'Seleccion Test Sancion%';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIoN: datos minimos de apoyo
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    -- Sede de prueba
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing Sancion', N'Ciudad Test', N'Pais Test', 50000, 'UTC-03:00');

    DECLARE @id_sede_test INT = (SELECT TOP 1 id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Sancion' ORDER BY id_sede DESC);

    -- Selecciones de prueba
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Seleccion Test Sancion 1', N'TEST', 'A');

    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Seleccion Test Sancion 2', N'TEST', 'A');

    DECLARE @id_sel1_test INT = (SELECT TOP 1 id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test Sancion 1' ORDER BY id_seleccion DESC);
    DECLARE @id_sel2_test INT = (SELECT TOP 1 id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test Sancion 2' ORDER BY id_seleccion DESC);

    -- Partido de prueba
    INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico, id_seleccion_1, id_seleccion_2)
    VALUES (@id_sede_test, '2026-06-10', '2026-06-10 18:00:00', '2026-06-10 21:00:00', 'GRUPOS', N'TEST-SANCION-ARB', 30000, @id_sel1_test, @id_sel2_test);

    DECLARE @id_partido_test_b7 INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);

    -- arbitros de prueba
    INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
    VALUES (N'arbitro1', N'Test Sancion', '1980-01-01', N'Pais Test', N'PRINCIPAL', N'Español');

    INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
    VALUES (N'arbitro2', N'Test Sancion', '1985-01-01', N'Pais Test', N'ASISTENTE', N'Ingles');

    INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
    VALUES (N'arbitro3', N'Test Sancion', '1982-01-01', N'Pais Test', N'VAR', N'Español, Ingles');

    DECLARE @id_arbitro_designado_b8 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_arbitro_no_designado INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro2' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_arbitro_sin_partido_b8 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro3' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_partido_test_b8 INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);

    -- Designacion arbitral para el partido de prueba
    INSERT INTO dbo.Designacion_Arbitral (id_partido, id_arbitro, rol_arbitro)
    VALUES (@id_partido_test_b8, @id_arbitro_designado_b8, N'PRINCIPAL');

    INSERT INTO dbo.Designacion_Arbitral (id_partido, id_arbitro, rol_arbitro)
    VALUES (@id_partido_test_b8, @id_arbitro_no_designado, N'ASISTENTE');

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: SANCIoN ARBITRAL
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Sancion_Arbitral';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Insercion exitosa - Sancion con partido designado
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Insercion exitosa - Sancion con partido designado ---';

    DECLARE @id_arbitro_designado_b10 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_partido_test_b10 INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);
    DECLARE @id_sancion1 INT;

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Alta
            @id_arbitro = @id_arbitro_designado_b10,
            @id_partido = @id_partido_test_b10,
            @fecha = '2026-06-10',
            @motivo = N'Falta grave en el partido',
            @tipo_sancion = 'SUSPENSION',
            @id_sancion = @id_sancion1 OUTPUT;

        PRINT 'OK - Sancion insertada con ID: ' + CAST(@id_sancion1 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 2: Insercion exitosa - Sancion sin partido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Insercion exitosa - Sancion sin partido ---';

    DECLARE @id_arbitro_sin_partido_b11 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro3' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_sancion2 INT;

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Alta
            @id_arbitro = @id_arbitro_sin_partido_b11,
            @id_partido = NULL,
            @fecha = '2026-06-01',
            @motivo = N'Comportamiento inapropiado fuera del partido',
            @tipo_sancion = 'ADVERTENCIA',
            @id_sancion = @id_sancion2 OUTPUT;

        PRINT 'OK - Sancion insertada con ID: ' + CAST(@id_sancion2 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 3: Insercion exitosa - Otra sancion para el mismo arbitro
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Insercion exitosa - Otra sancion mismo arbitro ---';

    DECLARE @id_arbitro_designado_b12 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_partido_test_b12 INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);
    DECLARE @id_sancion3 INT;

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Alta
            @id_arbitro = @id_arbitro_designado_b12,
            @id_partido = @id_partido_test_b12,
            @fecha = '2026-06-10',
            @motivo = N'Llegada tardia al campo de juego',
            @tipo_sancion = 'MULTA',
            @id_sancion = @id_sancion3 OUTPUT;

        PRINT 'OK - Sancion insertada con ID: ' + CAST(@id_sancion3 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 4: Validacion fallida - arbitro no designado para el partido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 6: Validacion fallida - arbitro no designado ---';

    DECLARE @id_arbitro_sin_partido_b13 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro3' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_partido_test_b13 INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);
    DECLARE @id_sancion_fail1 INT;

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Alta
            @id_arbitro = @id_arbitro_sin_partido_b13,
            @id_partido = @id_partido_test_b13,
            @fecha = '2026-06-10',
            @motivo = N'arbitro no designado',
            @tipo_sancion = 'SUSPENSION',
            @id_sancion = @id_sancion_fail1 OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 5: Validacion fallida - Partido inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 5: Validacion fallida - Partido inexistente ---';

    DECLARE @id_arbitro_designado_b14 INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
    DECLARE @id_sancion_fail2 INT;

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Alta
            @id_arbitro = @id_arbitro_designado_b14,
            @id_partido = 999999,
            @fecha = '2026-06-10',
            @motivo = N'Partido inexistente',
            @tipo_sancion = 'SUSPENSION',
            @id_sancion = @id_sancion_fail2 OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 6: GET por ID
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 9: GET por ID ---';

    DECLARE @id_sancion_get INT = (
        SELECT TOP 1 id_sancion
        FROM dbo.Sancion_Arbitral
        WHERE id_arbitro IN (SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion')
        ORDER BY id_sancion
    );

    IF @id_sancion_get IS NOT NULL
    BEGIN
        EXEC abm.Sancion_Arbitral_GetById @id_sancion = @id_sancion_get;
    END
    ELSE
        PRINT 'No hay sanciones para consultar';

    -- ---------------------------------------------------------
    -- CASO 7: GET por arbitro
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 10: GET por arbitro ---';

    DECLARE @id_arbitro_get INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'arbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);

    IF @id_arbitro_get IS NOT NULL
    BEGIN
        EXEC abm.Sancion_Arbitral_GetByArbitro @id_arbitro = @id_arbitro_get;
    END
    ELSE
        PRINT 'No hay arbitro de prueba para consultar';

    -- ---------------------------------------------------------
    -- CASO 8: GET por partido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 11: GET por partido ---';

    DECLARE @id_partido_get INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);

    IF @id_partido_get IS NOT NULL
    BEGIN
        EXEC abm.Sancion_Arbitral_GetByPartido @id_partido = @id_partido_get;
    END
    ELSE
        PRINT 'No hay partido de prueba para consultar';

    -- ---------------------------------------------------------
    -- CASO 9: UPDATE - Cambiar motivo
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 9: UPDATE - Cambiar motivo ---';

    DECLARE @id_sancion_update INT = (
        SELECT TOP 1 id_sancion
        FROM dbo.Sancion_Arbitral
        WHERE id_arbitro IN (SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion')
        ORDER BY id_sancion
    );

    IF @id_sancion_update IS NOT NULL
    BEGIN
        BEGIN TRY
            PRINT 'Datos antes:';
            EXEC abm.Sancion_Arbitral_GetById @id_sancion = @id_sancion_update;

            EXEC abm.Sancion_Arbitral_Modificacion
                @id_sancion = @id_sancion_update,
                @motivo = N'Motivo actualizado por revision';

            PRINT 'Datos despues:';
            EXEC abm.Sancion_Arbitral_GetById @id_sancion = @id_sancion_update;
        END TRY
        BEGIN CATCH
            PRINT 'ERROR: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay sanciones para actualizar';

    -- ---------------------------------------------------------
    -- CASO 10: UPDATE fallido - ID inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 10: UPDATE fallido - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Modificacion
            @id_sancion = 999999,
            @motivo = N'Sancion inexistente';

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 11: DELETE - Eliminar sancion
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 11: DELETE - Eliminar sancion ---';

    DECLARE @id_sancion_delete INT = (
        SELECT TOP 1 id_sancion
        FROM dbo.Sancion_Arbitral
        WHERE id_arbitro IN (SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion')
        ORDER BY id_sancion DESC
    );

    IF @id_sancion_delete IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC abm.Sancion_Arbitral_Baja @id_sancion = @id_sancion_delete;

            PRINT 'OK - Sancion eliminada';

            IF NOT EXISTS (SELECT 1 FROM dbo.Sancion_Arbitral WHERE id_sancion = @id_sancion_delete)
                PRINT 'CONFIRMADO: Sancion ya no existe en la BD';
            ELSE
                PRINT 'ERROR: Sancion aun existe';
        END TRY
        BEGIN CATCH
            PRINT 'ERROR: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay sanciones para eliminar';

    -- ---------------------------------------------------------
    -- CASO 13: DELETE fallido - ID inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 12: DELETE fallido - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Sancion_Arbitral_Baja @id_sancion = 999999;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    PRINT '';
    PRINT '=============================================';
    PRINT ' FIN DE PRUEBAS';
    PRINT '=============================================';
END;
GO

EXEC test.Sancion_Arbitral_Test;
GO
