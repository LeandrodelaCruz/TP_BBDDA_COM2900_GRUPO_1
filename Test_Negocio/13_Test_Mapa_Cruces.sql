/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 08/11/2026. Mapa arbitral sin ganadores ni participantes pendientes.
 Resultado esperado: rechazos y operaciones indicados; ROLLBACK completo del escenario.
*/
USE MUNDIALDEFUTBOL;
GO
IF @@TRANCOUNT<>0 THROW 59990,N'Ejecute sin transaccion previa.',1;
SET XACT_ABORT OFF;
BEGIN TRANSACTION;
BEGIN TRY
    DECLARE @marca NVARCHAR(40)=N'TMC_'+CONVERT(NVARCHAR(36),NEWID());
    DECLARE @sede INT,@a INT,@b INT,@c INT,@d INT,@p INT,@q INT,@semi INT,@incompatible INT;
    INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario)
        VALUES(@marca,N'Test',N'Test',10000,'UTC'); SET @sede=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'A','UEFA','A'); SET @a=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'B','UEFA','B'); SET @b=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'C','UEFA','C'); SET @c=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'D','UEFA','D'); SET @d=SCOPE_IDENTITY();
    DECLARE @ids TABLE(id INT);
    INSERT @ids EXEC abm.Partidos_Alta @sede,@a,@b,'20260701','20260701 12:00','20260701 12:00','CUARTOS';
    SELECT @p=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@c,@d,'20260701','20260701 18:00','20260701 18:00','CUARTOS';
    SELECT @q=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@a,@c,'20260705','20260705 12:00','20260705 12:00','SEMIFINAL';
    SELECT @semi=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@b,@d,'20260705','20260705 18:00','20260705 18:00','SEMIFINAL';
    SELECT @incompatible=id FROM @ids; DELETE @ids;
    DECLARE @antes TABLE(id INT PRIMARY KEY,s1 INT,s2 INT,resultado VARCHAR(20));
    INSERT @antes SELECT id_partido,id_seleccion_1,id_seleccion_2,resultado_final
        FROM dbo.Partido WHERE id_partido IN (@p,@q,@semi,@incompatible);
    BEGIN TRY
        EXEC abm.Partidos_Alta @sede,NULL,@b,'20260702','20260702 12:00','20260702 12:00','CUARTOS',@devolver=0;
        THROW 59999,N'FALLO: alta sin participantes aceptada.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51301 THROW;
    END CATCH;
    BEGIN TRY
        EXEC abm.Partidos_Modificacion @p,@sede,@a,NULL,'20260701','20260701 12:00','20260701 12:00','CUARTOS',@devolver=0;
        THROW 59999,N'FALLO: modificacion sin participantes aceptada.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51301 THROW;
    END CATCH;
    EXEC abm.Cruce_Partido_Alta @semi,1,@p,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @semi,2,@q,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @semi,1,@p,'GANADOR';
    IF (SELECT COUNT(*) FROM dbo.Cruce_Partido WHERE id_partido_destino=@semi)<>2
        THROW 59999,N'FALLO: la repeticion duplico cruces.',1;
    BEGIN TRY
        EXEC abm.Cruce_Partido_Alta @p,1,@semi,'GANADOR';
        THROW 59999,N'FALLO: fase invertida aceptada.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51322 THROW;
    END CATCH;
    BEGIN TRY
        EXEC abm.Cruce_Partido_Modificacion @semi,1,@q,'GANADOR';
        THROW 59999,N'FALLO: origen incompatible aceptado.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51324 THROW;
    END CATCH;
    IF NOT EXISTS(SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_destino=@semi AND posicion_destino=1 AND id_partido_origen=@p)
        THROW 59999,N'FALLO: se perdio el mapa anterior tras el rechazo.',1;
    EXEC abm.Cruce_Partido_Modificacion @semi,1,@p,'GANADOR';
    BEGIN TRY
        EXEC abm.Partidos_Modificacion @p,@sede,@a,@b,'20260701','20260701 13:00','20260701 13:00','CUARTOS',@devolver=0;
        THROW 59999,N'FALLO: horario del mapa modificado sin retirar cruces.',1;
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER()<>51301 THROW;
    END CATCH;
    EXEC abm.Cruce_Partido_Baja @semi,1;
    EXEC abm.Cruce_Partido_Alta @incompatible,1,@p,'GANADOR';
    EXEC abm.Cruce_Partido_Baja @incompatible,1;
    EXEC abm.Cruce_Partido_Baja @semi,2;
    IF EXISTS(SELECT id_partido,id_seleccion_1,id_seleccion_2,resultado_final FROM dbo.Partido
              WHERE id_partido IN (@p,@q,@semi,@incompatible)
              EXCEPT SELECT id,s1,s2,resultado FROM @antes)
        THROW 59999,N'FALLO: el mapa modifico participantes o resultados.',1;
    -- Dos saltos y tercer puesto: seguir solo la ruta de los participantes cargados.
    DECLARE @e INT,@f INT,@g INT,@h INT,@r INT,@s INT,@semi2 INT,@final INT,@tercero INT;
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'E','UEFA','E'); SET @e=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'F','UEFA','F'); SET @f=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'G','UEFA','G'); SET @g=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(@marca+N'H','UEFA','H'); SET @h=SCOPE_IDENTITY();
    INSERT @ids EXEC abm.Partidos_Alta @sede,@e,@f,'20260702','20260702 12:00','20260702 12:00','CUARTOS';
    SELECT @r=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@g,@h,'20260702','20260702 18:00','20260702 18:00','CUARTOS';
    SELECT @s=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@e,@g,'20260705','20260705 18:00','20260705 18:00','SEMIFINAL';
    SELECT @semi2=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@a,@e,'20260710','20260710 12:00','20260710 12:00','FINAL';
    SELECT @final=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@c,@g,'20260709','20260709 12:00','20260709 12:00','TERCER PUESTO';
    SELECT @tercero=id FROM @ids; DELETE @ids;
    EXEC abm.Cruce_Partido_Alta @semi,1,@p,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @semi,2,@q,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @semi2,1,@r,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @semi2,2,@s,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @final,1,@semi,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @final,2,@semi2,'GANADOR';
    EXEC abm.Cruce_Partido_Alta @tercero,1,@semi,'PERDEDOR';
    EXEC abm.Cruce_Partido_Alta @tercero,2,@semi2,'PERDEDOR';
    DECLARE @arbE INT,@arbG INT,@aviso NVARCHAR(2048);
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(@marca+N'E',@marca+N'E','Principal'); SET @arbE=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(@marca+N'G',@marca+N'G','Principal'); SET @arbG=SCOPE_IDENTITY();
    EXEC negocio.Evaluar_Cruce_Arbitral @p,@arbE,@aviso OUTPUT;
    IF @aviso NOT LIKE N'%POSIBLE CRUCE%' OR @aviso NOT LIKE N'%partido '+CONVERT(NVARCHAR(12),@final)+N',%'
        THROW 59999,N'FALLO: no se detecto el cruce de dos saltos hacia la final.',1;
    EXEC negocio.Evaluar_Cruce_Arbitral @q,@arbG,@aviso OUTPUT;
    IF @aviso NOT LIKE N'%POSIBLE CRUCE%' OR @aviso NOT LIKE N'%partido '+CONVERT(NVARCHAR(12),@tercero)+N',%'
        THROW 59999,N'FALLO: no se detecto el cruce por tercer puesto.',1;
    EXEC negocio.Evaluar_Cruce_Arbitral @p,@arbG,@aviso OUTPUT;
    IF @aviso LIKE N'%POSIBLE CRUCE%'
        THROW 59999,N'FALLO: se propago una seleccion por un destino donde no participa.',1;
    IF @@TRANCOUNT<>1 THROW 59999,N'FALLO: se perdio la transaccion externa.',1;
    PRINT N'OK: participantes obligatorios; mapa editable sin propagacion; cruce a dos saltos y tercer puesto; sin falsos cruces.';
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
GO
