/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
              de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 09/11/2026. Entrega 7: prueba del XML de plantillas con bajas.
    Datos propios en MUNDIALDEFUTBOL, con ROLLBACK al terminar o fallar.
    Esperado: mostrar A y B como BAJA, C como CONVOCADO en A -> B -> C;
    orden por dorsal, campos pedidos, seleccion vacia y filtros correctos.
*/
USE MUNDIALDEFUTBOL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'test') IS NULL
    THROW 53500,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE test.Reporte_Selecciones_Plantillas_XML_Test
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    IF @@TRANCOUNT<>0 THROW 53590,N'Ejecute el test sin una transaccion previa.',1;
    IF OBJECT_ID(N'reportes.Reporte_Selecciones_Plantillas_XML',N'P') IS NULL
        THROW 53590,N'Instale primero el reporte XML de plantillas.',1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @marca NVARCHAR(40)=N'RSP_'+CONVERT(NVARCHAR(36),NEWID());
        DECLARE @s1 INT,@s2 INT,@s3 INT,@a INT,@b INT,@c INT,@d INT,@e INT;
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' & Uno','UEFA','A'); SET @s1=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' Vacia','CONMEBOL','B'); SET @s2=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' Otra','AFC','C'); SET @s3=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s1,N'Saliente A',@marca,'19950101',N'Club A','Delantero',9); SET @a=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s1,N'Saliente B',@marca,'19960101',N'Club B','Delantero',9); SET @b=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s1,N'Vigente & C',@marca,'19970101',N'Club <C> & Asociados','Delantero',9); SET @c=SCOPE_IDENTITY();
        -- Se inserta despues pero debe aparecer primero por su dorsal menor.
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s1,N'Arquero D',@marca,'19980101',N'Club D','Arquero',1); SET @d=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            VALUES(@s3,N'Otro E',@marca,'19990101',N'Club E','Defensa',4); SET @e=SCOPE_IDENTITY();
        INSERT dbo.Reemplazo(id_jugador_baja,id_jugador_alta,fecha_cambio,motivo)
            VALUES(@a,@b,'20260601','Reemplazo simulado A-B'),
                  (@b,@c,'20260602','Reemplazo simulado B-C');

        DECLARE @xml XML,@ejemplo XML,@nombre NVARCHAR(125);
        EXEC reportes.Reporte_Selecciones_Plantillas_XML @id_seleccion=@s1,@reporte=@xml OUTPUT,@devolver=0;
        SET @ejemplo=@xml;
        IF @xml.value('count(/ReporteSeleccionesPlantillas/Seleccion)','int')<>1
           OR @xml.value('(/ReporteSeleccionesPlantillas/Seleccion/@id)[1]','int')<>@s1
           OR @xml.value('(//Seleccion/Confederacion/text())[1]','nvarchar(50)')<>N'UEFA'
           OR @xml.value('(//Seleccion/Grupo/text())[1]','varchar(1)')<>'A'
           OR @xml.value('(//Plantilla/@convocadosVigentes)[1]','int')<>2
           OR @xml.value('(//Plantilla/@jugadoresDadosDeBaja)[1]','int')<>2
           OR @xml.value('count(//Jugador)','int')<>4
            THROW 53591,N'Seleccion, campos generales o cantidad de convocados incorrectos.',1;
        IF @xml.exist('//Jugador[@id=sql:variable("@a") and @estado="BAJA"]')<>1
           OR @xml.exist('//Jugador[@id=sql:variable("@b") and @estado="BAJA"]')<>1
           OR @xml.exist('//Jugador[@id=sql:variable("@c") and @estado="CONVOCADO"]')<>1
           OR @xml.exist('//Jugador[@id=sql:variable("@d") and @estado="CONVOCADO"]')<>1
           OR @xml.exist('//Jugador[@id=sql:variable("@e")]')=1
            THROW 53591,N'No se respetaron las bajas, la cadena de reemplazos o el filtro por seleccion.',1;
        IF @xml.exist('//Jugador[@id=sql:variable("@a")]/Baja[@fecha="2026-06-01" and @idReemplazante=sql:variable("@b")][Motivo="Reemplazo simulado A-B"]')<>1
           OR @xml.exist('//Jugador[@id=sql:variable("@b")]/Baja[@fecha="2026-06-02" and @idReemplazante=sql:variable("@c")][Motivo="Reemplazo simulado B-C"]')<>1
           OR @xml.exist('//Jugador[@estado="CONVOCADO"]/Baja')=1
           OR @xml.value('count(//Jugador[@estado="BAJA"])','int')<>2
           OR @xml.value('count(//Jugador[@estado="CONVOCADO"])','int')<>2
            THROW 53591,N'Fechas, motivos, reemplazantes o clasificacion de bajas incorrectos.',1;
        SET @nombre=N'Vigente & C '+@marca;
        IF @xml.value('(//Jugador[@id=sql:variable("@c")]/Nombre/text())[1]','nvarchar(125)')<>@nombre
           OR @xml.value('(//Jugador[@id=sql:variable("@c")]/Posicion/text())[1]','varchar(40)')<>'Delantero'
           OR @xml.value('(//Jugador[@id=sql:variable("@c")]/Club/text())[1]','nvarchar(100)')<>N'Club <C> & Asociados'
           OR @xml.value('(//Jugador[@id=sql:variable("@c")]/Dorsal/text())[1]','int')<>9
            THROW 53591,N'Campos de jugador o escape de caracteres XML incorrectos.',1;
        IF @xml.value('(//Plantilla/Jugador[1]/@id)[1]','int')<>@d
           OR @xml.value('(//Plantilla/Jugador[2]/@id)[1]','int')<>@a
           OR @xml.value('(//Plantilla/Jugador[3]/@id)[1]','int')<>@b
           OR @xml.value('(//Plantilla/Jugador[4]/@id)[1]','int')<>@c
            THROW 53591,N'La plantilla no esta ordenada por dorsal.',1;
        EXEC reportes.Reporte_Selecciones_Plantillas_XML @id_seleccion=@s1,@reporte=@xml OUTPUT,@devolver=0;
        IF CONVERT(NVARCHAR(MAX),@xml)<>CONVERT(NVARCHAR(MAX),@ejemplo)
            THROW 53591,N'La consulta repetida cambio el contenido o el orden.',1;
        EXEC reportes.Reporte_Selecciones_Plantillas_XML @id_seleccion=@s2,@reporte=@xml OUTPUT,@devolver=0;
        IF @xml.value('count(//Seleccion)','int')<>1
           OR @xml.exist('//Seleccion[@id=sql:variable("@s2")]/Plantilla[@convocadosVigentes="0" and @jugadoresDadosDeBaja="0"]')<>1
           OR @xml.value('count(//Jugador)','int')<>0
            THROW 53591,N'La seleccion sin jugadores no conserva una plantilla vacia.',1;
        EXEC reportes.Reporte_Selecciones_Plantillas_XML @reporte=@xml OUTPUT,@devolver=0;
        IF @xml.value('count(/ReporteSeleccionesPlantillas/Seleccion)','int')<>(SELECT COUNT(*) FROM dbo.Seleccion)
           OR @xml.exist('//Seleccion[@id=sql:variable("@s3")]/Plantilla[@convocadosVigentes="1" and @jugadoresDadosDeBaja="0"]/Jugador[@id=sql:variable("@e") and @estado="CONVOCADO"]')<>1
           OR @xml.exist('//Seleccion[@id=sql:variable("@s2")]/Plantilla[@convocadosVigentes="0" and @jugadoresDadosDeBaja="0"]')<>1
            THROW 53591,N'La consulta sin filtro omitio selecciones o jugadores.',1;
        IF @xml.value('count(//Jugador)','int')<>
           (SELECT COUNT(*) FROM dbo.Jugador)
           OR @xml.value('count(//Jugador[@estado="CONVOCADO"])','int')<>
              (SELECT COUNT(*) FROM dbo.Jugador j WHERE NOT EXISTS(SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja=j.id_jugador))
           OR @xml.value('count(//Jugador[@estado="BAJA"])','int')<>
              (SELECT COUNT(*) FROM dbo.Jugador j WHERE EXISTS(SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja=j.id_jugador))
            THROW 53591,N'Los totales generales no coinciden con jugadores, convocados y bajas.',1;
        BEGIN TRY
            EXEC reportes.Reporte_Selecciones_Plantillas_XML @id_seleccion=-1,@devolver=0;
            THROW 53591,N'Se acepto una seleccion inexistente.',1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>53501 THROW;
        END CATCH;
        BEGIN TRY
            EXEC reportes.Reporte_Selecciones_Plantillas_XML @id_seleccion=-1,@devolver=NULL;
            THROW 53591,N'Se aceptaron parametros invalidos.',1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>53501 THROW;
            IF ERROR_MESSAGE() NOT LIKE N'%seleccion%' OR ERROR_MESSAGE() NOT LIKE N'%devuelve%' THROW;
        END CATCH;
        IF @@TRANCOUNT<>1 THROW 53591,N'El reporte altero la transaccion del test.',1;
        ROLLBACK TRANSACTION;
        SELECT @ejemplo AS ejemplo_xml;
        PRINT N'OK: plantillas XML con convocados y bajas, fecha/motivo/reemplazante, cadena de reemplazos, totales separados, orden y filtros. Datos revertidos.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
EXEC test.Reporte_Selecciones_Plantillas_XML_Test;
GO
