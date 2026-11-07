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
    DECLARE @json_bytes VARBINARY(MAX);

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
        THROW 53002, @mensajeCarga, 1;
    END CATCH;

    IF @json_bytes IS NULL OR DATALENGTH(@json_bytes) = 0
        THROW 53003, N'El archivo JSON está vacío o no se pudo leer.', 1;

    BEGIN TRY
        SET @json = CAST(CAST(@json_bytes AS XML) AS NVARCHAR(MAX));
    END TRY
    BEGIN CATCH
        DECLARE @mensajeUtf8 NVARCHAR(2048) =
            N'El archivo no está codificado en UTF-8 válido. Detalle: ' + ERROR_MESSAGE();
        THROW 53005, @mensajeUtf8, 1;
    END CATCH;

    ----------------------------------------------------------------
    -- 2. TABLA TEMPORAL DE PARTIDOS DEL JSON
    ----------------------------------------------------------------
    
        BEGIN TRY  

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
            seleccion_1_nombre NVARCHAR(100) '$.seleccion_1_nombre',
            seleccion_2_nombre NVARCHAR(100) '$.seleccion_2_nombre',
            jugadores_seleccion_1 NVARCHAR(MAX) '$.jugadores_seleccion_1' AS JSON,
            jugadores_seleccion_2 NVARCHAR(MAX) '$.jugadores_seleccion_2' AS JSON
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
                    WHEN LTRIM(RTRIM(pj.seleccion_1_nombre)) = 'Korea Republic' THEN 'South Korea'
                    ELSE LTRIM(RTRIM(pj.seleccion_1_nombre))
                END

        LEFT JOIN dbo.Seleccion s2
            ON s2.pais =
                CASE
                    WHEN LTRIM(RTRIM(pj.seleccion_2_nombre)) = 'Korea Republic' THEN 'South Korea'
                    ELSE LTRIM(RTRIM(pj.seleccion_2_nombre))
                END;

        ----------------------------------------------------------------
        -- 4. RESOLVER PARTIDOS
        ----------------------------------------------------------------

        UPDATE pj
        SET id_partido =
            CASE
                WHEN coincidencias.cantidad = 1 THEN coincidencias.id_partido
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
                    (p.id_seleccion_1 = pj.id_seleccion_1 AND p.id_seleccion_2 = pj.id_seleccion_2)
                    OR
                    (p.id_seleccion_1 = pj.id_seleccion_2 AND p.id_seleccion_2 = pj.id_seleccion_1)
                )
        ) coincidencias;

         -- DEBUG

        SELECT * FROM #PartidosJSON;



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
        CROSS APPLY OPENJSON(ISNULL(pj.jugadores_seleccion_1, '[]'))
        WITH
        (
            nombre_jugador NVARCHAR(150) '$.nombre_jugador',
            dorsal_en_cancha TINYINT '$.dorsal_en_cancha',
            es_titular BIT '$.es_titular',
            posicion_en_cancha VARCHAR(40) '$.posicion_en_cancha'
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
        CROSS APPLY OPENJSON(ISNULL(pj.jugadores_seleccion_2, '[]'))
        WITH
        (
            nombre_jugador NVARCHAR(150) '$.nombre_jugador',
            dorsal_en_cancha TINYINT '$.dorsal_en_cancha',
            es_titular BIT '$.es_titular',
            posicion_en_cancha VARCHAR(40) '$.posicion_en_cancha'
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

        -- DEBUG
        select * from #JugadoresJSON

        SELECT COUNT(*)
        FROM #JugadoresJSON

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
        -- 9.B TABLA TEMPORAL DE ALIAS DE JUGADORES
        ----------------------------------------------------------------
        CREATE TABLE #AliasJugadores
        (
            nombre_json NVARCHAR(150) PRIMARY KEY,
            nombre_db NVARCHAR(150)
        );

        INSERT INTO #AliasJugadores (nombre_json, nombre_db) VALUES
        ('Julian QUINONES', 'Julián Andrés QUIÑONES QUIÑONES'),
        ('LEE Jaesung', 'Lee Jae Sung'),
        ('SON Heungmin', 'Son Heung Min'),
        ('HWANG Heechan', 'Hwang Hee Chan'),
        ('Richie LARYEA', 'Richmond Mamah LARYEA'),
        ('Tani OLUWASEYI', 'Tanitoluwa Oluwatimilehin OLUWASEYI'),
        ('Sergino DEST', 'Sergiño DEST'),
        ('Chris RICHARDS', 'Christopher Jeffrey RICHARDS'), 
        ('Tim REAM', 'Timothy Michael REAM'),
        ('Alex FREEMAN', 'Alexander Michael FREEMAN'),
        ('Weston McKENNIE', 'Weston James Earl MC KENNIE'),
        ('Chris BRADY', 'Christopher Keith BRADY'),
        ('Max ARFSTEN', 'Maximilian Michael ARFSTEN'),
        ('Joe SCALLY', 'Joseph Michael SCALLY'),
        ('Alex ZENDEJAS', 'Alejandro ZENDEJAS SAAVEDRA'),
        ('ISSA LAYE', 'Gueye SEYDINAISSALAYE'), 
        ('SULTAN ALBRAKE', 'Sultan Al-Brake'),
        ('MARQUINHOS', 'Marcos AOAS CORREA'),
        ('ROGER IBANEZ', 'Roger Ibañez'),
        ('LUCAS PAQUETA', 'Lucas TOLENTINO COELHO DE LIMA'),
        ('RAPHINHA', 'Raphael DIAS BELLOLI'),
        ('EDERSON', 'Ederson SANTANA DE MORAES'),
        ('DANILO', 'Danilo Luiz DA SILVA'),
        ('LEO PEREIRA', 'Leonardo Pereira'),
        ('FABINHO', 'Fabio Henrique TAVARES'),
        ('Aiden ONEILL', 'Aiden O''Neill'),
        ('Jan Paul VAN HECKE', 'Jan-Paul VAN HECKE'),
        ('Gatito FERNANDEZ', 'Roberto Junior FERNANDEZ TORRES'),
        ('Azzedine OUNAHI', 'Azz-Eddine OUNAHI'),
        ('Andy ROBERTSON', 'Andrew Henry ROBERTSON'),
        ('Kenny McLEAN', 'Kenneth McLean'),
        ('Irfan Can KAHVECI', 'İrfan KAHVECİ'),
        ('Sontje HANSEN', 'Misjonne Juniffer Naigelino HANSEN'),
        ('Joel ORDONEZ', 'Joel Ordóñez'),
        ('Jayden Nelson', 'Jayden NELSON'),
        ('Miles ROBINSON', 'Miles Gordon ROBINSON'),
        ('Tyler ADAMS', 'Tyler Shaan ADAMS'),
        ('Mark McKENZIE', 'Mark Alexander McKENZIE'),
        ('EDERSON SILVA','Éderson José DOS SANTOS LOURENÇO DA SILVA');


        ----------------------------------------------------------------
        -- 10. PROCESAMIENTO INDIVIDUAL DE JUGADORES (SIN CURSOR, CON WHILE)
        ----------------------------------------------------------------

        DECLARE
            @i INT = 1,
            @max_id_registro INT,
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
            @nombre_db_alias NVARCHAR(150),
            @cantidad_existente INT,
            @titulares_actuales INT,
            @total_actuales INT,
            @titular_actual BIT,
            @filas_afectadas INT;

        -- Obtener el maximo id_registro para el bucle
        SELECT @max_id_registro = MAX(id_registro) FROM #JugadoresJSON;

        WHILE @i <= @max_id_registro
        BEGIN
            -- Obtener los datos de la fila actual
            SELECT
                @id_registro = id_registro,
                @id_partido = id_partido,
                @id_seleccion = id_seleccion,
                @id_formacion = id_formacion,
                @nombre_jugador = nombre_jugador,
                @dorsal_en_cancha = dorsal_en_cancha,
                @es_titular = es_titular,
                @posicion_en_cancha = posicion_en_cancha
            FROM #JugadoresJSON
            WHERE id_registro = @i;

            -- Si por alguna razon la fila no existe (por ejemplo, huecos en el IDENTITY), saltar
            IF @@ROWCOUNT > 0
            BEGIN
                SET @total_procesados += 1;
                SET @id_jugador = NULL;
                SET @cantidad_coincidencias = 0;
                SET @nombre_db_alias = NULL;
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
                    INSERT INTO #Errores (nombre_jugador, motivo)
                    VALUES (@nombre_jugador, 'No se pudo identificar el partido correspondiente.');
                    SET @total_errores += 1;
                END
                ------------------------------------------------------------
                -- 10.2. VALIDAR SELECCIÓN
                ------------------------------------------------------------
                ELSE IF @id_seleccion IS NULL
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo)
                    VALUES (@nombre_jugador, 'No se pudo identificar la selección del jugador.');
                    SET @total_errores += 1;
                END
                ------------------------------------------------------------
                -- 10.3. VALIDAR FORMACIÓN
                ------------------------------------------------------------
                ELSE IF @id_formacion IS NULL
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo)
                    VALUES (@nombre_jugador, 'No existe una formación para el partido y la selección.');
                    SET @total_errores += 1;
                END
                ------------------------------------------------------------
                -- 10.4. VALIDAR NOMBRE DEL JUGADOR
                ------------------------------------------------------------
                ELSE IF @nombre_jugador IS NULL OR LTRIM(RTRIM(@nombre_jugador)) = ''
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo)
                    VALUES (@nombre_jugador, 'El nombre del jugador está vacío o no fue informado.');
                    SET @total_errores += 1;
                END
                ELSE
                BEGIN
                    --------------------------------------------------------
                    -- 10.5.a VALIDAR SI EL JUGADOR ESTÁ EN LA TABLA DE ALIAS
                    --------------------------------------------------------
                    
                    SELECT @nombre_db_alias = nombre_db 
                    FROM #AliasJugadores 
                    WHERE nombre_json = @nombre_jugador;

                    IF @nombre_db_alias IS NOT NULL
                    BEGIN
                        -- Si hay alias, buscamos directamente por las palabras del nombre en la DB
                        SELECT
                            @cantidad_coincidencias = COUNT(*),
                            @id_jugador = MIN(j.id_jugador)
                        FROM dbo.Jugador j
                        WHERE
                            j.id_seleccion = @id_seleccion
                            AND NOT EXISTS
                            (
                                SELECT 1
                                FROM STRING_SPLIT(@nombre_db_alias, ' ') palabra
                                WHERE
                                    LTRIM(RTRIM(palabra.value)) <> ''
                                    AND CONCAT(' ', j.nombre, ' ', j.apellido, ' ') COLLATE Modern_Spanish_CI_AI
                                        NOT LIKE ('% ' + LTRIM(RTRIM(palabra.value)) + ' %') COLLATE Modern_Spanish_CI_AI
                            );
                    END
                    ELSE
                    BEGIN
                        ----------------------------------------------------
                        -- 10.5.b BÚSQUEDA NORMAL (Palabras Exactas)
                        ----------------------------------------------------
                        SELECT
                            @cantidad_coincidencias = COUNT(*),
                            @id_jugador = MIN(j.id_jugador)
                        FROM dbo.Jugador j
                        WHERE
                            j.id_seleccion = @id_seleccion
                            AND NOT EXISTS
                            (
                                SELECT 1
                                FROM STRING_SPLIT(@nombre_jugador, ' ') palabra
                                WHERE
                                    LTRIM(RTRIM(palabra.value)) <> ''
                                    AND CONCAT(' ', j.nombre, ' ', j.apellido, ' ') COLLATE Modern_Spanish_CI_AI
                                        NOT LIKE ('% ' + LTRIM(RTRIM(palabra.value)) + ' %') COLLATE Modern_Spanish_CI_AI
                            );

                        ----------------------------------------------------
                        -- 10.5.c BÚSQUEDA POR SOUNDEX (Fallback)
                        ----------------------------------------------------
                        IF @cantidad_coincidencias = 0
                        BEGIN
                            SELECT
                                @cantidad_coincidencias = COUNT(*),
                                @id_jugador = MIN(j.id_jugador)
                            FROM dbo.Jugador j
                            WHERE
                                j.id_seleccion = @id_seleccion
                                AND NOT EXISTS
                                (
                                    SELECT 1
                                    FROM STRING_SPLIT(@nombre_jugador, ' ') palabra_json
                                    WHERE
                                        LTRIM(RTRIM(palabra_json.value)) <> ''
                                        AND NOT EXISTS
                                        (
                                            SELECT 1
                                            FROM STRING_SPLIT(CONCAT(j.nombre, ' ', j.apellido), ' ') palabra_db
                                            WHERE
                                                LTRIM(RTRIM(palabra_db.value)) <> ''
                                                AND SOUNDEX(LTRIM(RTRIM(palabra_json.value))) = SOUNDEX(LTRIM(RTRIM(palabra_db.value)))
                                        )
                                );
                        END
                    END
                    
                    --------------------------------------------------------
                    -- 10.6. VALIDAR COINCIDENCIAS
                    --------------------------------------------------------
                    IF @cantidad_coincidencias = 0
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo)
                        VALUES (@nombre_jugador, 'No se encontró el jugador en la selección correspondiente.');
                        SET @total_errores += 1;
                    END
                    ELSE IF @cantidad_coincidencias > 1
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo)
                        VALUES (@nombre_jugador, 'Se encontraron varios jugadores con ese nombre. No se puede determinar una coincidencia única.');
                        SET @total_errores += 1;
                    END
                    ELSE
                    BEGIN
                        ----------------------------------------------------
                        -- 10.7. BUSCAR RELACIÓN EXISTENTE
                        ----------------------------------------------------
                        SELECT
                            @cantidad_existente = COUNT(*),
                            @titular_actual = CONVERT(BIT, MAX(CONVERT(INT, es_titular)))
                        FROM dbo.Formacion_Jugador
                        WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

                        ----------------------------------------------------
                        -- 10.8. CONTROLAR DUPLICADOS PREEXISTENTES
                        ----------------------------------------------------
                        IF @cantidad_existente > 1
                        BEGIN
                            INSERT INTO #Errores (nombre_jugador, motivo)
                            VALUES (@nombre_jugador, 'La relación entre el jugador y la formación ya se encuentra duplicada. No se puede realizar el UPSERT.');
                            SET @total_errores += 1;
                        END
                        ----------------------------------------------------
                        -- 10.9. ACTUALIZAR SI YA EXISTE
                        ----------------------------------------------------
                        ELSE IF @cantidad_existente = 1
                        BEGIN
                            SELECT @titulares_actuales = COUNT(*)
                            FROM dbo.Formacion_Jugador
                            WHERE id_formacion = @id_formacion AND id_jugador <> @id_jugador AND es_titular = 1;

                            IF @es_titular = 1 AND ISNULL(@titular_actual, 0) = 0 AND @titulares_actuales >= 11
                            BEGIN
                                INSERT INTO #Errores (nombre_jugador, motivo)
                                VALUES (@nombre_jugador, 'No se puede actualizar el jugador como titular porque la formación ya tiene 11 titulares.');
                                SET @total_errores += 1;
                            END
                            ELSE
                            BEGIN
                                BEGIN TRY
                                    UPDATE dbo.Formacion_Jugador
                                    SET posicion_en_cancha = @posicion_en_cancha,
                                        dorsal_en_cancha = @dorsal_en_cancha,
                                        es_titular = @es_titular
                                    WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

                                    SET @filas_afectadas = @@ROWCOUNT;

                                    IF @filas_afectadas = 1
                                        SET @total_actualizados += 1;
                                    ELSE
                                    BEGIN
                                        INSERT INTO #Errores (nombre_jugador, motivo)
                                        VALUES (@nombre_jugador, 'No se pudo actualizar la relación del jugador con la formación.');
                                        SET @total_errores += 1;
                                    END;
                                END TRY
                                BEGIN CATCH
                                    INSERT INTO #Errores (nombre_jugador, motivo)
                                    VALUES (@nombre_jugador, ERROR_MESSAGE());
                                    SET @total_errores += 1;
                                END CATCH;
                            END;
                        END
                        ----------------------------------------------------
                        -- 10.10. INSERTAR SI NO EXISTE
                        ----------------------------------------------------
                        ELSE
                        BEGIN
                            SELECT
                                @total_actuales = COUNT(*),
                                @titulares_actuales = COUNT(CASE WHEN es_titular = 1 THEN 1 END)
                            FROM dbo.Formacion_Jugador
                            WHERE id_formacion = @id_formacion;

                            IF @total_actuales >= 26
                            BEGIN
                                INSERT INTO #Errores (nombre_jugador, motivo)
                                VALUES (@nombre_jugador, 'No se puede insertar el jugador porque la formación ya tiene 26 convocados.');
                                SET @total_errores += 1;
                            END
                            ELSE IF @es_titular = 1 AND @titulares_actuales >= 11
                            BEGIN
                                INSERT INTO #Errores (nombre_jugador, motivo)
                                VALUES (@nombre_jugador, 'No se puede insertar el jugador como titular porque la formación ya tiene 11 titulares.');
                                SET @total_errores += 1;
                            END
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
                                    INSERT INTO #Errores (nombre_jugador, motivo)
                                    VALUES (@nombre_jugador, ERROR_MESSAGE());
                                    SET @total_errores += 1;
                                END CATCH;
                            END;
                        END;
                    END;
                END;
            END;

            -- Incrementar el contador
            SET @i += 1;
        END;

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
        SELECT id_error, nombre_jugador, motivo
        FROM #Errores
        ORDER BY id_error;
            END TRY
        BEGIN CATCH
            DECLARE @mensaje NVARCHAR(MAX);
            SET @mensaje = ERROR_MESSAGE();
            RAISERROR('Error durante la importación de formaciones: %s', 16, 1, @mensaje);
        END CATCH;
    END;
GO