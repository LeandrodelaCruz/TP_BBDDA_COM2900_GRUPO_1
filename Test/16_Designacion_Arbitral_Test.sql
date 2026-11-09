/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Instalar este procedimiento y ejecutar: EXEC test.Designacion_Arbitral_Test;
-- Usa la misma BD del proyecto. Solo opera sobre datos propios y los revierte.
CREATE OR ALTER PROCEDURE test.Designacion_Arbitral_Test
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    -- Evitar que el ROLLBACK final revierta trabajo previo del llamador.
    IF @@TRANCOUNT <> 0
        THROW 59990,N'Ejecute el test sin una transaccion previa abierta.',1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @marca NVARCHAR(40)=N'T16_'+CONVERT(NVARCHAR(36),NEWID()),
            @sede INT,@s1 INT,@s2 INT,@partido INT,@arbitro INT,@conflicto INT;
        INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario)
            VALUES(@marca,N'Test ABM',N'Test sede',50000,'UTC');
        SET @sede=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'_A','UEFA','A');
        SET @s1=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'_B','UEFA','B');
        SET @s2=SCOPE_IDENTITY();
        INSERT dbo.Partido(id_sede,id_seleccion_1,id_seleccion_2,fecha,horario_local,horario_UTC,fase)
            VALUES(@sede,@s1,@s2,'20260701','20260701 12:00','20260701 12:00','GRUPOS');
        SET @partido=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(nombre,apellido,pais,puesto) VALUES(N'Prueba',@marca,@marca+N'_X','Principal');
        SET @arbitro=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(@marca,@marca+N'_A','Principal');
        SET @conflicto=SCOPE_IDENTITY();

        BEGIN TRY
            EXEC abm.Designacion_Arbitral_Alta @partido,@conflicto,'PRINCIPAL';
            THROW 59999,N'FALLO: se acepto una nacionalidad incompatible.',1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>51601 THROW;
        END CATCH;
        IF EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@partido)
            THROW 59999,N'FALLO: el rechazo dejo una designacion.',1;

        EXEC abm.Designacion_Arbitral_Alta @partido,@arbitro,'PRINCIPAL';
        IF NOT EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral
            WHERE id_partido=@partido AND id_arbitro=@arbitro AND rol_arbitro='PRINCIPAL')
            THROW 59999,N'FALLO: alta no persistida.',1;

        EXEC abm.Designacion_Arbitral_Modificacion @partido,@arbitro,'CUARTO ARBITRO';
        IF (SELECT COUNT(*) FROM dbo.Designacion_Arbitral WHERE id_partido=@partido)<>1
            OR NOT EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral
                WHERE id_partido=@partido AND id_arbitro=@arbitro AND rol_arbitro='CUARTO ARBITRO')
            THROW 59999,N'FALLO: modificacion no persistida correctamente.',1;

        DECLARE @porPartido TABLE(id_partido INT,id_arbitro INT,nombre_arbitro NVARCHAR(121),
            pais_arbitro NVARCHAR(80),rol_arbitro VARCHAR(30),fecha DATE,
            seleccion_1 NVARCHAR(80),seleccion_2 NVARCHAR(80));
        DECLARE @porArbitro TABLE(id_partido INT,fecha DATE,fase VARCHAR(30),
            seleccion_1 NVARCHAR(80),seleccion_2 NVARCHAR(80),id_arbitro INT,
            nombre_arbitro NVARCHAR(121),rol_arbitro VARCHAR(30));
        INSERT @porPartido EXEC abm.Designacion_Arbitral_GetByPartido @partido;
        INSERT @porArbitro EXEC abm.Designacion_Arbitral_GetByArbitro @arbitro;
        IF (SELECT COUNT(*) FROM @porPartido)<>1 OR NOT EXISTS(
            SELECT 1 FROM @porPartido WHERE id_partido=@partido AND id_arbitro=@arbitro
                AND rol_arbitro='CUARTO ARBITRO' AND fecha='20260701'
                AND nombre_arbitro=N'Prueba '+@marca AND pais_arbitro=@marca+N'_X'
                AND seleccion_1=@marca+N'_A' AND seleccion_2=@marca+N'_B')
            THROW 59999,N'FALLO: consulta por partido incorrecta.',1;
        IF (SELECT COUNT(*) FROM @porArbitro)<>1 OR NOT EXISTS(
            SELECT 1 FROM @porArbitro WHERE id_partido=@partido AND id_arbitro=@arbitro
                AND rol_arbitro='CUARTO ARBITRO' AND fecha='20260701' AND fase='GRUPOS'
                AND nombre_arbitro=N'Prueba '+@marca
                AND seleccion_1=@marca+N'_A' AND seleccion_2=@marca+N'_B')
            THROW 59999,N'FALLO: consulta por arbitro incorrecta.',1;

        EXEC abm.Designacion_Arbitral_Baja @partido,@arbitro;
        IF EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@partido)
            THROW 59999,N'FALLO: baja no persistida.',1;
        DELETE @porPartido;
        DELETE @porArbitro;
        INSERT @porPartido EXEC abm.Designacion_Arbitral_GetByPartido @partido;
        INSERT @porArbitro EXEC abm.Designacion_Arbitral_GetByArbitro @arbitro;
        IF EXISTS(SELECT 1 FROM @porPartido) OR EXISTS(SELECT 1 FROM @porArbitro)
            THROW 59999,N'FALLO: las consultas devuelven la designacion eliminada.',1;
        IF @@TRANCOUNT<>1 THROW 59999,N'FALLO: se altero la transaccion del test.',1;
        ROLLBACK TRANSACTION;
        PRINT N'OK: alta, rechazo de nacionalidad, modificacion, ambas consultas y baja. Datos revertidos.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
