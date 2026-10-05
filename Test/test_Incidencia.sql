/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 04/10/2026

    Descripción:
    Script de testing COMPLETO para todos los procedimientos de Incidencia
    Incluye pruebas exitosas y pruebas de validaciones fallidas
    
    PROCEDIMIENTOS A PROBAR:
    - sp_Incidencia_Insert (con validaciones)
    - sp_Incidencia_GetGoles (goles con asistencias)
    - sp_Incidencia_GetAmonestaciones (amarillas con agredido)
    - sp_Incidencia_GetExpulsiones (rojas con agredido)
    - sp_Incidencia_GetByPartido (todas las incidencias)
    - sp_Incidencia_Update (solo motivo)
    - sp_Incidencia_Delete
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

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

DELETE FROM dbo.Partido_Seleccion 
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
GO

/* =========================================================
   PREPARACIÓN: datos mínimos de apoyo
   ========================================================= */

PRINT '=== Preparando datos de prueba ===';
GO

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
INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico)
VALUES (@id_sede_test, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-INCIDENCIA', 30000);

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');

-- Relación partido-selección
INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion) VALUES (@id_partido_test, @id_sel_test1);
INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion) VALUES (@id_partido_test, @id_sel_test2);

-- Formación Selección 1
DECLARE @id_formacion_sel1 INT;
INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
VALUES (@id_partido_test, @id_sel_test1, '4-3-3');
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
VALUES (@id_partido_test, @id_sel_test2, '4-4-2');
SET @id_formacion_sel2 = SCOPE_IDENTITY();

INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
SELECT @id_formacion_sel2, id_jugador, 'Delantero', 10, 1 FROM dbo.Jugador WHERE nombre = N'Goleador2Test';

INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
SELECT @id_formacion_sel2, id_jugador, 'Defensa', 2, 1 FROM dbo.Jugador WHERE nombre = N'Defensa2Test';

INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
SELECT @id_formacion_sel2, id_jugador, 'Mediocampista', 8, 1 FROM dbo.Jugador WHERE nombre = N'Mediocampista2Test';

PRINT '=== Datos de apoyo preparados ===';
GO

/* =========================================================
   PRUEBAS: INCIDENCIAS
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Incidencia';
PRINT '=============================================';
GO

-- ---------------------------------------------------------
-- CASO 1: Inserción exitosa - GOL
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 1: Inserción exitosa - GOL ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
DECLARE @id_goleador INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Goleador1Test');
DECLARE @id_incidencia_gol INT;

BEGIN TRY
    EXEC dbo.sp_Incidencia_Insert
        @id_partido = @id_partido_test,
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
GO

-- ---------------------------------------------------------
-- CASO 2: Inserción exitosa - AMONESTACION
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 2: Inserción exitosa - AMONESTACION ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
DECLARE @id_defensa1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Defensa1Test');
DECLARE @id_defensa2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Defensa2Test');
DECLARE @id_incidencia_amarilla INT;

BEGIN TRY
    EXEC dbo.sp_Incidencia_Insert
        @id_partido = @id_partido_test,
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
GO

-- ---------------------------------------------------------
-- CASO 3: Inserción exitosa - EXPULSION
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 3: Inserción exitosa - EXPULSION ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
DECLARE @id_mediocampista2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Mediocampista2Test');
DECLARE @id_goleador1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'Goleador1Test');
DECLARE @id_incidencia_roja INT;

BEGIN TRY
    EXEC dbo.sp_Incidencia_Insert
        @id_partido = @id_partido_test,
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
GO

-- ---------------------------------------------------------
-- CASO 4: Validación fallida - Tipo inválido
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 4: Validación fallida - Tipo inválido ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
DECLARE @id_jugador INT = (SELECT TOP 1 id_jugador FROM dbo.Jugador WHERE nombre LIKE N'%Test%');
DECLARE @id_incidencia_test INT;

BEGIN TRY
    EXEC dbo.sp_Incidencia_Insert
        @id_partido = @id_partido_test,
        @id_jugador = @id_jugador,
        @tipo = 'TIPO_INVALIDO',
        @periodo = 'PRIMER TIEMPO',
        @minuto = 15,
        @id_incidencia = @id_incidencia_test OUTPUT;
    
    PRINT 'ERROR: Debería haber fallado';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 5: Validación fallida - AMONESTACION sin agredido
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 5: Validación fallida - AMONESTACION sin agredido ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
DECLARE @id_jugador INT = (SELECT TOP 1 id_jugador FROM dbo.Jugador WHERE nombre LIKE N'%Test%');
DECLARE @id_incidencia_test INT;

BEGIN TRY
    EXEC dbo.sp_Incidencia_Insert
        @id_partido = @id_partido_test,
        @id_jugador = @id_jugador,
        @tipo = 'AMONESTACION',
        @periodo = 'PRIMER TIEMPO',
        @minuto = 25,
        @id_jugador_involucrado = NULL,
        @id_incidencia = @id_incidencia_test OUTPUT;
    
    PRINT 'ERROR: Debería haber fallado';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 6: GET - Goles
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 6: GET GOLES ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
EXEC dbo.sp_Incidencia_GetGoles @id_partido = @id_partido_test;
GO

-- ---------------------------------------------------------
-- CASO 7: GET - Amonestaciones
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 7: GET AMONESTACIONES ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
EXEC dbo.sp_Incidencia_GetAmonestaciones @id_partido = @id_partido_test;
GO

-- ---------------------------------------------------------
-- CASO 8: GET - Expulsiones
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 8: GET EXPULSIONES ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
EXEC dbo.sp_Incidencia_GetExpulsiones @id_partido = @id_partido_test;
GO

-- ---------------------------------------------------------
-- CASO 9: GET - Todas las incidencias
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 9: GET TODAS LAS INCIDENCIAS ---';

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-INCIDENCIA');
EXEC dbo.sp_Incidencia_GetByPartido @id_partido = @id_partido_test;
GO

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
        EXEC dbo.sp_Incidencia_Update
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
GO

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
        EXEC dbo.sp_Incidencia_Delete @id_incidencia = @id_incidencia_delete;
        
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
GO

PRINT '';
PRINT '=============================================';
PRINT ' FIN DE PRUEBAS';
PRINT '=============================================';
GO
