/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5 - Base de Datos
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Anunciante: Alta, Modificar, Baja, Consultar por ID y Listar.
*/
SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.sp_Anunciante_Alta
    @nombre NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Anunciante 'ALTA', NULL, @nombre, @errores OUTPUT;
    IF @errores <> N'' THROW 50001, @errores, 1;

    INSERT INTO dbo.Anunciante(nombre)
    VALUES (LTRIM(RTRIM(@nombre)));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_anunciante_creado;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Anunciante_Modificar
    @id_anunciante INT,
    @nombre NVARCHAR(4000)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Anunciante 'MODIFICAR', @id_anunciante, @nombre, @errores OUTPUT;
    IF @errores <> N'' THROW 50002, @errores, 1;

    UPDATE dbo.Anunciante
       SET nombre = LTRIM(RTRIM(@nombre))
     WHERE id_anunciante = @id_anunciante;

    SELECT * FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Anunciante_Baja
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Anunciante 'BAJA', @id_anunciante, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50003, @errores, 1;

    DELETE FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Anunciante_ConsultarPorId
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048);
    EXEC dbo.sp_Validar_Anunciante 'CONSULTAR', @id_anunciante, NULL, @errores OUTPUT;
    IF @errores <> N'' THROW 50004, @errores, 1;

    SELECT * FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.sp_Anunciante_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Anunciante ORDER BY id_anunciante;
END;
GO
