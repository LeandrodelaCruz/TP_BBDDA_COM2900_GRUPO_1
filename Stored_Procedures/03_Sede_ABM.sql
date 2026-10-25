/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04
    Descripción:
    Cinco procedimientos de manejo de dbo.Sede: Alta, Modificar, Baja, Consultar por ID y Listar.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.Validar_Sede
    @operacion       VARCHAR(12),
    @id_sede         INT = NULL,
    @nombre_estadio  NVARCHAR(120) = NULL,
    @ciudad          NVARCHAR(80) = NULL,
    @pais            NVARCHAR(80) = NULL,
    @capacidad       INT = NULL,
    @huso_horario    VARCHAR(100) = NULL,
    @errores         NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errores = N'';
    SET @operacion = UPPER(LTRIM(RTRIM(ISNULL(@operacion, ''))));

    IF @operacion NOT IN ('ALTA', 'MODIFICAR', 'BAJA', 'CONSULTAR')
        SET @errores += N'- Operación inválida para Sede. ';

    IF @operacion IN ('MODIFICAR', 'BAJA', 'CONSULTAR')
    BEGIN
        IF @id_sede IS NULL OR @id_sede <= 0
            SET @errores += N'- El id_sede debe ser mayor que cero. ';
        ELSE IF NOT EXISTS (
            SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede
        )
            SET @errores += N'- La sede indicada no existe. ';
    END;

    IF @operacion IN ('ALTA', 'MODIFICAR')
    BEGIN
        IF @nombre_estadio IS NULL OR LTRIM(RTRIM(@nombre_estadio)) = N''
            SET @errores += N'- El nombre del estadio es obligatorio. ';
        IF @nombre_estadio IS NOT NULL AND LEN(@nombre_estadio) > 120
            SET @errores += N'- El nombre del estadio no puede superar 120 caracteres. ';

        IF @ciudad IS NULL OR LTRIM(RTRIM(@ciudad)) = N''
            SET @errores += N'- La ciudad es obligatoria. ';
        IF @ciudad IS NOT NULL AND LEN(@ciudad) > 80
            SET @errores += N'- La ciudad no puede superar 80 caracteres. ';

        IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
            SET @errores += N'- El país es obligatorio. ';
        IF @pais IS NOT NULL AND LEN(@pais) > 80
            SET @errores += N'- El país no puede superar 80 caracteres. ';

        IF @capacidad IS NULL OR @capacidad <= 0
            SET @errores += N'- La capacidad debe ser mayor que cero. ';

        IF @huso_horario IS NULL OR LTRIM(RTRIM(@huso_horario)) = ''
            SET @errores += N'- El huso horario es obligatorio. ';
        IF @huso_horario IS NOT NULL AND LEN(@huso_horario) > 100
            SET @errores += N'- El huso horario no puede superar 100 caracteres. ';

        IF @nombre_estadio IS NOT NULL AND @ciudad IS NOT NULL AND @pais IS NOT NULL
           AND EXISTS (
                SELECT 1
                FROM dbo.Sede
                WHERE UPPER(LTRIM(RTRIM(nombre_estadio))) = UPPER(LTRIM(RTRIM(@nombre_estadio)))
                  AND UPPER(LTRIM(RTRIM(ciudad))) = UPPER(LTRIM(RTRIM(@ciudad)))
                  AND UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)))
                  AND (@id_sede IS NULL OR id_sede <> @id_sede)
           )
            SET @errores += N'- Ya existe esa sede (mismo estadio, ciudad y país). ';
    END;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Sede_Alta
    @nombre_estadio NVARCHAR(120),
    @ciudad NVARCHAR(80),
    @pais NVARCHAR(80),
    @capacidad INT,
    @huso_horario VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.Validar_Sede 'ALTA', NULL, @nombre_estadio, @ciudad, @pais, @capacidad,
         @huso_horario, @errores OUTPUT;
    IF @errores <> N'' THROW 50201, @errores, 1;

    INSERT INTO dbo.Sede(nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (
        LTRIM(RTRIM(@nombre_estadio)),
        LTRIM(RTRIM(@ciudad)),
        LTRIM(RTRIM(@pais)),
        @capacidad,
        LTRIM(RTRIM(@huso_horario))
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_sede_creada;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Sede_Modificar
    @id_sede INT,
    @nombre_estadio NVARCHAR(120),
    @ciudad NVARCHAR(80),
    @pais NVARCHAR(80),
    @capacidad INT,
    @huso_horario VARCHAR(100)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.Validar_Sede 'MODIFICAR', @id_sede, @nombre_estadio, @ciudad, @pais, @capacidad,
         @huso_horario, @errores OUTPUT;
    IF @errores <> N'' THROW 50202, @errores, 1;

    UPDATE dbo.Sede
       SET nombre_estadio = LTRIM(RTRIM(@nombre_estadio)),
           ciudad = LTRIM(RTRIM(@ciudad)),
           pais = LTRIM(RTRIM(@pais)),
           capacidad = @capacidad,
           huso_horario = LTRIM(RTRIM(@huso_horario))
     WHERE id_sede = @id_sede;

    SELECT * FROM dbo.Sede WHERE id_sede = @id_sede;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Sede_Baja
    @id_sede INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.Validar_Sede 'BAJA', @id_sede, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50203, @errores, 1;

    DELETE FROM dbo.Sede WHERE id_sede = @id_sede;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Sede_ConsultarPorId
    @id_sede INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.Validar_Sede 'CONSULTAR', @id_sede, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50204, @errores, 1;

    SELECT * FROM dbo.Sede WHERE id_sede = @id_sede;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Sede_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Sede ORDER BY id_sede;
END;
GO
