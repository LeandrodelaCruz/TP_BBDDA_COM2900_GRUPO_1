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
    Importa formaciones (esquema táctico por selección y partido) desde
    un archivo JSON (formato FIFA 2026). El archivo se lee con
    OPENROWSET(BULK, SINGLE_BLOB) + conversión UTF-8 explícita,
    se normaliza en una tabla de staging y luego se aplica lógica UPSERT
    reutilizando los SP de la Entrega 5:
        - abm.Formacion_Alta
        - abm.Formacion_Modificacion

    Reglas:
    - El JSON no trae jugadores: sólo se carga la cabecera dbo.Formacion.
      NO se inserta en dbo.Formacion_Jugador.
    - El partido se resuelve por clave natural
      (fecha, horario_UTC, id_seleccion_1, id_seleccion_2), igual que
      en importacion.Importar_Partido_JSON. No se usa id_match_fifa.
    - Las selecciones se resuelven por nombre EXACTO en inglés contra
      dbo.Seleccion.pais, con fallback por alias FIFA (tabla variable).
    - El esquema táctico se valida con formato ^[0-9](-[0-9]){2,4}$
      (ej: 4-4-2, 4-1-2-3, 3-4-1-2) y longitud <= 10 (VARCHAR(10)).
    - Una fila inválida NO cancela el procesamiento de las demás:
      se registra en #Errores_Importacion y se continúa.
    - Si falla la resolución del partido (fecha, selecciones, partido
      inexistente), se registra UN error a nivel partido y se salta
      ese partido completo. Si falla el UPSERT de una selección, se
      registra el error con el nombre de esa selección y se continúa
      con la otra.

    Nota sobre SQL dinámico:
    Se usa únicamente para OPENROWSET porque SQL Server no permite
    parametrizar la ruta del archivo. El resto es T-SQL estático.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Formacion_JSON
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -------------------------------------------------------------------------
    -- 1. Validar el parámetro de entrada.
    -------------------------------------------------------------------------
    IF @archivo IS NULL OR LTRIM(RTRIM(@archivo)) = N''
        THROW 53001, N'Debe indicar la ruta del archivo JSON a importar.', 1;

    -------------------------------------------------------------------------
    -- 2. Staging: una fila por PARTIDO con ambas selecciones desdobladas.
    --    Los campos se declaran NVARCHAR amplios para poder detectar
    --    errores de formato/longitud antes de invocar los ABM.
    -------------------------------------------------------------------------
    CREATE TABLE #Formacion_Staging
    (
        numero_partido         NVARCHAR(50)   NULL,  -- id_match_fifa (sólo informativo)
        fecha                  NVARCHAR(50)   NULL,
        horario_UTC            NVARCHAR(50)   NULL,
        sel1_nombre            NVARCHAR(200)  NULL,
        sel1_esquema_tactico   NVARCHAR(50)   NULL,
        sel2_nombre            NVARCHAR(200)  NULL,
        sel2_esquema_tactico   NVARCHAR(50)   NULL
    );

    -------------------------------------------------------------------------
    -- 3. Tabla temporal para informar errores sin detener toda la carga.
    -------------------------------------------------------------------------
    CREATE TABLE #Errores_Importacion
    (
        numero_partido NVARCHAR(50)   NULL,
        seleccion      NVARCHAR(200)  NULL,
        numero_error   INT            NOT NULL,
        mensaje_error  NVARCHAR(2048) NOT NULL
    );

    -------------------------------------------------------------------------
    -- 3.b Alias FIFA → país real en dbo.Seleccion.pais.
    --      El JSON ya coincide en su mayoría; se mantiene el alias de
    --      Korea Republic por consistencia con Importar_Partido_JSON.
    --      El fallback por nombre EXACTO cubre al resto.
    -------------------------------------------------------------------------
    DECLARE @Seleccion_Alias TABLE
    (
        nombre_fifa  NVARCHAR(200) NOT NULL PRIMARY KEY,
        pais_real    NVARCHAR(200) NOT NULL
    );

    INSERT INTO @Seleccion_Alias (nombre_fifa, pais_real)
    VALUES
        (N'Korea Republic', N'South Korea')
        -- Agregar aquí nuevas discrepancias FIFA ↔ dbo.Seleccion.pais
        -- que el reporte de errores vaya detectando.
    ;

    -------------------------------------------------------------------------
    -- 4. Leer el archivo JSON con OPENROWSET + conversión UTF-8.
    --    OPENROWSET(BULK) exige un literal de ruta, por eso se usa
    --    SQL dinámico sólo en este bloque. Se lee como SINGLE_BLOB y
    --    se convierte a NVARCHAR(MAX) pasando por XML para respetar
    --    la codificación UTF-8 (tildes, ç, ü, etc.).
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

    -------------------------------------------------------------------------
    -- 5. Parsear el JSON a la tabla de staging.
    --    Se desdoblan seleccion_1 y seleccion_2 con CROSS APPLY + OPENJSON
    --    para obtener una fila por partido con ambas selecciones.
    -------------------------------------------------------------------------
    BEGIN TRY
        INSERT INTO #Formacion_Staging
        (
            numero_partido,
            fecha,
            horario_UTC,
            sel1_nombre,
            sel1_esquema_tactico,
            sel2_nombre,
            sel2_esquema_tactico
        )
        SELECT
            CONVERT(NVARCHAR(50),  j.id_match_fifa)     AS numero_partido,
            CONVERT(NVARCHAR(50),  j.fecha)             AS fecha,
            CONVERT(NVARCHAR(50),  j.horario_utc)       AS horario_UTC,
            CONVERT(NVARCHAR(200), s1.nombre)           AS sel1_nombre,
            CONVERT(NVARCHAR(50),  s1.esquema_tactico)  AS sel1_esquema_tactico,
            CONVERT(NVARCHAR(200), s2.nombre)           AS sel2_nombre,
            CONVERT(NVARCHAR(50),  s2.esquema_tactico)  AS sel2_esquema_tactico
        FROM OPENJSON(@json)
        WITH
        (
            id_match_fifa  NVARCHAR(50)  '$.id_match_fifa',
            fecha          NVARCHAR(50)  '$.fecha',
            horario_utc    NVARCHAR(50)  '$.horario_utc',
            seleccion_1    NVARCHAR(MAX) '$.seleccion_1' AS JSON,
            seleccion_2    NVARCHAR(MAX) '$.seleccion_2' AS JSON
        ) AS j
        CROSS APPLY OPENJSON(j.seleccion_1)
        WITH
        (
            nombre          NVARCHAR(200) '$.nombre',
            esquema_tactico NVARCHAR(50)  '$.esquema_tactico'
        ) AS s1
        CROSS APPLY OPENJSON(j.seleccion_2)
        WITH
        (
            nombre          NVARCHAR(200) '$.nombre',
            esquema_tactico NVARCHAR(50)  '$.esquema_tactico'
        ) AS s2;
    END TRY
    BEGIN CATCH
        DECLARE @mensajeJson NVARCHAR(2048) =
            N'El archivo no tiene el formato JSON esperado. Detalle: ' + ERROR_MESSAGE();
        THROW 53004, @mensajeJson, 1;
    END CATCH;

    -------------------------------------------------------------------------
    -- 6. Variables de procesamiento y contadores.
    -------------------------------------------------------------------------
    DECLARE
        @numero_partido      NVARCHAR(50),
        @fecha_str           NVARCHAR(50),
        @horario_UTC_str     NVARCHAR(50),
        @sel1_nombre         NVARCHAR(200),
        @sel1_esquema        NVARCHAR(50),
        @sel2_nombre         NVARCHAR(200),
        @sel2_esquema        NVARCHAR(50),

        @fecha               DATE,
        @horario_UTC         DATETIME2(0),
        @id_seleccion_1      INT,
        @id_seleccion_2      INT,
        @id_partido          INT,

        -- Variables reutilizadas en el loop interno de 2 iteraciones
        @iter                TINYINT,
        @sel_nombre          NVARCHAR(200),
        @sel_esquema         NVARCHAR(50),
        @sel_esquema_trim    VARCHAR(10),
        @id_seleccion        INT,
        @id_formacion        INT,

        @procesados          INT = 0,   -- partidos leídos del staging
        @insertados          INT = 0,   -- formaciones insertadas
        @actualizados        INT = 0,   -- formaciones modificadas
        @cantidad_errores    INT = 0;

    -------------------------------------------------------------------------
    -- 7. Tablas variables para capturar lo que devuelven los ABM.
    -------------------------------------------------------------------------
    DECLARE @ResultadoAlta TABLE
    (
        id_formacion_generado INT
    );

    DECLARE @ResultadoModificacion TABLE
    (
        id_formacion_modificada INT
    );

    -------------------------------------------------------------------------
    -- 8. recorrido con WHILE sobre el staging (una fila por partido).
    -------------------------------------------------------------------------
    -- Copia fija de las filas a procesar; conserva el orden del proceso original.
    SELECT ROW_NUMBER() OVER (ORDER BY TRY_CAST(numero_partido AS INT), fecha) AS orden_recorrido,
           numero_partido, fecha, horario_UTC, sel1_nombre, sel1_esquema_tactico, sel2_nombre, sel2_esquema_tactico
    INTO #Trabajo_Recorrido
    FROM #Formacion_Staging;
    CREATE UNIQUE CLUSTERED INDEX IX_Trabajo_Recorrido
        ON #Trabajo_Recorrido (orden_recorrido);

    DECLARE @fila_recorrido BIGINT;
    SELECT @fila_recorrido = MIN(orden_recorrido) FROM #Trabajo_Recorrido;


    WHILE @fila_recorrido IS NOT NULL
    BEGIN
        SELECT @numero_partido = numero_partido,
               @fecha_str = fecha,
               @horario_UTC_str = horario_UTC,
               @sel1_nombre = sel1_nombre,
               @sel1_esquema = sel1_esquema_tactico,
               @sel2_nombre = sel2_nombre,
               @sel2_esquema = sel2_esquema_tactico
        FROM #Trabajo_Recorrido WHERE orden_recorrido = @fila_recorrido;
        SET @procesados += 1;

        -- Reset de variables por iteración
        SET @fecha           = NULL;
        SET @horario_UTC     = NULL;
        SET @id_seleccion_1  = NULL;
        SET @id_seleccion_2  = NULL;
        SET @id_partido      = NULL;

        BEGIN TRY
            -----------------------------------------------------------------
            -- 8.1 Casteos seguros de fecha y horario UTC.
            -----------------------------------------------------------------
            SET @fecha = TRY_CAST(@fecha_str AS DATE);
            IF @fecha IS NULL
                THROW 53101, N'La fecha del partido es inválida o está vacía.', 1;

            SET @horario_UTC = TRY_CAST(@horario_UTC_str AS DATETIME2(0));
            IF @horario_UTC IS NULL
                THROW 53102, N'El horario UTC es inválido o está vacío.', 1;

            -----------------------------------------------------------------
            -- 8.2 Resolución de selecciones (local y visitante):
            --     1) alias FIFA → id_seleccion (tabla variable)
            --     2) fallback: nombre EXACTO en dbo.Seleccion.pais
            -----------------------------------------------------------------

            -- 8.2.1 Local
            SELECT @id_seleccion_1 = s.id_seleccion
            FROM @Seleccion_Alias a
            INNER JOIN dbo.Seleccion s ON s.pais = a.pais_real
            WHERE a.nombre_fifa = @sel1_nombre;

            IF @id_seleccion_1 IS NULL
                SELECT @id_seleccion_1 = id_seleccion
                FROM dbo.Seleccion
                WHERE pais = @sel1_nombre;

            IF @id_seleccion_1 IS NULL
                THROW 53107, N'No existe la selección local en dbo.Seleccion (pais no coincide).', 1;

            -- 8.2.2 Visitante
            SELECT @id_seleccion_2 = s.id_seleccion
            FROM @Seleccion_Alias a
            INNER JOIN dbo.Seleccion s ON s.pais = a.pais_real
            WHERE a.nombre_fifa = @sel2_nombre;

            IF @id_seleccion_2 IS NULL
                SELECT @id_seleccion_2 = id_seleccion
                FROM dbo.Seleccion
                WHERE pais = @sel2_nombre;

            IF @id_seleccion_2 IS NULL
                THROW 53108, N'No existe la selección visitante en dbo.Seleccion (pais no coincide).', 1;

            -----------------------------------------------------------------
            -- 8.3 Resolver el partido por clave natural.
            --     Debe existir previamente (cargado por
            --     importacion.Importar_Partido_JSON o por el ABM).
            -----------------------------------------------------------------
            SELECT @id_partido = id_partido
            FROM dbo.Partido
            WHERE fecha          = @fecha
              AND horario_UTC    = @horario_UTC
              AND id_seleccion_1 = @id_seleccion_1
              AND id_seleccion_2 = @id_seleccion_2;

            IF @id_partido IS NULL
                THROW 53106, N'No existe el partido en dbo.Partido para la clave natural indicada (fecha, horario_UTC, selecciones). Cargue primero los partidos.', 1;
        END TRY
        BEGIN CATCH
            -----------------------------------------------------------------
            -- Error a nivel PARTIDO. No se puede continuar con ninguna de
            -- las dos selecciones. Se registra y se salta al próximo.
            -----------------------------------------------------------------
            INSERT INTO #Errores_Importacion
            (
                numero_partido, seleccion, numero_error, mensaje_error
            )
            VALUES
            (
                @numero_partido,
                NULL,
                ERROR_NUMBER(),
                ERROR_MESSAGE()
            );

            SET @cantidad_errores += 1;

            SELECT @fila_recorrido = MIN(orden_recorrido)
            FROM #Trabajo_Recorrido WHERE orden_recorrido > @fila_recorrido;
            CONTINUE;
        END CATCH;

        ---------------------------------------------------------------------
        -- 8.4 Loop interno: 2 iteraciones, una por cada selección.
        --     Cada iteración tiene su propio TRY/CATCH: si falla la
        --     selección 1, la 2 sigue procesándose.
        ---------------------------------------------------------------------
        SET @iter = 1;

        WHILE @iter <= 2
        BEGIN
            IF @iter = 1
            BEGIN
                SET @sel_nombre   = @sel1_nombre;
                SET @sel_esquema  = @sel1_esquema;
                SET @id_seleccion = @id_seleccion_1;
            END
            ELSE
            BEGIN
                SET @sel_nombre   = @sel2_nombre;
                SET @sel_esquema  = @sel2_esquema;
                SET @id_seleccion = @id_seleccion_2;
            END;

            SET @sel_esquema_trim = NULL;
            SET @id_formacion     = NULL;

            BEGIN TRY
                -----------------------------------------------------------------
                -- 8.4.1 Validación del esquema táctico:
                --   - obligatorio
                --   - longitud <= 10 (VARCHAR(10))
                --   - formato ^[0-9](-[0-9]){2,4}$
                --     (ej: 4-4-2, 4-1-2-3, 3-4-1-2)
                -----------------------------------------------------------------
                SET @sel_esquema_trim = LTRIM(RTRIM(ISNULL(@sel_esquema, N'')));

                IF @sel_esquema_trim = N''
                    THROW 53201, N'El esquema táctico es obligatorio.', 1;

                IF LEN(@sel_esquema_trim) > 10
                    THROW 53202, N'El esquema táctico supera la longitud máxima permitida (VARCHAR(10)).', 1;

                IF @sel_esquema_trim NOT LIKE '[0-9]-[0-9]%-[0-9]%'
                   OR @sel_esquema_trim LIKE '%[^0-9-]%'
                   OR @sel_esquema_trim LIKE '%-%-%-%-%-%'
                   OR @sel_esquema_trim LIKE '%[0-9][0-9]%'
                    THROW 53203, N'El esquema táctico no respeta el formato esperado (ej: 4-4-2, 4-1-2-3, 3-4-1-2).', 1;

                -----------------------------------------------------------------
                -- 8.4.2 Buscar si ya existe la formación (partido, selección).
                -----------------------------------------------------------------
                SELECT @id_formacion = id_formacion
                FROM dbo.Formacion
                WHERE id_partido   = @id_partido
                  AND id_seleccion = @id_seleccion;

                IF @id_formacion IS NULL
                BEGIN
                    -----------------------------------------------------------------
                    -- 8.4.3 ALTA reutilizando abm.Formacion_Alta.
                    -----------------------------------------------------------------
                    DELETE FROM @ResultadoAlta;

                    INSERT INTO @ResultadoAlta (id_formacion_generado)
                    EXEC abm.Formacion_Alta
                        @id_partido      = @id_partido,
                        @id_seleccion    = @id_seleccion,
                        @esquema_tactico = @sel_esquema_trim;

                    SET @insertados += 1;
                END
                ELSE
                BEGIN
                    -----------------------------------------------------------------
                    -- 8.4.4 MODIFICACIÓN reutilizando abm.Formacion_Modificacion.
                    -----------------------------------------------------------------
                    DELETE FROM @ResultadoModificacion;

                    INSERT INTO @ResultadoModificacion (id_formacion_modificada)
                    EXEC abm.Formacion_Modificacion
                        @id_formacion    = @id_formacion,
                        @id_partido      = @id_partido,
                        @id_seleccion    = @id_seleccion,
                        @esquema_tactico = @sel_esquema_trim;

                    SET @actualizados += 1;
                END;
            END TRY
            BEGIN CATCH
                -----------------------------------------------------------------
                -- Error a nivel SELECCIÓN: se registra y se sigue con la
                -- otra selección del mismo partido.
                -----------------------------------------------------------------
                INSERT INTO #Errores_Importacion
                (
                    numero_partido, seleccion, numero_error, mensaje_error
                )
                VALUES
                (
                    @numero_partido,
                    @sel_nombre,
                    ERROR_NUMBER(),
                    ERROR_MESSAGE()
                );

                SET @cantidad_errores += 1;
            END CATCH;

            SET @iter += 1;
        END;

        SELECT @fila_recorrido = MIN(orden_recorrido)
            FROM #Trabajo_Recorrido WHERE orden_recorrido > @fila_recorrido;
    END;


    -------------------------------------------------------------------------
    -- 9. Resumen final.
    -------------------------------------------------------------------------
    SELECT
        @archivo          AS archivo,
        @procesados       AS partidos_procesados,
        @insertados       AS formaciones_insertadas,
        @actualizados     AS formaciones_actualizadas,
        @cantidad_errores AS registros_con_error;

    -------------------------------------------------------------------------
    -- 10. Detalle de errores. Si no hubo, devuelve cero filas.
    -------------------------------------------------------------------------
    SELECT
        numero_partido,
        seleccion,
        numero_error,
        mensaje_error
    FROM #Errores_Importacion
    ORDER BY TRY_CAST(numero_partido AS INT), seleccion;
END;
GO