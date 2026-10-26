/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodr�guez, El�as Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripci�n:
    Script de testing del Stored Procedure ABM de la tabla:
        - dbo.Reemplazo

    Cada bloque incluye el RESULTADO ESPERADO en comentarios.
    Se prueban tanto casos exitosos como casos con validaciones fallidas.

    Ejecutar despu�s de SP Reemplazo ABM.sql
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Reemplazo_Test
AS
BEGIN
    SET NOCOUNT ON;

    /*
       datos m�nimos para tests
    */

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

    DECLARE @id_jug_baja_b3 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
    DECLARE @id_jug_alta_b3 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');
    DECLARE @id_jug_sel2_b3 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorSel2');

    -- Partido de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE resultado_final = N'TEST-ABM')
        INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico, id_seleccion_1, id_seleccion_2)
        VALUES (@id_sede_test, '2026-06-15', '2026-06-15 18:00:00', '2026-06-15 21:00:00', 'GRUPOS', N'TEST-ABM', 30000, @id_sel_test1, @id_sel_test2);

    DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');

    PRINT '=== Datos de apoyo preparados ===';

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Reemplazo';
    PRINT '=============================================';

    /*
    	CASO 1: Alta exitosa
    	RESULTADO ESPERADO: se inserta el reemplazo y se devuelve
    	el id_reemplazo_generado. Sin errores.
    */

    DECLARE @id_jug_baja_b4 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
    DECLARE @id_jug_alta_b4 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

    EXEC abm.Reemplazo_Alta
        @id_jugador_baja = @id_jug_baja_b4,
        @id_jugador_alta = @id_jug_alta_b4,
        @fecha_cambio    = '2026-06-01',
        @motivo          = 'Lesi�n muscular';
    PRINT 'OK - Alta Reemplazo ejecutada';

    /*
    	CASO 2: Alta fallida - jugadores iguales
    	RESULTADO ESPERADO: error con mensaje
    	"- El jugador de baja y el de alta no pueden ser el mismo."
    */ 

    DECLARE @id_jug_baja_b5 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');

    BEGIN TRY
        EXEC abm.Reemplazo_Alta
            @id_jugador_baja = @id_jug_baja_b5,
            @id_jugador_alta = @id_jug_baja_b5,
            @fecha_cambio    = '2026-06-01',
            @motivo          = 'Prueba';
        PRINT 'ERROR: no se lanz� la excepci�n esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 3: Alta fallida - jugadores de distinta selecci�n
    	 RESULTADO ESPERADO: error con mensaje
    	"- Ambos jugadores deben pertenecer a la misma selecci�n."
    */

    DECLARE @id_jug_baja_b6 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
    DECLARE @id_jug_sel2_b6 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorSel2');

    BEGIN TRY
        EXEC abm.Reemplazo_Alta
            @id_jugador_baja = @id_jug_baja_b6,
            @id_jugador_alta = @id_jug_sel2_b6,
            @fecha_cambio    = '2026-06-01',
            @motivo          = 'Prueba';
        PRINT 'ERROR: no se lanz� la excepci�n esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 4: Alta fallida - fecha futura
    	RESULTADO ESPERADO: error con mensaje
    	"- La fecha del cambio no puede ser futura."
    */

    DECLARE @id_jug_baja_b7 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
    DECLARE @id_jug_alta_b7 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

    BEGIN TRY
        EXEC abm.Reemplazo_Alta
            @id_jugador_baja = @id_jug_baja_b7,
            @id_jugador_alta = @id_jug_alta_b7,
            @fecha_cambio    = '2099-01-01',
            @motivo          = 'Prueba';
        PRINT 'ERROR: no se lanz� la excepci�n esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    /*
    	CASO 5: Modificaci�n exitosa
    	RESULTADO ESPERADO: se actualiza el reemplazo creado en el caso 1.
    */

    DECLARE @id_reemplazo_b8 INT = (SELECT MIN(id_reemplazo) FROM dbo.Reemplazo
                                 WHERE motivo = 'Lesi�n muscular');
    DECLARE @id_jug_baja_b8 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
    DECLARE @id_jug_alta_b8 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

    IF @id_reemplazo_b8 IS NOT NULL
    BEGIN
        EXEC abm.Reemplazo_Modificacion
            @id_reemplazo    = @id_reemplazo_b8,
            @id_jugador_baja = @id_jug_baja_b8,
            @id_jugador_alta = @id_jug_alta_b8,
            @fecha_cambio    = '2026-06-02',
            @motivo          = 'Lesi�n muscular - actualizado';

        PRINT 'OK - Modificaci�n de Reemplazo ejecutada';
    END
    ELSE
        PRINT 'No hay reemplazo de prueba para modificar';

    /*
    	CASO 6: Baja exitosa
    	RESULTADO ESPERADO: se elimina el reemplazo.
    */

    DECLARE @id_reemplazo_b9 INT = (SELECT MIN(id_reemplazo) FROM dbo.Reemplazo
                                 WHERE motivo = 'Lesi�n muscular - actualizado');

    IF @id_reemplazo_b9 IS NOT NULL
    BEGIN
        EXEC abm.Reemplazo_Baja @id_reemplazo = @id_reemplazo_b9;
        PRINT 'OK - Baja de Reemplazo ejecutada';
    END
    ELSE
        PRINT 'No hay reemplazo de prueba para eliminar';

    /*
    	CASO 7: Baja fallida - reemplazo inexistente
    	RESULTADO ESPERADO: error con mensaje
    	"- No existe el reemplazo indicado."
    */
    BEGIN TRY
        EXEC abm.Reemplazo_Baja @id_reemplazo = -99999;
        PRINT 'ERROR: no se lanz� la excepci�n esperada';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
    END CATCH

    -- Borramos lote de prueba
    delete dbo.Formacion
    delete dbo.Jugador
    delete dbo.Partido
    delete dbo.Sede
    delete dbo.Seleccion
    delete dbo.Reemplazo

    -- Confirmamos borrado de lote de prueba
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Sede]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Seleccion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Jugador]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Partido]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Formacion]
    select top 20 * from [MUNDIALDEFUTBOL].[dbo].[Reemplazo]
END;
GO

EXEC test.Reemplazo_Test;
GO