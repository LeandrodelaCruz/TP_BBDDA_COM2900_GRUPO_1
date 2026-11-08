/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Guardar
    @id_partido INT, @id_arbitro INT, @rol_arbitro VARCHAR(30), @modificar BIT,
    @advertencia NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF; -- Los rechazos previstos permiten volver al punto de guardado.
    -- Si el llamador abrio una transaccion, conservar su trabajo anterior.
    DECLARE @transacciones_previas INT = @@TRANCOUNT;
    BEGIN TRY
        IF @transacciones_previas = 0
            BEGIN TRANSACTION;
        ELSE
            SAVE TRANSACTION DesignacionGuardar;

    DECLARE @errores NVARCHAR(2048)=N'',@p1 NVARCHAR(80),@p2 NVARCHAR(80),@pais NVARCHAR(80),@puesto VARCHAR(50),
        @s1 INT,@s2 INT,@existe BIT=0;
    SET @advertencia=N'';
    SET @rol_arbitro=UPPER(LTRIM(RTRIM(@rol_arbitro)));
    SELECT @s1=id_seleccion_1,@s2=id_seleccion_2,@existe=1
        FROM dbo.Partido WHERE id_partido=@id_partido;
    SELECT @pais=negocio.Pais_Arbitral_Normalizado(pais),@puesto=UPPER(LTRIM(RTRIM(REPLACE(REPLACE(puesto,CHAR(13),''),CHAR(10),''))))
        FROM dbo.Arbitro WHERE id_arbitro=@id_arbitro;
    SELECT @p1=negocio.Pais_Arbitral_Normalizado(pais) FROM dbo.Seleccion WHERE id_seleccion=@s1;
    SELECT @p2=negocio.Pais_Arbitral_Normalizado(pais) FROM dbo.Seleccion WHERE id_seleccion=@s2;
    IF @existe=0 SET @errores+=N'- El partido no existe. ';
    ELSE IF @s1 IS NULL OR @s2 IS NULL SET @errores+=N'- Confirme ambos participantes. ';
    IF @pais IS NULL SET @errores+=N'- El arbitro no existe. ';
    IF @rol_arbitro IS NULL OR @rol_arbitro NOT IN ('PRINCIPAL','ASISTENTE','CUARTO ARBITRO','VAR','AVAR')
        SET @errores+=N'- Rol invalido. ';
    IF @modificar IS NULL SET @errores+=N'- Indique alta o modificacion. ';
    IF @modificar=1 AND NOT EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@id_partido AND id_arbitro=@id_arbitro)
        SET @errores+=N'- La designacion a modificar no existe. ';
    IF @modificar=0 AND EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@id_partido AND id_arbitro=@id_arbitro)
        SET @errores+=N'- El arbitro ya ocupa un puesto en este partido. ';
    IF @puesto IS NOT NULL AND @puesto<>CASE WHEN @rol_arbitro IN ('PRINCIPAL','CUARTO ARBITRO') THEN 'PRINCIPAL'
        WHEN @rol_arbitro='ASISTENTE' THEN 'ASISTENTE' WHEN @rol_arbitro IN ('VAR','AVAR') THEN 'VAR' ELSE '' END
        SET @errores+=N'- Categoria incompatible con el rol. ';
    IF (SELECT COUNT(*) FROM dbo.Designacion_Arbitral
        WHERE id_partido=@id_partido AND rol_arbitro=@rol_arbitro AND id_arbitro<>@id_arbitro)
        >= CASE WHEN @rol_arbitro='ASISTENTE' THEN 2 ELSE 1 END
        SET @errores+=N'- Cupo del rol completo. ';
    IF @pais IN (@p1,@p2) SET @errores+=N'- Conflicto de nacionalidad con una seleccion participante. ';
    -- Numero especifico para la demostracion, preservando el mensaje agrupado.
    IF @errores<>N''
    BEGIN
        IF @pais IN (@p1,@p2) THROW 51601,@errores,1;
        THROW 51602,@errores,1;
    END;
    EXEC negocio.Evaluar_Cruce_Arbitral @id_partido,@id_arbitro,@advertencia OUTPUT;
    IF @modificar=1 UPDATE dbo.Designacion_Arbitral SET rol_arbitro=@rol_arbitro WHERE id_partido=@id_partido AND id_arbitro=@id_arbitro;
    ELSE INSERT dbo.Designacion_Arbitral VALUES(@id_partido,@id_arbitro,@rol_arbitro);

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION DesignacionGuardar;
        THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Alta
    @id_partido INT, @id_arbitro INT, @rol_arbitro VARCHAR(30),
    @advertencia NVARCHAR(2048)=NULL OUTPUT, @mostrar_advertencia BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    EXEC abm.Designacion_Arbitral_Guardar @id_partido,@id_arbitro,@rol_arbitro,0,@advertencia OUTPUT;
    IF @mostrar_advertencia=1 AND @advertencia<>N'' PRINT @advertencia;
END;
GO
CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Modificacion
    @id_partido INT, @id_arbitro INT, @rol_arbitro VARCHAR(30),
    @advertencia NVARCHAR(2048)=NULL OUTPUT, @mostrar_advertencia BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    EXEC abm.Designacion_Arbitral_Guardar @id_partido,@id_arbitro,@rol_arbitro,1,@advertencia OUTPUT;
    IF @mostrar_advertencia=1 AND @advertencia<>N'' PRINT @advertencia;
END;
GO
CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;

        SELECT
            da.id_partido,
            da.id_arbitro,
            CONCAT(a.nombre, ' ', a.apellido) AS nombre_arbitro,
            a.pais AS pais_arbitro,
            da.rol_arbitro,
            p.fecha,
            s1.pais AS seleccion_1,
            s2.pais AS seleccion_2
        FROM dbo.Designacion_Arbitral da
        INNER JOIN dbo.Arbitro a ON da.id_arbitro = a.id_arbitro
        INNER JOIN dbo.Partido p ON da.id_partido = p.id_partido
        LEFT JOIN dbo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion
        LEFT JOIN dbo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion
        WHERE da.id_partido = @id_partido
        ORDER BY da.rol_arbitro;
END;
GO
CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_GetByArbitro
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        da.id_partido,
        p.fecha,
        p.fase,
        s1.pais AS seleccion_1,
        s2.pais AS seleccion_2,
        da.id_arbitro,
        CONCAT(a.nombre, ' ', a.apellido) AS nombre_arbitro,
        da.rol_arbitro
    FROM dbo.Designacion_Arbitral da
    INNER JOIN dbo.Arbitro a ON da.id_arbitro = a.id_arbitro
    INNER JOIN dbo.Partido p ON da.id_partido = p.id_partido
    LEFT JOIN dbo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion
    LEFT JOIN dbo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion
    WHERE da.id_arbitro = @id_arbitro
    ORDER BY p.fecha DESC;
END;
GO
CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Baja
    @id_partido INT,@id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF; -- Los rechazos previstos permiten volver al punto de guardado.
    -- Si el llamador abrio una transaccion, conservar su trabajo anterior.
    DECLARE @transacciones_previas INT = @@TRANCOUNT;
    BEGIN TRY
        IF @transacciones_previas = 0
            BEGIN TRANSACTION;
        ELSE
            SAVE TRANSACTION DesignacionBaja;

    IF NOT EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@id_partido AND id_arbitro=@id_arbitro)
        THROW 51603,N'La designacion no existe.',1;
    DELETE dbo.Designacion_Arbitral WHERE id_partido=@id_partido AND id_arbitro=@id_arbitro;

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION DesignacionBaja;
        THROW;
    END CATCH
END;
GO
