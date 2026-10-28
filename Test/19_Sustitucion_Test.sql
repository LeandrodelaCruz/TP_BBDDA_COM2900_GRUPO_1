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
    Script de testing COMPLETO para todos los procedimientos de Sustitucion
    Incluye pruebas exitosas y pruebas de validaciones fallidas
    
    PROCEDIMIENTOS A PROBAR:
    - Sustitucion_Alta (con validaciones)
    - Sustitucion_GetById
    - Sustitucion_GetByPartido
    - Sustitucion_Modificacion
    - Sustitucion_Baja
    
    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Sustitucion_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       =========================================================
       Se eliminan en orden inverso respetando las FK:
       1. Sustituciones
       2. Formacion_Jugador
       3. Formacion
       4. Sustitucion (por si acaso)
       6. Partido
       7. Jugador (de selecciones test)
       8. Seleccion
       9. Sede
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores ===';

    -- Eliminar sustituciones de pruebas anteriores
    DELETE FROM dbo.Sustitucion 
    WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');

    -- Eliminar formacion_jugador
    DELETE FROM dbo.Formacion_Jugador 
    WHERE id_formacion IN (
        SELECT id_formacion FROM dbo.Formacion 
        WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION')
    );

    -- Eliminar formaciones
    DELETE FROM dbo.Formacion 
    WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');

    -- Eliminar partidos
    DELETE FROM dbo.Partido 
    WHERE resultado_final = N'TEST-SUSTITUCION';

    -- Eliminar jugadores
    DELETE FROM dbo.Jugador 
    WHERE id_seleccion IN (
        SELECT id_seleccion FROM dbo.Seleccion 
        WHERE pais IN (N'Seleccion Test 1', N'Seleccion Test 2')
    );

    -- Eliminar selecciones
    DELETE FROM dbo.Seleccion 
    WHERE pais IN (N'Seleccion Test 1', N'Seleccion Test 2');

    -- Eliminar sede
    DELETE FROM dbo.Sede 
    WHERE nombre_estadio = N'Estadio Testing Sustitucion';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIoN: datos minimos de apoyo
       =========================================================
       Resultado esperado: se insertan (si no existen) una sede,
       dos selecciones, jugadores titulares y suplentes por seleccion,
       un partido, la relacion partido-seleccion y las formaciones.
       Todo con IDs conocidos para poder referenciarlos en las pruebas.
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    -- Sede de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Sustitucion')
        INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
        VALUES (N'Estadio Testing Sustitucion', N'Ciudad Test', N'Pais Test', 50000, 'UTC-03:00');

    -- Selecciones de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Seleccion Test 1')
        INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
        VALUES (N'Seleccion Test 1', N'TEST', 'A');

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Seleccion Test 2')
        INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
        VALUES (N'Seleccion Test 2', N'TEST', 'A');

    DECLARE @id_sede_test    INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Sustitucion');
    DECLARE @id_sel_test1_b6    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test 1');
    DECLARE @id_sel_test2    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test 2');

    -- Jugadores TITULARES de Seleccion 1
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel1')
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test1_b6, N'Titular1Sel1', N'Test', '1990-01-01', N'Club Test', N'Delantero', 9);

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Titular2Sel1')
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test1_b6, N'Titular2Sel1', N'Test', '1991-01-01', N'Club Test', N'Mediocampista', 8);

    -- Jugadores SUPLENTES de Seleccion 1
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1')
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test1_b6, N'Suplente1Sel1', N'Test', '1995-01-01', N'Club Test', N'Delantero', 18);

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1')
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test1_b6, N'Suplente2Sel1', N'Test', '1996-01-01', N'Club Test', N'Defensa', 20);

    -- Jugadores TITULARES de Seleccion 2
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel2')
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test2, N'Titular1Sel2', N'Test', '1992-01-01', N'Club Test', N'Portero', 1);

    -- Jugadores SUPLENTES de Seleccion 2
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel2')
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test2, N'Suplente1Sel2', N'Test', '1997-01-01', N'Club Test', N'Portero', 25);

    -- Partido de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION')
        INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico, id_seleccion_1, id_seleccion_2)
        VALUES (@id_sede_test, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-SUSTITUCION', 30000, @id_sel_test1_b6, @id_sel_test2);

    DECLARE @id_partido_test_b6 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');

    -- Formacion Seleccion 1 (con titulares y suplentes)
    DECLARE @id_formacion_sel1 INT;
    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido = @id_partido_test_b6 AND id_seleccion = @id_sel_test1_b6)
    BEGIN
        INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
        VALUES (@id_partido_test_b6, @id_sel_test1_b6, '4-3-3');
        SET @id_formacion_sel1 = SCOPE_IDENTITY();

        -- Titulares de Seleccion 1
        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel1, id_jugador, 'Delantero', 9, 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel1';

        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel1, id_jugador, 'Mediocampista', 8, 1 FROM dbo.Jugador WHERE nombre = N'Titular2Sel1';

        -- Suplentes de Seleccion 1
        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel1, id_jugador, 'Delantero', 18, 0 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1';

        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel1, id_jugador, 'Defensa', 20, 0 FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1';
    END
    ELSE
    BEGIN
        SET @id_formacion_sel1 = (SELECT id_formacion FROM dbo.Formacion WHERE id_partido = @id_partido_test_b6 AND id_seleccion = @id_sel_test1_b6);
    END

    -- Formacion Seleccion 2 (con titulares y suplentes)
    DECLARE @id_formacion_sel2 INT;
    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido = @id_partido_test_b6 AND id_seleccion = @id_sel_test2)
    BEGIN
        INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
        VALUES (@id_partido_test_b6, @id_sel_test2, '4-4-2');
        SET @id_formacion_sel2 = SCOPE_IDENTITY();

        -- Titulares de Seleccion 2
        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel2, id_jugador, 'Portero', 1, 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel2';

        -- Suplentes de Seleccion 2
        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel2, id_jugador, 'Portero', 25, 0 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel2';
    END
    ELSE
    BEGIN
        SET @id_formacion_sel2 = (SELECT id_formacion FROM dbo.Formacion WHERE id_partido = @id_partido_test_b6 AND id_seleccion = @id_sel_test2);
    END

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: dbo.Sustitucion
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Sustitucion';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Insercion exitosa - Sustitucion valida
    -- RESULTADO ESPERADO: se inserta la sustitucion y se devuelve
    -- el id_sustitucion_generado. Sin errores.
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Insercion exitosa ---';

    DECLARE @id_partido_test_b8 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_titular1_b8 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular1Sel1');
    DECLARE @id_suplente1_b8 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1');
    DECLARE @id_sustitucion_generado_b8 INT;

    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test_b8,
            @id_jugador_sale = @id_titular1_b8,
            @id_jugador_entra = @id_suplente1_b8,
            @minuto = 45,
            @periodo = 'PRIMER TIEMPO',
            @numero_ventana = 1,
            @motivo = 'Cambio tactico',
            @id_sustitucion = @id_sustitucion_generado_b8 OUTPUT;

        PRINT 'OK - Sustitucion insertada con ID: ' + CAST(@id_sustitucion_generado_b8 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 2: Insercion fallida - Jugador que entra es TITULAR
    -- RESULTADO ESPERADO: error con mensaje
    -- "El jugador que entra debe ser un SUPLENTE."
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Validacion fallida - Jugador entra es TITULAR ---';

    DECLARE @id_partido_test_b9 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_titular1_b9 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular1Sel1');
    DECLARE @id_titular2_b9 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular2Sel1');
    DECLARE @id_sustitucion_generado_b9 INT;
    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test_b9,
            @id_jugador_sale = @id_titular1_b9,
            @id_jugador_entra = @id_titular2_b9,
            @minuto = 60,
            @periodo = 'SEGUNDO TIEMPO',
            @numero_ventana = 2,
            @motivo = 'Test',
            @id_sustitucion = @id_sustitucion_generado_b9 OUTPUT;

        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 3: Insercion fallida - Numero de ventana invalido
    -- RESULTADO ESPERADO: error con mensaje sobre numero de ventana
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Validacion fallida - Numero ventana invalido ---';

    DECLARE @id_partido_test_b10 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_titular1_b10 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular1Sel1');
    DECLARE @id_suplente2_b10 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1');
    DECLARE @id_sustitucion_generado_b10 INT;

    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test_b10,
            @id_jugador_sale = @id_titular1_b10,
            @id_jugador_entra = @id_suplente2_b10,
            @minuto = 75,
            @periodo = 'SEGUNDO TIEMPO',
            @numero_ventana = 5,  -- Invalido (maximo 3 en reglamentario)
            @motivo = 'Test',
            @id_sustitucion = @id_sustitucion_generado_b10 OUTPUT;

        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 4: Insercion exitosa - Llenar cuota de sustituciones (4ta sustitucion)
    -- RESULTADO ESPERADO: se inserta la 4ta sustitucion exitosamente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 4: Insercion exitosa - 4ta sustitucion en reglamentario ---';

    DECLARE @id_partido_test_b11 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_suplente1_b11 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1');
    DECLARE @id_suplente2_b11 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1');
    DECLARE @id_sustitucion_generado_b11 INT;

    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test_b11,
            @id_jugador_sale = @id_suplente1_b11,
            @id_jugador_entra = @id_suplente2_b11,
            @minuto = 80,
            @periodo = 'SEGUNDO TIEMPO',
            @numero_ventana = 3,
            @motivo = 'Segunda sustitucion',
            @id_sustitucion = @id_sustitucion_generado_b11 OUTPUT;

        PRINT 'OK - Sustitucion 4 insertada con ID: ' + CAST(@id_sustitucion_generado_b11 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 5: Insercion exitosa - 5ta sustitucion (ultima permitida en reglamentario)
    -- RESULTADO ESPERADO: se inserta la 5ta sustitucion exitosamente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 5: Insercion exitosa - 5ta sustitucion (uLTIMA en reglamentario) ---';

    -- Necesitamos mas jugadores suplentes para esta prueba
    -- Agregamos 2 suplentes mas por si no existen
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1')
    BEGIN
        DECLARE @id_sel_test1_b12 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test 1');
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test1_b12, N'Suplente3Sel1', N'Test', '1998-01-01', N'Club Test', N'Defensa', 21);

        -- Agregar a la formacion
        DECLARE @id_formacion_sel1_v2 INT = (SELECT id_formacion FROM dbo.Formacion 
                                              WHERE id_seleccion = @id_sel_test1_b12 
                                              AND id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));
        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel1_v2, id_jugador, 'Defensa', 21, 0 FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1';
    END

    DECLARE @id_partido_test2 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_suplente2_v2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1');
    DECLARE @id_suplente3 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1');
    DECLARE @id_sustitucion_generado2 INT;

    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test2,
            @id_jugador_sale = @id_suplente2_v2,
            @id_jugador_entra = @id_suplente3,
            @minuto = 85,
            @periodo = 'SEGUNDO TIEMPO',
            @numero_ventana = 3,
            @motivo = 'Tercera sustitucion',
            @id_sustitucion = @id_sustitucion_generado2 OUTPUT;

        PRINT 'OK - Sustitucion 5 insertada con ID: ' + CAST(@id_sustitucion_generado2 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 6: Insercion fallida - 6ta sustitucion en REGLAMENTARIO (DEBE FALLAR)
    -- RESULTADO ESPERADO: error - limite de sustituciones alcanzado
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 6: Validacion fallida - 6ta sustitucion en reglamentario (RECHAZADA) ---';

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente4Sel1')
    BEGIN
        DECLARE @id_sel_test1_v3 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test 1');
        INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
        VALUES (@id_sel_test1_v3, N'Suplente4Sel1', N'Test', '1999-01-01', N'Club Test', N'Mediocampista', 22);

        DECLARE @id_formacion_sel1_v3 INT = (SELECT id_formacion FROM dbo.Formacion 
                                              WHERE id_seleccion = @id_sel_test1_v3 
                                              AND id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));
        INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        SELECT @id_formacion_sel1_v3, id_jugador, 'Mediocampista', 22, 0 FROM dbo.Jugador WHERE nombre = N'Suplente4Sel1';
    END

    DECLARE @id_partido_test3 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_suplente3_v2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1');
    DECLARE @id_suplente4 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente4Sel1');
    DECLARE @id_sustitucion_generado3 INT;

    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test3,
            @id_jugador_sale = @id_suplente3_v2,
            @id_jugador_entra = @id_suplente4,
            @minuto = 90,
            @periodo = 'SEGUNDO TIEMPO',
            @numero_ventana = 3,
            @motivo = 'Intento 6ta sustitucion',
            @id_sustitucion = @id_sustitucion_generado3 OUTPUT;

        PRINT 'ERROR: no se lanzo la excepcion esperada (deberia rechazar 6ta sustitucion)';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 7: Insercion exitosa - 6ta sustitucion en SUPLEMENTARIO (PERMITIDA)
    -- RESULTADO ESPERADO: se inserta exitosamente porque es suplementario
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 7: Insercion exitosa - 6ta sustitucion en SUPLEMENTARIO (PERMITIDA) ---';

    DECLARE @id_partido_test4 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    DECLARE @id_suplente4_v2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente4Sel1');
    DECLARE @id_titular2_b14 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular2Sel1');
    DECLARE @id_sustitucion_generado4 INT;

    BEGIN TRY
        EXEC abm.Sustitucion_Alta
            @id_partido = @id_partido_test4,
            @id_jugador_sale = @id_suplente4_v2,
            @id_jugador_entra = @id_titular2_b14,
            @minuto = 105,
            @periodo = 'PRIMER SUPLEMENTARIO',
            @numero_ventana = 4,
            @motivo = '6ta sustitucion en suplementario',
            @id_sustitucion = @id_sustitucion_generado4 OUTPUT;

        PRINT 'OK - Sustitucion 6 en suplementario insertada con ID: ' + CAST(@id_sustitucion_generado4 AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 8: GET - Obtener sustitucion por ID
    -- RESULTADO ESPERADO: muestra la sustitucion creada en CASO 1
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 9: GET por ID ---';

    DECLARE @id_sustitucion_creado_b15 INT = (SELECT MIN(id_sustitucion) FROM dbo.Sustitucion 
                                           WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));

    IF @id_sustitucion_creado_b15 IS NOT NULL
    BEGIN
        PRINT 'Datos de la sustitucion ' + CAST(@id_sustitucion_creado_b15 AS VARCHAR(10)) + ':';
        EXEC abm.Sustitucion_GetById @id_sustitucion = @id_sustitucion_creado_b15;
    END
    ELSE
        PRINT 'No se encontraron sustituciones registradas';

    -- ---------------------------------------------------------
    -- CASO 5: GET - Obtener todas las sustituciones de un partido
    -- RESULTADO ESPERADO: muestra todas las sustituciones del partido test
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 10: GET por Partido ---';

    DECLARE @id_partido_test_b16 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
    PRINT 'Sustituciones del partido ' + CAST(@id_partido_test_b16 AS VARCHAR(10)) + ':';
    EXEC abm.Sustitucion_GetByPartido @id_partido = @id_partido_test_b16;

    -- ---------------------------------------------------------
    -- CASO 6: UPDATE - Actualizar motivo de sustitucion
    -- RESULTADO ESPERADO: se actualiza solo el motivo
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 11: UPDATE - Cambiar motivo ---';

    DECLARE @id_sustitucion_creado_b17 INT = (SELECT MIN(id_sustitucion) FROM dbo.Sustitucion 
                                           WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));

    IF @id_sustitucion_creado_b17 IS NOT NULL
    BEGIN
        EXEC abm.Sustitucion_Modificacion
            @id_sustitucion = @id_sustitucion_creado_b17,
            @motivo = 'Cambio actualizado - jugador lesionado';

        PRINT 'Sustitucion actualizada:';
        EXEC abm.Sustitucion_GetById @id_sustitucion = @id_sustitucion_creado_b17;
    END

    -- ---------------------------------------------------------
    -- CASO 7: UPDATE - ID inexistente
    -- RESULTADO ESPERADO: error
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 12: UPDATE fallido - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Sustitucion_Modificacion
            @id_sustitucion = 999999,
            @motivo = 'Test';

        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 8: DELETE - Eliminar sustitucion
    -- RESULTADO ESPERADO: se elimina la sustitucion
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 13: DELETE - Eliminar sustitucion ---';

    DECLARE @id_sustitucion_creado_b19 INT = (SELECT MIN(id_sustitucion) FROM dbo.Sustitucion 
                                           WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));

    IF @id_sustitucion_creado_b19 IS NOT NULL
    BEGIN
        EXEC abm.Sustitucion_Baja @id_sustitucion = @id_sustitucion_creado_b19;

        -- Verificar que fue eliminada
        IF NOT EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_sustitucion = @id_sustitucion_creado_b19)
            PRINT 'OK - Sustitucion eliminada correctamente';
        ELSE
            PRINT 'ERROR: la sustitucion no fue eliminada';
    END

    PRINT '';
    PRINT '===========================================';
    PRINT 'FIN DE PRUEBAS';
    PRINT '===========================================';
END;
GO

EXEC test.Sustitucion_Test;
GO
