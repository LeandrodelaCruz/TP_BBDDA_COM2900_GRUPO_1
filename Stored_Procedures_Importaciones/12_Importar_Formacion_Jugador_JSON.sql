
USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Formacion_Jugador_JSON
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @json NVARCHAR(MAX);
    DECLARE @sql NVARCHAR(MAX);

    DECLARE @total_procesados INT = 0;
    DECLARE @total_insertados INT = 0;
    DECLARE @total_actualizados INT = 0;
    DECLARE @total_errores INT = 0;

    --------------------------------------------------------------------
    -- 1. LECTURA DEL ARCHIVO JSON
    --------------------------------------------------------------------

    BEGIN TRY

         SET @sql = N'
            SELECT @contenido =
                CONVERT(
                    NVARCHAR(MAX),
                    CONVERT(VARCHAR(MAX), BulkColumn)
                        COLLATE Latin1_General_100_CI_AS_SC_UTF8
                )
            FROM OPENROWSET(
                BULK ''' + REPLACE(@archivo, '''', '''''') + N''',
                SINGLE_BLOB
            ) AS archivo;
        ';

        EXEC sys.sp_executesql
            @sql,
            N'@contenido NVARCHAR(MAX) OUTPUT',
            @contenido = @json OUTPUT;

        IF @json IS NULL OR ISJSON(@json) <> 1
        BEGIN
            RAISERROR(
                'El archivo no contiene un JSON válido.',
                16,
                1
            );
            RETURN;
        END;

        ----------------------------------------------------------------
        -- 2. TABLA TEMPORAL DE PARTIDOS DEL JSON
        ----------------------------------------------------------------

        CREATE TABLE #PartidosJSON
        (
            id_registro INT IDENTITY(1,1) PRIMARY KEY,

            fecha DATE,
            horario_utc DATETIME2(0),

            seleccion_1_nombre NVARCHAR(100),
            seleccion_2_nombre NVARCHAR(100),

            jugadores_seleccion_1 NVARCHAR(MAX),
            jugadores_seleccion_2 NVARCHAR(MAX),

            id_seleccion_1 INT,
            id_seleccion_2 INT,

            id_partido INT
        );

        INSERT INTO #PartidosJSON
        (
            fecha,
            horario_utc,
            seleccion_1_nombre,
            seleccion_2_nombre,
            jugadores_seleccion_1,
            jugadores_seleccion_2
        )
        SELECT
            fecha,

            TRY_CONVERT(
                DATETIME2(0),
                REPLACE(
                    REPLACE(horario_utc, 'T', ' '),
                    'Z',
                    ''
                ),
                126
            ),

            seleccion_1_nombre,
            seleccion_2_nombre,

            jugadores_seleccion_1,
            jugadores_seleccion_2

        FROM OPENJSON(@json)
        WITH
        (
            fecha DATE '$.fecha',

            horario_utc NVARCHAR(40) '$.horario_utc',

            seleccion_1_nombre NVARCHAR(100)
                '$.seleccion_1_nombre',

            seleccion_2_nombre NVARCHAR(100)
                '$.seleccion_2_nombre',

            jugadores_seleccion_1 NVARCHAR(MAX)
                '$.jugadores_seleccion_1' AS JSON,

            jugadores_seleccion_2 NVARCHAR(MAX)
                '$.jugadores_seleccion_2' AS JSON
        );

        ----------------------------------------------------------------
        -- 3. RESOLVER SELECCIONES
        ----------------------------------------------------------------

        UPDATE pj
        SET
            id_seleccion_1 = s1.id_seleccion,
            id_seleccion_2 = s2.id_seleccion
        FROM #PartidosJSON pj

        LEFT JOIN dbo.Seleccion s1
            ON s1.pais =
                CASE
                    WHEN LTRIM(RTRIM(pj.seleccion_1_nombre))
                         = 'Korea Republic'
                    THEN 'South Korea'
                    ELSE LTRIM(RTRIM(pj.seleccion_1_nombre))
                END

        LEFT JOIN dbo.Seleccion s2
            ON s2.pais =
                CASE
                    WHEN LTRIM(RTRIM(pj.seleccion_2_nombre))
                         = 'Korea Republic'
                    THEN 'South Korea'
                    ELSE LTRIM(RTRIM(pj.seleccion_2_nombre))
                END;

        ----------------------------------------------------------------
        -- DEBUG: VERIFICAR SELECCIONES RESUELTAS
        ----------------------------------------------------------------

        SELECT
            JSON_VALUE(
                @json,
                '$[0].seleccion_2_nombre'
            ) AS seleccion_2_nombre;

        SELECT
            seleccion_1_nombre,
            seleccion_2_nombre,
            id_seleccion_1,
            id_seleccion_2
        FROM #PartidosJSON
        WHERE seleccion_1_nombre LIKE '%Australia%';

        ----------------------------------------------------------------
        -- 4. RESOLVER PARTIDOS
        ----------------------------------------------------------------

        UPDATE pj
        SET id_partido =
            CASE
                WHEN coincidencias.cantidad = 1
                THEN coincidencias.id_partido
                ELSE NULL
            END
        FROM #PartidosJSON pj

        OUTER APPLY
        (
            SELECT
                MIN(p.id_partido) AS id_partido,
                COUNT(*) AS cantidad
            FROM dbo.Partido p
            WHERE
                p.fecha = pj.fecha
                AND p.horario_UTC = pj.horario_utc
                AND
                (
                    (
                        p.id_seleccion_1 = pj.id_seleccion_1
                        AND
                        p.id_seleccion_2 = pj.id_seleccion_2
                    )
                    OR
                    (
                        p.id_seleccion_1 = pj.id_seleccion_2
                        AND
                        p.id_seleccion_2 = pj.id_seleccion_1
                    )
                )
        ) coincidencias;

        ----------------------------------------------------------------
        -- DEBUG: VERIFICAR PARTIDO IDENTIFICADO
        ----------------------------------------------------------------

        SELECT
            seleccion_1_nombre,
            seleccion_2_nombre,
            fecha,
            horario_utc,
            id_seleccion_1,
            id_seleccion_2,
            id_partido
        FROM #PartidosJSON
        WHERE seleccion_1_nombre LIKE '%Australia%';

        ----------------------------------------------------------------
        -- 5. TABLA TEMPORAL DE JUGADORES
        ----------------------------------------------------------------

        CREATE TABLE #JugadoresJSON
        (
            id_registro INT IDENTITY(1,1) PRIMARY KEY,

            id_partido INT,
            id_seleccion INT,
            id_formacion INT,

            nombre_jugador NVARCHAR(150),
            dorsal_en_cancha TINYINT,
            es_titular BIT,
            posicion_en_cancha VARCHAR(40)
        );

        ----------------------------------------------------------------
        -- 6. CARGAR JUGADORES DE LA SELECCIÓN 1
        ----------------------------------------------------------------

        INSERT INTO #JugadoresJSON
        (
            id_partido,
            id_seleccion,
            nombre_jugador,
            dorsal_en_cancha,
            es_titular,
            posicion_en_cancha
        )
        SELECT
            pj.id_partido,
            pj.id_seleccion_1,

            LTRIM(RTRIM(j.nombre_jugador)),
            j.dorsal_en_cancha,
            j.es_titular,
            j.posicion_en_cancha

        FROM #PartidosJSON pj

        CROSS APPLY OPENJSON(
            ISNULL(pj.jugadores_seleccion_1, '[]')
        )
        WITH
        (
            nombre_jugador NVARCHAR(150)
                '$.nombre_jugador',

            dorsal_en_cancha TINYINT
                '$.dorsal_en_cancha',

            es_titular BIT
                '$.es_titular',

            posicion_en_cancha VARCHAR(40)
                '$.posicion_en_cancha'
        ) j;

        ----------------------------------------------------------------
        -- 7. CARGAR JUGADORES DE LA SELECCIÓN 2
        ----------------------------------------------------------------

        INSERT INTO #JugadoresJSON
        (
            id_partido,
            id_seleccion,
            nombre_jugador,
            dorsal_en_cancha,
            es_titular,
            posicion_en_cancha
        )
        SELECT
            pj.id_partido,
            pj.id_seleccion_2,

            LTRIM(RTRIM(j.nombre_jugador)),
            j.dorsal_en_cancha,
            j.es_titular,
            j.posicion_en_cancha

        FROM #PartidosJSON pj

        CROSS APPLY OPENJSON(
            ISNULL(pj.jugadores_seleccion_2, '[]')
        )
        WITH
        (
            nombre_jugador NVARCHAR(150)
                '$.nombre_jugador',

            dorsal_en_cancha TINYINT
                '$.dorsal_en_cancha',

            es_titular BIT
                '$.es_titular',

            posicion_en_cancha VARCHAR(40)
                '$.posicion_en_cancha'
        ) j;

        ----------------------------------------------------------------
        -- 8. RESOLVER FORMACIONES
        ----------------------------------------------------------------

        UPDATE j
        SET id_formacion = f.id_formacion
        FROM #JugadoresJSON j

        INNER JOIN dbo.Formacion f
            ON f.id_partido = j.id_partido
            AND f.id_seleccion = j.id_seleccion;

        ----------------------------------------------------------------
        -- 9. TABLA TEMPORAL DE ERRORES
        ----------------------------------------------------------------

        CREATE TABLE #Errores
        (
            id_error INT IDENTITY(1,1) PRIMARY KEY,
            nombre_jugador NVARCHAR(150),
            motivo NVARCHAR(MAX)
        );

        ----------------------------------------------------------------
        -- 10. PROCESAMIENTO INDIVIDUAL DE JUGADORES
        ----------------------------------------------------------------

        DECLARE
            @id_registro INT,
            @id_partido INT,
            @id_seleccion INT,
            @id_formacion INT,

            @nombre_jugador NVARCHAR(150),
            @dorsal_en_cancha TINYINT,
            @es_titular BIT,
            @posicion_en_cancha VARCHAR(40),

            @id_jugador INT,
            @cantidad_coincidencias INT,

            -- Variables para UPSERT
            @cantidad_existente INT,
            @titulares_actuales INT,
            @total_actuales INT,
            @titular_actual BIT,
            @filas_afectadas INT;

        DECLARE cursor_jugadores CURSOR LOCAL FAST_FORWARD FOR

            SELECT
                id_registro,
                id_partido,
                id_seleccion,
                id_formacion,
                nombre_jugador,
                dorsal_en_cancha,
                es_titular,
                posicion_en_cancha
            FROM #JugadoresJSON
            ORDER BY id_registro;

        OPEN cursor_jugadores;

        FETCH NEXT FROM cursor_jugadores
        INTO
            @id_registro,
            @id_partido,
            @id_seleccion,
            @id_formacion,
            @nombre_jugador,
            @dorsal_en_cancha,
            @es_titular,
            @posicion_en_cancha;

        WHILE @@FETCH_STATUS = 0
        BEGIN

            SET @total_procesados += 1;

            SET @id_jugador = NULL;
            SET @cantidad_coincidencias = 0;

            SET @cantidad_existente = 0;
            SET @titulares_actuales = 0;
            SET @total_actuales = 0;
            SET @titular_actual = NULL;
            SET @filas_afectadas = 0;

            ------------------------------------------------------------
            -- 10.1. VALIDAR PARTIDO
            ------------------------------------------------------------

            IF @id_partido IS NULL
            BEGIN

                INSERT INTO #Errores
                (
                    nombre_jugador,
                    motivo
                )
                VALUES
                (
                    @nombre_jugador,
                    'No se pudo identificar el partido correspondiente.'
                );

                SET @total_errores += 1;

            END

            ------------------------------------------------------------
            -- 10.2. VALIDAR SELECCIÓN
            ------------------------------------------------------------

            ELSE IF @id_seleccion IS NULL
            BEGIN

                INSERT INTO #Errores
                (
                    nombre_jugador,
                    motivo
                )
                VALUES
                (
                    @nombre_jugador,
                    'No se pudo identificar la selección del jugador.'
                );

                SET @total_errores += 1;

            END

            ------------------------------------------------------------
            -- 10.3. VALIDAR FORMACIÓN
            ------------------------------------------------------------

            ELSE IF @id_formacion IS NULL
            BEGIN

                INSERT INTO #Errores
                (
                    nombre_jugador,
                    motivo
                )
                VALUES
                (
                    @nombre_jugador,
                    'No existe una formación para el partido y la selección.'
                );

                SET @total_errores += 1;

            END

            ------------------------------------------------------------
            -- 10.4. VALIDAR NOMBRE DEL JUGADOR
            ------------------------------------------------------------

            ELSE IF @nombre_jugador IS NULL
                 OR LTRIM(RTRIM(@nombre_jugador)) = ''
            BEGIN

                INSERT INTO #Errores
                (
                    nombre_jugador,
                    motivo
                )
                VALUES
                (
                    @nombre_jugador,
                    'El nombre del jugador está vacío o no fue informado.'
                );

                SET @total_errores += 1;

            END

            ELSE
            BEGIN

                --------------------------------------------------------
                -- 10.5. BUSCAR JUGADOR POR PALABRAS
                --------------------------------------------------------

                SELECT
                    @cantidad_coincidencias = COUNT(*),
                    @id_jugador = MIN(j.id_jugador)

                FROM dbo.Jugador j

                WHERE
                    j.id_seleccion = @id_seleccion

                    AND NOT EXISTS
                    (
                        SELECT 1
                        FROM STRING_SPLIT(
                            @nombre_jugador,
                            ' '
                        ) palabra

                        WHERE
                            LTRIM(RTRIM(palabra.value)) <> ''

                            AND CONCAT(
                                    ' ',
                                    LTRIM(RTRIM(j.nombre)),
                                    ' ',
                                    LTRIM(RTRIM(j.apellido)),
                                    ' '
                                )
                                COLLATE Modern_Spanish_CI_AI

                                NOT LIKE

                                (
                                    '% '
                                    + LTRIM(RTRIM(palabra.value))
                                    + ' %'
                                ) COLLATE Modern_Spanish_CI_AI
                    );

                --------------------------------------------------------
                -- 10.6. VALIDAR COINCIDENCIAS
                --------------------------------------------------------

                IF @cantidad_coincidencias = 0
                BEGIN

                    INSERT INTO #Errores
                    (
                        nombre_jugador,
                        motivo
                    )
                    VALUES
                    (
                        @nombre_jugador,
                        'No se encontró el jugador en la selección correspondiente.'
                    );

                    SET @total_errores += 1;

                END

                ELSE IF @cantidad_coincidencias > 1
                BEGIN

                    INSERT INTO #Errores
                    (
                        nombre_jugador,
                        motivo
                    )
                    VALUES
                    (
                        @nombre_jugador,
                        'Se encontraron varios jugadores con ese nombre. No se puede determinar una coincidencia única.'
                    );

                    SET @total_errores += 1;

                END

                ELSE
                BEGIN

                    ----------------------------------------------------
                    -- 10.7. BUSCAR RELACIÓN EXISTENTE
                    ----------------------------------------------------

                    SELECT
                        @cantidad_existente = COUNT(*),
                        @titular_actual =
                            CONVERT(BIT, MAX(CONVERT(INT, es_titular)))

                    FROM dbo.Formacion_Jugador

                    WHERE
                        id_formacion = @id_formacion
                        AND id_jugador = @id_jugador;

                    ----------------------------------------------------
                    -- 10.8. CONTROLAR DUPLICADOS PREEXISTENTES
                    ----------------------------------------------------

                    IF @cantidad_existente > 1
                    BEGIN

                        INSERT INTO #Errores
                        (
                            nombre_jugador,
                            motivo
                        )
                        VALUES
                        (
                            @nombre_jugador,
                            'La relación entre el jugador y la formación ya se encuentra duplicada. No se puede realizar el UPSERT.'
                        );

                        SET @total_errores += 1;

                    END

                    ----------------------------------------------------
                    -- 10.9. ACTUALIZAR SI YA EXISTE
                    ----------------------------------------------------

                    ELSE IF @cantidad_existente = 1
                    BEGIN

                        -- Contar titulares excluyendo al jugador
                        -- que se está actualizando.

                        SELECT
                            @titulares_actuales = COUNT(*)
                        FROM dbo.Formacion_Jugador
                        WHERE
                            id_formacion = @id_formacion
                            AND id_jugador <> @id_jugador
                            AND es_titular = 1;

                        -- Validar que no se superen los 11 titulares.

                        IF @es_titular = 1
                           AND ISNULL(@titular_actual, 0) = 0
                           AND @titulares_actuales >= 11
                        BEGIN

                            INSERT INTO #Errores
                            (
                                nombre_jugador,
                                motivo
                            )
                            VALUES
                            (
                                @nombre_jugador,
                                'No se puede actualizar el jugador como titular porque la formación ya tiene 11 titulares.'
                            );

                            SET @total_errores += 1;

                        END

                        ELSE
                        BEGIN

                            BEGIN TRY

                                UPDATE dbo.Formacion_Jugador
                                SET
                                    posicion_en_cancha = @posicion_en_cancha,
                                    dorsal_en_cancha = @dorsal_en_cancha,
                                    es_titular = @es_titular
                                WHERE
                                    id_formacion = @id_formacion
                                    AND id_jugador = @id_jugador;

                                SET @filas_afectadas = @@ROWCOUNT;

                                IF @filas_afectadas = 1
                                BEGIN
                                    SET @total_actualizados += 1;
                                END
                                ELSE
                                BEGIN

                                    INSERT INTO #Errores
                                    (
                                        nombre_jugador,
                                        motivo
                                    )
                                    VALUES
                                    (
                                        @nombre_jugador,
                                        'No se pudo actualizar la relación del jugador con la formación.'
                                    );

                                    SET @total_errores += 1;

                                END;

                            END TRY
                            BEGIN CATCH

                                INSERT INTO #Errores
                                (
                                    nombre_jugador,
                                    motivo
                                )
                                VALUES
                                (
                                    @nombre_jugador,
                                    ERROR_MESSAGE()
                                );

                                SET @total_errores += 1;

                            END CATCH;

                        END;

                    END

                    ----------------------------------------------------
                    -- 10.10. INSERTAR SI NO EXISTE
                    ----------------------------------------------------

                    ELSE
                    BEGIN

                        -- Obtener cantidad de convocados y titulares.

                        SELECT
                            @total_actuales = COUNT(*),

                            @titulares_actuales =
                                COUNT(
                                    CASE
                                        WHEN es_titular = 1
                                        THEN 1
                                    END
                                )

                        FROM dbo.Formacion_Jugador

                        WHERE id_formacion = @id_formacion;

                        ------------------------------------------------
                        -- VALIDAR MÁXIMO 26 CONVOCADOS
                        ------------------------------------------------

                        IF @total_actuales >= 26
                        BEGIN

                            INSERT INTO #Errores
                            (
                                nombre_jugador,
                                motivo
                            )
                            VALUES
                            (
                                @nombre_jugador,
                                'No se puede insertar el jugador porque la formación ya tiene 26 convocados.'
                            );

                            SET @total_errores += 1;

                        END

                        ------------------------------------------------
                        -- VALIDAR MÁXIMO 11 TITULARES
                        ------------------------------------------------

                        ELSE IF @es_titular = 1
                            AND @titulares_actuales >= 11
                        BEGIN

                            INSERT INTO #Errores
                            (
                                nombre_jugador,
                                motivo
                            )
                            VALUES
                            (
                                @nombre_jugador,
                                'No se puede insertar el jugador como titular porque la formación ya tiene 11 titulares.'
                            );

                            SET @total_errores += 1;

                        END

                        ------------------------------------------------
                        -- EJECUTAR ALTA MEDIANTE ABM
                        ------------------------------------------------

                        ELSE
                        BEGIN

                            BEGIN TRY

                                EXEC abm.FormacionJugador_Alta
                                    @id_formacion = @id_formacion,
                                    @id_jugador = @id_jugador,
                                    @posicion_en_cancha = @posicion_en_cancha,
                                    @dorsal_en_cancha = @dorsal_en_cancha,
                                    @es_titular = @es_titular;

                                SET @total_insertados += 1;

                            END TRY
                            BEGIN CATCH

                                INSERT INTO #Errores
                                (
                                    nombre_jugador,
                                    motivo
                                )
                                VALUES
                                (
                                    @nombre_jugador,
                                    ERROR_MESSAGE()
                                );

                                SET @total_errores += 1;

                            END CATCH;

                        END;

                    END;

                END;

            END;

            FETCH NEXT FROM cursor_jugadores
            INTO
                @id_registro,
                @id_partido,
                @id_seleccion,
                @id_formacion,
                @nombre_jugador,
                @dorsal_en_cancha,
                @es_titular,
                @posicion_en_cancha;

        END;

        CLOSE cursor_jugadores;
        DEALLOCATE cursor_jugadores;

        ----------------------------------------------------------------
        -- 11. RESUMEN DE IMPORTACIÓN
        ----------------------------------------------------------------

        SELECT
            @total_procesados AS total_jugadores_procesados,
            @total_insertados AS total_jugadores_insertados,
            @total_actualizados AS total_jugadores_actualizados,
            @total_errores AS total_errores;

        ----------------------------------------------------------------
        -- 12. DETALLE DE ERRORES
        ----------------------------------------------------------------

        SELECT
            id_error,
            nombre_jugador,
            motivo
        FROM #Errores
        ORDER BY id_error;

    END TRY

    BEGIN CATCH

        IF CURSOR_STATUS('local', 'cursor_jugadores') >= 0
            CLOSE cursor_jugadores;

        IF CURSOR_STATUS('local', 'cursor_jugadores') > -3
            DEALLOCATE cursor_jugadores;

        DECLARE @mensaje NVARCHAR(MAX);

        SET @mensaje = ERROR_MESSAGE();

        RAISERROR(
            'Error durante la importación de formaciones: %s',
            16,
            1,
            @mensaje
        );

    END CATCH;

END;
GO
