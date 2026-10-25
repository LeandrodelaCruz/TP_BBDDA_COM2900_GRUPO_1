/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Cinco procedimientos de manejo de dbo.Seleccion: Alta, Modificar, Baja, Consultar por ID y Listar.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.Seleccion_Alta
    @pais NVARCHAR(80),
    @confederacion NVARCHAR(50),
    @grupo_asignado VARCHAR(5)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
        SET @errores += N'- El país de la selección es obligatorio. ';
    IF @pais IS NOT NULL AND LEN(@pais) > 80
        SET @errores += N'- El país no puede superar 80 caracteres. ';

    IF @confederacion IS NULL OR LTRIM(RTRIM(@confederacion)) = N''
        SET @errores += N'- La confederación es obligatoria. ';
    IF @confederacion IS NOT NULL AND LEN(@confederacion) > 50
        SET @errores += N'- La confederación no puede superar 50 caracteres. ';

    IF @confederacion IS NOT NULL
       AND UPPER(LTRIM(RTRIM(@confederacion))) NOT IN
           (N'AFC', N'CAF', N'CONCACAF', N'CONMEBOL', N'OFC', N'UEFA')
        SET @errores += N'- Confederación inválida. Use AFC, CAF, CONCACAF, CONMEBOL, OFC o UEFA. ';

    IF @grupo_asignado IS NULL OR LTRIM(RTRIM(@grupo_asignado)) = ''
        SET @errores += N'- El grupo asignado es obligatorio. ';
    IF @grupo_asignado IS NOT NULL AND LEN(@grupo_asignado) > 5
        SET @errores += N'- El grupo asignado no puede superar 5 caracteres. ';

    IF @pais IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Seleccion
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)))
       )
        SET @errores += N'- Ya existe una selección registrada para ese país. ';

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

CREATE OR ALTER PROCEDURE dbo.Seleccion_Modificar
    @id_seleccion INT,
    @pais NVARCHAR(80),
    @confederacion NVARCHAR(50),
    @grupo_asignado VARCHAR(5)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_seleccion IS NULL OR @id_seleccion <= 0
        SET @errores += N'- El id_seleccion debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion
    )
        SET @errores += N'- La selección indicada no existe. ';

    IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
        SET @errores += N'- El país de la selección es obligatorio. ';
    IF @pais IS NOT NULL AND LEN(@pais) > 80
        SET @errores += N'- El país no puede superar 80 caracteres. ';

    IF @confederacion IS NULL OR LTRIM(RTRIM(@confederacion)) = N''
        SET @errores += N'- La confederación es obligatoria. ';
    IF @confederacion IS NOT NULL AND LEN(@confederacion) > 50
        SET @errores += N'- La confederación no puede superar 50 caracteres. ';

    IF @confederacion IS NOT NULL
       AND UPPER(LTRIM(RTRIM(@confederacion))) NOT IN
           (N'AFC', N'CAF', N'CONCACAF', N'CONMEBOL', N'OFC', N'UEFA')
        SET @errores += N'- Confederación inválida. Use AFC, CAF, CONCACAF, CONMEBOL, OFC o UEFA. ';

    IF @grupo_asignado IS NULL OR LTRIM(RTRIM(@grupo_asignado)) = ''
        SET @errores += N'- El grupo asignado es obligatorio. ';
    IF @grupo_asignado IS NOT NULL AND LEN(@grupo_asignado) > 5
        SET @errores += N'- El grupo asignado no puede superar 5 caracteres. ';

    IF @pais IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Seleccion
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)))
              AND id_seleccion <> @id_seleccion
       )
        SET @errores += N'- Ya existe una selección registrada para ese país. ';

    IF @errores <> N'' THROW 50302, @errores, 1;

    UPDATE dbo.Seleccion
       SET pais = LTRIM(RTRIM(@pais)),
           confederacion = UPPER(LTRIM(RTRIM(@confederacion))),
           grupo_asignado = UPPER(LTRIM(RTRIM(@grupo_asignado)))
     WHERE id_seleccion = @id_seleccion;

    SELECT * FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Seleccion_Baja
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_seleccion IS NULL OR @id_seleccion <= 0
        SET @errores += N'- El id_seleccion debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion
    )
        SET @errores += N'- La selección indicada no existe. ';

    IF @errores <> N'' THROW 50303, @errores, 1;

    DELETE FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Seleccion_ConsultarPorId
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_seleccion IS NULL OR @id_seleccion <= 0
        SET @errores += N'- El id_seleccion debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion
    )
        SET @errores += N'- La selección indicada no existe. ';

    IF @errores <> N'' THROW 50304, @errores, 1;

    SELECT * FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion;
END;
GO

CREATE OR ALTER PROCEDURE dbo.Seleccion_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Seleccion ORDER BY id_seleccion;
END;
GO
