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
        - dbo.Formacion_Jugador

    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
    Se prueban tanto casos exitosos como casos con validaciones fallidas.

    Ejecutar después de SP Formacion Jugador ABM.sql
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

-- Formación de prueba (necesaria para los casos de Formacion_Jugador)
IF NOT EXISTS (
    SELECT 1 FROM dbo.Formacion
    WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1
)
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_test, @id_sel_test1, '4-3-3');

PRINT '=== Datos de apoyo preparados ===';
GO

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Formacion_Jugador';
PRINT '=============================================';

/*
	CASO 1: Alta exitosa
	RESULTADO ESPERADO: se inserta el jugador en la formación.
*/

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);
DECLARE @id_jug1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');

EXEC dbo.SP_FormacionJugador_Alta
    @id_formacion       = @id_formacion,
    @id_jugador         = @id_jug1,
    @posicion_en_cancha = 'Delantero',
    @dorsal_en_cancha   = 10,
    @es_titular         = 1;
PRINT 'OK - Alta Formacion_Jugador ejecutada';
GO

/*
	CASO 2: Alta fallida - dorsal duplicado en la misma formación
	RESULTADO ESPERADO: error
	"- El dorsal en cancha ya está usado en esta formación."
*/

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);
DECLARE @id_jug2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

BEGIN TRY
    EXEC dbo.SP_FormacionJugador_Alta
        @id_formacion       = @id_formacion,
        @id_jugador         = @id_jug2,
        @posicion_en_cancha = 'Delantero',
        @dorsal_en_cancha   = 10,
        @es_titular         = 1;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 3: Baja fallida - formación con jugadores
	RESULTADO ESPERADO: error
	"- No se puede eliminar: la formación tiene jugadores asociados."
*/

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);

BEGIN TRY
    EXEC dbo.SP_Formacion_Baja @id_formacion = @id_formacion;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 4: Alta fallida - jugador de otra selección
	RESULTADO ESPERADO: error
	"- El jugador no pertenece a la selección de la formación."
*/

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);
DECLARE @id_jug_otra_sel INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorSel2');

BEGIN TRY
    EXEC dbo.SP_FormacionJugador_Alta
        @id_formacion       = @id_formacion,
        @id_jugador         = @id_jug_otra_sel, 
        @posicion_en_cancha = 'Mediocampista',
        @dorsal_en_cancha   = 5,
        @es_titular         = 1;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 5: Baja exitosa de Formacion_Jugador
	RESULTADO ESPERADO: se elimina la relación.
*/

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);
DECLARE @id_jug1 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');

EXEC dbo.SP_FormacionJugador_Baja
    @id_formacion = @id_formacion,
    @id_jugador   = @id_jug1;
PRINT 'OK - Baja Formacion_Jugador ejecutada';
GO

/*
	CASO 6: Baja exitosa de Formacion (ya sin jugadores)
	RESULTADO ESPERADO: se elimina la formación.
*/

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion
                             WHERE esquema_tactico = '4-3-3'
                             ORDER BY id_formacion);

IF @id_formacion IS NOT NULL
BEGIN
    EXEC dbo.SP_Formacion_Baja @id_formacion = @id_formacion;
    PRINT 'OK - Baja de Formación ejecutada';
END
ELSE
    PRINT 'No hay formación de prueba para eliminar';
GO

/*
	CASO 7: Baja fallida - Formacion_Jugador inexistente
	RESULTADO ESPERADO: error
	"- No existe la relación formación-jugador indicada."
*/

BEGIN TRY
    EXEC dbo.SP_FormacionJugador_Baja @id_formacion = -99999, @id_jugador = -99999;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

/*
	CASO 8: Alta fallida - jugador expulsado en el partido
	RESULTADO ESPERADO: error
	"- El jugador está expulsado en este partido y no puede integrar la formación."
*/

-- Formación de prueba (dado que se borro previamente)
DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sel_test1    INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

IF NOT EXISTS (
    SELECT 1 FROM dbo.Formacion
    WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1
)
    INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
    VALUES (@id_partido_test, @id_sel_test1, '4-3-3');


DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);
DECLARE @id_partido   INT = (SELECT id_partido FROM dbo.Formacion WHERE id_formacion = @id_formacion);
DECLARE @id_jug1      INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');

-- asignamos expulsión para jugador en partido
IF NOT EXISTS (
    SELECT 1 FROM dbo.Incidencia
    WHERE id_partido = @id_partido
      AND id_jugador = @id_jug1
      AND tipo = 'EXPULSION'
)
    INSERT INTO dbo.Incidencia (id_partido, id_jugador, tipo, motivo, minuto, periodo)
    VALUES (@id_partido, @id_jug1, 'EXPULSION', N'Roja directa test', 45, 'PRIMER TIEMPO');

BEGIN TRY
    EXEC dbo.SP_FormacionJugador_Alta
        @id_formacion       = @id_formacion,
        @id_jugador         = @id_jug1,
        @posicion_en_cancha = 'Delantero',
        @dorsal_en_cancha   = 10,
        @es_titular         = 1;
    PRINT 'ERROR: no se lanzó la excepción esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO

-- Borramos lote de prueba
delete dbo.Formacion_Jugador
delete dbo.Formacion
delete dbo.Incidencia
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
select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Incidencia]