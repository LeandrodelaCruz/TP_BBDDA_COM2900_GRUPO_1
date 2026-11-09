/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - Comision 01-2900
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 07/11/2026
    Objetivo: verificar orden, limites y continuacion del WHILE de jugadores.
    Ejecutar en MUNDIALDEFUTBOL con las tablas,
    esquemas, ABM, selecciones, jugadores, partidos y formaciones del repo.
    Copiar los tres JSON de Test_Importaciones/Datos_Recorridos a SQL Server.
    Todas las escrituras del test se revierten, incluidos los datos de apoyo.
    Esperado: 11 titulares, 26 convocados, repeticion sin duplicados, errores
    intermedios que no impiden aplicar la ultima fila valida.
*/
USE MUNDIALDEFUTBOL;
GO
CREATE OR ALTER PROCEDURE test.Recorrido_Formacion_Jugador_Test
    @archivo_12_titulares NVARCHAR(1000),
    @archivo_26 NVARCHAR(1000),
    @archivo_limite NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    IF @@TRANCOUNT <> 0
        THROW 51810, N'Ejecute sin una transaccion externa.', 1;

    DECLARE @formacion INT, @mexico INT, @cantidad INT;
    SELECT @cantidad = COUNT(*), @formacion = MIN(f.id_formacion), @mexico = MIN(f.id_seleccion)
    FROM dbo.Formacion f JOIN dbo.Partido p ON p.id_partido = f.id_partido
    JOIN dbo.Seleccion s ON s.id_seleccion = f.id_seleccion
    WHERE s.pais = N'Mexico' AND p.fecha = '20260611' AND p.horario_UTC = '20260611 19:00:00';
    IF @cantidad <> 1
        THROW 51811, N'Cargue la formacion de Mexico del primer partido del dataset.', 1;
    IF EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_seleccion = @mexico AND nombre = N'Prueba' AND apellido = N'Limite')
        THROW 51811, N'Ya existe el jugador reservado para probar el limite.', 1;
    SELECT * INTO #Estado_Original_Recorrido FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion;

    BEGIN TRY
        BEGIN TRANSACTION;
        -- Aislar el caso aun si se cargaron alineaciones antes de ejecutar el test.
        DECLARE @jugador INT;
        SELECT @jugador = MIN(id_jugador) FROM #Estado_Original_Recorrido;
        WHILE @jugador IS NOT NULL
        BEGIN
            EXEC abm.FormacionJugador_Baja @id_formacion = @formacion, @id_jugador = @jugador;
            SELECT @jugador = MIN(id_jugador) FROM #Estado_Original_Recorrido WHERE id_jugador > @jugador;
        END;

        EXEC importacion.Importar_Formacion_Jugador_JSON @archivo = @archivo_12_titulares;
        IF (SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion) <> 25
           OR (SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion AND es_titular = 1) <> 11
            THROW 51812, N'No se rechazo al titular 12 o no se continuo con el banco.', 1;
        PRINT 'OK - Formacion_Jugador: rechaza titular 12 y continua con el banco.';

        EXEC importacion.Importar_Formacion_Jugador_JSON @archivo = @archivo_26;
        IF (SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion) <> 26
            THROW 51813, N'No se completaron los 26 convocados al corregir el titular.', 1;
        SELECT * INTO #Antes_Repetir_Recorrido FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion;
        EXEC importacion.Importar_Formacion_Jugador_JSON @archivo = @archivo_26;
        IF EXISTS (SELECT * FROM #Antes_Repetir_Recorrido EXCEPT
                   SELECT * FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion)
           OR EXISTS (SELECT * FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion EXCEPT
                      SELECT * FROM #Antes_Repetir_Recorrido)
            THROW 51814, N'Repetir la entrada cambio las relaciones de la formacion.', 1;

        EXEC abm.Jugador_Alta '19900101',N'Club Test',N'Limite',N'Prueba','Defensa',26,@mexico;
        EXEC importacion.Importar_Formacion_Jugador_JSON @archivo = @archivo_limite;
        IF (SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion) <> 26
           OR NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                          WHERE id_formacion = @formacion AND posicion_en_cancha = 'Prueba posterior')
            THROW 51815, N'No se conservo el limite de 26 o no se proceso la fila posterior a los errores.', 1;
        PRINT 'OK - Formacion_Jugador: limite 26, repeticion estable y fila valida posterior a errores.';

        ROLLBACK TRANSACTION;
        IF EXISTS (SELECT * FROM #Estado_Original_Recorrido EXCEPT
                   SELECT * FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion)
           OR EXISTS (SELECT * FROM dbo.Formacion_Jugador WHERE id_formacion = @formacion EXCEPT
                      SELECT * FROM #Estado_Original_Recorrido)
           OR EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_seleccion = @mexico AND nombre = N'Prueba' AND apellido = N'Limite')
            THROW 51816, N'El test no restauro los datos iniciales.', 1;
        PRINT 'OK - Formacion_Jugador: todas las escrituras de prueba revertidas.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* Ejemplo: ajustar las rutas a la ubicacion de los tres JSON en SQL Server.
EXEC test.Recorrido_Formacion_Jugador_Test
    @archivo_12_titulares = N'/var/opt/mssql/import/12_Jugadores_12_Titulares.json',
    @archivo_26 = N'/var/opt/mssql/import/12_Jugadores_26.json',
    @archivo_limite = N'/var/opt/mssql/import/12_Jugadores_Limite.json';
*/
