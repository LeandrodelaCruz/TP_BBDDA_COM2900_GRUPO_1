/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodríguez, Elías Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripción:
    Script de testing del Stored Procedure ABM de la tabla:
        - dbo.Partido_Seleccion

    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
    Se prueban tanto casos exitosos como casos con validaciones fallidas.

    Ejecutar después de SP PartidoSeleccion ABM.sql
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/*
   datos mínimos para tests
*/

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

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Partido_Seleccion';
PRINT '=============================================';

/*
	 CASO 1: Alta exitosa
	RESULTADO ESPERADO: se agrega la selección al partido.
	(Se crea un partido nuevo para no tocar el de prueba existente.)
*/

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


/*
	CASO 2: Alta fallida - tercera selección en el mismo partido
	RESULTADO ESPERADO: error
	"- El partido ya tiene dos selecciones asignadas."
*/

DECLARE @id_partido_ps INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Pruebalandia');

EXEC dbo.SP_PartidoSeleccion_Alta @id_partido = @id_partido_ps, @id_seleccion = @id_sel2;

-- Tercera selección (creamos una auxiliar)
IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'ExtraTest')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'ExtraTest', N'TEST', 'B');

DECLARE @id_sel3 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'ExtraTest');

BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Alta
        @id_partido   = @id_partido_ps,
        @id_seleccion = @id_sel3;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


/*
	CASO 3: Alta fallida - duplicado exacto
	RESULTADO ESPERADO: error
	"- La selección ya está asignada a este partido."
*/

DECLARE @id_partido_ps INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Alta
        @id_partido   = @id_partido_ps,
        @id_seleccion = @id_sel1;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 4: Baja exitosa
	RESULTADO ESPERADO: se elimina la relación.
*/

DECLARE @id_partido_ps INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

EXEC dbo.SP_PartidoSeleccion_Baja @id_partido = @id_partido_ps, @id_seleccion = @id_sel1;
PRINT 'OK - Baja Partido_Seleccion ejecutada';
GO

/*
	CASO 5: Baja fallida - relación inexistente
	RESULTADO ESPERADO: error
	"- No existe la relación partido-selección indicada."
*/

BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Baja @id_partido = -99999, @id_seleccion = -99999;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 6: Modificación exitosa
	RESULTADO ESPERADO: se actualiza la relación partido-selección
	cambiando la selección asociada a un partido.
*/

DECLARE @id_sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');
DECLARE @id_sel2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Pruebalandia');

-- Creamos partido nuevo con una sola selección
INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final)
VALUES (@id_sede, '2026-07-01', '2026-07-01 18:00:00', '2026-07-01 21:00:00', 'GRUPOS', N'TEST-MOD');

DECLARE @id_partido_mod INT = SCOPE_IDENTITY();

INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion)
VALUES (@id_partido_mod, @id_sel1);

-- Modificamos: cambiamos selección Testlandia por Pruebalandia
EXEC dbo.SP_PartidoSeleccion_Modificacion
    @id_partido         = @id_partido_mod,
    @id_seleccion       = @id_sel1,
    @nuevo_id_partido   = @id_partido_mod,   -- mismo partido
    @nueva_id_seleccion = @id_sel2;          -- nueva selección

PRINT 'OK - Modificación Partido_Seleccion ejecutada';
GO

/*
-- CASO 7: Modificación fallida - relación original inexistente
-- RESULTADO ESPERADO: error
-- "- No existe la relación partido-selección original."
*/

BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Modificacion
        @id_partido         = -99999,
        @id_seleccion       = -99999,
        @nuevo_id_partido   = 1,
        @nueva_id_seleccion = 1;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 8: Modificación fallida - la nueva relación ya existe
	RESULTADO ESPERADO: error
	"- Ya existe la nueva relación partido-selección."
	(o bien "- El nuevo partido ya tiene dos selecciones asignadas."
	si el partido destino ya alcanzó el cupo de 2)
*/

DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');
DECLARE @id_sel2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Pruebalandia');

-- Reutilizamos el partido TEST-ABM (ya tiene 2 selecciones)
DECLARE @id_partido_lleno INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');

-- Intentamos mover una relación hacia un partido que ya está completo
BEGIN TRY
    EXEC dbo.SP_PartidoSeleccion_Modificacion
        @id_partido         = @id_partido_lleno,
        @id_seleccion       = @id_sel1,
        @nuevo_id_partido   = @id_partido_lleno,
        @nueva_id_seleccion = @id_sel2;  -- ya existe esa combinación
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

-- Borramos lote de prueba
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
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Reemplazo]