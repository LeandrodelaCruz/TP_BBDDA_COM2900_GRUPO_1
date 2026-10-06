/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04
    Descripción:
    Validaciones centralizadas para la tabla dbo.Sede.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.SP_Validar_Sede
    @operacion       VARCHAR(12),
    @id_sede         INT = NULL,
    @nombre_estadio  NVARCHAR(4000) = NULL,
    @ciudad          NVARCHAR(4000) = NULL,
    @pais            NVARCHAR(4000) = NULL,
    @capacidad       INT = NULL,
    @huso_horario    VARCHAR(4000) = NULL,
    @errores         NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errores = N'';
    SET @operacion = UPPER(LTRIM(RTRIM(ISNULL(@operacion, ''))));

    IF @operacion NOT IN ('ALTA', 'MODIFICAR', 'BAJA', 'CONSULTAR')
        SET @errores += N'- Operación inválida para Sede. ';

    IF @operacion IN ('MODIFICAR', 'BAJA', 'CONSULTAR')
    BEGIN
        IF @id_sede IS NULL OR @id_sede <= 0
            SET @errores += N'- El id_sede debe ser mayor que cero. ';
        ELSE IF NOT EXISTS (
            SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede
        )
            SET @errores += N'- La sede indicada no existe. ';
    END;

    IF @operacion IN ('ALTA', 'MODIFICAR')
    BEGIN
        IF @nombre_estadio IS NULL OR LTRIM(RTRIM(@nombre_estadio)) = N''
            SET @errores += N'- El nombre del estadio es obligatorio. ';
        IF @nombre_estadio IS NOT NULL AND LEN(@nombre_estadio) > 120
            SET @errores += N'- El nombre del estadio no puede superar 120 caracteres. ';

        IF @ciudad IS NULL OR LTRIM(RTRIM(@ciudad)) = N''
            SET @errores += N'- La ciudad es obligatoria. ';
        IF @ciudad IS NOT NULL AND LEN(@ciudad) > 80
            SET @errores += N'- La ciudad no puede superar 80 caracteres. ';

        IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
            SET @errores += N'- El país es obligatorio. ';
        IF @pais IS NOT NULL AND LEN(@pais) > 80
            SET @errores += N'- El país no puede superar 80 caracteres. ';

        IF @capacidad IS NULL OR @capacidad <= 0
            SET @errores += N'- La capacidad debe ser mayor que cero. ';

        IF @huso_horario IS NULL OR LTRIM(RTRIM(@huso_horario)) = ''
            SET @errores += N'- El huso horario es obligatorio. ';
        IF @huso_horario IS NOT NULL AND LEN(@huso_horario) > 100
            SET @errores += N'- El huso horario no puede superar 100 caracteres. ';

        IF @nombre_estadio IS NOT NULL AND @ciudad IS NOT NULL AND @pais IS NOT NULL
           AND EXISTS (
                SELECT 1
                FROM dbo.Sede
                WHERE UPPER(LTRIM(RTRIM(nombre_estadio))) = UPPER(LTRIM(RTRIM(@nombre_estadio)))
                  AND UPPER(LTRIM(RTRIM(ciudad))) = UPPER(LTRIM(RTRIM(@ciudad)))
                  AND UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)))
                  AND (@id_sede IS NULL OR id_sede <> @id_sede)
           )
            SET @errores += N'- Ya existe esa sede (mismo estadio, ciudad y país). ';
    END;
END;
GO
