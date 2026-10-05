/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripci�n:
    Script de testing de los Stored Procedures ABM de las tablas:
        - dbo.Partido

    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
    Se prueban tanto casos exitosos como casos con validaciones fallidas.

    Ejecutar despu�s de Script Tabla S3 ABM.sql
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   PREPARACI�N: datos m�nimos de apoyo
   =========================================================
   Resultado esperado: se insertan (si no existen) una sede,
   dos selecciones, dos jugadores por selecci�n, un partido
   y la relaci�n partido-selecci�n. Todo con IDs conocidos
   para poder referenciarlos en las pruebas.
   ========================================================= */

-- Sede de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing')
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing', N'Ciudad Test', N'Pa�s Test', 50000, 'UTC-03:00');

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

-- Jugadores de prueba (2 por selecci�n)
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

-- Relaci�n partido-selecci�n de prueba
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
   PRUEBAS: dbo.Partido
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Partido';
PRINT '=============================================';

-- ---------------------------------------------------------
-- CASO 8: Alta exitosa de partido
-- RESULTADO ESPERADO: id_partido_generado > 0
-- ---------------------------------------------------------
DECLARE @id_sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

EXEC dbo.SP_Partido_Alta
    @id_sede            = @id_sede,
    @fecha              = '2026-06-20',
    @horario_local      = '2026-06-20 15:00:00',
    @horario_UTC        = '2026-06-20 18:00:00',
    @fase               = 'GRUPOS',
    @resultado_final    = NULL,
    @asistencia_publico = 45000;
-- Esperado: 1 fila con id_partido_generado > 0
GO


-- ---------------------------------------------------------
-- CASO 9: Alta fallida - fase inv�lida
-- RESULTADO ESPERADO: error con mensaje
-- "- La fase indicada no es v�lida."
-- ---------------------------------------------------------
DECLARE @id_sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

BEGIN TRY
    EXEC dbo.SP_Partido_Alta
        @id_sede       = @id_sede,
        @fecha         = '2026-06-21',
        @horario_local = '2026-06-21 15:00:00',
        @horario_UTC   = '2026-06-21 18:00:00',
        @fase          = 'FASE_INVENTADA';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 10: Alta fallida - sede inexistente + asistencia > capacidad
-- RESULTADO ESPERADO: mensaje agrupado con al menos:
--   "- No existe la sede indicada."
-- ---------------------------------------------------------
BEGIN TRY
    EXEC dbo.SP_Partido_Alta
        @id_sede       = -99999,
        @fecha         = '2026-06-22',
        @horario_local = '2026-06-22 15:00:00',
        @horario_UTC   = '2026-06-22 18:00:00',
        @fase          = 'GRUPOS';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 11: Alta fallida - asistencia supera capacidad
-- RESULTADO ESPERADO: error
-- "- La asistencia supera la capacidad de la sede."
-- ---------------------------------------------------------
DECLARE @id_sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

BEGIN TRY
    EXEC dbo.SP_Partido_Alta
        @id_sede            = @id_sede,
        @fecha              = '2026-06-23',
        @horario_local      = '2026-06-23 15:00:00',
        @horario_UTC        = '2026-06-23 18:00:00',
        @fase               = 'GRUPOS',
        @asistencia_publico = 999999;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 12: Modificaci�n exitosa
-- RESULTADO ESPERADO: se actualiza el partido de prueba TEST-ABM.
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

IF @id_partido IS NOT NULL
BEGIN
    EXEC dbo.SP_Partido_Modificacion
        @id_partido         = @id_partido,
        @id_sede            = @id_sede,
        @fecha              = '2026-06-15',
        @horario_local      = '2026-06-15 19:00:00',
        @horario_UTC        = '2026-06-15 22:00:00',
        @fase               = 'GRUPOS',
        @resultado_final    = N'TEST-ABM',
        @asistencia_publico = 40000;
    PRINT 'OK - Modificaci�n de Partido ejecutada';
END
GO


-- ---------------------------------------------------------
-- CASO 13: Baja fallida - partido con dependencias (formaciones)
-- RESULTADO ESPERADO: error
-- "- No se puede eliminar: el partido tiene formaciones asociadas."
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');

BEGIN TRY
    EXEC dbo.SP_Partido_Baja @id_partido = @id_partido;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 14: Baja fallida - partido inexistente
-- RESULTADO ESPERADO: error "- No existe el partido indicado."
-- ---------------------------------------------------------
BEGIN TRY
    EXEC dbo.SP_Partido_Baja @id_partido = -99999;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO