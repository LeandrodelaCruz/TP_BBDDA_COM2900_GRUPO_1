/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Ejecutar en la BD del proyecto; sus datos se revierten al terminar.
IF @@TRANCOUNT <> 0
    THROW 59990,N'Ejecute el test sin una transaccion previa abierta.',1;
IF EXISTS(SELECT 1 FROM dbo.Seleccion WHERE pais LIKE N'TA[_]%')
    THROW 59990,N'El prefijo TA_ esta ocupado. El test no modifico esos datos.',1;
SET XACT_ABORT OFF;
BEGIN TRANSACTION;
BEGIN TRY

    DECLARE @sede INT,@sa INT,@sb INT,@sc INT,@sd INT,@p INT,@q INT,@semi INT;
    INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario) VALUES(N'TA_Estadio',N'TA_Ciudad',N'TA_Sede',50000,'UTC');
    SET @sede=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_A','UEFA','A'); SET @sa=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_B','UEFA','B'); SET @sb=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_C','UEFA','C'); SET @sc=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_D','UEFA','D'); SET @sd=SCOPE_IDENTITY();
    DECLARE @ids TABLE(id INT);
    INSERT @ids EXEC abm.Partidos_Alta @sede,@sa,@sb,'20260701','20260701 12:00','20260701 12:00','CUARTOS';
    SELECT @p=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@sc,@sd,'20260701','20260701 18:00','20260701 18:00','CUARTOS';
    SELECT @q=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@sa,@sc,'20260705','20260705 12:00','20260705 12:00','SEMIFINAL';
    SELECT @semi=id FROM @ids; DELETE @ids;
    EXEC abm.Cruce_Partido_Alta @semi,1,@p,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @semi,2,@q,'GANADOR';
    DECLARE @conflicto INT,@externo INT,@futuro INT,@asistente INT,@otro INT,@var INT,@avar INT;
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Conflicto',N'TA_A','Principal'); SET @conflicto=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Externo',N'TA_X','Principal'); SET @externo=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Futuro',N'TA_C','Principal'); SET @futuro=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Asistente1',N'TA_X','Asistente'); SET @asistente=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Asistente2',N'TA_Y','Asistente'); SET @otro=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_VAR',N'TA_X','VAR'); SET @var=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_AVAR',N'TA_Y','VAR'); SET @avar=SCOPE_IDENTITY();
    DECLARE @aviso NVARCHAR(2048);
    -- Reutilizar solo la referencia si USA ya esta cargada; no modificar su fila.
    DECLARE @usa INT=(SELECT id_seleccion FROM dbo.Seleccion WHERE pais=N'USA');
    IF @usa IS NULL
        UPDATE dbo.Seleccion SET pais=N'USA' WHERE id_seleccion=@sa;
    ELSE
        UPDATE dbo.Partido SET id_seleccion_1=@usa WHERE id_partido=@p;
    UPDATE dbo.Arbitro SET pais=N'United States' WHERE id_arbitro=@conflicto;
    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Alta @p,@conflicto,'PRINCIPAL';
        THROW 59999,N'FALLO: se esperaba rechazo: Alias USA y United States',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51601 THROW;
        PRINT N'OK: Alias USA y United States';
    END CATCH;

    UPDATE dbo.Seleccion SET pais=N'TA_A' WHERE id_seleccion=@sa;
    UPDATE dbo.Partido SET id_seleccion_1=@sa WHERE id_partido=@p;
    UPDATE dbo.Arbitro SET pais=N'TA_A' WHERE id_arbitro=@conflicto;

    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Alta @p,@conflicto,'PRINCIPAL';
        THROW 59999,N'FALLO: se esperaba rechazo: Nacionalidad rechazada',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51601 THROW;
        PRINT N'OK: Nacionalidad rechazada';
    END CATCH;
    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Alta @p,@asistente,'PRINCIPAL';
        THROW 59999,N'FALLO: se esperaba rechazo: Categoria incompatible',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51602 THROW;
        PRINT N'OK: Categoria incompatible';
    END CATCH;
    EXEC abm.Designacion_Arbitral_Alta @p,@futuro,'PRINCIPAL',@aviso OUTPUT,0;
    IF @aviso NOT LIKE N'%POSIBLE CRUCE%' OR @aviso NOT LIKE N'%INCOMPLETA%'
        THROW 59999,N'Falta advertencia de cruce potencial o cuadro parcial.',1;
    PRINT @aviso;
    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Alta @p,@externo,'PRINCIPAL';
        THROW 59999,N'FALLO: se esperaba rechazo: Un solo principal',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51602 THROW;
        PRINT N'OK: Un solo principal';
    END CATCH;
    EXEC abm.Designacion_Arbitral_Alta @p,@externo,'CUARTO ARBITRO',@aviso OUTPUT,0;
    EXEC abm.Designacion_Arbitral_Alta @p,@asistente,'ASISTENTE',@aviso OUTPUT,0;
    EXEC abm.Designacion_Arbitral_Alta @p,@otro,'ASISTENTE',@aviso OUTPUT,0;
    EXEC abm.Designacion_Arbitral_Alta @p,@var,'VAR',@aviso OUTPUT,0;
    EXEC abm.Designacion_Arbitral_Alta @p,@avar,'AVAR',@aviso OUTPUT,0;
    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Modificacion @p,@asistente,'VAR';
        THROW 59999,N'FALLO: se esperaba rechazo: Modificacion valida categoria y cupos',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51602 THROW;
        PRINT N'OK: Modificacion valida categoria y cupos';
    END CATCH;
    BEGIN TRY
        EXEC abm.Partidos_Modificacion @p,@sede,@sc,@sb,'20260701','20260701 12:00','20260701 12:00','CUARTOS';
        THROW 59999,N'FALLO: se esperaba rechazo: Cambio de participante contra arbitro designado',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51301 THROW;
        PRINT N'OK: Cambio de participante contra arbitro designado';
    END CATCH;
    BEGIN TRY
        EXEC abm.Arbitro_Modificar @futuro,NULL,N'TA_Futuro',NULL,N'TA_B','Principal',NULL;
        THROW 59999,N'FALLO: se esperaba rechazo: Cambio de pais con designaciones',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>50402 THROW;
        PRINT N'OK: Cambio de pais con designaciones';
    END CATCH;
    -- La ruta se precisa con los participantes informados, sin propagacion de resultados.
    EXEC abm.Partidos_Modificacion @semi,@sede,@sa,@sd,'20260705','20260705 12:00','20260705 12:00','SEMIFINAL',@devolver=0;
    EXEC negocio.Evaluar_Cruce_Arbitral @p,@futuro,@aviso OUTPUT;
    IF @aviso LIKE N'%POSIBLE CRUCE%' THROW 59999,N'La seleccion eliminada sigue generando conflicto potencial.',1;
    PRINT N'OK: el conflicto desaparece al informar otro participante en el destino';
    IF @@TRANCOUNT<>1 THROW 59999,N'Un rechazo destruyo la transaccion externa.',1;
    IF (SELECT COUNT(*) FROM dbo.Designacion_Arbitral WHERE id_partido=@p)<>6
        THROW 59999,N'Equipo incompleto.',1;
    EXEC abm.Designacion_Arbitral_GetByPartido @p;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
