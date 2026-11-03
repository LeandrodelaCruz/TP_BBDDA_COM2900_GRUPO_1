/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01:
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel

    Fecha: 01/11/2026

    Descripción:
    Importa partidos desde un archivo JSON (formato FIFA 2026).
    El archivo se lee con OPENROWSET(BULK, SINGLE_CLOB) + OPENJSON,
    se normaliza en una tabla de staging y luego se aplica lógica UPSERT
    reutilizando los SP de la Entrega 5:
        - abm.Partidos_Alta
        - abm.Partidos_Modificacion

    Reglas:
    - Sede y selecciones se resuelven por nombre EXACTO en inglés
      contra dbo.Sede.nombre_estadio y dbo.Seleccion.pais.
    - La sede se resuelve en cascada:
        1) alias explícito en tabla variable @Sede_Alias
           (cubre casos donde el nombre FIFA no es prefijo ni contiene
            el nombre real: "New York/New Jersey Stadium", "BC Place Vancouver")
        2) nombre exacto en dbo.Sede
        3) prefijo normalizado (cubre "... (Estadio X)")
    - La fase llega en inglés y se traduce al español que espera el ABM.
    - Clave natural para el UPSERT: (fecha, horario_UTC,
      id_seleccion_1, id_seleccion_2). No se usa id_partido_fifa.
    - Una fila inválida no cancela el procesamiento de las demás.

    Nota sobre SQL dinámico:
    Se usa únicamente para OPENROWSET porque SQL Server no permite
    parametrizar la ruta del archivo. El resto es T-SQL estático.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Partido_JSON
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- 1. Validar el parámetro de entrada.
    -------------------------------------------------------------------------
    IF @archivo IS NULL OR LTRIM(RTRIM(@archivo)) = N''
        THROW 52001, N'Debe indicar la ruta del archivo JSON a importar.', 1;

    -------------------------------------------------------------------------
    -- 2. Staging: recibe el JSON tal como viene.
    --    Los campos se declaran como NVARCHAR amplios para poder detectar
    --    errores de formato/longitud antes de invocar los ABM.
    -------------------------------------------------------------------------
    CREATE TABLE #Partido_Staging
    (
        numero_partido                 NVARCHAR(50)   NULL,
        sede                           NVARCHAR(200)  NULL,
        fecha                          NVARCHAR(50)   NULL,
        horario_local                  NVARCHAR(50)   NULL,
        horario_UTC                    NVARCHAR(50)   NULL,
        fase                           NVARCHAR(50)   NULL,
        resultado_final                NVARCHAR(50)   NULL,
        asistencia_publico             NVARCHAR(50)   NULL,
        seleccion_local                NVARCHAR(200)  NULL,
        seleccion_visitante            NVARCHAR(200)  NULL
    );

    -------------------------------------------------------------------------
    -- 3. Tabla temporal para informar errores sin detener toda la carga.
    -------------------------------------------------------------------------
    CREATE TABLE #Errores_Importacion
    (
        numero_partido NVARCHAR(50)   NULL,
        sede           NVARCHAR(200)  NULL,
        numero_error   INT            NOT NULL,
        mensaje_error  NVARCHAR(2048) NOT NULL
    );

    -------------------------------------------------------------------------
    -- 3.b Tabla variable de alias FIFA → sede real.
    --      Solo existe durante la ejecución del SP.
    --      Se resuelve id_sede por nombre real (no por IDENTITY) para
    --      no depender del orden de carga de dbo.Sede.
    -------------------------------------------------------------------------
    DECLARE @Sede_Alias TABLE
    (
        nombre_fifa NVARCHAR(200) NOT NULL PRIMARY KEY,
        id_sede     INT           NOT NULL
    );

    INSERT INTO @Sede_Alias (nombre_fifa, id_sede)
    SELECT v.nombre_fifa, s.id_sede
    FROM (VALUES
        (N'Mexico City Stadium',         N'Mexico City Stadium (Estadio Azteca)'),
        (N'New York/New Jersey Stadium', N'New York New Jersey Stadium (MetLife Stadium)'),
        (N'New York New Jersey Stadium', N'New York New Jersey Stadium (MetLife Stadium)'),
        (N'Los Angeles Stadium',         N'Los Angeles Stadium (SoFi Stadium)'),
        (N'Dallas Stadium',              N'Dallas Stadium (AT&T Stadium)'),
        (N'Vancouver Stadium',           N'Vancouver Stadium (BC Place)'),
        (N'BC Place Vancouver',          N'Vancouver Stadium (BC Place)'),
        (N'Toronto Stadium',             N'Toronto Stadium (BMO Field)'),
        (N'Guadalajara Stadium',         N'Guadalajara Stadium (Estadio Akron)'),
        (N'Monterrey Stadium',           N'Monterrey Stadium (Estadio BBVA)')
    ) AS v(nombre_fifa, nombre_real)
    INNER JOIN dbo.Sede s
        ON s.nombre_estadio = v.nombre_real;

    DECLARE @Seleccion_Alias TABLE
    (
        nombre_fifa NVARCHAR(200) NOT NULL PRIMARY KEY,
        id_seleccion INT NOT NULL
    );

    INSERT INTO @Seleccion_Alias (nombre_fifa, id_seleccion)
    SELECT v.nombre_fifa, s.id_seleccion
    FROM (VALUES
        (N'Korea Republic', N'South Korea')
        -- ... resto de discrepancias
    ) AS v(nombre_fifa, pais_real)
    INNER JOIN dbo.Seleccion s
        ON s.pais = v.pais_real;

    -------------------------------------------------------------------------
    -- 4. Leer el archivo JSON con OPENROWSET + OPENJSON.
    --    OPENROWSET(BULK) exige un literal de ruta, por eso se usa
    --    SQL dinámico sólo en este bloque. El contenido se guarda en
    --    una variable NVARCHAR(MAX) y luego se procesa con OPEN    JSON.
    -------------------------------------------------------------------------

    DECLARE @json_bytes VARBINARY(MAX);
    DECLARE @json       NVARCHAR(MAX);
    DECLARE @sql        NVARCHAR(MAX);

    SET @sql = N'
        SELECT @out = BulkColumn
        FROM OPENROWSET
        (
            BULK ''' + REPLACE(@archivo, N'''', N'''''') + N''',
            SINGLE_BLOB
        ) AS x;';

    BEGIN TRY
        EXEC sys.sp_executesql
             @sql,
             N'@out VARBINARY(MAX) OUTPUT',
             @out = @json_bytes OUTPUT;
    END TRY
    BEGIN CATCH
        DECLARE @mensajeCarga NVARCHAR(2048) =
            N'No se pudo leer el archivo indicado. Detalle: ' + ERROR_MESSAGE();
        THROW 52002, @mensajeCarga, 1;
    END CATCH;

    IF @json_bytes IS NULL OR DATALENGTH(@json_bytes) = 0
        THROW 52003, N'El archivo JSON está vacío o no se pudo leer.', 1;

    BEGIN TRY

        SET @json = CAST(CAST(@json_bytes AS XML) AS NVARCHAR(MAX));
    END TRY
    BEGIN CATCH
        DECLARE @mensajeUtf8 NVARCHAR(2048) =
            N'El archivo no está codificado en UTF-8 válido. Detalle: ' + ERROR_MESSAGE();
        THROW 52005, @mensajeUtf8, 1;
    END CATCH;

    -------------------------------------------------------------------------
    -- 5. Parsear el JSON a la tabla de staging.
    -------------------------------------------------------------------------

    BEGIN TRY
        INSERT INTO #Partido_Staging
        (
            numero_partido,
            sede,
            fecha,
            horario_local,
            horario_UTC,
            fase,
            resultado_final,
            asistencia_publico,
            seleccion_local,
            seleccion_visitante
        )
        SELECT
            CONVERT(NVARCHAR(50),  j.[numero_partido])              AS numero_partido,
            CONVERT(NVARCHAR(200), j.[sede])                        AS sede,
            CONVERT(NVARCHAR(50),  j.[fecha])                       AS fecha,
            CONVERT(NVARCHAR(50),  j.[horario_local])               AS horario_local,
            CONVERT(NVARCHAR(50),  j.[horario_UTC])                 AS horario_UTC,
            CONVERT(NVARCHAR(50),  j.[fase])                        AS fase,
            CONVERT(NVARCHAR(50),  j.[resultado_final])             AS resultado_final,
            CONVERT(NVARCHAR(50),  j.[asistencia_publico])          AS asistencia_publico,
            CONVERT(NVARCHAR(200), j.[seleccion_local])             AS seleccion_local,
            CONVERT(NVARCHAR(200), j.[seleccion_visitante])         AS seleccion_visitante
        FROM OPENJSON(@json)
        WITH
        (
            numero_partido      INT             '$.numero_partido',
            sede                NVARCHAR(200)   '$.sede',
            fecha               NVARCHAR(50)    '$.fecha',
            horario_local       NVARCHAR(50)    '$.horario_local',
            horario_UTC         NVARCHAR(50)    '$.horario_UTC',
            fase                NVARCHAR(50)    '$.fase',
            resultado_final     NVARCHAR(50)    '$.resultado_final',
            asistencia_publico  NVARCHAR(50)    '$.asistencia_publico',
            seleccion_local     NVARCHAR(200)   '$.seleccion_local',
            seleccion_visitante NVARCHAR(200)   '$.seleccion_visitante'
        ) AS j;
    END TRY
    BEGIN CATCH
        DECLARE @mensajeJson NVARCHAR(2048) =
            N'El archivo no tiene el formato JSON esperado. Detalle: ' + ERROR_MESSAGE();
        THROW 52004, @mensajeJson, 1;
    END CATCH;

    -------------------------------------------------------------------------
    -- 6. Variables de procesamiento y contadores.
    -------------------------------------------------------------------------
    DECLARE
        @numero_partido      NVARCHAR(50),
        @sede_json           NVARCHAR(200),
        @fecha_str           NVARCHAR(50),
        @horario_local_str   NVARCHAR(50),
        @horario_UTC_str     NVARCHAR(50),
        @fase_en             NVARCHAR(50),
        @resultado_final     NVARCHAR(50),
        @asistencia_str      NVARCHAR(50),
        @pais_local          NVARCHAR(200),
        @pais_visitante      NVARCHAR(200),

        @id_sede             INT,
        @id_seleccion_1      INT,
        @id_seleccion_2      INT,
        @fecha               DATE,
        @horario_local       DATETIME2(0),
        @horario_UTC         DATETIME2(0),
        @fase_es             VARCHAR(30),
        @asistencia          INT,
        @id_partido          INT,
        @sede_norm           NVARCHAR(200),

        @procesados          INT = 0,
        @insertados          INT = 0,
        @actualizados        INT = 0,
        @cantidad_errores    INT = 0;

    -------------------------------------------------------------------------
    -- 7. Tablas variables para capturar lo que devuelven los ABM.
    -------------------------------------------------------------------------
    DECLARE @ResultadoAlta TABLE
    (
        id_partido_generado INT
    );

    DECLARE @ResultadoModificacion TABLE
    (
        id_partido_modificado INT
    );

    -------------------------------------------------------------------------
    -- 8. Cursor sobre el staging.
    -------------------------------------------------------------------------
    DECLARE cur_partidos CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            numero_partido,
            sede,
            fecha,
            horario_local,
            horario_UTC,
            fase,
            resultado_final,
            asistencia_publico,
            seleccion_local,
            seleccion_visitante
        FROM #Partido_Staging
        ORDER BY TRY_CAST(numero_partido AS INT);

    OPEN cur_partidos;

    FETCH NEXT FROM cur_partidos
    INTO @numero_partido, @sede_json, @fecha_str, @horario_local_str,
         @horario_UTC_str, @fase_en, @resultado_final, @asistencia_str,
         @pais_local, @pais_visitante;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @procesados += 1;

        -- Reset de variables por iteración
        SET @id_sede         = NULL;
        SET @id_seleccion_1  = NULL;
        SET @id_seleccion_2  = NULL;
        SET @fecha           = NULL;
        SET @horario_local   = NULL;
        SET @horario_UTC     = NULL;
        SET @fase_es         = NULL;
        SET @asistencia      = NULL;
        SET @id_partido      = NULL;
        SET @sede_norm       = NULL;

        BEGIN TRY
            -----------------------------------------------------------------
            -- 8.1 Casteos seguros. Si alguno falla, se lanza error controlado.
            -----------------------------------------------------------------
            SET @fecha = TRY_CAST(@fecha_str AS DATE);
            IF @fecha IS NULL
                THROW 52101, N'La fecha del partido es inválida o está vacía.', 1;

            SET @horario_local = TRY_CAST(@horario_local_str AS DATETIME2(0));
            IF @horario_local IS NULL
                THROW 52102, N'El horario local es inválido o está vacío.', 1;

            SET @horario_UTC = TRY_CAST(@horario_UTC_str AS DATETIME2(0));
            IF @horario_UTC IS NULL
                THROW 52103, N'El horario UTC es inválido o está vacío.', 1;

            IF @asistencia_str IS NOT NULL AND LTRIM(RTRIM(@asistencia_str)) <> N''
            BEGIN
                SET @asistencia = TRY_CAST(@asistencia_str AS INT);
                IF @asistencia IS NULL
                    THROW 52104, N'La asistencia de público no es numérica.', 1;
            END;

            -----------------------------------------------------------------
            -- 8.2 Traducción de fase inglés → español (valores del ABM).
            -----------------------------------------------------------------
            SET @fase_es = CASE LTRIM(RTRIM(@fase_en))
                WHEN N'First Stage'   THEN 'GRUPOS'
                WHEN N'Round of 32'   THEN 'DIECISEISAVOS'
                WHEN N'Round of 16'   THEN 'OCTAVOS'
                WHEN N'Quarter-final' THEN 'CUARTOS'
                WHEN N'Semi-final'    THEN 'SEMIFINAL'
                WHEN N'Bronze final'  THEN 'TERCER PUESTO'
                WHEN N'Final'         THEN 'FINAL'
                ELSE NULL
            END;

            IF @fase_es IS NULL
                THROW 52105, N'La fase indicada no es válida o no se reconoce (traducción inglés→español).', 1;

            -----------------------------------------------------------------
            -- 8.3 Resolución de la sede en cascada:
            --    1) alias explícito (tabla variable)
            --    2) nombre exacto en dbo.Sede
            --    3) prefijo normalizado ("... (Estadio X)")
            -----------------------------------------------------------------

            -- 8.3.1 Alias FIFA → sede real
            SELECT @id_sede = id_sede
            FROM @Sede_Alias
            WHERE nombre_fifa = @sede_json;

            -- 8.3.2 Nombre exacto en dbo.Sede
            IF @id_sede IS NULL
                SELECT @id_sede = id_sede
                FROM dbo.Sede
                WHERE nombre_estadio = @sede_json;

            -- 8.3.3 Prefijo normalizado (saca '/', '-', paréntesis y pasa a minúsculas)
            IF @id_sede IS NULL
            BEGIN
                SET @sede_norm =
                    LOWER(REPLACE(REPLACE(REPLACE(REPLACE(LTRIM(RTRIM(@sede_json)),
                        N'/', N' '), N'-', N' '), N'(', N' '), N')', N' '));

                SELECT TOP (1) @id_sede = id_sede
                FROM dbo.Sede
                WHERE LOWER(nombre_estadio) LIKE @sede_norm + N'%'
                ORDER BY id_sede;
            END;

            IF @id_sede IS NULL
                THROW 52106, N'No existe la sede indicada en dbo.Sede (nombre_estadio no coincide).', 1;

            -----------------------------------------------------------------
            -- 8.4 Resolución de selecciones:
            --     1) alias FIFA → id_seleccion (tabla variable)
            --     2) fallback: nombre exacto en dbo.Seleccion.pais
            -----------------------------------------------------------------

            -- 8.4.1 Alias FIFA → id_seleccion (local)
            SELECT @id_seleccion_1 = id_seleccion
            FROM @Seleccion_Alias
            WHERE nombre_fifa = @pais_local;

            -- 8.4.2 Fallback por nombre exacto (local)
            IF @id_seleccion_1 IS NULL
                SELECT @id_seleccion_1 = id_seleccion
                FROM dbo.Seleccion
                WHERE pais = @pais_local;

            IF @id_seleccion_1 IS NULL
                THROW 52107, N'No existe la selección local en dbo.Seleccion (pais no coincide).', 1;

            -- 8.4.3 Alias FIFA → id_seleccion (visitante)
            SELECT @id_seleccion_2 = id_seleccion
            FROM @Seleccion_Alias
            WHERE nombre_fifa = @pais_visitante;

            -- 8.4.4 Fallback por nombre exacto (visitante)
            IF @id_seleccion_2 IS NULL
                SELECT @id_seleccion_2 = id_seleccion
                FROM dbo.Seleccion
                WHERE pais = @pais_visitante;

            IF @id_seleccion_2 IS NULL
                THROW 52108, N'No existe la selección visitante en dbo.Seleccion (pais no coincide).', 1;

            -----------------------------------------------------------------
            -- 8.5 Buscar por clave natural: (fecha, horario_UTC,
            --     id_seleccion_1, id_seleccion_2). Si existe → UPDATE,
            --     si no → INSERT.
            -----------------------------------------------------------------
            SELECT @id_partido = id_partido
            FROM dbo.Partido
            WHERE fecha          = @fecha
              AND horario_UTC    = @horario_UTC
              AND id_seleccion_1 = @id_seleccion_1
              AND id_seleccion_2 = @id_seleccion_2;

            IF @id_partido IS NULL
            BEGIN
                -----------------------------------------------------------------
                -- 8.6 ALTA reutilizando abm.Partidos_Alta.
                -----------------------------------------------------------------
                DELETE FROM @ResultadoAlta;

                INSERT INTO @ResultadoAlta (id_partido_generado)
                EXEC abm.Partidos_Alta
                    @id_sede            = @id_sede,
                    @id_seleccion_1     = @id_seleccion_1,
                    @id_seleccion_2     = @id_seleccion_2,
                    @fecha              = @fecha,
                    @horario_local      = @horario_local,
                    @horario_UTC        = @horario_UTC,
                    @fase               = @fase_es,
                    @resultado_final    = @resultado_final,
                    @asistencia_publico = @asistencia;

                SET @insertados += 1;
            END
            ELSE
            BEGIN
                -----------------------------------------------------------------
                -- 8.7 MODIFICACIÓN reutilizando abm.Partidos_Modificacion.
                -----------------------------------------------------------------
                DELETE FROM @ResultadoModificacion;

                INSERT INTO @ResultadoModificacion (id_partido_modificado)
                EXEC abm.Partidos_Modificacion
                    @id_partido         = @id_partido,
                    @id_sede            = @id_sede,
                    @id_seleccion_1     = @id_seleccion_1,
                    @id_seleccion_2     = @id_seleccion_2,
                    @fecha              = @fecha,
                    @horario_local      = @horario_local,
                    @horario_UTC        = @horario_UTC,
                    @fase               = @fase_es,
                    @resultado_final    = @resultado_final,
                    @asistencia_publico = @asistencia;

                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores_Importacion
            (
                numero_partido,
                sede,
                numero_error,
                mensaje_error
            )
            VALUES
            (
                @numero_partido,
                @sede_json,
                ERROR_NUMBER(),
                ERROR_MESSAGE()
            );

            SET @cantidad_errores += 1;
        END CATCH;

        FETCH NEXT FROM cur_partidos
        INTO @numero_partido, @sede_json, @fecha_str, @horario_local_str,
             @horario_UTC_str, @fase_en, @resultado_final, @asistencia_str,
             @pais_local, @pais_visitante;
    END;

    CLOSE cur_partidos;
    DEALLOCATE cur_partidos;

    -------------------------------------------------------------------------
    -- 9. Resumen final.
    -------------------------------------------------------------------------
    SELECT
        @archivo          AS archivo,
        @procesados       AS registros_procesados,
        @insertados       AS registros_insertados,
        @actualizados     AS registros_actualizados,
        @cantidad_errores AS registros_con_error;

    -------------------------------------------------------------------------
    -- 10. Detalle de errores. Si no hubo, devuelve cero filas.
    -------------------------------------------------------------------------
    SELECT
        numero_partido,
        sede,
        numero_error,
        mensaje_error
    FROM #Errores_Importacion
    ORDER BY TRY_CAST(numero_partido AS INT);
END;
GO