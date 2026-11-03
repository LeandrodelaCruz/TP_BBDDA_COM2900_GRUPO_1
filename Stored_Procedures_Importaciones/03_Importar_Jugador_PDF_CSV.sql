/*
    IMPORTACIÓN DE JUGADORES - PDF FIFA 2026 -> CSV -> SQL SERVER

    Fuente original:
    SquadLists-Spanish.pdf (convocatorias oficiales FIFA 2026).

    El PDF se extrae mediante el script Python provisto y genera:
        jugadores_fifa_pdf.csv

    Actualización 02/11/2026: lectura UTF-8 con RAW y longitudes acotadas.

    Este SP:
    - recibe la ruta del CSV como parámetro;
    - carga el archivo a una tabla temporal de staging;
    - transforma fecha y código de posición en T-SQL;
    - resuelve la FK contra dbo.Seleccion;
    - hace UPSERT reutilizando los ABM de la Entrega 5;
    - continúa procesando si una fila falla;
    - informa resumen y detalle de errores.

    SQL dinámico:
    Se usa únicamente para parametrizar la ruta de BULK INSERT.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Jugador_PDF_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@archivo)), N'') IS NULL
        THROW 51300, N'Debe indicar la ruta del archivo CSV.', 1;

    IF OBJECT_ID(N'dbo.Seleccion', N'U') IS NULL
        THROW 51301, N'No existe dbo.Seleccion. Debe crear/cargar Seleccion antes de importar jugadores.', 1;

    IF OBJECT_ID(N'dbo.Jugador', N'U') IS NULL
        THROW 51302, N'No existe dbo.Jugador. Debe crear la tabla Jugador antes de ejecutar esta importación.', 1;

    IF OBJECT_ID(N'abm.Jugador_Alta', N'P') IS NULL
       OR OBJECT_ID(N'abm.Jugador_Modificar', N'P') IS NULL
        THROW 51303, N'No existen los ABM requeridos: abm.Jugador_Alta / abm.Jugador_Modificar.', 1;

    CREATE TABLE #Jugador_Staging
    (
        -- El CSV es UTF-8. RAW conserva sus bytes y esta staging los interpreta
        -- antes de convertir a NVARCHAR. No depende de la collation de tempdb.
        -- VARCHAR mide bytes; las variables receptoras tienen igual n o mayor.
        seleccion VARCHAR(400) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        codigo_fifa VARCHAR(10) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        dorsal VARCHAR(20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        posicion_codigo VARCHAR(20) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        nombre VARCHAR(600) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        apellido VARCHAR(600) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        fecha_nacimiento VARCHAR(40) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        club_origen VARCHAR(1000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL
    );

    CREATE TABLE #Errores
    (
        numero_fila INT NOT NULL,
        seleccion NVARCHAR(400) NULL,
        nombre NVARCHAR(600) NULL,
        apellido NVARCHAR(600) NULL,
        mensaje NVARCHAR(2048) NOT NULL
    );

    /* BULK INSERT no acepta @archivo directamente como ruta.
       Por eso el SQL dinámico queda limitado exclusivamente a esta sentencia. */
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        BULK INSERT #Jugador_Staging
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
        THROW 51304, @mensaje_lectura, 1;
    END CATCH;

    DECLARE
        @numero_fila INT = 0,
        @seleccion_raw NVARCHAR(400),
        @codigo_fifa NVARCHAR(10),
        @dorsal_raw NVARCHAR(20),
        @posicion_raw NVARCHAR(20),
        @nombre_raw NVARCHAR(600),
        @apellido_raw NVARCHAR(600),
        @fecha_raw NVARCHAR(40),
        @club_raw NVARCHAR(1000),

        @id_seleccion INT,
        @id_jugador INT,
        @dorsal TINYINT,
        @fecha_nacimiento DATE,
        @posicion VARCHAR(40),
        @nombre NVARCHAR(600),
        @apellido NVARCHAR(600),
        @club_origen NVARCHAR(1000),

        @insertados INT = 0,
        @actualizados INT = 0,
        @errores INT = 0;

    DECLARE cursor_jugadores CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            seleccion,
            codigo_fifa,
            dorsal,
            posicion_codigo,
            nombre,
            apellido,
            fecha_nacimiento,
            club_origen
        FROM #Jugador_Staging;

    OPEN cursor_jugadores;

    FETCH NEXT FROM cursor_jugadores INTO
        @seleccion_raw,
        @codigo_fifa,
        @dorsal_raw,
        @posicion_raw,
        @nombre_raw,
        @apellido_raw,
        @fecha_raw,
        @club_raw;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @numero_fila += 1;

        BEGIN TRY
            SET @id_seleccion = NULL;
            SET @id_jugador = NULL;
            SET @dorsal = TRY_CONVERT(TINYINT, LTRIM(RTRIM(@dorsal_raw)));
            SET @fecha_nacimiento = TRY_CONVERT(DATE, LTRIM(RTRIM(@fecha_raw)), 103);

            SET @nombre = LTRIM(RTRIM(@nombre_raw));
            SET @apellido = LTRIM(RTRIM(@apellido_raw));
            -- Limpiar el CR final de filas CRLF que Linux puede dejar en el último campo.
            SET @club_origen = LTRIM(RTRIM(REPLACE(@club_raw, NCHAR(13), N'')));

            SET @posicion = CASE UPPER(LTRIM(RTRIM(@posicion_raw)))
                WHEN 'PO' THEN 'Portero'
                WHEN 'DF' THEN 'Defensa'
                WHEN 'MC' THEN 'Mediocentro'
                WHEN 'DC' THEN 'Delantero'
                ELSE NULL
            END;

            /* Validaciones de formato previas al ABM, para evitar truncamientos
               o conversiones inválidas antes de entrar a los SP de Entrega 5. */
            IF NULLIF(LTRIM(RTRIM(@seleccion_raw)), N'') IS NULL
                THROW 51310, N'La selección está vacía.', 1;

            IF @dorsal IS NULL OR @dorsal NOT BETWEEN 1 AND 26
                THROW 51311, N'El dorsal no es válido (debe estar entre 1 y 26).', 1;

            IF @fecha_nacimiento IS NULL
                THROW 51312, N'La fecha de nacimiento no tiene un formato válido.', 1;

            IF NULLIF(@nombre, N'') IS NULL
                THROW 51313, N'El nombre está vacío.', 1;

            IF DATALENGTH(@nombre) > 120
                THROW 51314, N'El nombre supera los 60 caracteres permitidos por dbo.Jugador.', 1;

            IF NULLIF(@apellido, N'') IS NULL
                THROW 51315, N'El apellido está vacío.', 1;

            IF DATALENGTH(@apellido) > 120
                THROW 51316, N'El apellido supera los 60 caracteres permitidos por dbo.Jugador.', 1;

            IF NULLIF(@club_origen, N'') IS NULL
                THROW 51317, N'El club de origen está vacío.', 1;

            IF DATALENGTH(@club_origen) > 200
                THROW 51318, N'El club de origen supera los 100 caracteres permitidos.', 1;

            IF @posicion IS NULL
                THROW 51319, N'Código de posición inválido. Valores esperados: PO, DF, MC o DC.', 1;

            SELECT TOP (1)
                @id_seleccion = id_seleccion
            FROM dbo.Seleccion
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@seleccion_raw)));

            IF @id_seleccion IS NULL
                THROW 51320, N'No existe la selección indicada en dbo.Seleccion.', 1;

            /* Clave natural elegida para el UPSERT:
               selección + nombre + apellido + fecha de nacimiento.
               No usamos dorsal porque puede cambiar. */
            SELECT TOP (1)
                @id_jugador = id_jugador
            FROM dbo.Jugador
            WHERE id_seleccion = @id_seleccion
              AND fecha_nacimiento = @fecha_nacimiento
              AND UPPER(LTRIM(RTRIM(nombre))) = UPPER(@nombre)
              AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(@apellido);

            IF @id_jugador IS NULL
            BEGIN
                EXEC abm.Jugador_Alta
                    @fecha_nacimiento = @fecha_nacimiento,
                    @club_origen = @club_origen,
                    @apellido = @apellido,
                    @nombre = @nombre,
                    @posicion = @posicion,
                    @dorsal = @dorsal,
                    @id_seleccion = @id_seleccion;

                SET @insertados += 1;
            END
            ELSE
            BEGIN
                EXEC abm.Jugador_Modificar
                    @id_jugador = @id_jugador,
                    @fecha_nacimiento = @fecha_nacimiento,
                    @club_origen = @club_origen,
                    @apellido = @apellido,
                    @nombre = @nombre,
                    @posicion = @posicion,
                    @dorsal = @dorsal,
                    @id_seleccion = @id_seleccion;

                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores
            (
                numero_fila,
                seleccion,
                nombre,
                apellido,
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @seleccion_raw,
                @nombre_raw,
                @apellido_raw,
                ERROR_MESSAGE()
            );

            SET @errores += 1;
        END CATCH;

        FETCH NEXT FROM cursor_jugadores INTO
            @seleccion_raw,
            @codigo_fifa,
            @dorsal_raw,
            @posicion_raw,
            @nombre_raw,
            @apellido_raw,
            @fecha_raw,
            @club_raw;
    END;

    CLOSE cursor_jugadores;
    DEALLOCATE cursor_jugadores;

    SELECT
        COUNT(*) AS registros_procesados,
        @insertados AS registros_insertados,
        @actualizados AS registros_actualizados,
        @errores AS registros_con_error
    FROM #Jugador_Staging;

    SELECT
        numero_fila,
        seleccion,
        nombre,
        apellido,
        mensaje
    FROM #Errores
    ORDER BY numero_fila;
END;
GO

