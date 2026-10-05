/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripci�n:
    Script de testing de los Stored Procedures ABM de las tablas:
        - dbo.Partido_Seleccion

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
   PRUEBAS: dbo.Partido_Seleccion
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Partido_Seleccion';
PRINT '=============================================';

-- ---------------------------------------------------------
-- CASO 15: Alta exitosa
-- RESULTADO ESPERADO: se agrega la selecci�n al partido.
-- (Se crea un partido nuevo para no tocar el de prueba existente.)
-- ---------------------------------------------------------
DECLARE @id_sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final)
VALUES (@id_sede, '2026-06-25', '2026-06-25 15:00:00', '2026-06-25 18:00:00', 'GRUPOS', N'TEST-PS');
DECLARE @id_partido_ps INT = SCOPE_IDENTITY();

EXEC dbo.SP_PartidoSeleccion_Alta
    @id_partido   = @id_partido_ps,
    @id_seleccion = @id_sel1;
PRINT 'OK - Alta Partido_Seleccion ejecutada';
GO


-- ---------------------------------------------------------
-- CASO 16: Alta fallida - tercera selecci�n en el mismo partido
-- RESULTADO ESPERADO: error
-- "- El partido ya tiene dos selecciones asignadas."
-- ---------------------------------------------------------
DECLARE @id_partido_ps INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Pruebalandia');

EXEC dbo.SP_PartidoSeleccion_Alta @id_partido = @id_partido_ps, @id_seleccion = @id_sel2;

-- Tercera selecci�n (creamos una auxiliar)
IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'ExtraTest')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'ExtraTest', N'TEST', 'B');

DECLARE @id_sel3 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'ExtraTest');

BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Alta
        @id_partido   = @id_partido_ps,
        @id_seleccion = @id_sel3;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 17: Alta fallida - duplicado exacto
-- RESULTADO ESPERADO: error
-- "- La selecci�n ya est� asignada a este partido."
-- ---------------------------------------------------------
DECLARE @id_partido_ps INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Alta
        @id_partido   = @id_partido_ps,
        @id_seleccion = @id_sel1;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 18: Baja exitosa
-- RESULTADO ESPERADO: se elimina la relaci�n.
-- ---------------------------------------------------------
DECLARE @id_partido_ps INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

EXEC dbo.SP_PartidoSeleccion_Baja @id_partido = @id_partido_ps, @id_seleccion = @id_sel1;
PRINT 'OK - Baja Partido_Seleccion ejecutada';
GO


-- ---------------------------------------------------------
-- CASO 19: Baja fallida - relaci�n inexistente
-- RESULTADO ESPERADO: error
-- "- No existe la relaci�n partido-selecci�n indicada."
-- ---------------------------------------------------------
BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Baja @id_partido = -99999, @id_seleccion = -99999;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

