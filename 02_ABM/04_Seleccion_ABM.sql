/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5 - Base de Datos
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Seleccion: Alta, Modificar, Baja, Consultar por ID y Listar.
*/
SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.sp_Seleccion_Alta
    @pais NVARCHAR(4000),
    @confederacion NVARCHAR(4000),
    @grupo_asignado VARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Seleccion 'ALTA', NULL, @pais, @confederacion, @grupo_asignado, @errores OUTPUT;
    IF @errores <> N'' THROW 50301, @errores, 1;

    INSERT INTO dbo.Seleccion(pais, confederacion, grupo_asignado)
    VALUES (
        LTRIM(RTRIM(@pais)),
        UPPER(LTRIM(RTRIM(@confederacion))),
        UPPER(LTRIM(RTRIM(@grupo_asignado)))
    );

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_seleccion_creada;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seleccion_Modificar
    @id_seleccion INT,
    @pais NVARCHAR(4000),
    @confederacion NVARCHAR(4000),
    @grupo_asignado VARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Seleccion 'MODIFICAR', @id_seleccion, @pais, @confederacion,
         @grupo_asignado, @errores OUTPUT;
    IF @errores <> N'' THROW 50302, @errores, 1;

    UPDATE dbo.Seleccion
       SET pais = LTRIM(RTRIM(@pais)),
           confederacion = UPPER(LTRIM(RTRIM(@confederacion))),
           grupo_asignado = UPPER(LTRIM(RTRIM(@grupo_asignado)))
     WHERE id_seleccion = @id_seleccion;

    SELECT * FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seleccion_Baja
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Seleccion 'BAJA', @id_seleccion, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50303, @errores, 1;

    DELETE FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seleccion_ConsultarPorId
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Seleccion 'CONSULTAR', @id_seleccion, NULL, NULL, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50304, @errores, 1;

    SELECT * FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Seleccion_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Seleccion ORDER BY id_seleccion;
END;
GO
