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
    Stored Procedures ABM para la tabla Jugador

    PROCEDIMIENTOS INCLUIDOS:
    - SP_Jugador_Alta
    - SP_Jugador_Modificar
    - SP_Jugador_Baja
   
*/


/* ==================== Jugador: ALTA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Jugador_Alta
    @fecha_nacimiento DATE,
    @club_origen NVARCHAR(100),
    @apellido NVARCHAR(60),
    @nombre NVARCHAR(60),
    @posicion VARCHAR(40),
    @dorsal TINYINT,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: club_origen vacío
    IF NULLIF(LTRIM(RTRIM(@club_origen)), '') IS NULL SET @Errores += N'club_origen es obligatorio. ';

    -- Validación 2: apellido vacío
    IF NULLIF(LTRIM(RTRIM(@apellido)), '') IS NULL SET @Errores += N'apellido es obligatorio. ';

    -- Validación 3: nombre vacío
    IF NULLIF(LTRIM(RTRIM(@nombre)), '') IS NULL SET @Errores += N'nombre es obligatorio. ';

    -- Validación 4: posicion vacío
    IF NULLIF(LTRIM(RTRIM(@posicion)), '') IS NULL SET @Errores += N'posicion es obligatorio. ';

    -- Validación 5: seleccion inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @Errores += N'- No existe la seleccion indicada. ';

    -- Validación 6: Dorsal fuera de rango
    IF @dorsal NOT BETWEEN 1 AND 26 SET @Errores += N'El dorsal debe estar entre 1 y 26. ';

    /*-- Validación 7: Dorsal repetido en la misma selección
    IF EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_seleccion = @id_seleccion AND dorsal = @dorsal)
    SET @Errores += N'El dorsal ' + CAST(@dorsal AS NVARCHAR(3)) + N' ya está asignado a otro jugador de esta selección. ';

    Hacer esta validación generaría conflictos al hacer reemplazos más adelante. Porque un jugador que reemplaza a otro va a tomar el número
    del jugador original.
    */
    IF @Errores <> N'' THROW 50001, @Errores, 1;

    INSERT INTO dbo.Jugador (fecha_nacimiento, club_origen, apellido, nombre, posicion, dorsal, id_seleccion)
    VALUES (@fecha_nacimiento, @club_origen, @apellido, @nombre, @posicion, @dorsal, @id_seleccion);
END;
GO

/* ==================== Jugador: MODIFICACIÓN ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Jugador_Modificar
    @id_jugador INT,
    @fecha_nacimiento DATE,
    @club_origen NVARCHAR(100),
    @apellido NVARCHAR(60),
    @nombre NVARCHAR(60),
    @posicion NVARCHAR(40),
    @dorsal TINYINT,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: jugador inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador) SET @Errores += N'El registro a modificar no existe. ';

    -- Validación 2: club_origen vacío
    IF NULLIF(LTRIM(RTRIM(@club_origen)), '') IS NULL SET @Errores += N'club_origen es obligatorio. ';

    -- Validación 3: apellido vacío
    IF NULLIF(LTRIM(RTRIM(@apellido)), '') IS NULL SET @Errores += N'apellido es obligatorio. ';

    -- Validación 4: nombre vacío
    IF NULLIF(LTRIM(RTRIM(@nombre)), '') IS NULL SET @Errores += N'nombre es obligatorio. ';

    -- Validación 5: posicion vacío
    IF NULLIF(LTRIM(RTRIM(@posicion)), '') IS NULL SET @Errores += N'posicion es obligatorio. ';
    IF @Errores <> N'' THROW 50002, @Errores, 1;

    -- Validación 6: seleccion inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
    SET @Errores += N'- No existe la seleccion indicada. ';

    UPDATE dbo.Jugador
    SET fecha_nacimiento = @fecha_nacimiento,
        club_origen = @club_origen,
        apellido = @apellido,
        nombre = @nombre,
        posicion = @posicion,
        dorsal = @dorsal,
        id_seleccion = @id_seleccion
    WHERE id_jugador = @id_jugador;
END;
GO

/* ==================== Jugador: BAJA ==================== */
CREATE OR ALTER PROCEDURE dbo.SP_Jugador_Baja
    @id_jugador INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Errores NVARCHAR(2048) = N'';

    -- Validación 1: jugador inexistente
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador) SET @Errores += N'El registro a eliminar no existe. ';
    IF @Errores <> N'' THROW 50003, @Errores, 1;

    BEGIN TRY
        DELETE FROM dbo.Jugador WHERE id_jugador = @id_jugador;
    END TRY
    BEGIN CATCH
        THROW 50004, N'No se pudo eliminar el registro. Verifique relaciones con otras tablas.', 1;
    END CATCH;
END;