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
    Stored Procedures ABM para la tabla Pieza_Para_Region

    PROCEDIMIENTOS INCLUIDOS:
    - SP_Pieza_Region_Alta
    - SP_Pieza_Region_Baja
    
*/


/* ==================== Pieza_Para_Region: ALTA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Pieza_Para_Region_Alta
    @id_pieza INT,
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: pieza inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Publicitaria WHERE id_pieza = id_pieza)
        SET @Errores += N'- No existe la pieza indicada. ';

    -- Validación 2: region inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Region WHERE @id_region = @id_region)
        SET @Errores += N'- No existe la region indicada. ';

    IF @Errores <> N'' THROW 50001, @Errores, 1;

    INSERT INTO dbo.Pieza_Para_Region (id_pieza, id_region)
    VALUES (@id_pieza, @id_region);
END;
GO

/* ==================== Pieza_Para_Region: MODIFICACIÓN ==================== */
/*
Pieza_Region es una tabla intermedia que sirve para identificar la relación entre Pieza_Publicitaria y Region. No tiene ningún contenido extra.
Si se quisiera modificar alguna de estas relaciones, se podría dar de baja la relación deseada y crear una nueva. La "Modificación" de relaciones
es redundante en este caso, por lo que no se llevará a cabo.

CREATE OR ALTER PROCEDURE dbo.SP_Pieza_Region_Modificar
    @id_pieza INT,
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: registro inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Region WHERE id_pieza = @id_pieza AND id_region = @id_region) SET @Errores += N'El registro a modificar no existe. ';
    IF @Errores <> N'' THROW 50002, @Errores, 1;

    -- Tabla sin columnas modificables fuera de su clave.
END;*/
GO

/* ==================== Pieza_Para_Region: BAJA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Pieza_Para_Region_Baja
    @id_pieza INT,
    @id_region INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: registro inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Para_Region WHERE id_pieza = @id_pieza AND id_region = @id_region) SET @Errores += N'El registro a eliminar no existe. ';
    IF @Errores <> N'' THROW 50003, @Errores, 1;

    BEGIN TRY
        DELETE FROM dbo.Pieza_Para_Region WHERE id_pieza = @id_pieza AND id_region = @id_region;
    END TRY
    BEGIN CATCH
        THROW 50004, N'No se pudo eliminar el registro. Verifique relaciones con otras tablas.', 1;
    END CATCH;
END;