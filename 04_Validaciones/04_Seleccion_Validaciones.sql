/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Validaciones centralizadas para la tabla dbo.Seleccion.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.SP_Validar_Seleccion
    @operacion       VARCHAR(12),
    @id_seleccion    INT = NULL,
    @pais            NVARCHAR(4000) = NULL,
    @confederacion   NVARCHAR(4000) = NULL,
    @grupo_asignado  VARCHAR(4000) = NULL,
    @errores         NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errores = N'';
    SET @operacion = UPPER(LTRIM(RTRIM(ISNULL(@operacion, ''))));

    IF @operacion NOT IN ('ALTA', 'MODIFICAR', 'BAJA', 'CONSULTAR')
        SET @errores += N'- Operación inválida para Selección. ';

    IF @operacion IN ('MODIFICAR', 'BAJA', 'CONSULTAR')
    BEGIN
        IF @id_seleccion IS NULL OR @id_seleccion <= 0
            SET @errores += N'- El id_seleccion debe ser mayor que cero. ';
        ELSE IF NOT EXISTS (
            SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion
        )
            SET @errores += N'- La selección indicada no existe. ';
    END;

    IF @operacion IN ('ALTA', 'MODIFICAR')
    BEGIN
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
                  AND (@id_seleccion IS NULL OR id_seleccion <> @id_seleccion)
           )
            SET @errores += N'- Ya existe una selección registrada para ese país. ';
    END;
END;
GO
