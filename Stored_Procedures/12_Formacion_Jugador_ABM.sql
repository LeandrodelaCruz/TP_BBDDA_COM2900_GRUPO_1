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
        - dbo.Formacion_Jugador

    Cada SP realiza validaciones y agrupa los errores en un unico mensaje.
*/

USE MUNDIALDEFUTBOL;
GO


/* =========================================================
   TABLA: dbo.Formacion_Jugador
   ========================================================= */

CREATE OR ALTER FUNCTION abm.fn_JugadorSuspendidoParaPartido
(
    @id_jugador INT,
    @id_partido INT
)
RETURNS BIT
AS
BEGIN
    DECLARE @fecha_partido DATE;

    SELECT @fecha_partido = fecha
    FROM dbo.Partido
    WHERE id_partido = @id_partido;

    -- Si el partido no existe, no se puede evaluar.
    IF @fecha_partido IS NULL
        RETURN 0;

    DECLARE @eventos TABLE
    (
        orden INT PRIMARY KEY,
        fecha DATE NOT NULL,
        tipo_evento VARCHAR(20) NOT NULL
    );

    /*
        Construimos los eventos anteriores al partido.

        FORMACION: el jugador figura en una formación.
        AMARILLA:  recibe una amonestación.
        EXPULSION: recibe una expulsión.
    */

    ;WITH Eventos AS
    (
        -- Una amarilla por partido como máximo.
        SELECT DISTINCT
            p.fecha,
            'AMARILLA' AS tipo_evento,
            p.id_partido,
            1 AS prioridad
        FROM dbo.Incidencia i
        INNER JOIN dbo.Partido p
            ON p.id_partido = i.id_partido
        WHERE i.id_jugador = @id_jugador
          AND i.tipo = 'AMONESTACION'
          AND p.fecha < @fecha_partido

        UNION ALL

        -- Las expulsiones generan una suspensión.
        SELECT
            p.fecha,
            'EXPULSION',
            p.id_partido,
            2
        FROM dbo.Incidencia i
        INNER JOIN dbo.Partido p
            ON p.id_partido = i.id_partido
        WHERE i.id_jugador = @id_jugador
          AND i.tipo = 'EXPULSION'
          AND p.fecha < @fecha_partido

        UNION ALL

        -- Una formación permite cumplir la suspensión.
        SELECT DISTINCT
            p.fecha,
            'FORMACION',
            p.id_partido,
            0
        FROM dbo.Formacion_Jugador fj
        INNER JOIN dbo.Formacion f
            ON f.id_formacion = fj.id_formacion
        INNER JOIN dbo.Partido p
            ON p.id_partido = f.id_partido
        WHERE fj.id_jugador = @id_jugador
          AND p.fecha < @fecha_partido
    ),
    EventosOrdenados AS
    (
        SELECT
            ROW_NUMBER() OVER
            (
                ORDER BY fecha, prioridad, id_partido, tipo_evento
            ) AS orden,
            fecha,
            tipo_evento
        FROM Eventos
    )
    INSERT INTO @eventos
    (
        orden,
        fecha,
        tipo_evento
    )
    SELECT
        orden,
        fecha,
        tipo_evento
    FROM EventosOrdenados;

    DECLARE @suspendido BIT = 0;

    ;WITH Procesamiento AS
    (
        -- Procesar el primer evento.
        SELECT
            e.orden,
            e.tipo_evento,

            CAST(
                CASE
                    WHEN e.tipo_evento = 'AMARILLA' THEN 1
                    ELSE 0
                END
                AS INT
            ) AS amarillas,

            CAST(
                CASE
                    WHEN e.tipo_evento = 'EXPULSION' THEN 1
                    ELSE 0
                END
                AS BIT
            ) AS suspendido

        FROM @eventos e
        WHERE e.orden = 1

        UNION ALL

        -- Procesar cada evento posterior.
        SELECT
            e.orden,
            e.tipo_evento,

            CAST(
                CASE
                    -- Cumple la suspensión.
                    WHEN e.tipo_evento = 'FORMACION'
                         AND p.suspendido = 1
                        THEN 0

                    -- No acumula amarillas mientras está suspendido.
                    WHEN e.tipo_evento = 'AMARILLA'
                         AND p.suspendido = 1
                        THEN p.amarillas

                    -- Acumula una nueva amarilla.
                    WHEN e.tipo_evento = 'AMARILLA'
                        THEN p.amarillas + 1

                    ELSE p.amarillas
                END
                AS INT
            ) AS amarillas,

            CAST(
                CASE
                    -- Una formación cumple la suspensión pendiente.
                    WHEN e.tipo_evento = 'FORMACION'
                        THEN 0

                    -- Una expulsión genera una suspensión.
                    WHEN e.tipo_evento = 'EXPULSION'
                        THEN 1

                    -- Si continúa suspendido, mantiene el estado.
                    WHEN p.suspendido = 1
                        THEN 1

                    -- La segunda amarilla genera una suspensión.
                    WHEN e.tipo_evento = 'AMARILLA'
                         AND p.amarillas + 1 >= 2
                        THEN 1

                    ELSE 0
                END
                AS BIT
            ) AS suspendido

        FROM Procesamiento p
        INNER JOIN @eventos e
            ON e.orden = p.orden + 1
    )
    SELECT TOP (1)
        @suspendido = suspendido
    FROM Procesamiento
    ORDER BY orden DESC;

    RETURN ISNULL(@suspendido, 0);
