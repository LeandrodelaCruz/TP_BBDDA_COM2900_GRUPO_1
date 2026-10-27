/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 26/10/2026
    Descripción:
    Importación de sedes desde venues.csv.
    El archivo se recibe como parámetro, se carga primero en una tabla temporal de staging
    y luego se realiza UPSERT reutilizando abm.Sede_Alta y abm.Sede_Modificar.

    Fuente esperada (columnas):
    venue_id, stadium_name, city, country, capacity, latitude, longitude, elevation_meters

    Nota sobre SQL dinámico:
    Se utiliza únicamente para BULK INSERT porque SQL Server exige que la ruta del archivo
    forme parte de la sentencia. El resto de la lógica es T-SQL estático.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.SP_Importar_Sede_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    IF @archivo IS NULL OR LTRIM(RTRIM(@archivo)) = N''
        THROW 51101, 'Debe indicar la ruta del archivo CSV a importar.', 1;

    IF LOWER(RIGHT(LTRIM(RTRIM(@archivo)), 4)) <> '.csv'
        THROW 51102, 'El archivo indicado debe tener extensión .csv.', 1;

    /*
        STAGING: recibe el CSV tal como viene.
        Se utilizan columnas amplias de texto para que una fila con un dato incorrecto
        pueda ser informada como error sin impedir el procesamiento de las demás.
    */
    CREATE TABLE #Sede_Staging
    (
        venue_id NVARCHAR(50) NULL,
        stadium_name NVARCHAR(300) NULL,
        city NVARCHAR(200) NULL,
        country NVARCHAR(100) NULL,
        capacity NVARCHAR(50) NULL,
        latitude NVARCHAR(100) NULL,
        longitude NVARCHAR(100) NULL,
        elevation_meters NVARCHAR(50) NULL
    );

    CREATE TABLE #Errores
    (
        venue_id NVARCHAR(50) NULL,
        estadio NVARCHAR(300) NULL,
        ciudad NVARCHAR(200) NULL,
        mensaje NVARCHAR(2048) NOT NULL
    );

    /*
        Único punto de SQL dinámico: parametrización de la ruta usada por BULK INSERT.
    */
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        BULK INSERT #Sede_Staging
        FROM ''' + REPLACE(LTRIM(RTRIM(@archivo)), '''', '''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"''
        );';

    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @mensaje_archivo NVARCHAR(2048) =
            N'No se pudo leer el archivo indicado. Detalle: ' + ERROR_MESSAGE();
        THROW 51103, @mensaje_archivo, 1;
    END CATCH;

    DECLARE
        @venue_id NVARCHAR(50),
        @nombre_estadio_raw NVARCHAR(300),
        @ciudad_raw NVARCHAR(200),
        @pais_raw NVARCHAR(100),
        @capacidad_raw NVARCHAR(50),
        @nombre_estadio NVARCHAR(300),
        @ciudad NVARCHAR(200),
        @pais NVARCHAR(100),
        @capacidad INT,
        @huso_horario VARCHAR(100),
        @id_sede INT,
        @insertados INT = 0,
        @actualizados INT = 0,
        @cantidad_errores INT = 0;

    /* Captura los SELECT que devuelven los ABM para no generar un resultset por fila. */
    DECLARE @resultado_alta TABLE
    (
        id_sede_creada INT
    );

    DECLARE @resultado_modificacion TABLE
    (
        id_sede INT,
        nombre_estadio NVARCHAR(120),
        ciudad NVARCHAR(80),
        pais NVARCHAR(80),
        capacidad INT,
        huso_horario VARCHAR(100)
    );

    DECLARE cursor_sedes CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            venue_id,
            stadium_name,
            city,
            country,
            capacity
        FROM #Sede_Staging;

    OPEN cursor_sedes;

    FETCH NEXT FROM cursor_sedes
    INTO @venue_id, @nombre_estadio_raw, @ciudad_raw, @pais_raw, @capacidad_raw;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        BEGIN TRY
            SET @nombre_estadio = LTRIM(RTRIM(@nombre_estadio_raw));
            SET @ciudad = LTRIM(RTRIM(@ciudad_raw));
            SET @pais = NULL;
            SET @capacidad = TRY_CONVERT(INT, NULLIF(LTRIM(RTRIM(@capacidad_raw)), N''));
            SET @huso_horario = NULL;
            SET @id_sede = NULL;

            /* Validaciones de forma previas al ABM para evitar truncamientos. */
            IF @nombre_estadio IS NULL OR @nombre_estadio = N''
                THROW 51110, 'El nombre del estadio está vacío en el archivo.', 1;

            IF LEN(@nombre_estadio) > 120
                THROW 51111, 'El nombre del estadio supera los 120 caracteres.', 1;

            IF @ciudad IS NULL OR @ciudad = N''
                THROW 51112, 'La ciudad está vacía en el archivo.', 1;

            IF LEN(@ciudad) > 80
                THROW 51113, 'La ciudad supera los 80 caracteres.', 1;

            IF @pais_raw IS NULL OR LTRIM(RTRIM(@pais_raw)) = N''
                THROW 51114, 'El país está vacío en el archivo.', 1;

            /*
                Transformación del código de país del dataset a la denominación usada
                por nuestro modelo. El Mundial 2026 tiene sedes en MEX, USA y CAN.
            */
            SET @pais = CASE UPPER(LTRIM(RTRIM(@pais_raw)))
                WHEN 'MEX' THEN N'México'
                WHEN 'USA' THEN N'Estados Unidos'
                WHEN 'CAN' THEN N'Canadá'
                WHEN N'MÉXICO' THEN N'México'
                WHEN 'MEXICO' THEN N'México'
                WHEN N'ESTADOS UNIDOS' THEN N'Estados Unidos'
                WHEN 'UNITED STATES' THEN N'Estados Unidos'
                WHEN N'CANADÁ' THEN N'Canadá'
                WHEN 'CANADA' THEN N'Canadá'
                ELSE NULL
            END;

            IF @pais IS NULL
                THROW 51115, 'Código o nombre de país no reconocido para una sede del Mundial 2026.', 1;

            IF @capacidad IS NULL OR @capacidad <= 0
                THROW 51116, 'La capacidad no es un número entero válido mayor que cero.', 1;

            /*
                El CSV no incluye huso horario. Se deriva a partir de la ciudad del estadio.
                Se guardan identificadores de zona IANA para conservar la región horaria y
                no un simple offset fijo.
            */
            SET @huso_horario = CASE UPPER(@ciudad)
                WHEN 'MEXICO CITY' THEN 'America/Mexico_City'
                WHEN 'EAST RUTHERFORD' THEN 'America/New_York'
                WHEN 'INGLEWOOD' THEN 'America/Los_Angeles'
                WHEN 'ARLINGTON' THEN 'America/Chicago'
                WHEN 'VANCOUVER' THEN 'America/Vancouver'
                WHEN 'TORONTO' THEN 'America/Toronto'
                WHEN 'ZAPOPAN' THEN 'America/Mexico_City'
                WHEN 'GUADALUPE' THEN 'America/Monterrey'
                WHEN 'ATLANTA' THEN 'America/New_York'
                WHEN 'FOXBOROUGH' THEN 'America/New_York'
                WHEN 'HOUSTON' THEN 'America/Chicago'
                WHEN 'KANSAS CITY' THEN 'America/Chicago'
                WHEN 'MIAMI GARDENS' THEN 'America/New_York'
                WHEN 'PHILADELPHIA' THEN 'America/New_York'
                WHEN 'SANTA CLARA' THEN 'America/Los_Angeles'
                WHEN 'SEATTLE' THEN 'America/Los_Angeles'
                ELSE NULL
            END;

            IF @huso_horario IS NULL
                THROW 51117, 'No existe un huso horario configurado para la ciudad indicada.', 1;

            /*
                Clave natural del UPSERT:
                nombre_estadio + ciudad + pais
                Es la misma combinación que utiliza el ABM para detectar duplicados.
            */
            SELECT @id_sede = id_sede
            FROM dbo.Sede
            WHERE UPPER(LTRIM(RTRIM(nombre_estadio))) = UPPER(@nombre_estadio)
              AND UPPER(LTRIM(RTRIM(ciudad))) = UPPER(@ciudad)
              AND UPPER(LTRIM(RTRIM(pais))) = UPPER(@pais);

            IF @id_sede IS NULL
            BEGIN
                DELETE FROM @resultado_alta;

                INSERT INTO @resultado_alta (id_sede_creada)
                EXEC abm.Sede_Alta
                    @nombre_estadio = @nombre_estadio,
                    @ciudad = @ciudad,
                    @pais = @pais,
                    @capacidad = @capacidad,
                    @huso_horario = @huso_horario;

                SET @insertados += 1;
            END
            ELSE
            BEGIN
                DELETE FROM @resultado_modificacion;

                INSERT INTO @resultado_modificacion
                (
                    id_sede,
                    nombre_estadio,
                    ciudad,
                    pais,
                    capacidad,
                    huso_horario
                )
                EXEC abm.Sede_Modificar
                    @id_sede = @id_sede,
                    @nombre_estadio = @nombre_estadio,
                    @ciudad = @ciudad,
                    @pais = @pais,
                    @capacidad = @capacidad,
                    @huso_horario = @huso_horario;

                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores
            (
                venue_id,
                estadio,
                ciudad,
                mensaje
            )
            VALUES
            (
                @venue_id,
                @nombre_estadio_raw,
                @ciudad_raw,
                ERROR_MESSAGE()
            );

            SET @cantidad_errores += 1;
        END CATCH;

        FETCH NEXT FROM cursor_sedes
        INTO @venue_id, @nombre_estadio_raw, @ciudad_raw, @pais_raw, @capacidad_raw;
    END;

    CLOSE cursor_sedes;
    DEALLOCATE cursor_sedes;

    /* Resumen de la importación. */
    SELECT
        COUNT(*) AS registros_procesados,
        @insertados AS registros_insertados,
        @actualizados AS registros_actualizados,
        @cantidad_errores AS registros_con_error
    FROM #Sede_Staging;

    /* Detalle de errores. Si no hubo errores, devuelve cero filas. */
    SELECT
        venue_id,
        estadio,
        ciudad,
        mensaje
    FROM #Errores;
END;
GO
