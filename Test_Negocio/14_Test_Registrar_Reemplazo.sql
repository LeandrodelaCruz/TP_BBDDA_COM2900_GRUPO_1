/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - Comision 01-2900
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 02/11/2026
    Objetivo: probar el reemplazo de convocatoria y su atomicidad.
    Requisitos: tablas, ABM de Seleccion/Jugador/Reemplazo y negocio 14.
    Ejecutar en una base de pruebas. No usa ni elimina datos ajenos.
    Cada caso revierte sus datos; los contadores IDENTITY pueden avanzar.
*/
USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Registrar_Reemplazo_Test
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT <> 0
        THROW 51500, N'Ejecute el test sin una transaccion abierta.', 1;

    DECLARE @caso INT = 1, @seleccion INT, @saliente INT, @entrante INT,
            @fallo BIT, @numero INT, @mensaje NVARCHAR(2048),
            @pais NVARCHAR(80) = N'TestReemplazo_' + CONVERT(NVARCHAR(36), NEWID());
    DECLARE @id TABLE (id INT);

    WHILE @caso <= 6
    BEGIN
        BEGIN TRY
            BEGIN TRANSACTION;
            DELETE FROM @id;
            INSERT INTO @id EXEC abm.Seleccion_Alta @pais, N'CONMEBOL', 'A';
            SELECT @seleccion = id FROM @id;
            EXEC abm.Jugador_Alta '19900101', N'Club Test', N'Original', N'Jugador', 'Defensa', 10, @seleccion;
            SELECT @saliente = id_jugador FROM dbo.Jugador WHERE id_seleccion = @seleccion;

            IF @caso = 1
            BEGIN
                -- Esperado: ambos jugadores conservados, un reemplazo,
                -- un solo convocado vigente y el mismo dorsal.
                EXEC negocio.Registrar_Reemplazo @saliente, '20260601', 'Lesion',
                    N'Entrante', N'Test', '19950101', N'Club Test', 'Defensa';
                SELECT @entrante = id_jugador FROM dbo.Jugador
                WHERE id_seleccion = @seleccion AND nombre = N'Entrante';
                IF (SELECT COUNT(*) FROM dbo.Jugador WHERE id_seleccion = @seleccion) <> 2
                    THROW 51501, N'No se conservaron ambos jugadores.', 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.Reemplazo WHERE id_jugador_baja = @saliente AND id_jugador_alta = @entrante)
                    THROW 51501, N'No se registro el reemplazo.', 1;
                IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @entrante AND dorsal = 10)
                    THROW 51501, N'El entrante no heredo el dorsal.', 1;

                -- Esperado: cadena A -> B -> C, solo C vigente.
                EXEC negocio.Registrar_Reemplazo @entrante, '20260602', 'Lesion',
                    N'Segundo', N'Test', '19960101', N'Club Test', 'Defensa';
                IF (SELECT COUNT(*) FROM dbo.Jugador j WHERE id_seleccion = @seleccion
                    AND NOT EXISTS (SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja = j.id_jugador)) <> 1
                    THROW 51501, N'La cadena no dejo un unico convocado vigente.', 1;
                EXEC negocio.Listar_Convocados_Vigentes @seleccion;
                SELECT r.* FROM dbo.Reemplazo r JOIN dbo.Jugador j ON j.id_jugador = r.id_jugador_baja
                WHERE j.id_seleccion = @seleccion;
            END
            ELSE
            BEGIN
                SET @fallo = 0;
                -- Caso 2: baja repetida. Caso 3: entrante ya convocado.
                -- Caso 4: datos obligatorios invalidos.
                -- Caso 5: cadena con fecha anterior al alta del saliente.
                -- Caso 6: error de escritura despues de crear al entrante.
                IF @caso IN (2, 5)
                BEGIN
                    EXEC negocio.Registrar_Reemplazo @saliente, '20260602', 'Lesion',
                        N'Primero', N'Test', '19950101', N'Club Test', 'Defensa';
                    IF @caso = 5
                        SELECT @saliente = id_jugador FROM dbo.Jugador
                        WHERE id_seleccion = @seleccion AND nombre = N'Primero';
                END;
                IF @caso = 6
                BEGIN
                    -- Inyeccion de fallo transitoria: el ABM de Jugador ya
                    -- habra insertado al entrante cuando falle Reemplazo.
                    -- CREATE TRIGGER necesita su propio lote. El ROLLBACK
                    -- elimina tanto el trigger como los datos de esta prueba.
                    EXEC(N'CREATE TRIGGER dbo.Test_Reemplazo_Fallo_Atomicidad
                        ON dbo.Reemplazo AFTER INSERT AS
                        BEGIN THROW 51506, ''Fallo de escritura simulado.'', 1; END;');
                END;
                BEGIN TRY
                    IF @caso = 3
                        EXEC negocio.Registrar_Reemplazo @saliente, '20260601', 'Lesion',
                            N'Jugador', N'Original', '19900101', N'Club Test', 'Defensa';
                    ELSE IF @caso = 4
                        EXEC negocio.Registrar_Reemplazo NULL, NULL, '',
                            N'', N'', NULL, N'', '';
                    ELSE
                        EXEC negocio.Registrar_Reemplazo @saliente, '20260601', 'Lesion',
                            N'Entrante', N'Test', '19970101', N'Club Test', 'Defensa';
                END TRY
                BEGIN CATCH
                    SELECT @fallo = 1, @numero = ERROR_NUMBER(), @mensaje = ERROR_MESSAGE();
                END CATCH;

                -- El error con XACT_ABORT puede dejar la transaccion externa
                -- no confirmable; el llamador debe revertirla por completo.
                IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
                IF @fallo = 0 THROW 51502, N'No se produjo el error esperado.', 1;
                IF @caso < 6 AND @numero <> 51401
                    THROW 51503, @mensaje, 1;
                IF @caso = 6 AND @numero <> 51506
                    THROW 51503, @mensaje, 1;
                IF @caso = 6 AND
                    (EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_seleccion = @seleccion)
                     OR OBJECT_ID(N'dbo.Test_Reemplazo_Fallo_Atomicidad', N'TR') IS NOT NULL)
                    THROW 51504, N'El rollback dejo datos u objetos de prueba.', 1;
                PRINT N'Error esperado: ' + @mensaje;
            END;

            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            PRINT N'OK - Caso ' + CONVERT(NVARCHAR(10), @caso);
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            THROW;
        END CATCH;
        SET @caso += 1;
    END;
END;
GO

EXEC test.Registrar_Reemplazo_Test;
GO
