/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
              de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 09/11/2026. Entrega 7: pruebas XML con datos propios y ROLLBACK.
    Esperado: 3 asignaciones / 2 como principal / 2 amonestaciones / 1 expulsion
    para el arbitro A; no atribuir tarjetas a cuarto, asistentes o VAR.
    Distinguir segunda amonestacion y expulsion, omitir goles y revisiones VAR,
    incluir principal sin tarjetas, respetar filtros y escapar caracteres XML.
*/
USE MUNDIALDEFUTBOL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'test') IS NULL
    THROW 53400,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE test.Reporte_Designaciones_Arbitrales_XML_Test
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    IF @@TRANCOUNT<>0 THROW 53490,N'Ejecute el test sin una transaccion previa.',1;
    IF OBJECT_ID(N'reportes.Reporte_Designaciones_Arbitrales_XML',N'P') IS NULL
        THROW 53490,N'Instale primero el reporte XML arbitral.',1;

    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @marca NVARCHAR(45)=N'RDA_'+CONVERT(NVARCHAR(36),NEWID());
        DECLARE @sede INT,@s1 INT,@s2 INT,@j1 INT,@j2 INT,@p1 INT,@p2 INT,@p3 INT,
                @a INT,@b INT,@asistente INT,@var INT,@sin_partidos INT;
        INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario)
            VALUES(@marca,N'Prueba',N'Prueba',1000,'UTC'); SET @sede=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' & Local','UEFA','A'); SET @s1=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' Visitante','UEFA','B'); SET @s2=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s1,N'Jugador & Uno',@marca,'19950101',N'Club','Delantero',9); SET @j1=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s2,N'Jugador Dos',@marca,'19950101',N'Club','Defensa',4); SET @j2=SCOPE_IDENTITY();
        INSERT dbo.Partido(id_sede,fecha,horario_local,horario_UTC,fase,id_seleccion_1,id_seleccion_2)
            VALUES(@sede,'20260611','20260611 12:00','20260611 12:00','GRUPOS',@s1,@s2); SET @p1=SCOPE_IDENTITY();
        INSERT dbo.Partido(id_sede,fecha,horario_local,horario_UTC,fase,id_seleccion_1,id_seleccion_2)
            VALUES(@sede,'20260612','20260612 12:00','20260612 12:00','GRUPOS',@s1,@s2); SET @p2=SCOPE_IDENTITY();
        INSERT dbo.Partido(id_sede,fecha,horario_local,horario_UTC,fase,id_seleccion_1,id_seleccion_2)
            VALUES(@sede,'20260613','20260613 12:00','20260613 12:00','GRUPOS',@s1,@s2); SET @p3=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(nombre,apellido,pais,puesto)
            VALUES(N'Arbitro & A',@marca,N'Pais de prueba','Principal'); SET @a=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(nombre,apellido,pais,puesto)
            VALUES(N'Arbitro B',@marca,N'Pais de prueba','Principal'); SET @b=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(nombre,apellido,pais,puesto)
            VALUES(N'Asistente',@marca,N'Pais de prueba','Asistente'); SET @asistente=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(nombre,apellido,pais,puesto)
            VALUES(N'VAR',@marca,N'Pais de prueba','VAR'); SET @var=SCOPE_IDENTITY();
        INSERT dbo.Arbitro(nombre,apellido,pais,puesto)
            VALUES(NULL,@marca,N'Pais de prueba','Principal'); SET @sin_partidos=SCOPE_IDENTITY();
        INSERT dbo.Designacion_Arbitral(id_partido,id_arbitro,rol_arbitro)
            VALUES(@p1,@a,'PRINCIPAL'),(@p1,@asistente,'ASISTENTE'),(@p1,@var,'VAR'),
                  (@p2,@b,'PRINCIPAL'),(@p2,@a,'CUARTO ARBITRO'),(@p3,@a,'PRINCIPAL');
        INSERT dbo.Incidencia(id_partido,id_jugador,tipo,minuto,periodo,motivo)
            VALUES(@p1,@j1,'AMONESTACION',24,'PRIMER TIEMPO',NULL),
                  (@p1,@j1,'AMONESTACION',68,'SEGUNDO TIEMPO','Segunda amarilla simulada'),
                  (@p1,@j1,'EXPULSION',68,'SEGUNDO TIEMPO','Expulsion por segunda amarilla'),
                  (@p1,@j2,'GOL',12,'PRIMER TIEMPO','Gol simulado'),
                  (@p2,@j2,'AMONESTACION',32,'PRIMER TIEMPO','Tarjeta simulada'),
                  (@p2,@j1,'REVISION VAR',48,'SEGUNDO TIEMPO','Revision simulada'),
                  (@p3,@j2,'GOL',20,'PRIMER TIEMPO','Gol simulado');

        DECLARE @xml XML,@ejemplo XML;
        EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_arbitro=@a,@reporte=@xml OUTPUT,@devolver=0;
        SET @ejemplo=@xml;
        IF @xml.value('count(/ReporteDesignacionesArbitrales/Arbitro)','int')<>1
           OR @xml.value('(/ReporteDesignacionesArbitrales/Arbitro/@id)[1]','int')<>@a
           OR @xml.value('(/ReporteDesignacionesArbitrales/Arbitro/Resumen/@partidosAsignados)[1]','int')<>3
           OR @xml.value('(/ReporteDesignacionesArbitrales/Arbitro/Resumen/@partidosComoPrincipal)[1]','int')<>2
           OR @xml.value('(/ReporteDesignacionesArbitrales/Arbitro/Resumen/@amonestaciones)[1]','int')<>2
           OR @xml.value('(/ReporteDesignacionesArbitrales/Arbitro/Resumen/@expulsiones)[1]','int')<>1
            THROW 53491,N'Resumen arbitral incorrecto o filtro por arbitro incumplido.',1;
        IF @xml.value('count(//Tarjeta)','int')<>3
           OR @xml.value('count(//Tarjeta[Tipo="AMONESTACION"])','int')<>2
           OR @xml.value('count(//Tarjeta[Tipo="EXPULSION"])','int')<>1
           OR @xml.exist('//Tarjeta[Tipo="GOL" or Tipo="REVISION VAR"]')=1
            THROW 53491,N'El detalle no coincide con las tarjetas del principal.',1;
        IF @xml.exist('//Partido[@id=sql:variable("@p2")]/Tarjetas[@atribuibles="false"]')<>1
           OR @xml.exist('//Partido[@id=sql:variable("@p2")]/Tarjetas/Tarjeta')=1
           OR @xml.exist('//Partido[@id=sql:variable("@p2")]/Resumen')=1
            THROW 53491,N'Se atribuyeron tarjetas al cuarto arbitro.',1;
        IF @xml.exist('//Partido[@id=sql:variable("@p3")]/Resumen[@amonestaciones="0" and @expulsiones="0"]')<>1
           OR @xml.exist('//Partido[@id=sql:variable("@p3")]/Tarjetas[@atribuibles="true"]')<>1
            THROW 53491,N'Falta el principal sin tarjetas registradas.',1;
        IF @xml.value('(//Tarjeta[1]/Jugador/@id)[1]','int')<>@j1
           OR @xml.value('(//Tarjeta[1]/Jugador/text())[1]','nvarchar(125)')<>N'Jugador & Uno '+@marca
           OR @xml.exist('//Tarjeta[1]/Motivo')=1
            THROW 53491,N'Identidad del jugador, caracteres XML u omision del motivo nulo incorrectos.',1;
        IF @xml.value('(//Tarjeta[2]/Tipo/text())[1]','varchar(30)')<>'AMONESTACION'
           OR @xml.value('(//Tarjeta[3]/Tipo/text())[1]','varchar(30)')<>'EXPULSION'
            THROW 53491,N'Orden de segunda amonestacion y expulsion incorrecto.',1;

        EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_partido=@p1,@reporte=@xml OUTPUT,@devolver=0;
        IF @xml.value('count(/ReporteDesignacionesArbitrales/Arbitro)','int')<>3
           OR @xml.value('count(//Partido[@id!=sql:variable("@p1")])','int')<>0
           OR @xml.value('count(//Tarjeta)','int')<>3
           OR @xml.value('count(//Tarjetas[@atribuibles="false"])','int')<>2
            THROW 53491,N'Filtro por partido o atribucion a asistentes/VAR incorrectos.',1;
        EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_arbitro=@a,@id_partido=@p2,@reporte=@xml OUTPUT,@devolver=0;
        IF @xml.value('count(//Partido)','int')<>1 OR @xml.value('count(//Tarjeta)','int')<>0
           OR @xml.value('(/ReporteDesignacionesArbitrales/Arbitro/Resumen/@partidosComoPrincipal)[1]','int')<>0
            THROW 53491,N'Los filtros combinados o los totales filtrados son incorrectos.',1;
        EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_arbitro=@sin_partidos,@reporte=@xml OUTPUT,@devolver=0;
        IF @xml.exist('/ReporteDesignacionesArbitrales')<>1 OR @xml.value('count(//Arbitro)','int')<>0
            THROW 53491,N'La consulta sin coincidencias no devolvio una raiz vacia.',1;
        BEGIN TRY
            EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_arbitro=-1,@id_partido=-1,@devolver=0;
            THROW 53491,N'Se aceptaron filtros inexistentes.',1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>53401 THROW;
            IF ERROR_MESSAGE() NOT LIKE N'%arbitro%' OR ERROR_MESSAGE() NOT LIKE N'%partido%' THROW;
        END CATCH;
        INSERT dbo.Designacion_Arbitral(id_partido,id_arbitro,rol_arbitro) VALUES(@p1,@b,'PRINCIPAL');
        BEGIN TRY
            EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_partido=@p1,@devolver=0;
            THROW 53491,N'No se detecto la ambiguedad de dos principales.',1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>53402 THROW;
        END CATCH;
        IF @@TRANCOUNT<>1 THROW 53491,N'El reporte altero la transaccion del test.',1;
        ROLLBACK TRANSACTION;
        SELECT @ejemplo AS ejemplo_xml;
        PRINT N'OK: XML, filtros, resumen, doble amarilla, otros roles, cero tarjetas, caracteres especiales y validaciones. Datos revertidos.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
EXEC test.Reporte_Designaciones_Arbitrales_XML_Test;
GO
