/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodríguez, Elías Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripción:
    Script de creación de Stored Procedures ABM (Alta, Baja, Modificación)
    para la tabla:
        - dbo.Partido_Seleccion

    Cada SP realiza validaciones y agrupa los errores en un único mensaje.
*/

USE MUNDIALDEFUTBOL;
GO

/* =========================================================
   TABLA: dbo.Partido_Seleccion
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_PartidoSeleccion_Alta
    @id_partido   INT,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selección indicada. ';

    -- Validación: no más de 2 selecciones por partido
    IF (SELECT COUNT(*) FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido) >= 2
        SET @errores += N'- El partido ya tiene dos selecciones asignadas. ';

    -- Validación: evitar duplicado exacto
    IF EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selección ya está asignada a este partido. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion)
        VALUES (@id_partido, @id_seleccion);

        SELECT @id_partido AS id_partido, @id_seleccion AS id_seleccion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_PartidoSeleccion_Baja
    @id_partido   INT,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la relación partido-selección indicada. ';

    -- No eliminar si hay formaciones asociadas
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- No se puede eliminar: existe una formación asociada. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Partido_Seleccion
        WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion;

        SELECT @id_partido AS id_partido, @id_seleccion AS id_seleccion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_PartidoSeleccion_Modificacion
    @id_partido       INT,
    @id_seleccion     INT,
    @nuevo_id_partido INT,
    @nueva_id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la relación partido-selección original. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @nuevo_id_partido)
        SET @errores += N'- No existe el nuevo partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @nueva_id_seleccion)
        SET @errores += N'- No existe la nueva selección indicada. ';

    IF (@id_partido <> @nuevo_id_partido OR @id_seleccion <> @nueva_id_seleccion)
       AND EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @nuevo_id_partido AND id_seleccion = @nueva_id_seleccion)
        SET @errores += N'- Ya existe la nueva relación partido-selección. ';

    IF (SELECT COUNT(*) FROM dbo.Partido_Seleccion
        WHERE id_partido = @nuevo_id_partido
          AND NOT (id_partido = @id_partido AND id_seleccion = @id_seleccion)) >= 2
        SET @errores += N'- El nuevo partido ya tiene dos selecciones asignadas. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Partido_Seleccion
        SET id_partido   = @nuevo_id_partido,
            id_seleccion = @nueva_id_seleccion
        WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion;

        SELECT @nuevo_id_partido AS id_partido, @nueva_id_seleccion AS id_seleccion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
