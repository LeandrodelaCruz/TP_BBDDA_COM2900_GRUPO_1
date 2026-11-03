USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Universidad:
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        importacion.Importar_Pieza_Publicitaria_CSV

    Objetivo:
        Importar piezas publicitarias desde el CSV generado
        mediante scraping de System1.

        Del CSV se utilizan:
            - anunciante
            - campania
            - pieza_nombre
            - pieza_contenido
            - pieza_idioma

        Dependencias:
            - dbo.Anunciante debe estar cargada.
            - dbo.Campania debe estar cargada.

        Implementa UPSERT reutilizando los SP ABM.

        Un error en una fila no impide procesar las demás.
============================================================*/


IF SCHEMA_ID(N'importacion') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA importacion');
END;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Pieza_Publicitaria_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN

    SET NOCOUNT ON;

    --------------------------------------------------------
    -- 1. VALIDAR PARAMETRO
    --------------------------------------------------------

    IF @archivo IS NULL
       OR LTRIM(RTRIM(@archivo)) = N''
    BEGIN
        THROW 51201,
              'Debe indicar el archivo CSV a importar.',
              1;
    END;

    --------------------------------------------------------
    -- 2. STAGING
    --------------------------------------------------------

    CREATE TABLE #Publicidad_Staging
    (
        anunciante       NVARCHAR(200)  NULL,
        pais             NVARCHAR(100)  NULL,
        campania         NVARCHAR(500)  NULL,
        pieza_nombre     NVARCHAR(500)  NULL,
        pieza_contenido  NVARCHAR(1000) NULL,
        pieza_idioma     NVARCHAR(100)  NULL,
        fuente           NVARCHAR(1000) NULL
    );

    --------------------------------------------------------
    -- 3. CARGAR CSV
    --------------------------------------------------------
    DECLARE @sql NVARCHAR(MAX);

    SET @sql =
        N'BULK INSERT #Publicidad_Staging
          FROM '''
        + REPLACE(@archivo, '''', '''''')
        + N'''
          WITH
          (
              FORMAT = ''CSV'',
              DATAFILETYPE = ''widechar'',
              FIRSTROW = 2,
              FIELDQUOTE = ''"'',
              TABLOCK
          );';

    BEGIN TRY

        EXEC sys.sp_executesql @sql;

    END TRY
    BEGIN CATCH

        DECLARE @error_bulk NVARCHAR(2048);

        SET @error_bulk =
            N'No se pudo leer el archivo CSV. '
            + ERROR_MESSAGE();

        THROW 51202, @error_bulk, 1;

    END CATCH;

    --------------------------------------------------------
    -- 4. DATOS A PROCESAR
    --------------------------------------------------------

    CREATE TABLE #Pieza_Procesar
    (
        numero_fila    INT IDENTITY(1,1) NOT NULL,
        anunciante     NVARCHAR(200)  NULL,
        campania       NVARCHAR(500)  NULL,
        nombre         NVARCHAR(500)  NULL,
        contenido      NVARCHAR(1000) NULL,
        idioma         NVARCHAR(100)  NULL
    );

    INSERT INTO #Pieza_Procesar
    (
        anunciante,
        campania,
        nombre,
        contenido,
        idioma
    )
    SELECT DISTINCT
        LTRIM(RTRIM(anunciante)),
        LTRIM(RTRIM(campania)),
        LTRIM(RTRIM(pieza_nombre)),
        LTRIM(RTRIM(pieza_contenido)),
        LTRIM(RTRIM(pieza_idioma))
    FROM #Publicidad_Staging;
    --------------------------------------------------------
    -- 5. TABLA DE ERRORES
    --------------------------------------------------------
    CREATE TABLE #Errores
    (
        numero_fila INT,
        anunciante  NVARCHAR(200),
        campania    NVARCHAR(500),
        pieza       NVARCHAR(500),
        mensaje     NVARCHAR(2048)
    );
    --------------------------------------------------------
    -- 6. CONTADORES
    --------------------------------------------------------

    DECLARE
        @procesados   INT = 0,
        @insertados   INT = 0,
        @actualizados INT = 0,
        @errores      INT = 0;
    --------------------------------------------------------
    -- 7. VARIABLES
    --------------------------------------------------------

    DECLARE
        @numero_fila   INT,
        @anunciante    NVARCHAR(200),
        @campania      NVARCHAR(500),
        @nombre        NVARCHAR(500),
        @contenido     NVARCHAR(1000),
        @idioma        NVARCHAR(100),

        @id_anunciante INT,
        @id_campania   INT,
        @id_pieza      INT;
    --------------------------------------------------------
    -- 8. CURSOR
    --------------------------------------------------------
    DECLARE cursor_piezas CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT
            numero_fila,
            anunciante,
            campania,
            nombre,
            contenido,
            idioma
        FROM #Pieza_Procesar
        ORDER BY numero_fila;

    OPEN cursor_piezas;

    FETCH NEXT FROM cursor_piezas
    INTO
        @numero_fila,
        @anunciante,
        @campania,
        @nombre,
        @contenido,
        @idioma;

    WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @procesados += 1;

        SET @id_anunciante = NULL;
        SET @id_campania = NULL;
        SET @id_pieza = NULL;

        BEGIN TRY

            ------------------------------------------------
            -- 9. NORMALIZAR
            ------------------------------------------------

            SET @anunciante =
                LTRIM(RTRIM(@anunciante));
            SET @campania =
                LTRIM(RTRIM(@campania));
            SET @nombre =
                LTRIM(RTRIM(@nombre));
            SET @contenido =
                LTRIM(RTRIM(@contenido));
            SET @idioma =
                LTRIM(RTRIM(@idioma));

            ------------------------------------------------
            -- 10. VALIDACIONES
            ------------------------------------------------

            IF @anunciante IS NULL
               OR @anunciante = N''
            BEGIN
                THROW 51210,
                      'El anunciante esta vacio.',
                      1;
            END;

            IF @campania IS NULL
               OR @campania = N''
            BEGIN
                THROW 51211,
                      'La campaña esta vacia.',
                      1;
            END;

            IF @nombre IS NULL
               OR @nombre = N''
            BEGIN
                THROW 51212,
                      'El nombre de la pieza esta vacio.',
                      1;
            END;


            IF @contenido IS NULL
               OR @contenido = N''
            BEGIN
                THROW 51213,
                      'El contenido de la pieza esta vacio.',
                      1;
            END;

            IF @idioma IS NULL
               OR @idioma = N''
            BEGIN
                THROW 51214,
                      'El idioma de la pieza esta vacio.',
                      1;
            END;

            -----------------------------------------------
            -- 11. BUSCAR ANUNCIANTE
            ------------------------------------------------

            SELECT
                @id_anunciante = id_anunciante
            FROM dbo.Anunciante
            WHERE
                UPPER(LTRIM(RTRIM(nombre)))
                =
                UPPER(LTRIM(RTRIM(@anunciante)));


            IF @id_anunciante IS NULL
            BEGIN
                THROW 51215,
                      'El anunciante asociado a la pieza no existe.',
                      1;
            END;

            ------------------------------------------------
            -- 12. BUSCAR CAMPAÑA
            ------------------------------------------------

            SELECT
                @id_campania = id_campania
            FROM dbo.Campania
            WHERE
                id_anunciante = @id_anunciante
                AND UPPER(LTRIM(RTRIM(descripcion)))
                    =
                    UPPER(LTRIM(RTRIM(@campania)));


            IF @id_campania IS NULL
            BEGIN
                THROW 51216,
                      'La campaña asociada a la pieza no existe.',
                      1;
            END;

            ------------------------------------------------
            -- 13. BUSCAR PIEZA
            --
            -- Clave logica:
            -- campaña + nombre de pieza
            ------------------------------------------------

            SELECT
                @id_pieza = id_pieza
            FROM dbo.Pieza_Publicitaria
            WHERE
                id_campania = @id_campania
                AND UPPER(LTRIM(RTRIM(nombre)))
                    =
                    UPPER(LTRIM(RTRIM(@nombre)));

            ------------------------------------------------
            -- 14. UPSERT
            ------------------------------------------------

            IF @id_pieza IS NULL
            BEGIN

                EXEC abm.Pieza_Publicitaria_Alta
                    @nombre = @nombre,
                    @contenido = @contenido,
                    @idioma = @idioma,
                    @id_campania = @id_campania;


                SET @insertados += 1;

            END
            ELSE
            BEGIN

                EXEC abm.Pieza_Publicitaria_Modificar
                    @id_pieza = @id_pieza,
                    @nombre = @nombre,
                    @contenido = @contenido,
                    @idioma = @idioma,
                    @id_campania = @id_campania;


                SET @actualizados += 1;

            END;

        END TRY

        BEGIN CATCH

            SET @errores += 1;


            INSERT INTO #Errores
            (
                numero_fila,
                anunciante,
                campania,
                pieza,
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @anunciante,
                @campania,
                @nombre,
                ERROR_MESSAGE()
            );

        END CATCH;


        ----------------------------------------------------
        -- SIGUIENTE FILA
        ----------------------------------------------------

        FETCH NEXT FROM cursor_piezas
        INTO
            @numero_fila,
            @anunciante,
            @campania,
            @nombre,
            @contenido,
            @idioma;

    END;


    --------------------------------------------------------
    -- 15. CERRAR CURSOR
    --------------------------------------------------------

    CLOSE cursor_piezas;
    DEALLOCATE cursor_piezas;


    --------------------------------------------------------
    -- 16. RESUMEN
    --------------------------------------------------------

    SELECT
        @procesados   AS procesados,
        @insertados   AS insertados,
        @actualizados AS actualizados,
        @errores      AS errores;


    --------------------------------------------------------
    -- 17. ERRORES PARCIALES
    --------------------------------------------------------

    SELECT
        numero_fila,
        anunciante,
        campania,
        pieza,
        mensaje
    FROM #Errores
    ORDER BY numero_fila;

END;
GO