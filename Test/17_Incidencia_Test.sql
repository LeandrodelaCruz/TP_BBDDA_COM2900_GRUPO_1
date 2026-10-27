/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01: 
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel


    Descripción:
    Script de testing COMPLETO para todos los procedimientos de Incidencia
    Incluye pruebas exitosas y pruebas de validaciones fallidas
    
    PROCEDIMIENTOS A PROBAR:
    - Incidencia_Alta (con validaciones)
    - Incidencia_GetGoles (goles con asistencias)
    - Incidencia_GetAmonestaciones (amarillas con agredido)
    - Incidencia_GetExpulsiones (rojas con agredido)
    - Incidencia_GetByPartido (todas las incidencias)
    - Incidencia_Modificacion (solo motivo)
    - Incidencia_Baja
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Incidencia_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores ===';

    DELETE FROM dbo.Incidencia 
    WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');

    DELETE FROM dbo.Formacion_Jugador 
    WHERE id_formacion IN (SELECT id_formacion FROM dbo.Formacion 
                          WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA'));

    DELETE FROM dbo.Formacion 
    WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');

    DELETE FROM dbo.Partido 
    WHERE resultado_final = N'TEST-INCIDENCIA';

    DELETE FROM dbo.Jugador 
    WHERE nombre LIKE N'%Test%' AND id_seleccion IN (SELECT id_seleccion FROM dbo.Seleccion WHERE pais LIKE N'%Test%Incidencia%');

    DELETE FROM dbo.Seleccion 
    WHERE pais LIKE N'%Test%Incidencia%';

    DELETE FROM dbo.Sede 
    WHERE nombre_estadio LIKE N'%Testing%Incidencia%';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIÓN: datos mínimos de apoyo
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    -- Sede de prueba
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing Incidencia', N'Ciudad Test', N'País Test', 50000, 'UTC-03:00');

    -- Selecciones de prueba
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test Incidencia 1', N'TEST', 'A');

    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test Incidencia 2', N'TEST', 'A');

    DECLARE @id_sede_test INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Incidencia');
    DECLARE @id_sel_test1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test Incidencia 1');
    DECLARE @id_sel_test2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test Incidencia 2');

    -- Jugadores de Selección 1
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Goleador1Test', N'Test', '1990-01-01', N'Club Test', N'Delantero', 9);

    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Defensa1Test', N'Test', '1991-01-01', N'Club Test', N'Defensa', 4);

    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Mediocampista1Test', N'Test', '1992-01-01', N'Club Test', N'Mediocampista', 7);

    -- Jugadores de Selección 2
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test2, N'Goleador2Test', N'Test', '1993-01-01', N'Club Test', N'Delantero', 10);

    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test2, N'Defensa2Test', N'Test', '1994-01-01', N'Club Test', N'Defensa', 2);

    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test2, N'Mediocampista2Test', N'Test', '1995-01-01', N'Club Test', N'Mediocampista', 8);

    -- Partido de prueba
    INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico, id_seleccion_1, id_seleccion_2)
    VALUES (@id_sede_test, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-INCIDENCIA', 30000, @id_sel_test1, @id_sel_test2);

    DECLARE @id_partido_test_b5 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');

    -- Formación Selección 1
    DECLARE @id_formacion_sel1 INT;
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_test_b5, @id_sel_test1, '4-3-3');
    SET @id_formacion_sel1 = SCOPE_IDENTITY();

    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Delantero', 9, 1 FROM dbo.Jugador WHERE nombre = N'Goleador1Test';

    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Defensa', 4, 1 FROM dbo.Jugador WHERE nombre = N'Defensa1Test';

    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Mediocampista', 7, 1 FROM dbo.Jugador WHERE nombre = N'Mediocampista1Test';

    -- Formación Selección 2
    DECLARE @id_formacion_sel2 INT;
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_test_b5, @id_sel_test2, '4-4-2');
    SET @id_formacion_sel2 = SCOPE_IDENTITY();

    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel2, id_jugador, 'Delantero', 10, 1 FROM dbo.Jugador WHERE nombre = N'Goleador2Test';

    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel2, id_jugador, 'Defensa', 2, 1 FROM dbo.Jugador WHERE nombre = N'Defensa2Test';

    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel2, id_jugador, 'Mediocampista', 8, 1 FROM dbo.Jugador WHERE nombre = N'Mediocampista2Test';

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: INCIDENCIAS
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Incidencia';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Inserción exitosa - GOL
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Inserción exitosa - GOL ---';

    DECLARE @id_partido_test_b7 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    DECLARE @id_goleador INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Goleador1Test');
    DECLARE @id_incidencia_gol INT;

    BEGIN TRY
        EXEC abm.Incidencia_Alta
            @id_partido = @id_partido_test_b7,
            @id_jugador = @id_goleador,
            @tipo = 'GOL',
            @periodo = 'PRIMER TIEMPO',
            @minuto = 25,
            @motivo = 'Gol de cabeza en el área',
            @id_jugador_involucrado = NULL,
            @id_incidencia = @id_incidencia_gol OUTPUT;

        PRINT 'OK - GOL insertado con ID: ' + CAST(@id_incidencia_gol AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 2: Inserción exitosa - AMONESTACION
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Inserción exitosa - AMONESTACION ---';

    DECLARE @id_partido_test_b8 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    DECLARE @id_defensa1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Defensa1Test');
    DECLARE @id_defensa2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Defensa2Test');
    DECLARE @id_incidencia_amarilla INT;

    BEGIN TRY
        EXEC abm.Incidencia_Alta
            @id_partido = @id_partido_test_b8,
            @id_jugador = @id_defensa1,
            @tipo = 'AMONESTACION',
            @periodo = 'PRIMER TIEMPO',
            @minuto = 30,
            @motivo = 'Falta sobre el rival',
            @id_jugador_involucrado = @id_defensa2,
            @id_incidencia = @id_incidencia_amarilla OUTPUT;

        PRINT 'OK - AMONESTACION insertada con ID: ' + CAST(@id_incidencia_amarilla AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 3: Inserción exitosa - EXPULSION
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Inserción exitosa - EXPULSION ---';

    DECLARE @id_partido_test_b9 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    DECLARE @id_mediocampista2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Mediocampista2Test');
    DECLARE @id_goleador1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Goleador1Test');
    DECLARE @id_incidencia_roja INT;

    BEGIN TRY
        EXEC abm.Incidencia_Alta
            @id_partido = @id_partido_test_b9,
            @id_jugador = @id_mediocampista2,
            @tipo = 'EXPULSION',
            @periodo = 'SEGUNDO TIEMPO',
            @minuto = 70,
            @motivo = 'Agresión directa al rival',
            @id_jugador_involucrado = @id_goleador1,
            @id_incidencia = @id_incidencia_roja OUTPUT;

        PRINT 'OK - EXPULSION insertada con ID: ' + CAST(@id_incidencia_roja AS VARCHAR(10));
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 4: Validación fallida - Tipo inválido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 4: Validación fallida - Tipo inválido ---';

    DECLARE @id_partido_test_b10 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    DECLARE @id_jugador_b10 INT = (SELECT TOP 1 id_jugador FROM dbo.Jugador WHERE nombre LIKE N'%Test%');
    DECLARE @id_incidencia_test_b10 INT;

    BEGIN TRY
        EXEC abm.Incidencia_Alta
            @id_partido = @id_partido_test_b10,
            @id_jugador_b10 = @id_jugador_b10,
            @tipo = 'TIPO_INVALIDO',
            @periodo = 'PRIMER TIEMPO',
            @minuto = 15,
            @id_incidencia = @id_incidencia_test_b10 OUTPUT;

        PRINT 'ERROR: Debería haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 5: Validación fallida - AMONESTACION sin agredido
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 5: Validación fallida - AMONESTACION sin agredido ---';

    DECLARE @id_partido_test_b11 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    DECLARE @id_jugador_b11 INT = (SELECT TOP 1 id_jugador FROM dbo.Jugador WHERE nombre LIKE N'%Test%');
    DECLARE @id_incidencia_test_b11 INT;

    BEGIN TRY
        EXEC abm.Incidencia_Alta
            @id_partido = @id_partido_test_b11,
            @id_jugador_b11 = @id_jugador_b11,
            @tipo = 'AMONESTACION',
            @periodo = 'PRIMER TIEMPO',
            @minuto = 25,
            @id_jugador_involucrado = NULL,
            @id_incidencia = @id_incidencia_test_b11 OUTPUT;

        PRINT 'ERROR: Debería haber fallado';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH

    -- ---------------------------------------------------------
    -- CASO 6: GET - Goles
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 6: GET GOLES ---';

    DECLARE @id_partido_test_b12 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    EXEC abm.Incidencia_GetGoles @id_partido = @id_partido_test_b12;

    -- ---------------------------------------------------------
    -- CASO 7: GET - Amonestaciones
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 7: GET AMONESTACIONES ---';

    DECLARE @id_partido_test_b13 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    EXEC abm.Incidencia_GetAmonestaciones @id_partido = @id_partido_test_b13;

    -- ---------------------------------------------------------
    -- CASO 8: GET - Expulsiones
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 8: GET EXPULSIONES ---';

    DECLARE @id_partido_test_b14 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    EXEC abm.Incidencia_GetExpulsiones @id_partido = @id_partido_test_b14;

    -- ---------------------------------------------------------
    -- CASO 9: GET - Todas las incidencias
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 9: GET TODAS LAS INCIDENCIAS ---';

    DECLARE @id_partido_test_b15 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
    EXEC abm.Incidencia_GetByPartido @id_partido = @id_partido_test_b15;

    -- ---------------------------------------------------------
    -- CASO 10: UPDATE - Cambiar motivo
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 10: UPDATE - Cambiar motivo ---';

    DECLARE @id_incidencia_update INT = (SELECT TOP 1 id_incidencia FROM dbo.Incidencia 
                                         WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA')
                                         ORDER BY id_incidencia DESC);

    IF @id_incidencia_update IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC abm.Incidencia_Modificacion
                @id_incidencia = @id_incidencia_update,
                @motivo = 'Motivo actualizado - análisis de video';

            PRINT 'OK - Incidencia actualizada';

            SELECT id_incidencia, tipo, motivo FROM dbo.Incidencia WHERE id_incidencia = @id_incidencia_update;
        END TRY
        BEGIN CATCH
            PRINT 'ERROR: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay incidencias para actualizar';

    -- ---------------------------------------------------------
    -- CASO 11: DELETE - Eliminar incidencia
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 11: DELETE - Eliminar incidencia ---';

    DECLARE @id_incidencia_delete INT = (SELECT TOP 1 id_incidencia FROM dbo.Incidencia 
                                         WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA')
                                         ORDER BY id_incidencia DESC);

    IF @id_incidencia_delete IS NOT NULL
    BEGIN
        BEGIN TRY
            EXEC abm.Incidencia_Baja @id_incidencia = @id_incidencia_delete;

            PRINT 'OK - Incidencia eliminada';

            IF NOT EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_incidencia = @id_incidencia_delete)
                PRINT 'CONFIRMADO: Incidencia ya no existe en la BD';
        END TRY
        BEGIN CATCH
            PRINT 'ERROR: ' + ERROR_MESSAGE();
        END CATCH
    END
    ELSE
        PRINT 'No hay incidencias para eliminar';

    PRINT '';
    PRINT '=============================================';
    PRINT ' FIN DE PRUEBAS';
    PRINT '=============================================';
END;
GO

EXEC test.Incidencia_Test;
GO
