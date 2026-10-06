/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01: 
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel

    Descripción:
    Stored Procedures ABM para la tabla Pieza_Publicitaria

    PROCEDIMIENTOS INCLUIDOS:
    - SP_Pieza_Publicitaria_Alta
    - SP_Pieza_Publicitaria_Modificar
    - SP_Pieza_Publicitaria_Baja

*/


/* ==================== Pieza_Publicitaria: ALTA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Pieza_Publicitaria_Alta
    @id_campania INT,
    @nombre NVARCHAR(120),
    @contenido NVARCHAR(500) = NULL,
    @idioma NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: nombre vacío
    IF NULLIF(LTRIM(RTRIM(@nombre)), '') IS NULL SET @Errores += N'nombre es obligatorio. ';

    -- Validación 2: idioma vacío
    IF NULLIF(LTRIM(RTRIM(@idioma)), '') IS NULL SET @Errores += N'idioma es obligatorio. ';

    -- Validación 3: campania inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Campania WHERE id_campania = @id_campania)
        SET @Errores += N'- No existe la campania indicada. ';

    IF @Errores <> N'' THROW 50001, @Errores, 1;

    INSERT INTO dbo.Pieza_Publicitaria (id_campania, nombre, contenido, idioma)
    VALUES (@id_campania, @nombre, @contenido, @idioma);

END;
GO

/* ==================== Pieza_Publicitaria: MODIFICACIÓN ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Pieza_Publicitaria_Modificar
    @id_pieza INT,
    @id_campania INT,
    @nombre NVARCHAR(120),
    @contenido NVARCHAR(500) = NULL,
    @idioma NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: pieza inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Publicitaria WHERE id_pieza = @id_pieza) SET @Errores += N'El registro a modificar no existe. ';

    -- Validación 2: nombre vacío
    IF NULLIF(LTRIM(RTRIM(@nombre)), '') IS NULL SET @Errores += N'nombre es obligatorio. ';

    -- Validación 3: idioma vacío
    IF NULLIF(LTRIM(RTRIM(@idioma)), '') IS NULL SET @Errores += N'idioma es obligatorio. ';

    -- Validación 4: campania inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Campania WHERE id_campania = @id_campania)
        SET @Errores += N'- No existe la campania indicada. ';

    IF @Errores <> N'' THROW 50002, @Errores, 1;

    UPDATE dbo.Pieza_Publicitaria
    SET id_campania = @id_campania,
        nombre = @nombre,
        contenido = @contenido,
        idioma = @idioma
    WHERE id_pieza = @id_pieza;
END;
GO

/* ==================== Pieza_Publicitaria: BAJA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Pieza_Publicitaria_Baja
    @id_pieza INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: pieza inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Publicitaria WHERE id_pieza = @id_pieza) SET @Errores += N'El registro a eliminar no existe. ';
    IF @Errores <> N'' THROW 50003, @Errores, 1;

    BEGIN TRY
        DELETE FROM dbo.Pieza_Publicitaria WHERE id_pieza = @id_pieza;
    END TRY
    BEGIN CATCH
        THROW 50004, N'No se pudo eliminar el registro. Verifique relaciones con otras tablas.', 1;
    END CATCH;
END;