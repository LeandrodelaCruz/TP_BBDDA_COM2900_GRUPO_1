/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodriguez, Elias Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripcion:
    Script de creacion de Stored Procedures ABM (Alta, Baja, Modificacion)
    para la tabla:
        - dbo.Formacion

    Cada SP realiza validaciones y agrupa los errores en un unico mensaje.
*/

USE MUNDIALDEFUTBOL;
GO

/*
   TABLA: dbo.Formacion
*/

CREATE OR ALTER PROCEDURE abm.Formacion_Alta
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
        SET @errores += N'- No existe la seleccion indicada. ';

    -- Validacion: no repetir formacion para el mismo partido-seleccion
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- Ya existe una formacion para ese partido y seleccion. ';

    -- Validación: la selección debe participar del partido
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido
                   WHERE id_partido = @id_partido
                     AND (@id_seleccion = id_seleccion_1 OR @id_seleccion = id_seleccion_2))
        SET @errores += N'- La selección no participa en el partido indicado. ';

    -- Validacion: esquema tactico obligatorio
    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema tactico es obligatorio. ';

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

CREATE OR ALTER PROCEDURE abm.Formacion_Baja
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formacion indicada. ';

    -- No borrar si tiene jugadores asociados
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion)
        SET @errores += N'- No se puede eliminar: la formacion tiene jugadores asociados. ';

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

CREATE OR ALTER PROCEDURE abm.Formacion_Modificacion
    @id_formacion     INT,
    @id_partido       INT,
    @id_seleccion     INT,
    @esquema_tactico  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formacion indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la seleccion indicada. ';

    -- No permitir cambiar a una combinacion ya usada por otra formacion
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido
                 AND id_seleccion = @id_seleccion
                 AND id_formacion <> @id_formacion)
        SET @errores += N'- Ya existe otra formacion para ese partido y seleccion. ';

    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema tactico es obligatorio. ';

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
