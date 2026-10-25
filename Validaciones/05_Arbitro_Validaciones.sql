/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Validaciones centralizadas para la tabla dbo.Arbitro.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.SP_Validar_Arbitro
    @operacion         VARCHAR(12),
    @id_arbitro        INT = NULL,
    @nombre            NVARCHAR(4000) = NULL,
    @apellido          NVARCHAR(4000) = NULL,
    @fecha_nacimiento  DATE = NULL,
    @pais              NVARCHAR(4000) = NULL,
    @puesto            VARCHAR(4000) = NULL,
    @idiomas           NVARCHAR(4000) = NULL,
    @errores           NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errores = N'';
    SET @operacion = UPPER(LTRIM(RTRIM(ISNULL(@operacion, ''))));

    IF @operacion NOT IN ('ALTA', 'MODIFICAR', 'BAJA', 'CONSULTAR')
        SET @errores += N'- Operación inválida para Árbitro. ';

    IF @operacion IN ('MODIFICAR', 'BAJA', 'CONSULTAR')
    BEGIN
        IF @id_arbitro IS NULL OR @id_arbitro <= 0
            SET @errores += N'- El id_arbitro debe ser mayor que cero. ';
        ELSE IF NOT EXISTS (
            SELECT 1 FROM dbo.Arbitro WHERE id_arbitro = @id_arbitro
        )
            SET @errores += N'- El árbitro indicado no existe. ';
    END;

    IF @operacion IN ('ALTA', 'MODIFICAR')
    BEGIN
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
                  AND (@id_arbitro IS NULL OR id_arbitro <> @id_arbitro)
           )
            SET @errores += N'- Ese árbitro ya se encuentra registrado. ';
    END;
END;
GO
