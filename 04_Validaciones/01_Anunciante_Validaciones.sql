/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5 - Base de Datos
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Validaciones centralizadas para la tabla dbo.Anunciante.
*/
SET NOCOUNT ON;
GO


CREATE OR ALTER PROCEDURE dbo.sp_Validar_Anunciante
    @operacion      VARCHAR(12),
    @id_anunciante  INT = NULL,
    @nombre         NVARCHAR(4000) = NULL,
    @errores        NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @errores = N'';
    SET @operacion = UPPER(LTRIM(RTRIM(ISNULL(@operacion, ''))));

    IF @operacion NOT IN ('ALTA', 'MODIFICAR', 'BAJA', 'CONSULTAR')
        SET @errores += N'- Operación inválida para Anunciante. ';

    IF @operacion IN ('MODIFICAR', 'BAJA', 'CONSULTAR')
    BEGIN
        IF @id_anunciante IS NULL OR @id_anunciante <= 0
            SET @errores += N'- El id_anunciante debe ser mayor que cero. ';
        ELSE IF NOT EXISTS (
            SELECT 1 FROM dbo.Anunciante WHERE id_anunciante = @id_anunciante
        )
            SET @errores += N'- El anunciante indicado no existe. ';
    END;

    IF @operacion IN ('ALTA', 'MODIFICAR')
    BEGIN
        IF @nombre IS NULL OR LTRIM(RTRIM(@nombre)) = N''
            SET @errores += N'- El nombre del anunciante es obligatorio. ';

        IF @nombre IS NOT NULL AND LEN(@nombre) > 120
            SET @errores += N'- El nombre no puede superar los 120 caracteres. ';

        IF @nombre IS NOT NULL
           AND EXISTS (
                SELECT 1
                FROM dbo.Anunciante
                WHERE UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
                  AND (@id_anunciante IS NULL OR id_anunciante <> @id_anunciante)
           )
            SET @errores += N'- Ya existe un anunciante con ese nombre. ';
    END;
END;
GO
