/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Region: Alta, Modificar, Baja, Consultar por ID y Listar.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE abm.Region_Alta
    @nombre NVARCHAR(80),
    @idioma NVARCHAR(50) = NULL,
    @huso_horario VARCHAR(100),
    @hora_prime_inicio TIME(0),
    @hora_prime_fin TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        SET @errores += N'- El nombre de la región es obligatorio. ';
    IF @nombre IS NOT NULL AND LEN(@nombre) > 80
        SET @errores += N'- El nombre de la región no puede superar 80 caracteres. ';

    IF @idioma IS NOT NULL AND LTRIM(RTRIM(@idioma)) = N''
        SET @errores += N'- Si se informa idioma, no puede quedar vacío. ';
    IF @idioma IS NOT NULL AND LEN(@idioma) > 50
        SET @errores += N'- El idioma no puede superar 50 caracteres. ';

    IF @huso_horario IS NULL OR LTRIM(RTRIM(@huso_horario)) = ''
        SET @errores += N'- El huso horario es obligatorio. ';
    IF @huso_horario IS NOT NULL AND LEN(@huso_horario) > 100
        SET @errores += N'- El huso horario no puede superar 100 caracteres. ';

    IF @hora_prime_inicio IS NULL
        SET @errores += N'- La hora de inicio de prime time es obligatoria. ';
    IF @hora_prime_fin IS NULL
        SET @errores += N'- La hora de fin de prime time es obligatoria. ';

    IF @hora_prime_inicio IS NOT NULL
       AND @hora_prime_fin IS NOT NULL
       AND @hora_prime_inicio >= @hora_prime_fin
        SET @errores += N'- La hora de inicio de prime time debe ser menor que la hora de fin. ';

    IF @hora_prime_inicio IS NOT NULL AND @hora_prime_inicio <= CAST('00:00:00' AS TIME(0))
        SET @errores += N'- La hora de inicio de prime time debe ser mayor que 00:00. ';
    IF @hora_prime_fin IS NOT NULL AND @hora_prime_fin <= CAST('00:00:00' AS TIME(0))
        SET @errores += N'- La hora de fin de prime time debe ser mayor que 00:00. ';

    IF @nombre IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Region
            WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
       )
        SET @errores += N'- Ya existe una región con ese nombre. ';

    IF @errores <> N'' THROW 50101, @errores, 1;

    INSERT INTO dbo.Region(nombre, idioma, huso_horario, hora_prime_inicio, hora_prime_fin)
    VALUES (
        LTRIM(RTRIM(@nombre)),
        CASE WHEN @idioma IS NULL THEN NULL ELSE LTRIM(RTRIM(@idioma)) END,
        LTRIM(RTRIM(@huso_horario)),
        @hora_prime_inicio,
        @hora_prime_fin
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_region_creada;
END;
GO

CREATE OR ALTER PROCEDURE abm.Region_Modificar
    @id_region INT,
    @nombre NVARCHAR(80),
    @idioma NVARCHAR(50) = NULL,
    @huso_horario VARCHAR(100),
    @hora_prime_inicio TIME(0),
    @hora_prime_fin TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_region IS NULL OR @id_region <= 0
        SET @errores += N'- El id_region debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Region WHERE id_region = @id_region
    )
        SET @errores += N'- La región indicada no existe. ';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        SET @errores += N'- El nombre de la región es obligatorio. ';
    IF @nombre IS NOT NULL AND LEN(@nombre) > 80
        SET @errores += N'- El nombre de la región no puede superar 80 caracteres. ';

    IF @idioma IS NOT NULL AND LTRIM(RTRIM(@idioma)) = N''
        SET @errores += N'- Si se informa idioma, no puede quedar vacío. ';
    IF @idioma IS NOT NULL AND LEN(@idioma) > 50
        SET @errores += N'- El idioma no puede superar 50 caracteres. ';

    IF @huso_horario IS NULL OR LTRIM(RTRIM(@huso_horario)) = ''
        SET @errores += N'- El huso horario es obligatorio. ';
    IF @huso_horario IS NOT NULL AND LEN(@huso_horario) > 100
        SET @errores += N'- El huso horario no puede superar 100 caracteres. ';

    IF @hora_prime_inicio IS NULL
        SET @errores += N'- La hora de inicio de prime time es obligatoria. ';
    IF @hora_prime_fin IS NULL
        SET @errores += N'- La hora de fin de prime time es obligatoria. ';

    IF @hora_prime_inicio IS NOT NULL
       AND @hora_prime_fin IS NOT NULL
       AND @hora_prime_inicio >= @hora_prime_fin
        SET @errores += N'- La hora de inicio de prime time debe ser menor que la hora de fin. ';

    IF @hora_prime_inicio IS NOT NULL AND @hora_prime_inicio <= CAST('00:00:00' AS TIME(0))
        SET @errores += N'- La hora de inicio de prime time debe ser mayor que 00:00. ';
    IF @hora_prime_fin IS NOT NULL AND @hora_prime_fin <= CAST('00:00:00' AS TIME(0))
        SET @errores += N'- La hora de fin de prime time debe ser mayor que 00:00. ';

    IF @nombre IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Region
            WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
              AND id_region <> @id_region
       )
        SET @errores += N'- Ya existe una región con ese nombre. ';

    IF @errores <> N'' THROW 50102, @errores, 1;

    UPDATE dbo.Region
       SET nombre = LTRIM(RTRIM(@nombre)),
           idioma = CASE WHEN @idioma IS NULL THEN NULL ELSE LTRIM(RTRIM(@idioma)) END,
           huso_horario = LTRIM(RTRIM(@huso_horario)),
           hora_prime_inicio = @hora_prime_inicio,
           hora_prime_fin = @hora_prime_fin
     WHERE id_region = @id_region;

    SELECT * FROM dbo.Region WHERE id_region = @id_region;
END;
GO

CREATE OR ALTER PROCEDURE abm.Region_Baja
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_region IS NULL OR @id_region <= 0
        SET @errores += N'- El id_region debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Region WHERE id_region = @id_region
    )
        SET @errores += N'- La región indicada no existe. ';

    IF @errores <> N'' THROW 50103, @errores, 1;

    DELETE FROM dbo.Region WHERE id_region = @id_region;
END;
GO

CREATE OR ALTER PROCEDURE abm.Region_ConsultarPorId
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_region IS NULL OR @id_region <= 0
        SET @errores += N'- El id_region debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Region WHERE id_region = @id_region
    )
        SET @errores += N'- La región indicada no existe. ';

    IF @errores <> N'' THROW 50104, @errores, 1;

    SELECT * FROM dbo.Region WHERE id_region = @id_region;
END;
GO

CREATE OR ALTER PROCEDURE abm.Region_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Region ORDER BY id_region;
END;
GO
