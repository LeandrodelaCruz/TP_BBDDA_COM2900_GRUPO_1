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
    Script de testing COMPLETO para todos los procedimientos de Sustitución
    Incluye pruebas exitosas y pruebas de validaciones fallidas
    
    PROCEDIMIENTOS A PROBAR:
    - sp_Sustitucion_Alta (con validaciones)
    - sp_Sustitucion_GetById
    - sp_Sustitucion_GetByPartido
    - sp_Sustitucion_Modificacion
    - sp_Sustitucion_Baja
    
    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   LIMPIEZA: Eliminar datos previos de pruebas anteriores
   =========================================================
   Se eliminan en orden inverso respetando las FK:
   1. Sustituciones
   2. Formacion_Jugador
   3. Formacion
   4. Partido_Seleccion
   5. Sustitucion (por si acaso)
   6. Partido
   7. Jugador (de selecciones test)
   8. Seleccion
   9. Sede
   ========================================================= */

PRINT '=== Limpiando datos de pruebas anteriores ===';
GO

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

-- Eliminar relaciones partido-selección
DELETE FROM dbo.Partido_Seleccion 
WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');

-- Eliminar partidos
DELETE FROM dbo.Partido 
WHERE resultado_final = N'TEST-SUSTITUCION';

-- Eliminar jugadores
DELETE FROM dbo.Jugador 
WHERE id_seleccion IN (
    SELECT id_seleccion FROM dbo.Seleccion 
    WHERE pais IN (N'Selección Test 1', N'Selección Test 2')
);

-- Eliminar selecciones
DELETE FROM dbo.Seleccion 
WHERE pais IN (N'Selección Test 1', N'Selección Test 2');

-- Eliminar sede
DELETE FROM dbo.Sede 
WHERE nombre_estadio = N'Estadio Testing Sustitución';

PRINT '=== Limpieza completada ===';
GO

/* =========================================================
   PREPARACIÓN: datos mínimos de apoyo
   =========================================================
   Resultado esperado: se insertan (si no existen) una sede,
   dos selecciones, jugadores titulares y suplentes por selección,
   un partido, la relación partido-selección y las formaciones.
   Todo con IDs conocidos para poder referenciarlos en las pruebas.
   ========================================================= */

PRINT '=== Preparando datos de prueba ===';
GO

-- Sede de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Sustitución')
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing Sustitución', N'Ciudad Test', N'País Test', 50000, 'UTC-03:00');

-- Selecciones de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Selección Test 1')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test 1', N'TEST', 'A');

IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Selección Test 2')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test 2', N'TEST', 'A');

DECLARE @id_sede_test    INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Sustitución');
DECLARE @id_sel_test1    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test 1');
DECLARE @id_sel_test2    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test 2');

-- Jugadores TITULARES de Selección 1
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel1')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Titular1Sel1', N'Test', '1990-01-01', N'Club Test', N'Delantero', 9);

IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Titular2Sel1')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Titular2Sel1', N'Test', '1991-01-01', N'Club Test', N'Mediocampista', 8);

-- Jugadores SUPLENTES de Selección 1
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Suplente1Sel1', N'Test', '1995-01-01', N'Club Test', N'Delantero', 18);

IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Suplente2Sel1', N'Test', '1996-01-01', N'Club Test', N'Defensa', 20);

-- Jugadores TITULARES de Selección 2
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel2')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test2, N'Titular1Sel2', N'Test', '1992-01-01', N'Club Test', N'Portero', 1);

-- Jugadores SUPLENTES de Selección 2
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel2')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test2, N'Suplente1Sel2', N'Test', '1997-01-01', N'Club Test', N'Portero', 25);

-- Partido de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION')
    INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico)
    VALUES (@id_sede_test, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-SUSTITUCION', 30000);

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');

-- Relación partido-selección
IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1)
    INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion) VALUES (@id_partido_test, @id_sel_test1);

IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test2)
    INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion) VALUES (@id_partido_test, @id_sel_test2);

