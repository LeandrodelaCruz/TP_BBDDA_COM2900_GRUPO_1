/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Carga sintetica: no representa designaciones oficiales. No ejecuta la carga al instalar.
IF SCHEMA_ID(N'carga') IS NULL
    THROW 51910,N'Ejecute Table/00_Script_DB_Schemas_Creacion.sql primero.',1;
GO
CREATE OR ALTER PROCEDURE carga.Cargar_Designaciones_Arbitrales
    @id_partido INT=NULL, @demostrar_rechazo BIT=1,
    @completados INT=0 OUTPUT,@omitidos INT=0 OUTPUT,@errores INT=0 OUTPUT,
    @rechazados INT=0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    IF @@TRANCOUNT<>0 THROW 51620,N'Ejecute la carga sin una transaccion externa.',1;
    IF @demostrar_rechazo IS NULL THROW 51620,N'Indique si se demuestra un rechazo.',1;
    IF @id_partido IS NOT NULL AND NOT EXISTS(SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido)
        THROW 51620,N'El partido solicitado no existe.',1;
    SELECT @completados=0,@omitidos=0,@errores=0,@rechazados=0;
    DECLARE @partidos TABLE(id INT PRIMARY KEY);
    INSERT @partidos SELECT id_partido FROM dbo.Partido WHERE @id_partido IS NULL OR id_partido=@id_partido;
    DECLARE @puestos TABLE(orden INT PRIMARY KEY,rol VARCHAR(30),categoria VARCHAR(50),cantidad INT);
    INSERT @puestos VALUES(1,'PRINCIPAL','PRINCIPAL',1),(2,'ASISTENTE','ASISTENTE',1),
        (3,'ASISTENTE','ASISTENTE',2),(4,'CUARTO ARBITRO','PRINCIPAL',1),(5,'VAR','VAR',1),(6,'AVAR','VAR',1);
    DECLARE @candidatos TABLE(orden INT PRIMARY KEY,id INT);
    DECLARE @existentes TABLE(id INT PRIMARY KEY,rol VARCHAR(30));
    DECLARE @detalle TABLE(orden INT IDENTITY PRIMARY KEY,partido INT,rol VARCHAR(30),arbitro INT,
        estado VARCHAR(25),numero_error INT,detalle NVARCHAR(2048));
    DECLARE @p INT,@s1 INT,@s2 INT,@o INT,@c INT,@a INT,@rol VARCHAR(30),@cat VARCHAR(50),@cantidad INT,
        @ok BIT,@demo BIT=0,@antes INT,@aviso NVARCHAR(2048);
    SELECT @p=MIN(id) FROM @partidos;
    WHILE @p IS NOT NULL
    BEGIN
        SELECT @s1=NULL,@s2=NULL,@rol=NULL,@a=NULL;
        BEGIN TRY
            BEGIN TRANSACTION;
            SELECT @s1=id_seleccion_1,@s2=id_seleccion_2 FROM dbo.Partido WHERE id_partido=@p;
            -- Validar datos previos: no omitir silenciosamente un equipo invalido.
            DELETE @existentes;
            INSERT @existentes SELECT id_arbitro,rol_arbitro FROM dbo.Designacion_Arbitral WHERE id_partido=@p;
            SELECT @a=MIN(id) FROM @existentes;
            WHILE @a IS NOT NULL
            BEGIN
                SELECT @rol=rol FROM @existentes WHERE id=@a;
                EXEC abm.Designacion_Arbitral_Guardar @p,@a,@rol,1,@aviso OUTPUT;
                IF @aviso<>N'' INSERT @detalle VALUES(@p,@rol,@a,'ADVERTENCIA',NULL,@aviso);
                SELECT @a=MIN(id) FROM @existentes WHERE id>@a;
            END;
            SELECT @antes=COUNT(*) FROM @existentes;
            SELECT @o=MIN(orden) FROM @puestos;
            WHILE @o IS NOT NULL
            BEGIN
                SELECT @rol=rol,@cat=categoria,@cantidad=cantidad FROM @puestos WHERE orden=@o;
                IF (SELECT COUNT(*) FROM dbo.Designacion_Arbitral WHERE id_partido=@p AND rol_arbitro=@rol)<@cantidad
                BEGIN
                    DELETE @candidatos;
                    -- El orden se sortea una sola vez por puesto; luego MIN(clave) garantiza avance finito.
                    INSERT @candidatos
                    SELECT CONVERT(INT,ROW_NUMBER() OVER(ORDER BY
                        CASE WHEN @demostrar_rechazo=1 AND @demo=0 AND EXISTS
                            (SELECT 1 FROM dbo.Seleccion se WHERE se.id_seleccion IN (@s1,@s2)
                             AND negocio.Pais_Arbitral_Normalizado(se.pais)=negocio.Pais_Arbitral_Normalizado(a.pais)) THEN 0 ELSE 1 END,
                        NEWID(),a.id_arbitro)),a.id_arbitro
                    FROM dbo.Arbitro a WHERE UPPER(LTRIM(RTRIM(REPLACE(REPLACE(a.puesto,CHAR(13),''),CHAR(10),''))))=@cat
                      AND NOT EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral d WHERE d.id_partido=@p AND d.id_arbitro=a.id_arbitro);
                    SELECT @c=MIN(orden),@ok=0 FROM @candidatos;
                    WHILE @c IS NOT NULL AND @ok=0
                    BEGIN
                        SELECT @a=id FROM @candidatos WHERE orden=@c;
                        BEGIN TRY
                            EXEC abm.Designacion_Arbitral_Alta @p,@a,@rol,@aviso OUTPUT,0;
                            SET @ok=1;
                            INSERT @detalle VALUES(@p,@rol,@a,'PROVISIONAL',NULL,@aviso);
                        END TRY
                        BEGIN CATCH
                            IF ERROR_NUMBER() NOT IN (51601,51602) OR XACT_STATE()<>1 THROW;
                            SET @rechazados+=1;
                            IF ERROR_NUMBER()=51601 SET @demo=1;
                            INSERT @detalle VALUES(@p,@rol,@a,'RECHAZADO',ERROR_NUMBER(),ERROR_MESSAGE());
                        END CATCH;
                        SELECT @c=MIN(orden) FROM @candidatos WHERE orden>@c;
                    END;
                    IF @ok=0 THROW 51621,N'Se agotaron los candidatos del puesto: se revierten las nuevas designaciones de este partido.',1;
                END;
                SELECT @o=MIN(orden) FROM @puestos WHERE orden>@o;
            END;
            IF @antes=6
            BEGIN
                SET @omitidos+=1;
                INSERT @detalle VALUES(@p,NULL,NULL,'YA COMPLETO',NULL,N'Se conserva el equipo existente.');
            END
            ELSE SET @completados+=1;
            COMMIT TRANSACTION;
            UPDATE @detalle SET estado='CARGADO' WHERE partido=@p AND estado='PROVISIONAL';
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            SET @errores+=1;
            UPDATE @detalle SET estado='REVERTIDO' WHERE partido=@p AND estado='PROVISIONAL';
            INSERT @detalle VALUES(@p,@rol,@a,'ERROR PARTIDO',ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SELECT @p=MIN(id) FROM @partidos WHERE id>@p;
    END;
    SELECT @completados AS partidos_completados,@omitidos AS partidos_omitidos,@errores AS partidos_con_error,
        @rechazados AS candidatos_rechazados,
        CASE WHEN @demostrar_rechazo=0 THEN N'Demostracion no solicitada.' WHEN @demo=1 THEN N'Rechazo por nacionalidad demostrado.'
             ELSE N'No se encontro un candidato conflictivo en los puestos pendientes; no se fabrico un rechazo.' END AS demostracion;
    SELECT * FROM @detalle ORDER BY orden;
END;
GO
