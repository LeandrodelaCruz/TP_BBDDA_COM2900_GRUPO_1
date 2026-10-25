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


CREATE OR ALTER PROCEDURE abm.Arbitro_Alta
    @nombre NVARCHAR(60),
    @apellido NVARCHAR(60),
    @fecha_nacimiento DATE,
    @pais NVARCHAR(80),
    @puesto VARCHAR(50),
    @idiomas NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        SET @errores += N'- El nombre del árbitro es obligatorio. ';
    IF @nombre IS NOT NULL AND LEN(@nombre) > 60
        SET @errores += N'- El nombre no puede superar 60 caracteres. ';

    IF @apellido IS NULL OR LTRIM(RTRIM(@apellido)) = N''
        SET @errores += N'- El apellido del árbitro es obligatorio. ';
    IF @apellido IS NOT NULL AND LEN(@apellido) > 60
        SET @errores += N'- El apellido no puede superar 60 caracteres. ';

    IF @fecha_nacimiento IS NULL
        SET @errores += N'- La fecha de nacimiento es obligatoria. ';
    ELSE IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha de nacimiento no puede estar en el futuro. ';

    IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
        SET @errores += N'- El país del árbitro es obligatorio. ';
    IF @pais IS NOT NULL AND LEN(@pais) > 80
        SET @errores += N'- El país no puede superar 80 caracteres. ';

    IF @puesto IS NULL OR LTRIM(RTRIM(@puesto)) = ''
        SET @errores += N'- El puesto/categoría del árbitro es obligatorio. ';
    IF @puesto IS NOT NULL AND LEN(@puesto) > 50
        SET @errores += N'- El puesto/categoría no puede superar 50 caracteres. ';

    IF @idiomas IS NOT NULL AND LTRIM(RTRIM(@idiomas)) = N''
        SET @errores += N'- Si se informan idiomas, el valor no puede quedar vacío. ';
    IF @idiomas IS NOT NULL AND LEN(@idiomas) > 200
        SET @errores += N'- Los idiomas no pueden superar 200 caracteres. ';

    IF @nombre IS NOT NULL AND @apellido IS NOT NULL
       AND @fecha_nacimiento IS NOT NULL AND @pais IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Arbitro
            WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
              AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(LTRIM(RTRIM(@apellido)))
              AND fecha_nacimiento = @fecha_nacimiento
              AND UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)))
       )
        SET @errores += N'- Ese árbitro ya se encuentra registrado. ';

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

CREATE OR ALTER PROCEDURE abm.Arbitro_Modificar
    @id_arbitro INT,
    @nombre NVARCHAR(60),
    @apellido NVARCHAR(60),
    @fecha_nacimiento DATE,
    @pais NVARCHAR(80),
    @puesto VARCHAR(50),
    @idiomas NVARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_arbitro IS NULL OR @id_arbitro <= 0
        SET @errores += N'- El id_arbitro debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro
    )
        SET @errores += N'- El árbitro indicado no existe. ';

    IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
        SET @errores += N'- El nombre del árbitro es obligatorio. ';
    IF @nombre IS NOT NULL AND LEN(@nombre) > 60
        SET @errores += N'- El nombre no puede superar 60 caracteres. ';

    IF @apellido IS NULL OR LTRIM(RTRIM(@apellido)) = N''
        SET @errores += N'- El apellido del árbitro es obligatorio. ';
    IF @apellido IS NOT NULL AND LEN(@apellido) > 60
        SET @errores += N'- El apellido no puede superar 60 caracteres. ';

    IF @fecha_nacimiento IS NULL
        SET @errores += N'- La fecha de nacimiento es obligatoria. ';
    ELSE IF @fecha_nacimiento > CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha de nacimiento no puede estar en el futuro. ';

    IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
        SET @errores += N'- El país del árbitro es obligatorio. ';
    IF @pais IS NOT NULL AND LEN(@pais) > 80
        SET @errores += N'- El país no puede superar 80 caracteres. ';

    IF @puesto IS NULL OR LTRIM(RTRIM(@puesto)) = ''
        SET @errores += N'- El puesto/categoría del árbitro es obligatorio. ';
    IF @puesto IS NOT NULL AND LEN(@puesto) > 50
        SET @errores += N'- El puesto/categoría no puede superar 50 caracteres. ';

    IF @idiomas IS NOT NULL AND LTRIM(RTRIM(@idiomas)) = N''
        SET @errores += N'- Si se informan idiomas, el valor no puede quedar vacío. ';
    IF @idiomas IS NOT NULL AND LEN(@idiomas) > 200
        SET @errores += N'- Los idiomas no pueden superar 200 caracteres. ';

    IF @nombre IS NOT NULL AND @apellido IS NOT NULL
       AND @fecha_nacimiento IS NOT NULL AND @pais IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Arbitro
            WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
              AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(LTRIM(RTRIM(@apellido)))
              AND fecha_nacimiento = @fecha_nacimiento
              AND UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)))
              AND id_arbitro <> @id_arbitro
       )
        SET @errores += N'- Ese árbitro ya se encuentra registrado. ';

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

CREATE OR ALTER PROCEDURE abm.Arbitro_Baja
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_arbitro IS NULL OR @id_arbitro <= 0
        SET @errores += N'- El id_arbitro debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro
    )
        SET @errores += N'- El árbitro indicado no existe. ';

    IF @errores <> N'' THROW 50403, @errores, 1;

    DELETE FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro;
END;
GO

CREATE OR ALTER PROCEDURE abm.Arbitro_ConsultarPorId
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048) = N'';

    IF @id_arbitro IS NULL OR @id_arbitro <= 0
        SET @errores += N'- El id_arbitro debe ser mayor que cero. ';
    ELSE IF NOT EXISTS (
        SELECT 1 FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro
    )
        SET @errores += N'- El árbitro indicado no existe. ';

    IF @errores <> N'' THROW 50404, @errores, 1;

    SELECT * FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro;
END;
GO

CREATE OR ALTER PROCEDURE abm.Arbitro_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Arbitro ORDER BY id_arbitro;
END;
GO
