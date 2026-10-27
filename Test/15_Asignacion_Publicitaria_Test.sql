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
    Script de testing COMPLETO para todos los procedimientos de Asignacion Publicitaria.
    Incluye borrado inicial, datos de prueba y pruebas exitosas/validaciones fallidas.
    Cada caso de prueba define sus variables dentro de su propio lote (GO) para poder
    ejecutarse individualmente o corriendo todo el archivo.
    
    PROCEDIMIENTOS A PROBAR:
    - Asignacion_Publicitaria_Alta
    - Asignacion_Publicitaria_GetById
    - Asignacion_Publicitaria_GetByPartido
    - Asignacion_Publicitaria_GetByAnunciante
    - Asignacion_Publicitaria_TotalesPorAnunciante
    - Asignacion_Publicitaria_Modificacion
    - Asignacion_Publicitaria_Baja
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Asignacion_Publicitaria_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores ===';

    -- Eliminar asignaciones de partidos de prueba
    DELETE FROM dbo.Asignacion_Publicitaria
    WHERE id_partido IN (
        SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB'
    );

    -- Eliminar partidos de prueba
    DELETE FROM dbo.Partido
    WHERE resultado_final = N'TEST-ASIGNACION-PUB';

    -- Eliminar piezas publicitarias de prueba
    DELETE FROM dbo.Pieza_Para_Region
    WHERE id_pieza IN (
        SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre LIKE N'%Test%Asignacion%'
    );

    DELETE FROM dbo.Pieza_Publicitaria
    WHERE nombre LIKE N'%Test%Asignacion%';

    -- Eliminar campanias de prueba
    DELETE FROM dbo.Campania
    WHERE descripcion LIKE N'%Test%Asignacion%';

    -- Eliminar anunciante de prueba
    DELETE FROM dbo.Anunciante
    WHERE nombre LIKE N'%Test%Asignacion%';

    -- Eliminar sede de prueba
    DELETE FROM dbo.Sede
    WHERE nombre_estadio LIKE N'%Testing%Asignacion%';

    -- Eliminar selecciones de prueba
    DELETE FROM dbo.Seleccion
    WHERE pais LIKE N'Seleccion Test Asignacion%';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIoN: datos minimos de apoyo
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    -- Sede de prueba
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing Asignacion', N'Ciudad Test', N'Pais Test', 50000, 'UTC-03:00');

    DECLARE @id_sede_test INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Asignacion');

    -- Selecciones de prueba
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Seleccion Test Asignacion 1', N'TEST', 'A');

    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Seleccion Test Asignacion 2', N'TEST', 'A');

    DECLARE @id_sel1_test INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test Asignacion 1');
    DECLARE @id_sel2_test INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test Asignacion 2');

    -- Partido de prueba
    INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico, id_seleccion_1, id_seleccion_2)
    VALUES (@id_sede_test, '2026-06-20', '2026-06-20 18:00:00', '2026-06-20 21:00:00', 'GRUPOS', N'TEST-ASIGNACION-PUB', 30000, @id_sel1_test, @id_sel2_test);

    -- Anunciante de prueba
    INSERT INTO dbo.Anunciante (nombre)
    VALUES (N'Anunciante Test Asignacion');

    DECLARE @id_anunciante_test INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test Asignacion');

    -- Campanias de prueba
    INSERT INTO dbo.Campania (id_anunciante, descripcion)
    VALUES (@id_anunciante_test, N'Campaña Test Asignacion 1');

    INSERT INTO dbo.Campania (id_anunciante, descripcion)
    VALUES (@id_anunciante_test, N'Campaña Test Asignacion 2');

    DECLARE @id_campania1 INT = (SELECT id_campania FROM dbo.Campania WHERE descripcion = N'Campaña Test Asignacion 1');
    DECLARE @id_campania2 INT = (SELECT id_campania FROM dbo.Campania WHERE descripcion = N'Campaña Test Asignacion 2');

    -- Piezas publicitarias de prueba
    INSERT INTO dbo.Pieza_Publicitaria (id_campania, nombre, contenido, idioma)
    VALUES (@id_campania1, N'Pieza Test Asignacion 1', N'Contenido pieza 1', N'Español');

    INSERT INTO dbo.Pieza_Publicitaria (id_campania, nombre, contenido, idioma)
    VALUES (@id_campania1, N'Pieza Test Asignacion 2', N'Contenido pieza 2', N'Ingles');

    INSERT INTO dbo.Pieza_Publicitaria (id_campania, nombre, contenido, idioma)
    VALUES (@id_campania2, N'Pieza Test Asignacion 3', N'Contenido pieza 3', N'Portugues');

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: ASIGNACIoN PUBLICITARIA
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Asignacion_Publicitaria';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Insercion exitosa - Asignacion espacio 1
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Insercion exitosa - Espacio 1 ---';

    DECLARE @id_partido_test_b7 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_pieza1_b7 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 1');
    DECLARE @id_asignacion1 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b7,
            @id_pieza = @id_pieza1_b7,
            @numero_espacio = 1,
            @costo_aplicado = 50000.00,
            @id_asignacion = @id_asignacion1 OUTPUT;

        PRINT 'OK - Asignacion insertada con ID: ' + CAST(@id_asignacion1 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 2: Insercion exitosa - Asignacion espacio 2
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Insercion exitosa - Espacio 2 ---';

    DECLARE @id_partido_test_b8 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_pieza2_b8 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 2');
    DECLARE @id_asignacion2 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b8,
            @id_pieza = @id_pieza2_b8,
            @numero_espacio = 2,
            @costo_aplicado = 45000.00,
            @id_asignacion = @id_asignacion2 OUTPUT;

        PRINT 'OK - Asignacion insertada con ID: ' + CAST(@id_asignacion2 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 3: Insercion exitosa - Asignacion espacio 3 (misma pieza, otro partido)
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Insercion exitosa - Espacio 3 ---';

    DECLARE @id_partido_test_b9 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_pieza3 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 3');
    DECLARE @id_asignacion3 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b9,
            @id_pieza = @id_pieza3,
            @numero_espacio = 3,
            @costo_aplicado = 60000.00,
            @id_asignacion = @id_asignacion3 OUTPUT;

        PRINT 'OK - Asignacion insertada con ID: ' + CAST(@id_asignacion3 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 4: Validacion fallida - Numero de espacio invalido (> 4)
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 4: Validacion fallida - Numero de espacio invalido (> 4) ---';

    DECLARE @id_partido_test_b10 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_pieza1_b10 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 1');
    DECLARE @id_asignacion_fail INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b10,
            @id_pieza = @id_pieza1_b10,
            @numero_espacio = 5,
            @costo_aplicado = 50000.00,
            @id_asignacion = @id_asignacion_fail OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 5: Validacion fallida - Costo negativo
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 5: Validacion fallida - Costo negativo ---';

    DECLARE @id_partido_test_b11 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_pieza1_b11 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 1');
    DECLARE @id_asignacion_fail2 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b11,
            @id_pieza = @id_pieza1_b11,
            @numero_espacio = 4,
            @costo_aplicado = -100.00,
            @id_asignacion = @id_asignacion_fail2 OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 6: Validacion fallida - Espacio ya ocupado en el partido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 6: Validacion fallida - Espacio ya ocupado ---';

    DECLARE @id_partido_test_b12 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_pieza2_b12 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 2');
    DECLARE @id_asignacion_fail3 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b12,
            @id_pieza = @id_pieza2_b12,
            @numero_espacio = 1,
            @costo_aplicado = 70000.00,
            @id_asignacion = @id_asignacion_fail3 OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 7: Validacion fallida - Partido inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 7: Validacion fallida - Partido inexistente ---';

    DECLARE @id_pieza1_b13 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test Asignacion 1');
    DECLARE @id_asignacion_fail4 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = 999999,
            @id_pieza = @id_pieza1_b13,
            @numero_espacio = 4,
            @costo_aplicado = 70000.00,
            @id_asignacion = @id_asignacion_fail4 OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 8: Validacion fallida - Pieza inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 8: Validacion fallida - Pieza inexistente ---';

    DECLARE @id_partido_test_b14 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');
    DECLARE @id_asignacion_fail5 INT;

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Alta
            @id_partido = @id_partido_test_b14,
            @id_pieza = 999999,
            @numero_espacio = 4,
            @costo_aplicado = 70000.00,
            @id_asignacion = @id_asignacion_fail5 OUTPUT;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 9: GET por ID
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 9: GET por ID ---';

    DECLARE @id_asignacion_get INT = (
        SELECT TOP 1 id_asignacion
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB')
        ORDER BY id_asignacion
    );

    IF @id_asignacion_get IS NOT NULL
    BEGIN
        EXEC abm.Asignacion_Publicitaria_GetById @id_asignacion = @id_asignacion_get;
    END
    ELSE
        PRINT 'No hay asignaciones para consultar';

    -- ---------------------------------------------------------
    -- CASO 10: GET por partido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 10: GET por partido ---';

    DECLARE @id_partido_get INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB');

    IF @id_partido_get IS NOT NULL
    BEGIN
        EXEC abm.Asignacion_Publicitaria_GetByPartido @id_partido = @id_partido_get;
    END
    ELSE
        PRINT 'No hay partido de prueba para consultar';

    -- ---------------------------------------------------------
    -- CASO 11: GET por anunciante
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 11: GET por anunciante ---';

    DECLARE @id_anunciante_get INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test Asignacion');

    IF @id_anunciante_get IS NOT NULL
    BEGIN
        EXEC abm.Asignacion_Publicitaria_GetByAnunciante @id_anunciante = @id_anunciante_get;
    END
    ELSE
        PRINT 'No hay anunciante de prueba para consultar';

    -- ---------------------------------------------------------
    -- CASO 12: GET totales por anunciante
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 12: GET totales por anunciante ---';

    DECLARE @id_anunciante_total INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test Asignacion');

    IF @id_anunciante_total IS NOT NULL
    BEGIN
        EXEC abm.Asignacion_Publicitaria_TotalesPorAnunciante @id_anunciante = @id_anunciante_total;
    END
    ELSE
        PRINT 'No hay anunciante de prueba para totales';

    -- ---------------------------------------------------------
    -- CASO 13: UPDATE - Cambiar costo
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 13: UPDATE - Cambiar costo ---';

    DECLARE @id_asignacion_update INT = (
        SELECT TOP 1 id_asignacion
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB')
        ORDER BY id_asignacion
    );

    IF @id_asignacion_update IS NOT NULL
    BEGIN
        BEGIN TRY
            PRINT 'Costo antes:';
            EXEC abm.Asignacion_Publicitaria_GetById @id_asignacion = @id_asignacion_update;

            EXEC abm.Asignacion_Publicitaria_Modificacion
                @id_asignacion = @id_asignacion_update,
                @costo_aplicado = 75000.00;

            PRINT 'Costo despues:';
            EXEC abm.Asignacion_Publicitaria_GetById @id_asignacion = @id_asignacion_update;
        END TRY
        BEGIN CATCH
            PRINT 'ERROR: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay asignaciones para actualizar';

    -- ---------------------------------------------------------
    -- CASO 14: UPDATE fallido - ID inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 14: UPDATE fallido - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Modificacion
            @id_asignacion = 999999,
            @costo_aplicado = 50000.00;

        PRINT 'ERROR: Deberia haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 15: UPDATE fallido - Costo negativo
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 15: UPDATE fallido - Costo negativo ---';

    DECLARE @id_asignacion_update_neg INT = (
        SELECT TOP 1 id_asignacion
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB')
        ORDER BY id_asignacion
    );

    IF @id_asignacion_update_neg IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC abm.Asignacion_Publicitaria_Modificacion
                @id_asignacion = @id_asignacion_update_neg,
                @costo_aplicado = -50000.00;

            PRINT 'ERROR: Deberia haber fallado';
        END TRY
        BEGIN CATCH
            PRINT 'OK - Validacion correcta: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay asignaciones para actualizar';

    -- ---------------------------------------------------------
    -- CASO 16: DELETE - Eliminar asignacion
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 16: DELETE - Eliminar asignacion ---';

    DECLARE @id_asignacion_delete INT = (
        SELECT TOP 1 id_asignacion
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ASIGNACION-PUB')
        ORDER BY id_asignacion DESC
    );

    IF @id_asignacion_delete IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC abm.Asignacion_Publicitaria_Baja @id_asignacion = @id_asignacion_delete;

            PRINT 'OK - Asignacion eliminada';

            IF NOT EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_asignacion = @id_asignacion_delete)
                PRINT 'CONFIRMADO: Asignacion ya no existe en la BD';
            ELSE
                PRINT 'ERROR: Asignacion aun existe';
        END TRY
        BEGIN CATCH
            PRINT 'ERROR: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay asignaciones para eliminar';

    -- ---------------------------------------------------------
    -- CASO 17: DELETE fallido - ID inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 17: DELETE fallido - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Asignacion_Publicitaria_Baja @id_asignacion = 999999;

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

EXEC test.Asignacion_Publicitaria_Test;
GO
