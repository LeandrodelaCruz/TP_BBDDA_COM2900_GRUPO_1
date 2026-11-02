/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01:
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel

    Descripción:
    Importa jugadores obtenidos mediante scraping de la página pública
    "2026 FIFA World Cup squads".

    El archivo generado por scraping contiene:
        seleccion,dorsal,posicion,jugador,fecha_nacimiento,club_origen

    El proceso reutiliza los SP de la Entrega 5:
        - abm.Jugador_Alta
        - abm.Jugador_Modificar

    SQL dinámico:
    Se utiliza únicamente para BULK INSERT porque la ruta del archivo debe
    recibirse como parámetro y BULK INSERT no acepta una variable directamente
    en la cláusula FROM.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.SP_Importar_Jugador_Scraping_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    IF @archivo IS NULL OR LTRIM(RTRIM(@archivo)) = N''
        THROW 51301, N'Debe indicar el archivo generado por scraping.', 1;

    /* La staging replica exactamente el CSV generado por el scraper. */
    CREATE TABLE #Jugador_Staging
    (
        seleccion NVARCHAR(100) NULL,
        dorsal NVARCHAR(20) NULL,
        posicion NVARCHAR(40) NULL,
        jugador NVARCHAR(200) NULL,
        fecha_nacimiento NVARCHAR(50) NULL,
        club_origen NVARCHAR(200) NULL
    );

    CREATE TABLE #Errores
    (
        numero_fila INT NOT NULL,
        seleccion NVARCHAR(100) NULL,
        jugador NVARCHAR(200) NULL,
        mensaje NVARCHAR(2048) NOT NULL
    );

    /* Único tramo dinámico: BULK INSERT necesita la ruta como literal. */
    DECLARE @sql NVARCHAR(MAX);
    SET @sql = N'
        BULK INSERT #Jugador_Staging
        FROM ''' + REPLACE(@archivo, '''', '''''') + N'''
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
        THROW 51302, @mensaje_archivo, 1;
    END CATCH;

    DECLARE
        @numero_fila INT = 0,
        @seleccion_raw NVARCHAR(100),
        @dorsal_raw NVARCHAR(20),
        @posicion_raw NVARCHAR(40),
        @jugador_raw NVARCHAR(200),
        @fecha_raw NVARCHAR(50),
        @club_raw NVARCHAR(200),

        @id_seleccion INT,
        @id_jugador INT,
        @dorsal INT,
        @fecha_nacimiento DATE,
        @posicion VARCHAR(40),
        @jugador NVARCHAR(200),
        @nombre NVARCHAR(60),
        @apellido NVARCHAR(60),
        @club NVARCHAR(100),
        @ultimo_espacio INT,

        @insertados INT = 0,
        @actualizados INT = 0,
        @cantidad_errores INT = 0;

    DECLARE cursor_jugadores CURSOR LOCAL FAST_FORWARD FOR
        SELECT seleccion, dorsal, posicion, jugador, fecha_nacimiento, club_origen
        FROM #Jugador_Staging;

    OPEN cursor_jugadores;

    FETCH NEXT FROM cursor_jugadores
    INTO @seleccion_raw, @dorsal_raw, @posicion_raw, @jugador_raw, @fecha_raw, @club_raw;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @numero_fila += 1;

        BEGIN TRY
            /* Normalización básica del registro obtenido por scraping. */
            SET @seleccion_raw = LTRIM(RTRIM(@seleccion_raw));
            SET @jugador = LTRIM(RTRIM(@jugador_raw));
            SET @club = LTRIM(RTRIM(@club_raw));
            SET @dorsal = TRY_CONVERT(INT, LTRIM(RTRIM(@dorsal_raw)));
            SET @fecha_nacimiento = TRY_CONVERT(DATE, LTRIM(RTRIM(@fecha_raw)), 23);

            SET @posicion = CASE UPPER(LTRIM(RTRIM(@posicion_raw)))
                WHEN 'GK' THEN 'Arquero'
                WHEN 'DF' THEN 'Defensa'
                WHEN 'MF' THEN 'Mediocampista'
                WHEN 'FW' THEN 'Delantero'
                ELSE NULL
            END;

            IF @seleccion_raw IS NULL OR @seleccion_raw = N''
                THROW 51303, N'La selección es obligatoria.', 1;

            SET @id_seleccion = NULL;
            SELECT TOP (1) @id_seleccion = id_seleccion
            FROM dbo.Seleccion
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(@seleccion_raw);

            IF @id_seleccion IS NULL
                THROW 51304, N'No existe en dbo.Seleccion la selección indicada por el scraping.', 1;

            IF @dorsal IS NULL OR @dorsal NOT BETWEEN 1 AND 26
                THROW 51305, N'El dorsal debe ser un número entre 1 y 26.', 1;

            IF @fecha_nacimiento IS NULL
                THROW 51306, N'La fecha de nacimiento no tiene formato válido YYYY-MM-DD.', 1;

            IF @posicion IS NULL
                THROW 51307, N'La posición obtenida no es válida.', 1;

            IF @club IS NULL OR @club = N''
                THROW 51308, N'El club de origen es obligatorio.', 1;

            IF LEN(@club) > 100
                THROW 51309, N'El club de origen supera los 100 caracteres permitidos.', 1;

            IF @jugador IS NULL OR @jugador = N''
                THROW 51310, N'El nombre del jugador es obligatorio.', 1;

            /*
               La fuente entrega el nombre completo en un solo campo.
               Regla documentada de transformación:
                 - último término => apellido
                 - términos anteriores => nombre
               Si es monónimo, se reporta el registro como error y no se inventa un apellido.
            */
            SET @ultimo_espacio = LEN(@jugador) - CHARINDEX(' ', REVERSE(@jugador)) + 1;

            IF CHARINDEX(' ', @jugador) = 0
                THROW 51311, N'El jugador tiene un nombre monónimo y el modelo exige nombre y apellido separados.', 1;

            SET @nombre = LTRIM(RTRIM(LEFT(@jugador, @ultimo_espacio - 1)));
            SET @apellido = LTRIM(RTRIM(SUBSTRING(@jugador, @ultimo_espacio + 1, LEN(@jugador))));

            IF @nombre = N'' OR @apellido = N''
                THROW 51312, N'No se pudo separar correctamente nombre y apellido.', 1;

            IF LEN(@nombre) > 60
                THROW 51313, N'El nombre resultante supera los 60 caracteres.', 1;

            IF LEN(@apellido) > 60
                THROW 51314, N'El apellido resultante supera los 60 caracteres.', 1;

            /*
               Clave natural usada para el UPSERT:
               selección + nombre + apellido + fecha de nacimiento.
               No se usa dorsal porque puede cambiar ante reemplazos.
            */
            SET @id_jugador = NULL;
            SELECT TOP (1) @id_jugador = id_jugador
            FROM dbo.Jugador
            WHERE id_seleccion = @id_seleccion
              AND fecha_nacimiento = @fecha_nacimiento
              AND UPPER(LTRIM(RTRIM(nombre))) = UPPER(@nombre)
              AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(@apellido);

            IF @id_jugador IS NULL
            BEGIN
                EXEC abm.Jugador_Alta
                    @fecha_nacimiento = @fecha_nacimiento,
                    @club_origen = @club,
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
                    @club_origen = @club,
                    @apellido = @apellido,
                    @nombre = @nombre,
                    @posicion = @posicion,
                    @dorsal = @dorsal,
                    @id_seleccion = @id_seleccion;

                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores(numero_fila, seleccion, jugador, mensaje)
            VALUES(@numero_fila, @seleccion_raw, @jugador_raw, ERROR_MESSAGE());

            SET @cantidad_errores += 1;
        END CATCH;

        FETCH NEXT FROM cursor_jugadores
        INTO @seleccion_raw, @dorsal_raw, @posicion_raw, @jugador_raw, @fecha_raw, @club_raw;
    END;

    CLOSE cursor_jugadores;
    DEALLOCATE cursor_jugadores;

    SELECT
        COUNT(*) AS registros_procesados,
        @insertados AS registros_insertados,
        @actualizados AS registros_actualizados,
        @cantidad_errores AS registros_con_error
    FROM #Jugador_Staging;

    SELECT numero_fila, seleccion, jugador, mensaje
    FROM #Errores
    ORDER BY numero_fila;
END;
GO
