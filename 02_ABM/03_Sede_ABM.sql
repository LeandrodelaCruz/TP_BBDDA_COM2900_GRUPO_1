/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5 - Base de Datos
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Sede: Alta, Modificar, Baja, Consultar por ID y Listar.
*/
SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.sp_Sede_Alta
    @nombre_estadio NVARCHAR(4000),
    @ciudad NVARCHAR(4000),
    @pais NVARCHAR(4000),
    @capacidad INT,
    @huso_horario VARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Sede 'ALTA', NULL, @nombre_estadio, @ciudad, @pais, @capacidad,
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

CREATE OR ALTER PROCEDURE dbo.sp_Sede_Modificar
    @id_sede INT,
    @nombre_estadio NVARCHAR(4000),
    @ciudad NVARCHAR(4000),
    @pais NVARCHAR(4000),
    @capacidad INT,
    @huso_horario VARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Sede 'MODIFICAR', @id_sede, @nombre_estadio, @ciudad, @pais, @capacidad,
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

CREATE OR ALTER PROCEDURE dbo.sp_Sede_Baja
    @id_sede INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Sede 'BAJA', @id_sede, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50203, @errores, 1;

    DELETE FROM dbo.Sede WHERE id_sede = @id_sede;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sede_ConsultarPorId
    @id_sede INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Sede 'CONSULTAR', @id_sede, NULL, NULL, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50204, @errores, 1;

    SELECT * FROM dbo.Sede WHERE id_sede = @id_sede;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Sede_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Sede ORDER BY id_sede;
END;
GO
