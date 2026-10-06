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


CREATE OR ALTER PROCEDURE dbo.SP_Region_Alta
    @nombre NVARCHAR(4000),
    @idioma NVARCHAR(4000) = NULL,
    @huso_horario VARCHAR(4000),
    @hora_prime_inicio TIME(0),
    @hora_prime_fin TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Region 'ALTA', NULL, @nombre, @idioma, @huso_horario,
         @hora_prime_inicio, @hora_prime_fin, @errores OUTPUT;
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

CREATE OR ALTER PROCEDURE dbo.sp_Region_Modificar
    @id_region INT,
    @nombre NVARCHAR(4000),
    @idioma NVARCHAR(4000) = NULL,
    @huso_horario VARCHAR(4000),
    @hora_prime_inicio TIME(0),
    @hora_prime_fin TIME(0)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Region 'MODIFICAR', @id_region, @nombre, @idioma, @huso_horario,
         @hora_prime_inicio, @hora_prime_fin, @errores OUTPUT;
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

CREATE OR ALTER PROCEDURE dbo.sp_Region_Baja
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Region 'BAJA', @id_region, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50103, @errores, 1;

    DELETE FROM dbo.Region WHERE id_region = @id_region;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Region_ConsultarPorId
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Region 'CONSULTAR', @id_region, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50104, @errores, 1;

    SELECT * FROM dbo.Region WHERE id_region = @id_region;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Region_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Region ORDER BY id_region;
END;
GO
