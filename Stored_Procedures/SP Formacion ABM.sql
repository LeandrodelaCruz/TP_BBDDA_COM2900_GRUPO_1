/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripción:
    Script de creación de Stored Procedures ABM (Alta, Baja, Modificación)
    para las tablas:
        - dbo.Reemplazo
        - dbo.Partido
        - dbo.Partido_Seleccion
        - dbo.Formacion
        - dbo.Formacion_Jugador

    Cada SP realiza validaciones y agrupa los errores en un único mensaje.
*/

USE MUNDIALDEFUTBOL;
GO

/* =========================================================
   TABLA: dbo.Formacion
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_Formacion_Alta
    @id_partido       INT,
    @id_seleccion     INT,
    @esquema_tactico  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selección indicada. ';

    -- Validación: la selección debe estar asociada al partido
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selección no participa en el partido indicado. ';

    -- Validación: no repetir formación para el mismo partido-selección
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- Ya existe una formación para ese partido y selección. ';

    -- Validación: esquema táctico obligatorio
    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema táctico es obligatorio. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
        VALUES (@id_partido, @id_seleccion, @esquema_tactico);

        SELECT SCOPE_IDENTITY() AS id_formacion_generado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Formacion_Baja
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formación indicada. ';

    -- No borrar si tiene jugadores asociados
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion)
        SET @errores += N'- No se puede eliminar: la formación tiene jugadores asociados. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Formacion WHERE id_formacion = @id_formacion;
        SELECT @id_formacion AS id_formacion_eliminada;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Formacion_Modificacion
    @id_formacion     INT,
    @id_partido       INT,
    @id_seleccion     INT,
    @esquema_tactico  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formación indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selección indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selección no participa en el partido indicado. ';

    -- No permitir cambiar a una combinación ya usada por otra formación
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido
                 AND id_seleccion = @id_seleccion
                 AND id_formacion <> @id_formacion)
        SET @errores += N'- Ya existe otra formación para ese partido y selección. ';

    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema táctico es obligatorio. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Formacion
        SET id_partido      = @id_partido,
            id_seleccion    = @id_seleccion,
            esquema_tactico = @esquema_tactico
        WHERE id_formacion = @id_formacion;

        SELECT @id_formacion AS id_formacion_modificada;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
