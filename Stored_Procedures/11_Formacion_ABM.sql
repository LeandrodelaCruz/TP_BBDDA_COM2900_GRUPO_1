/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodr�guez, El�as Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripci�n:
    Script de creaci�n de Stored Procedures ABM (Alta, Baja, Modificaci�n)
    para la tabla:
        - dbo.Formacion

    Cada SP realiza validaciones y agrupa los errores en un �nico mensaje.
*/

USE MUNDIALDEFUTBOL;
GO

/*
   TABLA: dbo.Formacion
*/

CREATE OR ALTER PROCEDURE dbo.Formacion_Alta
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
        SET @errores += N'- No existe la selecci�n indicada. ';

    -- Validaci�n: la selecci�n debe estar asociada al partido
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selecci�n no participa en el partido indicado. ';

    -- Validaci�n: no repetir formaci�n para el mismo partido-selecci�n
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- Ya existe una formaci�n para ese partido y selecci�n. ';

    -- Validaci�n: esquema t�ctico obligatorio
    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema t�ctico es obligatorio. ';

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

CREATE OR ALTER PROCEDURE dbo.Formacion_Baja
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formaci�n indicada. ';

    -- No borrar si tiene jugadores asociados
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion)
        SET @errores += N'- No se puede eliminar: la formaci�n tiene jugadores asociados. ';

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

CREATE OR ALTER PROCEDURE dbo.Formacion_Modificacion
    @id_formacion     INT,
    @id_partido       INT,
    @id_seleccion     INT,
    @esquema_tactico  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formaci�n indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selecci�n indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selecci�n no participa en el partido indicado. ';

    -- No permitir cambiar a una combinaci�n ya usada por otra formaci�n
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido
                 AND id_seleccion = @id_seleccion
                 AND id_formacion <> @id_formacion)
        SET @errores += N'- Ya existe otra formaci�n para ese partido y selecci�n. ';

    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema t�ctico es obligatorio. ';

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
