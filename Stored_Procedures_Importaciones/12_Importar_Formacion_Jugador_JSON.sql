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
    -- 1. LECTURA Y CONVERSIÓN DEL ARCHIVO JSON
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

    BEGIN TRY  
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
                REPLACE(REPLACE(horario_utc, 'T', ' '), 'Z', ''),
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
        -- 3. RESOLVER SELECCIONES Y PARTIDOS
        ----------------------------------------------------------------
        UPDATE pj
        SET
            id_seleccion_1 = s1.id_seleccion,
            id_seleccion_2 = s2.id_seleccion
        FROM #PartidosJSON pj
        LEFT JOIN dbo.Seleccion s1
            ON s1.pais = CASE WHEN LTRIM(RTRIM(pj.seleccion_1_nombre)) = 'Korea Republic' THEN 'South Korea' ELSE LTRIM(RTRIM(pj.seleccion_1_nombre)) END
        LEFT JOIN dbo.Seleccion s2
            ON s2.pais = CASE WHEN LTRIM(RTRIM(pj.seleccion_2_nombre)) = 'Korea Republic' THEN 'South Korea' ELSE LTRIM(RTRIM(pj.seleccion_2_nombre)) END;

        UPDATE pj
        SET id_partido = coincidencias.id_partido
        FROM #PartidosJSON pj
        OUTER APPLY
        (
            SELECT MIN(p.id_partido) AS id_partido, COUNT(*) AS cantidad
            FROM dbo.Partido p
            WHERE p.fecha = pj.fecha
              AND p.horario_UTC = pj.horario_utc
              AND (
                    (p.id_seleccion_1 = pj.id_seleccion_1 AND p.id_seleccion_2 = pj.id_seleccion_2)
                    OR
                    (p.id_seleccion_1 = pj.id_seleccion_2 AND p.id_seleccion_2 = pj.id_seleccion_1)
                  )
            HAVING COUNT(*) = 1
        ) coincidencias;

        ----------------------------------------------------------------
        -- 4. TABLA TEMPORAL DE JUGADORES EXTRAÍDOS DEL JSON
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

        -- Carga de Selección 1
        INSERT INTO #JugadoresJSON (id_partido, id_seleccion, nombre_jugador, dorsal_en_cancha, es_titular, posicion_en_cancha)
        SELECT pj.id_partido, pj.id_seleccion_1, LTRIM(RTRIM(j.nombre_jugador)), j.dorsal_en_cancha, j.es_titular, j.posicion_en_cancha
        FROM #PartidosJSON pj
        CROSS APPLY OPENJSON(ISNULL(pj.jugadores_seleccion_1, '[]'))
        WITH (
            nombre_jugador NVARCHAR(150) '$.nombre_jugador',
            dorsal_en_cancha TINYINT '$.dorsal_en_cancha',
            es_titular BIT '$.es_titular',
            posicion_en_cancha VARCHAR(40) '$.posicion_en_cancha'
        ) j;

        -- Carga de Selección 2
        INSERT INTO #JugadoresJSON (id_partido, id_seleccion, nombre_jugador, dorsal_en_cancha, es_titular, posicion_en_cancha)
        SELECT pj.id_partido, pj.id_seleccion_2, LTRIM(RTRIM(j.nombre_jugador)), j.dorsal_en_cancha, j.es_titular, j.posicion_en_cancha
        FROM #PartidosJSON pj
        CROSS APPLY OPENJSON(ISNULL(pj.jugadores_seleccion_2, '[]'))
        WITH (
            nombre_jugador NVARCHAR(150) '$.nombre_jugador',
            dorsal_en_cancha TINYINT '$.dorsal_en_cancha',
            es_titular BIT '$.es_titular',
            posicion_en_cancha VARCHAR(40) '$.posicion_en_cancha'
        ) j;

        -- Resolver ID de Formación
        UPDATE j
        SET id_formacion = f.id_formacion
        FROM #JugadoresJSON j
        INNER JOIN dbo.Formacion f
            ON f.id_partido = j.id_partido
           AND f.id_seleccion = j.id_seleccion;

        ----------------------------------------------------------------
        -- 5. TABLA TEMPORAL DE ALIAS
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
        ('EDERSON SILVA','Éderson José DOS SANTOS LOURENÇO DA SILVA'),
        ('GAVI', 'Pablo PAEZ GAVIRA'),
        ('RODRI', 'Rodrigo HERNÁNDEZ CASCANTE'),
        ('PEDRI', 'Pedro GONZÁLEZ LÓPEZ'),
        ('Alex GRIMALDO', 'Alejandro GRIMALDO GARCÍA'),
        ('Alex BAENA', 'Alejandro BAENA RODRÍGUEZ'),
        ('Dani OLMO', 'Daniel OLMO CARVAJAL'),
        ('Nico WILLIAMS', 'Nicholas WILLIAMS ARTHUER'),
        ('Alireza BEIRANVAND', 'Ali Reza SAFARBEIRANVAND'),
        ('Milad MOHAMMADI', 'Milad MOHAMMADIKESHMARZI'),
        ('Ramin REZAEIAN', 'Ramin REZAEIANSEMESKANDI'),
        ('Payam NIAZMAND', 'Seyedpayam NIAZMAND'),
        ('Ehsan HAJISAFI', 'Ehsan HAJI SAFI'),
        ('Hossein KANANI', 'Mohammadhossein KANANI ZADEGAN'),
        ('Dayot UPAMECANO', 'Dayotchanculle Oswald UPAMECANO'),
        ('Manu KONE', 'Kouadio Emmanuel Boris KONE'),
        ('Ngolo KANTE', 'N''golo KANTE'),
        ('MERCHAS DOSKI', 'Merchas Ghazi Salih SALIH'),
        ('AMIR ALAMMARI', 'Amir Fouad Aboud AL-AMMARI'),
        ('ALI ALHAMADI', 'Ali Ibrahim Karim ALZUBAIDI'),
        ('FRANS PUTROS', 'Frans Dhia Jirjis HADDAD'),
        ('AHMED QASEM', 'Ahmed Ihab Ahmed AHMED'),
        ('MARKO FARJI', 'Marko Jabbar Hussein HUSSEIN'),
        ('Nico GONZALEZ', 'Nicolas Ivan GONZALEZ'),
        ('Nico PAZ', 'Nicolas PAZ MARTÍNEZ'),
        ('VITINHA', 'Vitor MACHADO FERREIRA'),
        ('SAMU COSTA', 'Samuel DE ALMEIDA COSTA'),
        ('Nico OREILLY', 'Nico O''REILLY'),
        ('Noni MADUEKE', 'Chukwunonso Azuka Tristan MADUEKE'),
        ('Dan BURN', 'Daniel Johnson BURN'),
        ('Ollie WATKINS', 'Oliver George Arthur WATKINS'),
        ('Kamaldeen SULEMANA', 'Kamal Deen SULEMANA'),
        ('Umar ESHMURODOV', 'Umarbek ESHMURODOV'),
        ('Ali ABDI', 'Ali ELABDI'),
        ('Mouhib CHAMAKH', 'Abdelmouhib CHAMAKH'),
        ('Mohamed HADJ MAHMOUD', 'Mohamed BELHADJ MAHMOUD'),
        ('Maxi ARAUJO', 'Maximiliano Javier ARAÚJO VILCHES'),
        ('Max CROCOMBE', 'Maxime Teremoana CROCOMBE'),
        ('Tim PAYNE ', 'Timothy John PAYNE'),
        ('Chris WOOD', 'Christopher Grant WOOD'),
        ('Alex PAULSEN', 'Alexander Noah PAULSEN'),
        ('Tommy SMITH', 'Thomas Jefferson SMITH'),
        ('Ben OLD', 'Benjamin Craig OLD'),
        ('Ben WAINE', 'Benjamin Peter WAINE'),
        ('Thelo AASGAARD', 'Thelonious Gerard AASGAARD'),
        ('NOOR ALRAWABDEH', 'Noor Al-Deen Mahmoud Ali AL RAWABDEH'),
        ('MOHANNAD ABUTAHA', 'Mohannad Mahmoud Saleh ABU TAHA'),
        ('NIZAR ALRASHDAN', 'Nizar Mahmoud Ahmed AL-RASHDAN'),
        ('MOUSA ALTAMARI', 'Mousa Mohammad Mousa SULEIMAN'),
        ('NOUR BANIATEYAH', 'Noureddin Zaid Khaleel BANI ATEYAH'),
        ('SAED ALROSAN', 'Sa''ed Ahmad Salameh ALROSAN'),
        ('IBRAHIM SADEH', 'Ibrahim Mohammad Sami SA''DEH'),
        ('MOHAMMAD ABUZRAIQ', 'Mohammad Faisal Yousef ABU ZRAIQ'),
        ('Cucho HERNANDEZ', 'Juan Camilo HERNANDEZ SUAREZ'),
        ('VOZINHA', 'Josimar José ÉVORA DIAS'),
        ('DINEY BORGES', 'Edilson Alberto MONTEIRO SANCHES BORGES'),
        ('PICO LOPES', 'Roberto Carlos LOPES'),
        ('CJ DOS SANTOS', 'Carlos Joaquim ANTUNES DOS SANTOS'),
        ('STOPIRA', 'Ianique DOS SANTOS TAVARES'),
        ('YANNICK SEMEDO', 'Jair SEMEDO MONTEIRO'),
        ('AHMED FATOUH', 'Ahmed Mohamed Aboelfetouh MOHAMED'),
        ('TREZEGUET', 'Mahmoud Ahmed Ibrahim HASSAN'),
        ('NABIL DONGA', 'Nabil Emad Aly Elmahdy ALY'),
        ('Aaron WAN-BISSAKA', 'Wan BISSAKA'),
        ('Ngalayel MUKAU', 'Ngal’ayel MUKAU'),
        ('NEYMAR JR', 'Neymar DA SILVA SANTOS JÚNIOR'),
        ('HOSSAM ABDELMAGUID', 'Hossam Abdelmegeed Abdelsalam ABDELMEGEED');

        ----------------------------------------------------------------
        -- 6. TABLA TEMPORAL DE ERRORES DE IMPORTACIÓN
        ----------------------------------------------------------------
        CREATE TABLE #Errores
        (
            id_error INT IDENTITY(1,1) PRIMARY KEY,
            nombre_jugador NVARCHAR(150),
            motivo NVARCHAR(MAX)
        );

        ----------------------------------------------------------------
        -- 7. PROCESAMIENTO DIRECTO CON VALIDACIONES
        ----------------------------------------------------------------
        DECLARE
            @i INT = 1,
            @max_id_registro INT,
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
            @existe_relacion INT,
            @titular_actual BIT;

        SELECT @max_id_registro = MAX(id_registro) FROM #JugadoresJSON;

        WHILE @i <= @max_id_registro
        BEGIN
            SELECT
                @id_partido = id_partido,
                @id_seleccion = id_seleccion,
                @id_formacion = id_formacion,
                @nombre_jugador = nombre_jugador,
                @dorsal_en_cancha = dorsal_en_cancha,
                @es_titular = es_titular,
                @posicion_en_cancha = posicion_en_cancha
            FROM #JugadoresJSON
            WHERE id_registro = @i;

            IF @@ROWCOUNT > 0
            BEGIN
                SET @total_procesados += 1;
                SET @id_jugador = NULL;
                SET @cantidad_coincidencias = 0;
                SET @nombre_db_alias = NULL;

                --------------------------------------------------------
                -- VALIDACIONES ESTRUCTURALES DEL REGISTRO
                --------------------------------------------------------
                IF @id_partido IS NULL
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'No se pudo identificar el partido correspondiente.');
                    SET @total_errores += 1;
                END
                ELSE IF @id_seleccion IS NULL
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'No se pudo identificar la selección del jugador.');
                    SET @total_errores += 1;
                END
                ELSE IF @id_formacion IS NULL
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'No existe una formación registrada para esta selección en el partido.');
                    SET @total_errores += 1;
                END
                ELSE IF @nombre_jugador IS NULL OR LTRIM(RTRIM(@nombre_jugador)) = ''
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'El nombre del jugador está vacío.');
                    SET @total_errores += 1;
                END
                ELSE IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'El dorsal en cancha debe estar comprendido entre 1 y 99.');
                    SET @total_errores += 1;
                END
                ELSE IF @es_titular IS NULL
                BEGIN
                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'Debe indicar si el jugador es titular (campo es_titular no nulo).');
                    SET @total_errores += 1;
                END
                ELSE
                BEGIN
                    ----------------------------------------------------
                    -- RESOLUCIÓN DE JUGADOR (ALIAS -> EXACTO -> SOUNDEX)
                    ----------------------------------------------------

                    -- 1. Intentar por Tabla de Alias
                    SELECT @nombre_db_alias = nombre_db 
                    FROM #AliasJugadores 
                    WHERE nombre_json = @nombre_jugador;

                    IF @nombre_db_alias IS NOT NULL
                    BEGIN
                        SELECT
                            @cantidad_coincidencias = COUNT(*),
                            @id_jugador = MIN(j.id_jugador)
                        FROM dbo.Jugador j
                        WHERE j.id_seleccion = @id_seleccion
                          AND NOT EXISTS
                          (
                              SELECT 1
                              FROM STRING_SPLIT(@nombre_db_alias, ' ') palabra
                              WHERE LTRIM(RTRIM(palabra.value)) <> ''
                                AND CONCAT(' ', REPLACE(REPLACE(j.nombre, N'Ñ', N'N'), N'ñ', N'n'), ' ', REPLACE(REPLACE(j.apellido, N'Ñ', N'N'), N'ñ', N'n'), ' ') COLLATE Modern_Spanish_CI_AI
                                    NOT LIKE ('% ' + REPLACE(REPLACE(LTRIM(RTRIM(palabra.value)), N'Ñ', N'N'), N'ñ', N'n') + ' %') COLLATE Modern_Spanish_CI_AI
                          );
                    END

                    -- 2. Búsqueda por Palabras Exactas
                    IF @cantidad_coincidencias = 0 OR @id_jugador IS NULL
                    BEGIN
                        SELECT
                            @cantidad_coincidencias = COUNT(*),
                            @id_jugador = MIN(j.id_jugador)
                        FROM dbo.Jugador j
                        WHERE j.id_seleccion = @id_seleccion
                          AND NOT EXISTS
                          (
                              SELECT 1
                              FROM STRING_SPLIT(@nombre_jugador, ' ') palabra
                              WHERE LTRIM(RTRIM(palabra.value)) <> ''
                                AND CONCAT(' ', REPLACE(REPLACE(j.nombre, N'Ñ', N'N'), N'ñ', N'n'), ' ', REPLACE(REPLACE(j.apellido, N'Ñ', N'N'), N'ñ', N'n'), ' ') COLLATE Modern_Spanish_CI_AI
                                    NOT LIKE ('% ' + REPLACE(REPLACE(LTRIM(RTRIM(palabra.value)), N'Ñ', N'N'), N'ñ', N'n') + ' %') COLLATE Modern_Spanish_CI_AI
                          );
                    END

                    -- 3. Fallback: Búsqueda por Soundex
                    IF @cantidad_coincidencias = 0 OR @id_jugador IS NULL
                    BEGIN
                        SELECT
                            @cantidad_coincidencias = COUNT(*),
                            @id_jugador = MIN(j.id_jugador)
                        FROM dbo.Jugador j
                        WHERE j.id_seleccion = @id_seleccion
                          AND NOT EXISTS
                          (
                              SELECT 1
                              FROM STRING_SPLIT(@nombre_jugador, ' ') palabra_json
                              WHERE LTRIM(RTRIM(palabra_json.value)) <> ''
                                AND NOT EXISTS
                                (
                                    SELECT 1
                                    FROM STRING_SPLIT(CONCAT(j.nombre, ' ', j.apellido), ' ') palabra_db
                                    WHERE LTRIM(RTRIM(palabra_db.value)) <> ''
                                      AND SOUNDEX(REPLACE(REPLACE(LTRIM(RTRIM(palabra_json.value)), N'Ñ', N'N'), N'ñ', N'n')) = 
                                        SOUNDEX(REPLACE(REPLACE(LTRIM(RTRIM(palabra_db.value)), N'Ñ', N'N'), N'ñ', N'n'))
                                )
                          );
                    END

                    ----------------------------------------------------
                    -- EVALUACIÓN DE COINCIDENCIAS Y VALIDACIONES DE ABM
                    ----------------------------------------------------
                    IF @cantidad_coincidencias = 0 OR @id_jugador IS NULL
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'No se encontró el jugador en la selección correspondiente.');
                        SET @total_errores += 1;
                    END
                    ELSE IF @cantidad_coincidencias > 1
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'Se encontraron varios jugadores coincidentes. No se puede determinar una coincidencia única.');
                        SET @total_errores += 1;
                    END
                    -- Validar que el jugador no esté dado de baja de la convocatoria
                    ELSE IF EXISTS (SELECT 1 FROM dbo.Reemplazo WHERE id_jugador_baja = @id_jugador)
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'El jugador fue dado de baja de la convocatoria (Reemplazo).');
                        SET @total_errores += 1;
                    END
                    -- Validar que el jugador no esté expulsado en este partido
                    ELSE IF EXISTS (
                        SELECT 1 
                        FROM dbo.Incidencia 
                        WHERE id_partido = @id_partido 
                          AND id_jugador = @id_jugador 
                          AND tipo = 'EXPULSION'
                    )
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'El jugador se encuentra expulsado en este partido y no puede ser incluido en la formación.');
                        SET @total_errores += 1;
                    END
                    -- Validar dorsal duplicado en la misma formación por otro jugador
                    ELSE IF EXISTS (
                        SELECT 1 
                        FROM dbo.Formacion_Jugador 
                        WHERE id_formacion = @id_formacion 
                          AND dorsal_en_cancha = @dorsal_en_cancha 
                          AND id_jugador <> @id_jugador
                    )
                    BEGIN
                        INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'El dorsal ' + CAST(@dorsal_en_cancha AS VARCHAR) + ' ya está asignado a otro jugador en esta formación.');
                        SET @total_errores += 1;
                    END
                    ELSE
                    BEGIN
                        ------------------------------------------------
                        -- INSERCIÓN O MODIFICACIÓN DIRECTA (UPSERT)
                        ------------------------------------------------
                        SELECT 
                            @existe_relacion = COUNT(*),
                            @titular_actual = MAX(CONVERT(INT, es_titular))
                        FROM dbo.Formacion_Jugador
                        WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

                        -- CASO 1: MODIFICACIÓN (El jugador ya está en la formación)
                        IF @existe_relacion > 0
                        BEGIN
                            -- Validar si pasa a ser titular y ya hay 11 titulares
                            IF @es_titular = 1 AND ISNULL(@titular_actual, 0) = 0 AND (
                                SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion AND es_titular = 1 AND id_jugador <> @id_jugador
                            ) >= 11
                            BEGIN
                                INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'No se puede cambiar a titular: la formación ya posee 11 titulares.');
                                SET @total_errores += 1;
                            END
                            ELSE
                            BEGIN
                                BEGIN TRY
                                    UPDATE dbo.Formacion_Jugador
                                    SET posicion_en_cancha = @posicion_en_cancha,
                                        dorsal_en_cancha   = @dorsal_en_cancha,
                                        es_titular         = @es_titular
                                    WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

                                    SET @total_actualizados += 1;
                                END TRY
                                BEGIN CATCH
                                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, ERROR_MESSAGE());
                                    SET @total_errores += 1;
                                END CATCH;
                            END;
                        END
                        -- CASO 2: ALTA DIRECTA
                        ELSE
                        BEGIN
                            -- Validar total máximo de convocados (26)
                            IF (SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion) >= 26
                            BEGIN
                                INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'La formación ya alcanzó el tope de 26 jugadores convocados.');
                                SET @total_errores += 1;
                            END
                            -- Validar total máximo de titulares (11)
                            ELSE IF @es_titular = 1 AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion AND es_titular = 1) >= 11
                            BEGIN
                                INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, 'No se puede agregar como titular: la formación ya posee 11 titulares.');
                                SET @total_errores += 1;
                            END
                            ELSE
                            BEGIN
                                BEGIN TRY
                                    INSERT INTO dbo.Formacion_Jugador
                                        (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
                                    VALUES
                                        (@id_formacion, @id_jugador, @posicion_en_cancha, @dorsal_en_cancha, @es_titular);

                                    SET @total_insertados += 1;
                                END TRY
                                BEGIN CATCH
                                    INSERT INTO #Errores (nombre_jugador, motivo) VALUES (@nombre_jugador, ERROR_MESSAGE());
                                    SET @total_errores += 1;
                                END CATCH;
                            END;
                        END;
                    END;
                END;
            END;

            SET @i += 1;
        END;

        ----------------------------------------------------------------
        -- 8. RESUMEN Y DETALLE DE ERRORES
        ----------------------------------------------------------------
        SELECT
            @total_procesados   AS total_jugadores_procesados,
            @total_insertados   AS total_jugadores_insertados,
            @total_actualizados AS total_jugadores_actualizados,
            @total_errores      AS total_errores;

        SELECT id_error, nombre_jugador, motivo
        FROM #Errores
        ORDER BY id_error;

    END TRY
    BEGIN CATCH
        DECLARE @mensaje NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR('Error en el proceso de importación directa: %s', 16, 1, @mensaje);
    END CATCH;
END;
GO