-- Formación Selección 1 (con titulares y suplentes)
DECLARE @id_formacion_sel1 INT;
IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1)
BEGIN
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_test, @id_sel_test1, '4-3-3');
    SET @id_formacion_sel1 = SCOPE_IDENTITY();
    
    -- Titulares de Selección 1
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Delantero', 9, 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel1';
    
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Mediocampista', 8, 1 FROM dbo.Jugador WHERE nombre = N'Titular2Sel1';
    
    -- Suplentes de Selección 1
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Delantero', 18, 0 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1';
    
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1, id_jugador, 'Defensa', 20, 0 FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1';
END
ELSE
BEGIN
    SET @id_formacion_sel1 = (SELECT id_formacion FROM dbo.Formacion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1);
END

-- Formación Selección 2 (con titulares y suplentes)
DECLARE @id_formacion_sel2 INT;
IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test2)
BEGIN
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_test, @id_sel_test2, '4-4-2');
    SET @id_formacion_sel2 = SCOPE_IDENTITY();
    
    -- Titulares de Selección 2
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel2, id_jugador, 'Portero', 1, 1 FROM dbo.Jugador WHERE nombre = N'Titular1Sel2';
    
    -- Suplentes de Selección 2
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel2, id_jugador, 'Portero', 25, 0 FROM dbo.Jugador WHERE nombre = N'Suplente1Sel2';
END
ELSE
BEGIN
    SET @id_formacion_sel2 = (SELECT id_formacion FROM dbo.Formacion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test2);
END

PRINT '=== Datos de apoyo preparados ===';
GO


