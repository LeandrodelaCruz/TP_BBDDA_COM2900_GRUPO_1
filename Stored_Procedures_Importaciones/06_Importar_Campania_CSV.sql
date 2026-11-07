USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Universidad:
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        importacion.Importar_Campania_CSV

    Objetivo:
        Importar campañas desde el CSV generado mediante
        scraping de System1.

        Del CSV completo utiliza:
            - anunciante
            - campania

        La tabla Anunciante debe encontrarse cargada
        previamente.

        Se implementa UPSERT reutilizando los SP ABM.

        Un error en una fila no impide procesar las demás.
============================================================*/


IF SCHEMA_ID(N'importacion') IS NULL
    THROW 51910, N'Falta el esquema importacion. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO


CREATE OR ALTER PROCEDURE importacion.Importar_Campania_CSV
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
        THROW 51101,
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

        THROW 51102, @error_bulk, 1;

    END CATCH;


    --------------------------------------------------------
    -- 4. DATOS A PROCESAR
    --------------------------------------------------------

    CREATE TABLE #Campania_Procesar
    (
        numero_fila INT IDENTITY(1,1) NOT NULL,
        anunciante  NVARCHAR(200) NULL,
        descripcion NVARCHAR(500) NULL
    );


    INSERT INTO #Campania_Procesar
    (
        anunciante,
        descripcion
    )
    SELECT DISTINCT
        LTRIM(RTRIM(anunciante)),
        LTRIM(RTRIM(campania))
    FROM #Publicidad_Staging;


    --------------------------------------------------------
    -- 5. ERRORES
    --------------------------------------------------------

    CREATE TABLE #Errores
    (
        numero_fila INT,
        anunciante  NVARCHAR(200),
        campania    NVARCHAR(500),
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
        @descripcion   NVARCHAR(500),
        @id_anunciante INT,
        @id_campania   INT;


    --------------------------------------------------------
    -- 8. recorrido con WHILE
    --------------------------------------------------------

    -- Copia fija de las filas a procesar; conserva el orden del proceso original.
    SELECT ROW_NUMBER() OVER (ORDER BY numero_fila) AS orden_recorrido,
           numero_fila, anunciante, descripcion
    INTO #Trabajo_Recorrido
    FROM #Campania_Procesar;
    CREATE UNIQUE CLUSTERED INDEX IX_Trabajo_Recorrido
        ON #Trabajo_Recorrido (orden_recorrido);

    DECLARE @fila_recorrido BIGINT;
    SELECT @fila_recorrido = MIN(orden_recorrido) FROM #Trabajo_Recorrido;


    WHILE @fila_recorrido IS NOT NULL
    BEGIN
        SELECT @numero_fila = numero_fila,
               @anunciante = anunciante,
               @descripcion = descripcion
        FROM #Trabajo_Recorrido WHERE orden_recorrido = @fila_recorrido;

        SET @procesados += 1;

        SET @id_anunciante = NULL;
        SET @id_campania = NULL;


        BEGIN TRY

            ------------------------------------------------
            -- 9. NORMALIZAR
            ------------------------------------------------

            SET @anunciante =
                LTRIM(RTRIM(@anunciante));

            SET @descripcion =
                LTRIM(RTRIM(@descripcion));


            ------------------------------------------------
            -- 10. VALIDACIONES
            ------------------------------------------------

            IF @anunciante IS NULL
               OR @anunciante = N''
            BEGIN
                THROW 51110,
                      'El anunciante de la campaña esta vacio.',
                      1;
            END;


            IF @descripcion IS NULL
               OR @descripcion = N''
            BEGIN
                THROW 51111,
                      'La descripcion de la campaña esta vacia.',
                      1;
            END;


            ------------------------------------------------
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
                THROW 51112,
                      'El anunciante asociado a la campaña no existe.',
                      1;
            END;


            ------------------------------------------------
            -- 12. BUSCAR CAMPAniaA
            --
            -- Clave logica:
            -- anunciante + descripcion
            ------------------------------------------------

            SELECT
                @id_campania = id_campania
            FROM dbo.Campania
            WHERE
                id_anunciante = @id_anunciante
                AND UPPER(LTRIM(RTRIM(descripcion)))
                    =
                    UPPER(LTRIM(RTRIM(@descripcion)));

            ------------------------------------------------
            -- 13. UPSERT
            ------------------------------------------------
            -- si el id de la campania es null, entonces crea uno nuevo
            IF @id_campania IS NULL
            BEGIN

                EXEC abm.Campania_Alta
                    @descripcion = @descripcion,
                    @id_anunciante = @id_anunciante;


                SET @insertados += 1;

            END
            ELSE
            BEGIN

                EXEC abm.Campania_Modificar
                    @id_campania = @id_campania,
                    @descripcion = @descripcion,
                    @id_anunciante = @id_anunciante;


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
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @anunciante,
                @descripcion,
                ERROR_MESSAGE()
            );

        END CATCH;


        ----------------------------------------------------
        -- SIGUIENTE FILA
        ----------------------------------------------------

        SELECT @fila_recorrido = MIN(orden_recorrido)
            FROM #Trabajo_Recorrido WHERE orden_recorrido > @fila_recorrido;

    END;


    --------------------------------------------------------
    -- 14. FIN DEL RECORRIDO
    --------------------------------------------------------


    --------------------------------------------------------
    -- 15. RESUMEN
    --------------------------------------------------------

    SELECT
        @procesados   AS procesados,
        @insertados   AS insertados,
        @actualizados AS actualizados,
        @errores      AS errores;

    --------------------------------------------------------
    -- 16. ERRORES PARCIALES
    --------------------------------------------------------

    SELECT
        numero_fila,
        anunciante,
        campania,
        mensaje
    FROM #Errores
    ORDER BY numero_fila;

END;
GO