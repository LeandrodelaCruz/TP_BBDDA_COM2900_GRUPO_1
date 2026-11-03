USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Universidad:
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        importacion.Importar_Anunciante_CSV

    Objetivo:
        Importar anunciantes desde el CSV generado mediante
        scraping de System1.

        Del archivo completo se utilizan solamente:
            - anunciante
            - pais

        Se implementa UPSERT reutilizando los SP ABM.

        Un error en una fila no impide procesar las demás.
============================================================*/

------------------------------------------------------------
-- CREAR ESQUEMA SI NO EXISTE
------------------------------------------------------------

IF SCHEMA_ID(N'importacion') IS NULL
    THROW 51910, N'Falta el esquema importacion. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO

------------------------------------------------------------
-- PROCEDIMIENTO
------------------------------------------------------------

CREATE OR ALTER PROCEDURE importacion.Importar_Anunciante_CSV
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
        THROW 51001,
              'Debe indicar el archivo CSV a importar.',
              1;
    END;

    --------------------------------------------------------
    -- 2. TABLA STAGING
    --
    -- Debe respetar las 7 columnas del CSV.
    --------------------------------------------------------

    CREATE TABLE #Publicidad_Staging
    (
        anunciante       NVARCHAR(200)  NULL, -- Aca en realidad solo me interesa anunciante y pais
        pais             NVARCHAR(100)  NULL,
        campania         NVARCHAR(500)  NULL,
        pieza_nombre     NVARCHAR(500)  NULL,
        pieza_contenido  NVARCHAR(1000) NULL,
        pieza_idioma     NVARCHAR(100)  NULL,
        fuente           NVARCHAR(1000) NULL
    );

    --------------------------------------------------------
    -- 3. BULK INSERT
    --
    -- Se utiliza SQL dinamico solamente porque BULK INSERT
    -- no permite parametrizar directamente la ruta.
    --
    -- El CSV fue generado en UTF-16, por eso se utiliza
    -- DATAFILETYPE = widechar.
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

        THROW 51002, @error_bulk, 1;

    END CATCH;

    --------------------------------------------------------
    -- 4. DATOS A PROCESAR
    --
    -- Para esta importacion solamente interesan:
    -- anunciante y pais.
    --------------------------------------------------------

    CREATE TABLE #Anunciante_Procesar
    (
        numero_fila INT IDENTITY(1,1) NOT NULL,
        nombre      NVARCHAR(200) NULL,
        pais        NVARCHAR(100) NULL
    );
 --- Esta la creo para descartar el resto de informacion

    INSERT INTO #Anunciante_Procesar
    (
        nombre,
        pais
    )
    SELECT DISTINCT -- ESTE DISTINCT Es importante porque evita que si un anunciante tenga varias campanias se cargue varias veces
        LTRIM(RTRIM(anunciante)),
        LTRIM(RTRIM(pais))
    FROM #Publicidad_Staging; 


    --------------------------------------------------------
    -- 5. TABLA DE ERRORES
    --------------------------------------------------------

    CREATE TABLE #Errores
    (
        numero_fila INT,
        anunciante  NVARCHAR(200),
        pais        NVARCHAR(100),
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
        @nombre        NVARCHAR(200),
        @pais_origen   NVARCHAR(100),
        @pais          NVARCHAR(80),
        @id_anunciante INT,
        @nuevo_id      INT;


    --------------------------------------------------------
    -- 8. CURSOR
    --------------------------------------------------------

    DECLARE cursor_anunciantes CURSOR LOCAL FAST_FORWARD -- Uso cursor porque  la consigna pide que un error en un registro no impida la carga de los demas
    FOR
        SELECT
            numero_fila,
            nombre,
            pais
        FROM #Anunciante_Procesar
        ORDER BY numero_fila;


    OPEN cursor_anunciantes;


    FETCH NEXT FROM cursor_anunciantes
    INTO
        @numero_fila,
        @nombre,
        @pais_origen;


    WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @procesados += 1;

        -- Muy importante para el UPSERT.
        SET @id_anunciante = NULL;
        SET @nuevo_id = NULL;
        SET @pais = NULL;


        BEGIN TRY

            ------------------------------------------------
            -- 9. NORMALIZAR DATOS
            ------------------------------------------------

            SET @nombre =
                LTRIM(RTRIM(@nombre));

            SET @pais_origen =
                LTRIM(RTRIM(@pais_origen));

            ------------------------------------------------
            -- 10. VALIDACIONES
            ------------------------------------------------

            IF @nombre IS NULL
               OR @nombre = N''
            BEGIN
                THROW 51010,
                      'El nombre del anunciante esta vacio.',
                      1;
            END;


            IF LEN(@nombre) > 120
            BEGIN
                THROW 51011,
                      'El nombre del anunciante supera los 120 caracteres.',
                      1;
            END;


            IF @pais_origen IS NULL
               OR @pais_origen = N''
            BEGIN
                THROW 51012,
                      'El pais del anunciante esta vacio.',
                      1;
            END;


            ------------------------------------------------
            -- 11. NORMALIZAR PAIS
            --
            -- System1 utiliza nombres de paises en ingles.
            -- La transformacion se realiza en T-SQL.
            ------------------------------------------------

            SET @pais =
                CASE UPPER(@pais_origen)

                    WHEN 'ARGENTINA'
                        THEN N'Argentina'

                    WHEN 'BRAZIL'
                        THEN N'Brasil'

                    WHEN 'FRANCE'
                        THEN N'Francia'

                    WHEN 'US'
                        THEN N'Estados Unidos'

                    WHEN 'UNITED STATES'
                        THEN N'Estados Unidos'

                    WHEN 'GERMANY'
                        THEN N'Alemania'

                    WHEN 'SPAIN'
                        THEN N'España'

                    WHEN 'UK'
                        THEN N'Reino Unido'

                    WHEN 'UNITED KINGDOM'
                        THEN N'Reino Unido'

                    WHEN 'MEXICO'
                        THEN N'México'

                    ELSE
                        @pais_origen

                END;


            IF LEN(@pais) > 80
            BEGIN
                THROW 51013,
                      'El pais supera los 80 caracteres.',
                      1;
            END;


            ------------------------------------------------
            -- 12. BUSCAR ANUNCIANTE
            ------------------------------------------------

            SET @id_anunciante = NULL;


            SELECT
                @id_anunciante = id_anunciante
            FROM dbo.Anunciante
            WHERE
                UPPER(LTRIM(RTRIM(nombre)))
                =
                UPPER(LTRIM(RTRIM(@nombre)));


            ------------------------------------------------
            -- 13. UPSERT
            ------------------------------------------------

            IF @id_anunciante IS NULL
            BEGIN

                EXEC abm.Anunciante_Alta
                    @nombre = @nombre, -- Busca por nombre porque es la clave natural
                    @pais = @pais,
                    @id_anunciante = @nuevo_id OUTPUT;


                SET @insertados += 1;

            END
            ELSE
            BEGIN

                EXEC abm.Anunciante_Modificar
                    @id_anunciante = @id_anunciante,
                    @nombre = @nombre,
                    @pais = @pais;


                SET @actualizados += 1;

            END;

        END TRY

        BEGIN CATCH

            SET @errores += 1;


            INSERT INTO #Errores
            (
                numero_fila,
                anunciante,
                pais,
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @nombre,
                @pais_origen,
                ERROR_MESSAGE()
            );

        END CATCH;


        ----------------------------------------------------
        -- SIGUIENTE FILA
        ----------------------------------------------------

        FETCH NEXT FROM cursor_anunciantes
        INTO
            @numero_fila,
            @nombre,
            @pais_origen;

    END;


    --------------------------------------------------------
    -- 14. CERRAR CURSOR
    --------------------------------------------------------

    CLOSE cursor_anunciantes;
    DEALLOCATE cursor_anunciantes;


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
        pais,
        mensaje
    FROM #Errores
    ORDER BY numero_fila;

END;
GO