END;
GO

CREATE OR ALTER PROCEDURE abm.FormacionJugador_Alta
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

    -- datos de la formacion
    SELECT @id_partido_formacion = id_partido
    FROM dbo.Formacion
    WHERE id_formacion = @id_formacion;

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formacion indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador)
        SET @errores += N'- No existe el jugador indicado. ';

    -- Validacion: el jugador debe pertenecer a la seleccion de la formacion
	IF NOT EXISTS (
		SELECT 1
		FROM dbo.Formacion f
		INNER JOIN dbo.Jugador j ON j.id_jugador = @id_jugador
		WHERE f.id_formacion = @id_formacion
		  AND f.id_seleccion = j.id_seleccion
	)	
		SET @errores += N'- El jugador no pertenece a la seleccion de la formacion. ';

    -- Validacion: no repetir jugador en la misma formacion
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- El jugador ya esta cargado en esta formacion. ';

    -- Validacion: dorsal en cancha entre 1 y 99
    IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal en cancha debe estar entre 1 y 99. ';

    -- Validacion: no repetir dorsal en la misma formacion
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion AND dorsal_en_cancha = @dorsal_en_cancha)
        SET @errores += N'- El dorsal en cancha ya esta usado en esta formacion. ';

    -- Validacion: es_titular obligatorio
    IF @es_titular IS NULL
        SET @errores += N'- Debe indicar si el jugador es titular. ';

    -- Validacion: maximo 11 titulares por formacion
    IF @es_titular = 1
       AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador
            WHERE id_formacion = @id_formacion AND es_titular = 1) >= 11
        SET @errores += N'- La formacion ya tiene 11 titulares. ';

	-- Validacion: el jugador no debe estar expulsado en el partido de la formacion
    IF @id_partido_formacion IS NOT NULL
       AND EXISTS (
            SELECT 1
            FROM dbo.Incidencia i
            WHERE i.id_partido = @id_partido_formacion
              AND i.id_jugador = @id_jugador
              AND i.tipo = 'EXPULSION'
       )
        SET @errores += N'- El jugador esta expulsado en este partido y no puede integrar la formacion. ';

	-- Validación: el jugador no debe tener una suspensión pendiente.
	IF @id_partido_formacion IS NOT NULL
	 AND abm.fn_JugadorSuspendidoParaPartido(
			   @id_jugador,
			   @id_partido_formacion
		   ) = 1
	BEGIN
		SET @errores +=
			N'- El jugador está suspendido para este partido y no puede integrar la formación. ';
	END;

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

CREATE OR ALTER PROCEDURE abm.FormacionJugador_Baja
    @id_formacion INT,
    @id_jugador   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                   WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- No existe la relacion formacion-jugador indicada. ';

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

CREATE OR ALTER PROCEDURE abm.FormacionJugador_Modificacion
    @id_formacion          INT,
    @id_jugador            INT,
    @posicion_en_cancha    VARCHAR(40) = NULL,
    @dorsal_en_cancha      TINYINT,
    @es_titular            BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    -- Validacion 1: la relacion original debe existir
    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                   WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- No existe la relacion formacion-jugador indicada. ';

    -- Validacion 2: dorsal entre 1 y 99
    IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal en cancha debe estar entre 1 y 99. ';

    -- Validacion 3: no repetir dorsal en la misma formacion (excluyendo el registro actual)
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion
                 AND dorsal_en_cancha = @dorsal_en_cancha
                 AND id_jugador <> @id_jugador)
        SET @errores += N'- El dorsal en cancha ya esta usado en esta formacion. ';

    -- Validacion 4: es_titular obligatorio
    IF @es_titular IS NULL
        SET @errores += N'- Debe indicar si el jugador es titular. ';

    -- Validacion 5: maximo 11 titulares por formacion (si pasa a titular)
    IF @es_titular = 1
       AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador
            WHERE id_formacion = @id_formacion
              AND es_titular = 1
              AND id_jugador <> @id_jugador) >= 11
        SET @errores += N'- La formacion ya tiene 11 titulares. ';

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