/* =========================================================
   PRUEBAS: dbo.Sustitucion
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Sustitucion';
PRINT '=============================================';
GO

-- ---------------------------------------------------------
-- CASO 1: Inserción exitosa - Sustitución válida
-- RESULTADO ESPERADO: se inserta la sustitución y se devuelve
-- el id_sustitucion_generado. Sin errores.
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 1: Inserción exitosa ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
DECLARE @id_titular1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular1Sel1');
DECLARE @id_suplente1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1');
DECLARE @id_sustitucion_generado INT;

BEGIN TRY
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test,
        @id_jugador_sale = @id_titular1,
        @id_jugador_entra = @id_suplente1,
        @minuto = 45,
        @periodo = 'PRIMER TIEMPO',
        @numero_ventana = 1,
        @motivo = 'Cambio táctico',
        @id_sustitucion = @id_sustitucion_generado OUTPUT;
    
    PRINT 'OK - Sustitución insertada con ID: ' + CAST(@id_sustitucion_generado AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 2: Inserción fallida - Jugador que entra es TITULAR
-- RESULTADO ESPERADO: error con mensaje
-- "El jugador que entra debe ser un SUPLENTE."
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 2: Validación fallida - Jugador entra es TITULAR ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
DECLARE @id_titular1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular1Sel1');
DECLARE @id_titular2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular2Sel1');
DECLARE @id_sustitucion_generado INT;
BEGIN TRY
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test,
        @id_jugador_sale = @id_titular1,
        @id_jugador_entra = @id_titular2,
        @minuto = 60,
        @periodo = 'SEGUNDO TIEMPO',
        @numero_ventana = 2,
        @motivo = 'Test',
        @id_sustitucion = @id_sustitucion_generado OUTPUT;
    
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 3: Inserción fallida - Número de ventana inválido
-- RESULTADO ESPERADO: error con mensaje sobre número de ventana
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 3: Validación fallida - Número ventana inválido ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
DECLARE @id_titular1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular1Sel1');
DECLARE @id_suplente2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1');
DECLARE @id_sustitucion_generado INT;

BEGIN TRY
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test,
        @id_jugador_sale = @id_titular1,
        @id_jugador_entra = @id_suplente2,
        @minuto = 75,
        @periodo = 'SEGUNDO TIEMPO',
        @numero_ventana = 5,  -- Inválido (máximo 3 en reglamentario)
        @motivo = 'Test',
        @id_sustitucion = @id_sustitucion_generado OUTPUT;
    
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 4: Inserción exitosa - Llenar cuota de sustituciones (4ta sustitución)
-- RESULTADO ESPERADO: se inserta la 4ta sustitución exitosamente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 4: Inserción exitosa - 4ta sustitución en reglamentario ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
DECLARE @id_suplente1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente1Sel1');
DECLARE @id_suplente2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1');
DECLARE @id_sustitucion_generado INT;

BEGIN TRY
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test,
        @id_jugador_sale = @id_suplente1,
        @id_jugador_entra = @id_suplente2,
        @minuto = 80,
        @periodo = 'SEGUNDO TIEMPO',
        @numero_ventana = 3,
        @motivo = 'Segunda sustitución',
        @id_sustitucion = @id_sustitucion_generado OUTPUT;
    
    PRINT 'OK - Sustitución 4 insertada con ID: ' + CAST(@id_sustitucion_generado AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 5: Inserción exitosa - 5ta sustitución (última permitida en reglamentario)
-- RESULTADO ESPERADO: se inserta la 5ta sustitución exitosamente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 5: Inserción exitosa - 5ta sustitución (ÚLTIMA en reglamentario) ---';

-- Necesitamos más jugadores suplentes para esta prueba
-- Agregamos 2 suplentes más por si no existen
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1')
BEGIN
    DECLARE @id_sel_test1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test 1');
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'Suplente3Sel1', N'Test', '1998-01-01', N'Club Test', N'Defensa', 21);
    
    -- Agregar a la formación
    DECLARE @id_formacion_sel1_v2 INT = (SELECT id_formacion FROM dbo.Formacion 
                                          WHERE id_seleccion = @id_sel_test1 
                                          AND id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    SELECT @id_formacion_sel1_v2, id_jugador, 'Defensa', 21, 0 FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1';
END

DECLARE @id_partido_test2 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
DECLARE @id_suplente2_v2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente2Sel1');
DECLARE @id_suplente3 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente3Sel1');
DECLARE @id_sustitucion_generado2 INT;

BEGIN TRY
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test2,
        @id_jugador_sale = @id_suplente2_v2,
        @id_jugador_entra = @id_suplente3,
        @minuto = 85,
        @periodo = 'SEGUNDO TIEMPO',
        @numero_ventana = 3,
        @motivo = 'Tercera sustitución',
        @id_sustitucion = @id_sustitucion_generado2 OUTPUT;
    
    PRINT 'OK - Sustitución 5 insertada con ID: ' + CAST(@id_sustitucion_generado2 AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 6: Inserción fallida - 6ta sustitución en REGLAMENTARIO (DEBE FALLAR)
-- RESULTADO ESPERADO: error - límite de sustituciones alcanzado
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 6: Validación fallida - 6ta sustitución en reglamentario (RECHAZADA) ---';

IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'Suplente4Sel1')
BEGIN
    DECLARE @id_sel_test1_v3 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test 1');
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
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test3,
        @id_jugador_sale = @id_suplente3_v2,
        @id_jugador_entra = @id_suplente4,
        @minuto = 90,
        @periodo = 'SEGUNDO TIEMPO',
        @numero_ventana = 3,
        @motivo = 'Intento 6ta sustitución',
        @id_sustitucion = @id_sustitucion_generado3 OUTPUT;
    
    PRINT 'ERROR: no se lanzó la excepción esperada (debería rechazar 6ta sustitución)';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 7: Inserción exitosa - 6ta sustitución en SUPLEMENTARIO (PERMITIDA)
-- RESULTADO ESPERADO: se inserta exitosamente porque es suplementario
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 7: Inserción exitosa - 6ta sustitución en SUPLEMENTARIO (PERMITIDA) ---';

DECLARE @id_partido_test4 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
DECLARE @id_suplente4_v2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Suplente4Sel1');
DECLARE @id_titular2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Titular2Sel1');
DECLARE @id_sustitucion_generado4 INT;

BEGIN TRY
    EXEC dbo.sp_Sustitucion_Alta
        @id_partido = @id_partido_test4,
        @id_jugador_sale = @id_suplente4_v2,
        @id_jugador_entra = @id_titular2,
        @minuto = 105,
        @periodo = 'PRIMER SUPLEMENTARIO',
        @numero_ventana = 4,
        @motivo = '6ta sustitución en suplementario',
        @id_sustitucion = @id_sustitucion_generado4 OUTPUT;
    
    PRINT 'OK - Sustitución 6 en suplementario insertada con ID: ' + CAST(@id_sustitucion_generado4 AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 8: GET - Obtener sustitución por ID
-- RESULTADO ESPERADO: muestra la sustitución creada en CASO 1
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 9: GET por ID ---';

DECLARE @id_sustitucion_creado INT = (SELECT MIN(id_sustitucion) FROM dbo.Sustitucion 
                                       WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));

IF @id_sustitucion_creado IS NOT NULL
BEGIN
    PRINT 'Datos de la sustitución ' + CAST(@id_sustitucion_creado AS VARCHAR(10)) + ':';
    EXEC dbo.sp_Sustitucion_GetById @id_sustitucion = @id_sustitucion_creado;
END
ELSE
    PRINT 'No se encontraron sustituciones registradas';
GO


-- ---------------------------------------------------------
-- CASO 5: GET - Obtener todas las sustituciones de un partido
-- RESULTADO ESPERADO: muestra todas las sustituciones del partido test
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 10: GET por Partido ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION');
PRINT 'Sustituciones del partido ' + CAST(@id_partido_test AS VARCHAR(10)) + ':';
EXEC dbo.sp_Sustitucion_GetByPartido @id_partido = @id_partido_test;
GO


-- ---------------------------------------------------------
-- CASO 6: UPDATE - Actualizar motivo de sustitución
-- RESULTADO ESPERADO: se actualiza solo el motivo
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 11: UPDATE - Cambiar motivo ---';

DECLARE @id_sustitucion_creado INT = (SELECT MIN(id_sustitucion) FROM dbo.Sustitucion 
                                       WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));

IF @id_sustitucion_creado IS NOT NULL
BEGIN
    EXEC dbo.sp_Sustitucion_Modificacion
        @id_sustitucion = @id_sustitucion_creado,
        @motivo = 'Cambio actualizado - jugador lesionado';
    
    PRINT 'Sustitución actualizada:';
    EXEC dbo.sp_Sustitucion_GetById @id_sustitucion = @id_sustitucion_creado;
END
GO


-- ---------------------------------------------------------
-- CASO 7: UPDATE - ID inexistente
-- RESULTADO ESPERADO: error
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 12: UPDATE fallido - ID inexistente ---';

BEGIN TRY
    EXEC dbo.sp_Sustitucion_Modificacion
        @id_sustitucion = 999999,
        @motivo = 'Test';
    
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 8: DELETE - Eliminar sustitución
-- RESULTADO ESPERADO: se elimina la sustitución
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 13: DELETE - Eliminar sustitución ---';

DECLARE @id_sustitucion_creado INT = (SELECT MIN(id_sustitucion) FROM dbo.Sustitucion 
                                       WHERE id_partido = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SUSTITUCION'));

IF @id_sustitucion_creado IS NOT NULL
BEGIN
    EXEC dbo.sp_Sustitucion_Baja @id_sustitucion = @id_sustitucion_creado;
    
    -- Verificar que fue eliminada
    IF NOT EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_sustitucion = @id_sustitucion_creado)
        PRINT 'OK - Sustitución eliminada correctamente';
    ELSE
        PRINT 'ERROR: la sustitución no fue eliminada';
END
GO


PRINT '';
PRINT '===========================================';
PRINT 'FIN DE PRUEBAS';
PRINT '===========================================';
GO
