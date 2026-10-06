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
    Stored Procedures ABM para la tabla Campania

    PROCEDIMIENTOS INCLUIDOS:
    - SP_Campania_Alta
    - SP_Campania_Modificar
    - SP_Campania_Baja

*/

/* ==================== Campania: ALTA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Campania_Alta
    @descripcion NVARCHAR(250),
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: descripción vacía
    IF NULLIF(LTRIM(RTRIM(@descripcion)), '') IS NULL SET @Errores += N'descripcion es obligatorio. ';

    -- Validación 2: anunciante inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante)
        SET @Errores += N'- No existe el anunciante indicado. ';
    
    IF @Errores <> N'' THROW 50001, @Errores, 1;

    INSERT INTO dbo.Campania (descripcion, id_anunciante)
    VALUES (@descripcion, @id_anunciante);

END;
GO

/* ==================== Campania: MODIFICACIÓN ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Campania_Modificar
    @id_campania INT,
    @descripcion NVARCHAR(250),
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: campania inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Campania WHERE id_campania = @id_campania) SET @Errores += N'El registro a modificar no existe. ';

    -- Validación 2: descripción vacía
    IF NULLIF(LTRIM(RTRIM(@descripcion)), '') IS NULL SET @Errores += N'descripcion es obligatorio. ';
    IF @Errores <> N'' THROW 50002, @Errores, 1;

    -- Validación 3: anunciante inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante)
    SET @Errores += N'- No existe el anunciante indicado. ';

    UPDATE dbo.Campania
    SET descripcion = @descripcion,
        id_anunciante = @id_anunciante
    WHERE id_campania = @id_campania;
END;
GO

/* ==================== Campania: BAJA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Campania_Baja
    @id_campania INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';
    
    -- Validación 1: campania inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Campania WHERE id_campania = @id_campania) SET @Errores += N'El registro a eliminar no existe. ';
    IF @Errores <> N'' THROW 50003, @Errores, 1;

    BEGIN TRY
        DELETE FROM dbo.Campania WHERE id_campania = @id_campania;
    END TRY
    BEGIN CATCH
        THROW 50004, N'No se pudo eliminar el registro. Verifique relaciones con otras tablas.', 1;
    END CATCH;
END;
GO