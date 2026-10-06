/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripci�n:
    Script de testing de los Stored Procedures ABM de las tablas:
        - dbo.Reemplazo
        - dbo.Partido
        - dbo.Partido_Seleccion
        - dbo.Formacion
        - dbo.Formacion_Jugador

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
-- CASO 21: Alta fallida - selecci�n no participa del partido
-- RESULTADO ESPERADO: error
-- "- La selecci�n no participa en el partido indicado."
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-PS');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

BEGIN TRY
    EXEC dbo.SP_Formacion_Alta
        @id_partido      = @id_partido,
        @id_seleccion    = @id_sel1,
        @esquema_tactico = '4-4-2';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 22: Alta fallida - duplicado (mismo partido + selecci�n)
-- RESULTADO ESPERADO: error
-- "- Ya existe una formaci�n para ese partido y selecci�n."
-- ---------------------------------------------------------
DECLARE @id_partido INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ABM');
DECLARE @id_sel1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Testlandia');

BEGIN TRY
    EXEC dbo.SP_Formacion_Alta
        @id_partido      = @id_partido,
        @id_seleccion    = @id_sel1,
        @esquema_tactico = '3-5-2';
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO


-- ---------------------------------------------------------
-- CASO 23: Modificaci�n exitosa
-- RESULTADO ESPERADO: se actualiza el esquema t�ctico.
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
    PRINT 'OK - Modificaci�n de Formaci�n ejecutada';
END
GO


-- ---------------------------------------------------------
-- CASO 24: Baja fallida - formaci�n con jugadores
-- RESULTADO ESPERADO: error
-- "- No se puede eliminar: la formaci�n tiene jugadores asociados."
-- (Se prueba luego de cargar Formacion_Jugador, en el caso 27.)
-- ---------------------------------------------------------

DECLARE @id_formacion INT = (SELECT TOP 1 id_formacion FROM dbo.Formacion ORDER BY id_formacion);

BEGIN TRY
    EXEC dbo.SP_Formacion_Baja @id_formacion = @id_formacion;
    PRINT 'ERROR: no se lanz� la excepci�n esperada';
END TRY
BEGIN CATCH
    PRINT 'OK - Error esperado: ' + ERROR_MESSAGE();
END CATCH
GO