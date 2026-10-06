/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Arbitro: Alta, Modificar, Baja, Consultar por ID y Listar.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.SP_Arbitro_Alta
    @nombre NVARCHAR(4000),
    @apellido NVARCHAR(4000),
    @fecha_nacimiento DATE,
    @pais NVARCHAR(4000),
    @puesto VARCHAR(4000),
    @idiomas NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Arbitro 'ALTA', NULL, @nombre, @apellido, @fecha_nacimiento,
         @pais, @puesto, @idiomas, @errores OUTPUT;
    IF @errores <> N'' THROW 50401, @errores, 1;

    INSERT INTO dbo.Arbitro(nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
    VALUES (
        LTRIM(RTRIM(@nombre)),
        LTRIM(RTRIM(@apellido)),
        @fecha_nacimiento,
        LTRIM(RTRIM(@pais)),
        LTRIM(RTRIM(@puesto)),
        CASE WHEN @idiomas IS NULL THEN NULL ELSE LTRIM(RTRIM(@idiomas)) END
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_arbitro_creado;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Arbitro_Modificar
    @id_arbitro INT,
    @nombre NVARCHAR(4000),
    @apellido NVARCHAR(4000),
    @fecha_nacimiento DATE,
    @pais NVARCHAR(4000),
    @puesto VARCHAR(4000),
    @idiomas NVARCHAR(4000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.SP_Validar_Arbitro 'MODIFICAR', @id_arbitro, @nombre, @apellido, @fecha_nacimiento,
         @pais, @puesto, @idiomas, @errores OUTPUT;
    IF @errores <> N'' THROW 50402, @errores, 1;

    UPDATE dbo.Arbitro
       SET nombre = LTRIM(RTRIM(@nombre)),
           apellido = LTRIM(RTRIM(@apellido)),
           fecha_nacimiento = @fecha_nacimiento,
           pais = LTRIM(RTRIM(@pais)),
           puesto = LTRIM(RTRIM(@puesto)),
           idiomas = CASE WHEN @idiomas IS NULL THEN NULL ELSE LTRIM(RTRIM(@idiomas)) END
     WHERE id_arbitro = @id_arbitro;

    SELECT * FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Arbitro_Baja
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Arbitro 'BAJA', @id_arbitro, NULL, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50403, @errores, 1;

    DELETE FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Arbitro_ConsultarPorId
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Arbitro 'CONSULTAR', @id_arbitro, NULL, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50404, @errores, 1;

    SELECT * FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro;
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Arbitro_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Arbitro ORDER BY id_arbitro;
END;
GO
