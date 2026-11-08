/*============================================================
    Universidad:
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        carga.Cargar_Regiones

    Objetivo:
        Cargar los mercados/regiones utilizados por el
        módulo publicitario.

        Region es una tabla de configuración interna.
        No se obtiene mediante scraping ni archivo externo.

        Los husos horarios utilizan identificadores IANA.
        Los horarios de prime time son parámetros de negocio.

        Se implementa UPSERT reutilizando los ABM.
============================================================*/

USE MUNDIALDEFUTBOL;
GO
------------------------------------------------------------
-- VALIDAR ESQUEMA (creado en Table/00_Script_DB_Schemas_Creacion.sql)
------------------------------------------------------------

IF SCHEMA_ID(N'carga') IS NULL
    THROW 51910, N'Falta el esquema carga. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO


------------------------------------------------------------
-- PROCEDIMIENTO
------------------------------------------------------------

CREATE OR ALTER PROCEDURE carga.Cargar_Regiones
AS
BEGIN

    SET NOCOUNT ON;


    --------------------------------------------------------
    -- 1. REGIONES A CARGAR
    --------------------------------------------------------

    DECLARE @Regiones TABLE
    (
        numero_fila       INT IDENTITY(1,1),
        nombre            NVARCHAR(80),
        idioma            NVARCHAR(50),
        huso_horario      VARCHAR(100),
        hora_prime_inicio TIME(0),
        hora_prime_fin    TIME(0)
    );

    INSERT INTO @Regiones
    (
        nombre,
        idioma,
        huso_horario,
        hora_prime_inicio,
        hora_prime_fin
    )
    values
    (
        N'Argentina',
        N'Español',
        'America/Argentina/Buenos_Aires',
        '18:00',
        '23:00'
    ),
    (
        N'Brasil',
        N'Portugués',
        'America/Sao_Paulo',
        '18:00',
        '23:00'
    ),
    (
        N'Francia',
        N'Francés',
        'Europe/Paris',
        '20:00',
        '23:59'
    ),
    (
        N'Estados Unidos',
        N'Inglés',
        'America/New_York',
        '19:00',
        '22:00'
    ),
    (
        N'Alemania',
        N'Alemán',
        'Europe/Berlin',
        '20:00',
        '23:59'
    ),
    (
        N'España',
        N'Español',
        'Europe/Madrid',
        '20:00',
        '23:59'
    ),
    (
        N'Reino Unido',
        N'Inglés',
        'Europe/London',
        '19:00',
        '23:00'
    ),
    (
        N'México',
        N'Español',
        'America/Mexico_City',
        '20:00',
        '23:00'
    );


    --------------------------------------------------------
    -- 2. ERRORES
    --------------------------------------------------------

    DECLARE @TablaErrores TABLE
    (
        numero_fila INT,
        region      NVARCHAR(80),
        mensaje     NVARCHAR(2048)
    );

    --------------------------------------------------------
    -- 3. CONTADORES
    --------------------------------------------------------

    DECLARE
        @procesados   INT = 0,
        @insertados   INT = 0,
        @actualizados INT = 0,
        @errores      INT = 0;


    --------------------------------------------------------
    -- 4. VARIABLES
    --------------------------------------------------------

    DECLARE
        @numero_fila       INT,
        @nombre            NVARCHAR(80),
        @idioma            NVARCHAR(50),
        @huso_horario      VARCHAR(100),
        @hora_prime_inicio TIME(0),
        @hora_prime_fin    TIME(0),
        @id_region         INT;


    --------------------------------------------------------
    -- 5. recorrido con WHILE
    --------------------------------------------------------

    -- Copia fija de las filas a procesar; conserva el orden del proceso original.
    SELECT ROW_NUMBER() OVER (ORDER BY numero_fila) AS orden_recorrido,
           numero_fila, nombre, idioma, huso_horario, hora_prime_inicio, hora_prime_fin
    INTO #Trabajo_Recorrido
    FROM @Regiones;
    CREATE UNIQUE CLUSTERED INDEX IX_Trabajo_Recorrido
        ON #Trabajo_Recorrido (orden_recorrido);

    DECLARE @fila_recorrido BIGINT;
    SELECT @fila_recorrido = MIN(orden_recorrido) FROM #Trabajo_Recorrido;


    WHILE @fila_recorrido IS NOT NULL
    BEGIN
        SELECT @numero_fila = numero_fila,
               @nombre = nombre,
               @idioma = idioma,
               @huso_horario = huso_horario,
               @hora_prime_inicio = hora_prime_inicio,
               @hora_prime_fin = hora_prime_fin
        FROM #Trabajo_Recorrido WHERE orden_recorrido = @fila_recorrido;

        SET @procesados += 1;
        SET @id_region = NULL;


        BEGIN TRY

            ------------------------------------------------
            -- VALIDACIONES DE LA CARGA
            ------------------------------------------------

            IF @nombre IS NULL
               OR LTRIM(RTRIM(@nombre)) = N''
            BEGIN
                THROW 51301,
                      'El nombre de la region es obligatorio.',
                      1;
            END;


            IF @idioma IS NULL
               OR LTRIM(RTRIM(@idioma)) = N''
            BEGIN
                THROW 51302,
                      'El idioma es obligatorio.',
                      1;
            END;


            IF @huso_horario IS NULL
               OR LTRIM(RTRIM(@huso_horario)) = ''
            BEGIN
                THROW 51303,
                      'El huso horario es obligatorio.',
                      1;
            END;


            IF @hora_prime_inicio IS NULL
               OR @hora_prime_fin IS NULL
            BEGIN
                THROW 51304,
                      'El horario de prime time es obligatorio.',
                      1;
            END;


            IF @hora_prime_inicio >= @hora_prime_fin
            BEGIN
                THROW 51305,
                      'La hora de inicio debe ser anterior a la hora de fin.',
                      1;
            END;


            ------------------------------------------------
            -- BUSCAR REGION EXISTENTE
            ------------------------------------------------

            SELECT
                @id_region = id_region
            FROM dbo.Region
            WHERE
                UPPER(LTRIM(RTRIM(nombre)))
                =
                UPPER(LTRIM(RTRIM(@nombre)));

            ------------------------------------------------
            -- UPSERT
            ------------------------------------------------

            IF @id_region IS NULL
            BEGIN

                EXEC abm.Region_Alta
                    @nombre = @nombre,
                    @idioma = @idioma,
                    @huso_horario = @huso_horario,
                    @hora_prime_inicio = @hora_prime_inicio,
                    @hora_prime_fin = @hora_prime_fin;

                SET @insertados += 1;

            END
            ELSE
            BEGIN

                EXEC abm.Region_Modificar
                    @id_region = @id_region,
                    @nombre = @nombre,
                    @idioma = @idioma,
                    @huso_horario = @huso_horario,
                    @hora_prime_inicio = @hora_prime_inicio,
                    @hora_prime_fin = @hora_prime_fin;


                SET @actualizados += 1;

            END;

        END TRY

        BEGIN CATCH

            SET @errores += 1;


            INSERT INTO @TablaErrores
            (
                numero_fila,
                region,
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @nombre,
                ERROR_MESSAGE()
            );

        END CATCH;


        SELECT @fila_recorrido = MIN(orden_recorrido)
            FROM #Trabajo_Recorrido WHERE orden_recorrido > @fila_recorrido;

    END;


    --------------------------------------------------------
    -- 6. RESUMEN
    --------------------------------------------------------

    SELECT
        @procesados   AS procesados,
        @insertados   AS insertados,
        @actualizados AS actualizados,
        @errores      AS errores;


    --------------------------------------------------------
    -- 7. ERRORES
    --------------------------------------------------------

    SELECT
        numero_fila,
        region,
        mensaje
    FROM @TablaErrores
    ORDER BY numero_fila;

END;
GO