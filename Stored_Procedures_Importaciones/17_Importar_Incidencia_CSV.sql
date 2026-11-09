/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comision: Com: 01-2900
    Grupo 01:
    - Caro, Nicolas Dario
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodriguez Elias Uriel

    Fecha: 03/11/2026

    Descripcion:
    Importa incidencias desde el archivo match_events.csv.

    El proceso:
    - recibe la ruta del CSV como parametro;
    - carga el archivo a una tabla temporal de staging;
    - traduce los event_type del ingles al espanol del dominio;
    - asocia cada asistencia (Assist) al gol del mismo partido, minuto y equipo;
    - calcula el periodo a partir del minuto;
    - inserta cada incidencia reutilizando abm.Incidencia_Alta;
    - continua procesando si una fila falla;
    - informa resumen y detalle de errores.

    Mapeo de event_type:
        Goal                -> GOL
        Own Goal            -> GOL EN CONTRA
        Assist              -> se consume como asistencia del GOL
        Yellow Card         -> AMONESTACION
        Red Card            -> EXPULSION
        Penalty Shootout Goal -> GOL DE PENAL
        Penalty Shootout Miss -> PENAL ERRADO
        VAR Review          -> REVISION VAR

    SQL dinamico:
    Se usa unicamente para parametrizar la ruta de BULK INSERT.
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'importacion') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA importacion');
END;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Incidencia_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- 1. Validar parametro de entrada y dependencias.
    -------------------------------------------------------------------------

    IF NULLIF(LTRIM(RTRIM(@archivo)), N'') IS NULL
        THROW 51600, N'Debe indicar la ruta del archivo CSV.', 1;

    IF OBJECT_ID(N'dbo.Incidencia', N'U') IS NULL
        THROW 51601, N'No existe dbo.Incidencia. Debe crear la tabla antes de ejecutar esta importacion.', 1;

    IF OBJECT_ID(N'dbo.Partido', N'U') IS NULL
        THROW 51602, N'No existe dbo.Partido. Debe crear/cargar Partido antes de importar incidencias.', 1;

    IF OBJECT_ID(N'dbo.Jugador', N'U') IS NULL
        THROW 51603, N'No existe dbo.Jugador. Debe crear/cargar Jugador antes de importar incidencias.', 1;

    IF OBJECT_ID(N'abm.Incidencia_Alta', N'P') IS NULL
        THROW 51604, N'No existe el ABM requerido: abm.Incidencia_Alta.', 1;

    -------------------------------------------------------------------------
    -- 2. Staging: recibe el CSV tal como viene.
    -------------------------------------------------------------------------

    CREATE TABLE #Incidencia_Staging
    (
        event_id   VARCHAR(50)  COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        match_id   VARCHAR(50)  COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        minute     VARCHAR(20)  COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        event_type VARCHAR(100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        team_id    VARCHAR(50)  COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        player_id  VARCHAR(50)  COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL
    );

    CREATE TABLE #Errores
    (
        numero_fila  INT            NOT NULL,
        event_id     NVARCHAR(50)   NULL,
        event_type   NVARCHAR(100)  NULL,
        mensaje      NVARCHAR(2048) NOT NULL
    );

    -------------------------------------------------------------------------
    -- 3. BULK INSERT con SQL dinamico unicamente para la ruta.
    -------------------------------------------------------------------------

    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        BULK INSERT #Incidencia_Staging
        FROM ''' + REPLACE(@archivo, '''', '''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"'',
            CODEPAGE = ''RAW'',
            DATAFILETYPE = ''char''
        );';

    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @mensaje_lectura NVARCHAR(2048) =
            N'No se pudo leer el archivo indicado. Detalle: ' + ERROR_MESSAGE();
        THROW 51605, @mensaje_lectura, 1;
    END CATCH;

    -------------------------------------------------------------------------
    -- 4. Normalizar staging: tipos numericos, tipos en espanol y periodo.
    -------------------------------------------------------------------------

    CREATE TABLE #Incidencia_Normalizada
    (
        numero_fila   INT IDENTITY(1,1) NOT NULL,
        event_id      INT  NULL,
        id_partido    INT  NOT NULL,
        minuto        TINYINT NULL,
        periodo       VARCHAR(30) NOT NULL,
        tipo          VARCHAR(30) NOT NULL,
        id_jugador    INT  NOT NULL,
        id_equipo     INT  NOT NULL,
        id_asistencia INT  NULL,
        es_asistencia BIT  NOT NULL DEFAULT 0,
        procesado     BIT  NOT NULL DEFAULT 0
    );

    INSERT INTO #Incidencia_Normalizada
    (
        event_id,
        id_partido,
        minuto,
        periodo,
        tipo,
        id_jugador,
        id_equipo,
        es_asistencia
    )
    SELECT
        TRY_CONVERT(INT, LTRIM(RTRIM(s.event_id))),
        TRY_CONVERT(INT, LTRIM(RTRIM(s.match_id))),
        TRY_CONVERT(TINYINT, LTRIM(RTRIM(s.minute))),
        CASE
            WHEN TRY_CONVERT(TINYINT, LTRIM(RTRIM(s.minute))) <= 45  THEN 'PRIMER TIEMPO'
            WHEN TRY_CONVERT(TINYINT, LTRIM(RTRIM(s.minute))) <= 90  THEN 'SEGUNDO TIEMPO'
            WHEN TRY_CONVERT(TINYINT, LTRIM(RTRIM(s.minute))) <= 105 THEN 'PRIMER SUPLEMENTARIO'
            WHEN TRY_CONVERT(TINYINT, LTRIM(RTRIM(s.minute))) <= 120 THEN 'SEGUNDO SUPLEMENTARIO'
            ELSE 'PENALES'
        END AS periodo,
        CASE LTRIM(RTRIM(s.event_type))
            WHEN 'Goal'                   THEN 'GOL'
            WHEN 'Own Goal'               THEN 'GOL EN CONTRA'
            WHEN 'Yellow Card'            THEN 'AMONESTACION'
            WHEN 'Red Card'               THEN 'EXPULSION'
            WHEN 'Penalty Shootout Goal'  THEN 'GOL DE PENAL'
            WHEN 'Penalty Shootout Miss'  THEN 'PENAL ERRADO'
            WHEN 'VAR Review'             THEN 'REVISION VAR'
            WHEN 'Assist'                 THEN 'ASSIST'
            ELSE LTRIM(RTRIM(s.event_type))
        END AS tipo,
        TRY_CONVERT(INT, LTRIM(RTRIM(s.player_id))),
        TRY_CONVERT(INT, LTRIM(RTRIM(s.team_id))),
        CASE WHEN LTRIM(RTRIM(s.event_type)) = 'Assist' THEN 1 ELSE 0 END AS es_asistencia
    FROM #Incidencia_Staging s;

    -------------------------------------------------------------------------
    -- 5. Emparejar asistencias con goles del mismo partido/minuto/equipo.
    -------------------------------------------------------------------------

    UPDATE g
    SET g.id_asistencia = a.id_jugador
    FROM #Incidencia_Normalizada g
    INNER JOIN #Incidencia_Normalizada a
        ON  a.es_asistencia = 1
        AND a.id_partido = g.id_partido
        AND a.minuto = g.minuto
        AND a.id_equipo = g.id_equipo
    WHERE g.tipo = 'GOL'
      AND g.id_asistencia IS NULL;

    -- Marcar las filas de asistencia como ya procesadas (no se insertan solas).
    UPDATE #Incidencia_Normalizada
    SET procesado = 1
    WHERE es_asistencia = 1;

    -------------------------------------------------------------------------
    -- 6. Bucle WHILE de procesamiento fila por fila.
    -------------------------------------------------------------------------

    DECLARE
        @numero_fila          INT = 0,
        @id_partido           INT,
        @id_jugador           INT,
        @id_equipo            INT,
        @id_jugador_involucrado INT = NULL,
        @minuto               TINYINT,
        @periodo              VARCHAR(30),
        @tipo                 VARCHAR(30),
        @id_asistencia        INT,
        @es_asistencia        BIT,

        @insertados           INT = 0,
        @errores              INT = 0,
        @id_incidencia        INT,
        @hay_fila             BIT = 1;

    WHILE @hay_fila = 1
    BEGIN
        SELECT TOP (1)
            @numero_fila     = numero_fila,
            @id_partido      = id_partido,
            @id_jugador      = id_jugador,
            @id_equipo       = id_equipo,
            @minuto          = minuto,
            @periodo         = periodo,
            @tipo            = tipo,
            @id_asistencia   = id_asistencia,
            @es_asistencia   = es_asistencia
        FROM #Incidencia_Normalizada
        WHERE numero_fila > @numero_fila
        ORDER BY numero_fila;

        SET @hay_fila = CASE WHEN @@ROWCOUNT > 0 THEN 1 ELSE 0 END;
        IF @hay_fila = 0
            CONTINUE;

        BEGIN TRY
            SET @id_jugador_involucrado = NULL;

            -- Saltear asistencias (ya se consumieron en el gol).
            IF @es_asistencia = 1
                CONTINUE;

            -- Validaciones previas.
            IF @id_partido IS NULL
                THROW 51610, N'El match_id no es numerico o esta vacio.', 1;

            IF @id_jugador IS NULL
                THROW 51611, N'El player_id no es numerico o esta vacio.', 1;

            IF @id_equipo IS NULL
                THROW 51612, N'El team_id no es numerico o esta vacio.', 1;

            IF @minuto IS NULL
                THROW 51613, N'El minuto no es numerico o esta vacio.', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
                THROW 51614, N'No existe el partido indicado (match_id).', 1;

            IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador)
                THROW 51615, N'No existe el jugador indicado (player_id).', 1;

            IF NOT EXISTS (
                SELECT 1 FROM dbo.Jugador
                WHERE id_jugador = @id_jugador
                  AND id_seleccion = @id_equipo
            )
                THROW 51616, N'El jugador no pertenece al equipo indicado (team_id).', 1;

            -- GOL: la asistencia (si existe) se pasa como jugador involucrado.
            IF @tipo = 'GOL'
            BEGIN
                SET @id_jugador_involucrado = @id_asistencia;
            END

            -- AMONESTACION y EXPULSION: en este dataset no tenemos agredido.
            -- El modelo exige uno, asi que se deja NULL; si se requiere en
            -- otra importacion futura se completara.

            EXEC abm.Incidencia_Alta
                @id_partido = @id_partido,
                @id_jugador = @id_jugador,
                @tipo = @tipo,
                @periodo = @periodo,
                @minuto = @minuto,
                @motivo = NULL,
                @id_jugador_involucrado = @id_jugador_involucrado,
                @id_incidencia = @id_incidencia OUTPUT;

            SET @insertados += 1;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores (numero_fila, event_id, event_type, mensaje)
            VALUES (
                @numero_fila,
                CAST(@id_partido AS NVARCHAR(50)) + N'-' + CAST(@id_jugador AS NVARCHAR(50)),
                @tipo,
                ERROR_MESSAGE()
            );

            SET @errores += 1;
        END CATCH;

    END;

    -------------------------------------------------------------------------
    -- 7. Resumen y detalle de errores.
    -------------------------------------------------------------------------

    SELECT
        N'Resumen importacion Incidencias' AS resultado,
        @insertados AS insertados,
        @errores    AS errores;

    IF @errores > 0
    BEGIN
        SELECT
            numero_fila,
            event_id,
            event_type,
            mensaje
        FROM #Errores
        ORDER BY numero_fila;
    END;
END;
GO
