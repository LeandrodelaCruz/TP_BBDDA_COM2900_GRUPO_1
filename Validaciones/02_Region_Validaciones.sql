/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Validaciones centralizadas para la tabla dbo.Region.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.SP_Validar_Region
    @operacion          VARCHAR(12),
    @id_region          INT = NULL,
    @nombre             NVARCHAR(4000) = NULL,
    @idioma             NVARCHAR(4000) = NULL,
    @huso_horario       VARCHAR(4000) = NULL,
    @hora_prime_inicio  TIME(0) = NULL,
    @hora_prime_fin     TIME(0) = NULL,
    @errores            NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errores = N'';
    SET @operacion = UPPER(LTRIM(RTRIM(ISNULL(@operacion, ''))));

    IF @operacion NOT IN ('ALTA', 'MODIFICAR', 'BAJA', 'CONSULTAR')
        SET @errores += N'- Operación inválida para Región. ';

    IF @operacion IN ('MODIFICAR', 'BAJA', 'CONSULTAR')
    BEGIN
        IF @id_region IS NULL OR @id_region <= 0
            SET @errores += N'- El id_region debe ser mayor que cero. ';
        ELSE IF NOT EXISTS (
            SELECT 1 FROM dbo.Region WHERE id_region = @id_region
        )
            SET @errores += N'- La región indicada no existe. ';
    END;

    IF @operacion IN ('ALTA', 'MODIFICAR')
    BEGIN
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
            SET @errores += N'- El nombre de la región es obligatorio. ';
        IF @nombre IS NOT NULL AND LEN(@nombre) > 80
            SET @errores += N'- El nombre de la región no puede superar 80 caracteres. ';

        IF @idioma IS NOT NULL AND LTRIM(RTRIM(@idioma)) = N''
            SET @errores += N'- Si se informa idioma, no puede quedar vacío. ';
        IF @idioma IS NOT NULL AND LEN(@idioma) > 50
            SET @errores += N'- El idioma no puede superar 50 caracteres. ';

        IF @huso_horario IS NULL OR LTRIM(RTRIM(@huso_horario)) = ''
            SET @errores += N'- El huso horario es obligatorio. ';
        IF @huso_horario IS NOT NULL AND LEN(@huso_horario) > 100
            SET @errores += N'- El huso horario no puede superar 100 caracteres. ';

        IF @hora_prime_inicio IS NULL
            SET @errores += N'- La hora de inicio de prime time es obligatoria. ';
        IF @hora_prime_fin IS NULL
            SET @errores += N'- La hora de fin de prime time es obligatoria. ';

        IF @hora_prime_inicio IS NOT NULL
           AND @hora_prime_fin IS NOT NULL
           AND @hora_prime_inicio >= @hora_prime_fin
            SET @errores += N'- La hora de inicio de prime time debe ser menor que la hora de fin. ';

        /* Replica las restricciones que el grupo incluyó en la tabla. */
        IF @hora_prime_inicio IS NOT NULL AND @hora_prime_inicio <= CAST('00:00:00' AS TIME(0))
            SET @errores += N'- La hora de inicio de prime time debe ser mayor que 00:00. ';
        IF @hora_prime_fin IS NOT NULL AND @hora_prime_fin <= CAST('00:00:00' AS TIME(0))
            SET @errores += N'- La hora de fin de prime time debe ser mayor que 00:00. ';

        IF @nombre IS NOT NULL
           AND EXISTS (
                SELECT 1
                FROM dbo.Region
                WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
                  AND (@id_region IS NULL OR id_region <> @id_region)
           )
            SET @errores += N'- Ya existe una región con ese nombre. ';
    END;
END;
GO
