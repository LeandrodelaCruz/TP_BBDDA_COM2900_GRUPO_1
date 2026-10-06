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

SET NOCOUNT ON;
GO

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

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Reemplazo';
PRINT '=============================================';

/*
	CASO 1: Alta exitosa
	RESULTADO ESPERADO: se inserta el reemplazo y se devuelve
	el id_reemplazo_generado. Sin errores.
*/

DECLARE @id_jug_baja INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
DECLARE @id_jug_alta INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

EXEC dbo.SP_Reemplazo_Alta
    @id_jugador_baja = @id_jug_baja,
    @id_jugador_alta = @id_jug_alta,
    @fecha_cambio    = '2026-06-01',
    @motivo          = 'Lesi�n muscular';
PRINT 'OK - Alta Reemplazo ejecutada';

GO


/*
	CASO 2: Alta fallida - jugadores iguales
	RESULTADO ESPERADO: error con mensaje
	"- El jugador de baja y el de alta no pueden ser el mismo."
*/ 

DECLARE @id_jug_baja INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');

BEGIN TRY
    EXEC dbo.SP_Reemplazo_Alta
        @id_jugador_baja = @id_jug_baja,
        @id_jugador_alta = @id_jug_baja,
        @fecha_cambio    = '2026-06-01',
        @motivo          = 'Prueba';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


/*
	CASO 3: Alta fallida - jugadores de distinta selecci�n
	 RESULTADO ESPERADO: error con mensaje
	"- Ambos jugadores deben pertenecer a la misma selecci�n."
*/

DECLARE @id_jug_baja INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
DECLARE @id_jug_sel2 INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorSel2');

BEGIN TRY
    EXEC dbo.SP_Reemplazo_Alta
        @id_jugador_baja = @id_jug_baja,
        @id_jugador_alta = @id_jug_sel2,
        @fecha_cambio    = '2026-06-01',
        @motivo          = 'Prueba';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


/*
	CASO 4: Alta fallida - fecha futura
	RESULTADO ESPERADO: error con mensaje
	"- La fecha del cambio no puede ser futura."
*/

DECLARE @id_jug_baja INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
DECLARE @id_jug_alta INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

BEGIN TRY
    EXEC dbo.SP_Reemplazo_Alta
        @id_jugador_baja = @id_jug_baja,
        @id_jugador_alta = @id_jug_alta,
        @fecha_cambio    = '2099-01-01',
        @motivo          = 'Prueba';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


/*
	CASO 5: Modificaci�n exitosa
	RESULTADO ESPERADO: se actualiza el reemplazo creado en el caso 1.
*/

DECLARE @id_reemplazo INT = (SELECT MIN(id_reemplazo) FROM dbo.Reemplazo
                             WHERE motivo = 'Lesi�n muscular');
DECLARE @id_jug_baja INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorBaja1');
DECLARE @id_jug_alta INT = (SELECT id_jugador FROM dbo.Jugador WHERE nombre = N'JugadorAlta1');

IF @id_reemplazo IS NOT NULL
BEGIN
    EXEC dbo.SP_Reemplazo_Modificacion
        @id_reemplazo    = @id_reemplazo,
        @id_jugador_baja = @id_jug_baja,
        @id_jugador_alta = @id_jug_alta,
        @fecha_cambio    = '2026-06-02',
        @motivo          = 'Lesi�n muscular - actualizado';

    PRINT 'OK - Modificaci�n de Reemplazo ejecutada';
END
ELSE
    PRINT 'No hay reemplazo de prueba para modificar';
GO


/*
	CASO 6: Baja exitosa
	RESULTADO ESPERADO: se elimina el reemplazo.
*/

DECLARE @id_reemplazo INT = (SELECT MIN(id_reemplazo) FROM dbo.Reemplazo
                             WHERE motivo = 'Lesi�n muscular - actualizado');

IF @id_reemplazo IS NOT NULL
BEGIN
    EXEC dbo.SP_Reemplazo_Baja @id_reemplazo = @id_reemplazo;
    PRINT 'OK - Baja de Reemplazo ejecutada';
END
ELSE
    PRINT 'No hay reemplazo de prueba para eliminar';
GO


/*
	CASO 7: Baja fallida - reemplazo inexistente
	RESULTADO ESPERADO: error con mensaje
	"- No existe el reemplazo indicado."
*/
BEGIN TRY
    EXEC dbo.SP_Reemplazo_Baja @id_reemplazo = -99999;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
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
