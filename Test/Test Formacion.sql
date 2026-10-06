/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripción:
    Script de testing del Stored Procedure ABM de la tabla:
        - dbo.Formacion

    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
    Se prueban tanto casos exitosos como casos con validaciones fallidas.

    Ejecutar después de SP Formacion ABM.sql
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   PREPARACIÓN: datos mínimos de apoyo
   =========================================================
   Resultado esperado: se insertan (si no existen) una sede,
   dos selecciones, dos jugadores por selección, un partido
   y la relación partido-selección. Todo con IDs conocidos
   para poder referenciarlos en las pruebas.
   ========================================================= */

-- Sede de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing')
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing', N'Ciudad Test', N'País Test', 50000, 'UTC-03:00');

-- Selecciones de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Testlandia')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Testlandia', N'TEST', 'A');

IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Pruebalandia')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Pruebalandia', N'TEST', 'A');

DECLARE @id_sede_test    INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');
DECLARE @id_sel_test1    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');
DECLARE @id_sel_test2    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Pruebalandia');

-- Jugadores de prueba (2 por selección)
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'JugadorBaja1')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'JugadorBaja1', N'Test', '1995-01-01', N'Club Test', N'Delantero', 10);

IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'JugadorAlta1')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test1, N'JugadorAlta1', N'Test', '1996-01-01', N'Club Test', N'Delantero', 11);

IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'JugadorSel2')
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_test2, N'JugadorSel2', N'Test', '1997-01-01', N'Club Test', N'Mediocampista', 5);

DECLARE @id_jug_baja INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
DECLARE @id_jug_alta INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');
DECLARE @id_jug_sel2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorSel2');

-- Partido de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE resultado_final = N'TEST-ABM')
    INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico)
    VALUES (@id_sede_test, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-ABM', 30000);

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');

-- Relación partido-selección de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
               WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1)
    INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion)
    VALUES (@id_partido_test, @id_sel_test1);

IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
               WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test2)
    INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion)
    VALUES (@id_partido_test, @id_sel_test2);

PRINT '=== Datos de apoyo preparados ===';
GO

/* =========================================================
   PRUEBAS: dbo.Formacion
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Formacion';
PRINT '=============================================';

-- ---------------------------------------------------------
-- CASO 20: Alta exitosa
-- RESULTADO ESPERADO: id_formacion_generado > 0
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

EXEC dbo.SP_Formacion_Alta
    @id_partido      = @id_partido,
    @id_seleccion    = @id_sel1,
    @esquema_tactico = '4-3-3';
-- Esperado: 1 fila con id_formacion_generado > 0
GO


-- ---------------------------------------------------------
-- CASO 21: Alta fallida - selección no participa del partido
-- RESULTADO ESPERADO: error
-- "- La selección no participa en el partido indicado."
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

BEGIN TRY
    EXEC dbo.SP_Formacion_Alta
        @id_partido      = @id_partido,
        @id_seleccion    = @id_sel1,
        @esquema_tactico = '4-4-2';
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 22: Alta fallida - duplicado (mismo partido + selección)
-- RESULTADO ESPERADO: error
-- "- Ya existe una formación para ese partido y selección."
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

BEGIN TRY
    EXEC dbo.SP_Formacion_Alta
        @id_partido      = @id_partido,
        @id_seleccion    = @id_sel1,
        @esquema_tactico = '3-5-2';
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 23: Modificación exitosa
-- RESULTADO ESPERADO: se actualiza el esquema táctico.
-- ---------------------------------------------------------
DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion
                             WHERE esquema_tactico = '4-3-3'
                             ORDER BY id_formacion);
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

IF @id_formacion IS NOT NULL
BEGIN
    EXEC dbo.SP_Formacion_Modificacion
        @id_formacion    = @id_formacion,
        @id_partido      = @id_partido,
        @id_seleccion    = @id_sel1,
        @esquema_tactico = '4-2-3-1';
    PRINT 'OK - Modificación de Formación ejecutada';
END
GO

-- ---------------------------------------------------------
-- PREPARACIÓN CASO 24: crear una formación con jugadores asociados
-- para forzar el error de baja.
-- RESULTADO ESPERADO: 1 formación nueva + 2 filas en Formacion_Jugador.
-- ---------------------------------------------------------

-- 1. Obtener IDs necesarios
DECLARE @id_partido_24 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sel_24     INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Pruebalandia'); -- ID 37

-- 2. Insertar jugadores NUEVOS que pertenezcan a Pruebalandia (si no existen)
IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'JugadorPrueba1' AND id_seleccion = @id_sel_24)
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_24, N'JugadorPrueba1', N'Test', '1998-01-01', N'Club Prueba', N'Defensor', 2);

IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE nombre = N'JugadorPrueba2' AND id_seleccion = @id_sel_24)
    INSERT INTO dbo.Jugador (id_seleccion, nombre, apellido, fecha_nacimiento, club_origen, posicion, dorsal)
    VALUES (@id_sel_24, N'JugadorPrueba2', N'Test', '1999-01-01', N'Club Prueba', N'Mediocampista', 5);

-- 3. Obtener los IDs de estos nuevos jugadores
DECLARE @id_jug_prueba1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorPrueba1' AND id_seleccion = @id_sel_24);
DECLARE @id_jug_prueba2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorPrueba2' AND id_seleccion = @id_sel_24);

-- 4. Crear la formación para Pruebalandia si no existe
IF NOT EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido_24 AND id_seleccion = @id_sel_24)
BEGIN
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_24, @id_sel_24, '4-4-2');
END

DECLARE @id_formacion_24 INT = (SELECT id_formacion FROM dbo.Formacion
                                WHERE id_partido = @id_partido_24
                                  AND id_seleccion = @id_sel_24);

-- 5. Asociar los NUEVOS jugadores a esa formación
IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion_24 AND id_jugador = @id_jug_prueba1)
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    VALUES (@id_formacion_24, @id_jug_prueba1, N'Defensor', 2, 1);

IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion_24 AND id_jugador = @id_jug_prueba2)
    INSERT INTO dbo.Formacion_Jugador (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
    VALUES (@id_formacion_24, @id_jug_prueba2, N'Mediocampista', 5, 1);

PRINT 'OK - Formación con jugadores asociados preparada para CASO 24';

-- ---------------------------------------------------------
-- CASO 24: Baja fallida - formación con jugadores
-- RESULTADO ESPERADO: error
-- "- No se puede eliminar: la formación tiene jugadores asociados."
-- ---------------------------------------------------------

BEGIN TRY
    EXEC dbo.SP_Formacion_Baja @id_formacion = @id_formacion_24;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

-- Borramos lote de prueba
delete dbo.Formacion_Jugador
delete dbo.Formacion
delete dbo.Jugador
delete dbo.Partido_Seleccion
delete dbo.Partido
delete dbo.Sede
delete dbo.Seleccion
delete dbo.Reemplazo

-- Confirmamos borrado de lote de prueba
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Sede]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Seleccion]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Jugador]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Partido]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Partido_Seleccion]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion_Jugador]
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Reemplazo]