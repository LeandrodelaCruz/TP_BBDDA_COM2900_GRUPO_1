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
        - dbo.Formacion_Jugador

    Cada SP realiza validaciones y agrupa los errores en un único mensaje.
*/

USE MUNDIALDEFUTBOL;
GO


/* =========================================================
   TABLA: dbo.Formacion_Jugador
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_FormacionJugador_Alta
    @id_formacion       INT,
    @id_jugador         INT,
    @posicion_en_cancha VARCHAR(40) = NULL,
    @dorsal_en_cancha   TINYINT,
    @es_titular         BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

	DECLARE @id_partido_formacion   INT;

    -- datos de la formación
    SELECT @id_partido_formacion = id_partido
    FROM dbo.Formacion
    WHERE id_formacion = @id_formacion;

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formación indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador)
        SET @errores += N'- No existe el jugador indicado. ';

    -- Validación: el jugador debe pertenecer a la selección de la formación
	IF NOT EXISTS (
		SELECT 1
		FROM dbo.Formacion f
		INNER JOIN dbo.Jugador j ON j.id_jugador = @id_jugador
		WHERE f.id_formacion = @id_formacion
		  AND f.id_seleccion = j.id_seleccion
	)	
		SET @errores += N'- El jugador no pertenece a la selección de la formación. ';

    -- Validación: no repetir jugador en la misma formación
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- El jugador ya está cargado en esta formación. ';

    -- Validación: dorsal en cancha entre 1 y 99
    IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal en cancha debe estar entre 1 y 99. ';

    -- Validación: no repetir dorsal en la misma formación
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion AND dorsal_en_cancha = @dorsal_en_cancha)
        SET @errores += N'- El dorsal en cancha ya está usado en esta formación. ';

    -- Validación: es_titular obligatorio
    IF @es_titular IS NULL
        SET @errores += N'- Debe indicar si el jugador es titular. ';

    -- Validación: máximo 11 titulares por formación
    IF @es_titular = 1
       AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador
            WHERE id_formacion = @id_formacion AND es_titular = 1) >= 11
        SET @errores += N'- La formación ya tiene 11 titulares. ';

	-- Validación: el jugador no debe estar expulsado en el partido de la formación
    IF @id_partido_formacion IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Incidencia i
            WHERE i.id_partido = @id_partido_formacion
              AND i.id_jugador = @id_jugador
              AND i.tipo = 'EXPULSION'
       )
        SET @errores += N'- El jugador está expulsado en este partido y no puede integrar la formación. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Formacion_Jugador
            (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        VALUES
            (@id_formacion, @id_jugador, @posicion_en_cancha, @dorsal_en_cancha, @es_titular);

        SELECT @id_formacion AS id_formacion, @id_jugador AS id_jugador;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_FormacionJugador_Baja
    @id_formacion INT,
    @id_jugador   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                   WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- No existe la relación formación-jugador indicada. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Formacion_Jugador
        WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

        SELECT @id_formacion AS id_formacion, @id_jugador AS id_jugador;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_FormacionJugador_Modificacion
    @id_formacion          INT,
    @id_jugador            INT,
    @posicion_en_cancha    VARCHAR(40) = NULL,
    @dorsal_en_cancha      TINYINT,
    @es_titular            BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    -- Validación 1: la relación original debe existir
    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                   WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- No existe la relación formación-jugador indicada. ';

    -- Validación 2: dorsal entre 1 y 99
    IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal en cancha debe estar entre 1 y 99. ';

    -- Validación 3: no repetir dorsal en la misma formación (excluyendo el registro actual)
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion
                 AND dorsal_en_cancha = @dorsal_en_cancha
                 AND id_jugador <> @id_jugador)
        SET @errores += N'- El dorsal en cancha ya está usado en esta formación. ';

    -- Validación 4: es_titular obligatorio
    IF @es_titular IS NULL
        SET @errores += N'- Debe indicar si el jugador es titular. ';

    -- Validación 5: máximo 11 titulares por formación (si pasa a titular)
    IF @es_titular = 1
       AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador
            WHERE id_formacion = @id_formacion
              AND es_titular = 1
              AND id_jugador <> @id_jugador) >= 11
        SET @errores += N'- La formación ya tiene 11 titulares. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Formacion_Jugador
        SET posicion_en_cancha = @posicion_en_cancha,
            dorsal_en_cancha   = @dorsal_en_cancha,
            es_titular         = @es_titular
        WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

        SELECT @id_formacion AS id_formacion, @id_jugador AS id_jugador;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
