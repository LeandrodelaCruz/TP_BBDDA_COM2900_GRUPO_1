/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodríguez, Elías Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripcion:
    Script de testing del Stored Procedure ABM de la tabla:
        - dbo.Partido

    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
    Se prueban tanto casos exitosos como casos con validaciones fallidas.

    Ejecutar despues de SP Partido ABM.sql
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Partido_Test
AS
BEGIN
    SET NOCOUNT ON;

    /*
       datos mínimos para tests
    */

    -- Sede de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing')
        INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
        VALUES (N'Estadio Testing', N'Ciudad Test', N'Pais Test', 50000, 'UTC-03:00');

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

    -- Jugadores de prueba 
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
        INSERT INTO dbo.Partido (id_sede, id_seleccion_1, id_seleccion_2, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico)
        VALUES (@id_sede_test, @id_sel_test1, @id_sel_test2, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-ABM', 30000);

    DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');

    -- Formacion de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion
                   WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1)
        INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
        VALUES (@id_partido_test, @id_sel_test1, '4-3-3');

    PRINT '=== Datos de apoyo preparados ===';

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Partido';
    PRINT '=============================================';

    /*
    	CASO 1: Alta exitosa de partido
    	RESULTADO ESPERADO: id_partido_generado > 0
    */

    DECLARE @id_sede_b4 INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

	BEGIN TRY
    EXEC abm.Partidos_Alta
        @id_sede            = @id_sede_b4,
        @id_seleccion_1     = @id_sel_test1,
        @id_seleccion_2     = @id_sel_test2,
        @fecha              = '2026-06-20',
        @horario_local      = '2026-06-20 15:00:00',
        @horario_UTC        = '2026-06-20 18:00:00',
        @fase               = 'GRUPOS',
        @resultado_final    = NULL,
        @asistencia_publico = 45000;
    PRINT 'OK - Alta Partido ejecutada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 2: Alta fallida - fase invalida
    	RESULTADO ESPERADO: error con mensaje
    	"- La fase indicada no es valida."
    */

    DECLARE @id_sede_b5 INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

    BEGIN TRY
        EXEC abm.Partidos_Alta
            @id_sede       = @id_sede_b5,
			@id_seleccion_1     = @id_sel_test1,
            @id_seleccion_2     = @id_sel_test2,
            @fecha         = '2026-06-21',
            @horario_local = '2026-06-21 15:00:00',
            @horario_UTC   = '2026-06-21 18:00:00',
            @fase          = 'FASE_INVENTADA';
        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 3: Alta fallida - sede inexistente
    	RESULTADO ESPERADO: mensaje agrupado con al menos:
    	"- No existe la sede indicada."
    */

    BEGIN TRY
        EXEC abm.Partidos_Alta
            @id_sede       = -99999,
			@id_seleccion_1     = @id_sel_test1,
            @id_seleccion_2     = @id_sel_test2,
            @fecha         = '2026-06-22',
            @horario_local = '2026-06-22 15:00:00',
            @horario_UTC   = '2026-06-22 18:00:00',
            @fase          = 'GRUPOS';
        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 4: Alta fallida - asistencia supera capacidad
    	RESULTADO ESPERADO: error
    	"- La asistencia supera la capacidad de la sede."
    */

    DECLARE @id_sede_b7 INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

    BEGIN TRY
        EXEC abm.Partidos_Alta
            @id_sede            = @id_sede_b7,
			@id_seleccion_1     = @id_sel_test1,
            @id_seleccion_2     = @id_sel_test2,
            @fecha              = '2026-06-23',
            @horario_local      = '2026-06-23 15:00:00',
            @horario_UTC        = '2026-06-23 18:00:00',
            @fase               = 'GRUPOS',
            @asistencia_publico = 999999;
        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

	/* 
    CASO 5: Alta fallida - selecciones iguales
    RESULTADO ESPERADO: "- Las dos selecciones del partido deben ser distintas."
    */

    BEGIN TRY
        EXEC abm.Partidos_Alta
            @id_sede            = @id_sede_test,
            @id_seleccion_1     = @id_sel_test1,
            @id_seleccion_2     = @id_sel_test1,
            @fecha              = '2026-06-24',
            @horario_local      = '2026-06-24 15:00:00',
            @horario_UTC        = '2026-06-24 18:00:00',
            @fase               = 'GRUPOS';
        PRINT 'ERROR: no se lanzó la excepción esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH


    /*
    	CASO 6: Modificacion exitosa
    	RESULTADO ESPERADO: se actualiza el partido de prueba TEST-ABM.
    */

    DECLARE @id_partido_b8 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
    DECLARE @id_sede_b8 INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing');

    IF @id_partido_b8 IS NOT NULL
    BEGIN
        EXEC abm.Partidos_Modificacion
            @id_partido         = @id_partido_b8,
            @id_sede            = @id_sede_b8,
			@id_seleccion_1     = @id_sel_test1,
			@id_seleccion_2     = @id_sel_test2,
            @fecha              = '2026-06-15',
            @horario_local      = '2026-06-15 19:00:00',
            @horario_UTC        = '2026-06-15 22:00:00',
            @fase               = 'GRUPOS',
            @resultado_final    = N'TEST-ABM',
            @asistencia_publico = 40000;
        PRINT 'OK - Modificacion de Partido ejecutada';
    END
	SELECT * FROM dbo.partido
    /*
    	CASO 7: Baja fallida - partido con dependencias (formaciones)
    	RESULTADO ESPERADO: error
    	"- No se puede eliminar: el partido tiene formaciones asociadas."
    */

    DECLARE @id_partido_b9 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');

    BEGIN TRY
        EXEC abm.Partidos_Baja @id_partido = @id_partido_b9;
        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 8: Baja fallida - partido inexistente
    	RESULTADO ESPERADO: error "- No existe el partido indicado."
    */

    BEGIN TRY
        EXEC abm.Partidos_Baja @id_partido = -99999;
        PRINT 'ERROR: no se lanzo la excepcion esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    -- Borramos todo lo creado   

    delete dbo.Formacion_Jugador
    delete dbo.Jugador
    delete dbo.Formacion
    delete dbo.Partido
    delete dbo.Anunciante
    delete dbo.Region
    delete dbo.Sede
    delete dbo.Seleccion
    delete dbo.Arbitro
    delete dbo.Campania
    delete dbo.Pieza_Publicitaria
    delete dbo.Pieza_Para_Region
    delete dbo.Personal_Tecnico 
    delete dbo.Reemplazo
    delete dbo.Sustitucion
    delete dbo.Designacion_Arbitral
    delete dbo.Sancion_Arbitral
    delete dbo.Asignacion_Publicitaria
    delete dbo.Incidencia

    -- Confirmamos borrado de lote de prueba

    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Seleccion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Jugador]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Partido]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion_Jugador]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Reemplazo]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Anunciante]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Region]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Sede]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Seleccion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Arbitro]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Campania]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Pieza_Publicitaria]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Pieza_Para_Region]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Personal_Tecnico]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Jugador]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Reemplazo]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Partido]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion_Jugador]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Sustitucion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Designacion_Arbitral]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Sancion_Arbitral]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Asignacion_Publicitaria]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Incidencia]

END;
GO

EXEC test.Partido_Test;
GO
