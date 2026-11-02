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
    Stored Procedures ABM para la tabla Personal_Tecnico
    Actualización 01/11/2026: nombre_completo reemplaza nombre y apellido.

    PROCEDIMIENTOS INCLUIDOS:
    - Personal_Tecnico_Alta
    - Personal_Tecnico_Modificar
    - Personal_Tecnico_Baja

*/


USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


/* ==================== Personal_Tecnico: ALTA ==================== */
CREATE OR ALTER PROCEDURE abm.Personal_Tecnico_Alta
    @nombre_completo NVARCHAR(1000),
    @rol NVARCHAR(50),
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Nombre completo sin suponer cómo se separan nombres y apellidos.
    IF NULLIF(LTRIM(RTRIM(@nombre_completo)), N'') IS NULL SET @Errores += N'nombre_completo es obligatorio. ';
    IF DATALENGTH(LTRIM(RTRIM(@nombre_completo))) > 240 SET @Errores += N'nombre_completo supera 120 caracteres Unicode. ';

    -- Validación 3: rol vacío
    IF NULLIF(LTRIM(RTRIM(@rol)), '') IS NULL SET @Errores += N'rol es obligatorio. ';

    -- Validación 4: seleccion inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @Errores += N'- No existe la seleccion indicada. ';

    IF @Errores <> N'' THROW 50001, @Errores, 1;

    INSERT INTO dbo.Personal_Tecnico (nombre_completo, rol, id_seleccion)
    VALUES (LTRIM(RTRIM(@nombre_completo)), @rol, @id_seleccion);

END;
GO

/* ==================== Personal_Tecnico: MODIFICACIÓN ==================== */
CREATE OR ALTER PROCEDURE abm.Personal_Tecnico_Modificar
    @id_personal INT,
    @nombre_completo NVARCHAR(1000),
    @rol NVARCHAR(50),
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: pieza inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Personal_Tecnico WHERE id_personal = @id_personal) SET @Errores += N'El registro a modificar no existe. ';
    
    IF NULLIF(LTRIM(RTRIM(@nombre_completo)), N'') IS NULL SET @Errores += N'nombre_completo es obligatorio. ';
    IF DATALENGTH(LTRIM(RTRIM(@nombre_completo))) > 240 SET @Errores += N'nombre_completo supera 120 caracteres Unicode. ';

    -- Validación 4: rol vacío
    IF NULLIF(LTRIM(RTRIM(@rol)), '') IS NULL SET @Errores += N'rol es obligatorio. ';
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @Errores += N'- No existe la seleccion indicada. ';
    IF @Errores <> N'' THROW 50002, @Errores, 1;

    UPDATE dbo.Personal_Tecnico
    SET nombre_completo = LTRIM(RTRIM(@nombre_completo)),
        rol = @rol,
        id_seleccion = @id_seleccion
    WHERE id_personal = @id_personal;
END;
GO

/* ==================== Personal_Tecnico: BAJA ==================== */
CREATE OR ALTER PROCEDURE abm.Personal_Tecnico_Baja
    @id_personal INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: pieza inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Personal_Tecnico WHERE id_personal = @id_personal) SET @Errores += N'El registro a eliminar no existe. ';
    IF @Errores <> N'' THROW 50003, @Errores, 1;

    BEGIN TRY
        DELETE FROM dbo.Personal_Tecnico WHERE id_personal = @id_personal;
    END TRY
    BEGIN CATCH
        THROW 50004, N'No se pudo eliminar el registro. Verifique relaciones con otras tablas.', 1;
    END CATCH;
END;
