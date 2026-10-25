/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Anunciante: Alta, Modificar, Baja, Consultar por ID y Listar.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.Anunciante_Alta
    @nombre NVARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        SET @errores += N'- El nombre del anunciante es obligatorio. ';

    IF @nombre IS NOT NULL AND LEN(@nombre) > 120
        SET @errores += N'- El nombre no puede superar los 120 caracteres. ';

    IF @nombre IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Anunciante
            WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
       )
        SET @errores += N'- Ya existe un anunciante con ese nombre. ';

    IF @errores <> N'' THROW 50001, @errores, 1;

    INSERT INTO dbo.Anunciante(nombre)
    VALUES (LTRIM(RTRIM(@nombre)));

    SELECT CAST(SCOPE_IDENTITY() AS INT) AS id_anunciante_creado;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Anunciante_Modificar
    @id_anunciante INT,
    @nombre NVARCHAR(120)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_anunciante IS NULL OR @id_anunciante <= 0
        SET @errores += N'- El id_anunciante debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante
    )
        SET @errores += N'- El anunciante indicado no existe. ';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        SET @errores += N'- El nombre del anunciante es obligatorio. ';

    IF @nombre IS NOT NULL AND LEN(@nombre) > 120
        SET @errores += N'- El nombre no puede superar los 120 caracteres. ';

    IF @nombre IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Anunciante
            WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
              AND id_anunciante <> @id_anunciante
       )
        SET @errores += N'- Ya existe un anunciante con ese nombre. ';

    IF @errores <> N'' THROW 50002, @errores, 1;

    UPDATE dbo.Anunciante
       SET nombre = LTRIM(RTRIM(@nombre))
     WHERE id_anunciante = @id_anunciante;

    SELECT * FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Anunciante_Baja
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_anunciante IS NULL OR @id_anunciante <= 0
        SET @errores += N'- El id_anunciante debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante
    )
        SET @errores += N'- El anunciante indicado no existe. ';

    IF @errores <> N'' THROW 50003, @errores, 1;

    DELETE FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Anunciante_ConsultarPorId
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_anunciante IS NULL OR @id_anunciante <= 0
        SET @errores += N'- El id_anunciante debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante
    )
        SET @errores += N'- El anunciante indicado no existe. ';

    IF @errores <> N'' THROW 50004, @errores, 1;

    SELECT * FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Anunciante_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Anunciante ORDER BY id_anunciante;
END;
GO
