USE MUNDIALDEFUTBOL;
GO


IF SCHEMA_ID(N'test') IS NULL
    THROW 51910, N'Falta el esquema test. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO


CREATE OR ALTER PROCEDURE test.Cargar_Pieza_Para_Region_Test
AS
BEGIN

    SET NOCOUNT ON;


    PRINT '=============================================';
    PRINT 'TEST PIEZA PARA REGION';
    PRINT '=============================================';


    BEGIN TRY

        ----------------------------------------------------
        -- RELACIONES ESPERADAS
        ----------------------------------------------------

        DECLARE @Esperadas TABLE
        (
            anunciante NVARCHAR(120),
            region NVARCHAR(80)
        );


        INSERT INTO @Esperadas
        (
            anunciante,
            region
        )
        VALUES
            (N'Adidas', N'Argentina'),
            (N'Guaraná Antarctica', N'Brasil'),
            (N'KFC', N'Francia'),
            (N'Home Depot', N'Estados Unidos'),
            (N'Magenta TV', N'Alemania'),
            (N'McDonald’s', N'España'),
            (N'AB InBev', N'Reino Unido'),
            (N'Bimbo', N'México');


        ----------------------------------------------------
        -- TEST 1
        -- PRIMERA CARGA
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 1 - Ejecutando carga...';


        EXEC carga.Cargar_Pieza_Para_Region;


        ----------------------------------------------------
        -- TEST 2
        -- COMPROBAR LAS 8 RELACIONES
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 2 - Verificando relaciones...';


        DECLARE @cantidad_relaciones INT;


        SELECT
            @cantidad_relaciones = COUNT(*)

        FROM @Esperadas E

        INNER JOIN dbo.Anunciante A
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.anunciante)))

        INNER JOIN dbo.Campania C
            ON C.id_anunciante = A.id_anunciante

        INNER JOIN dbo.Pieza_Publicitaria P
            ON P.id_campania = C.id_campania

        INNER JOIN dbo.Pieza_Para_Region PR
            ON PR.id_pieza = P.id_pieza

        INNER JOIN dbo.Region R
            ON R.id_region = PR.id_region
           AND UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.region)));


        IF @cantidad_relaciones <> 8
        BEGIN
            THROW 52401,
                  'TEST FALLIDO: no se encontraron las 8 relaciones esperadas.',
                  1;
        END;


        PRINT 'OK - Las 8 relaciones existen.';


        ----------------------------------------------------
        -- TEST 3
        -- FK VALIDAS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 3 - Verificando integridad de las relaciones...';


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Pieza_Para_Region PR

            LEFT JOIN dbo.Pieza_Publicitaria P
                ON P.id_pieza = PR.id_pieza

            LEFT JOIN dbo.Region R
                ON R.id_region = PR.id_region

            WHERE
                P.id_pieza IS NULL
                OR R.id_region IS NULL
        )
        BEGIN
            THROW 52402,
                  'TEST FALLIDO: existe una relación con una FK inválida.',
                  1;
        END;


        PRINT 'OK - Todas las relaciones tienen FK válidas.';


        ----------------------------------------------------
        -- TEST 4
        -- DUPLICADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 4 - Verificando duplicados...';


        IF EXISTS
        (
            SELECT
                id_pieza,
                id_region
            FROM dbo.Pieza_Para_Region
            GROUP BY
                id_pieza,
                id_region
            HAVING COUNT(*) > 1
        )
        BEGIN
            THROW 52403,
                  'TEST FALLIDO: existen relaciones duplicadas.',
                  1;
        END;


        PRINT 'OK - No existen relaciones duplicadas.';


        ----------------------------------------------------
        -- TEST 5
        -- SEGUNDA EJECUCION
        ----------------------------------------------------

        DECLARE @cantidad_antes INT;

        SELECT
            @cantidad_antes = COUNT(*)
        FROM dbo.Pieza_Para_Region;


        PRINT '';
        PRINT 'TEST 5 - Ejecutando nuevamente la carga...';


        EXEC carga.Cargar_Pieza_Para_Region;


        DECLARE @cantidad_despues INT;

        SELECT
            @cantidad_despues = COUNT(*)
        FROM dbo.Pieza_Para_Region;


        IF @cantidad_antes <> @cantidad_despues
        BEGIN
            THROW 52404,
                  'TEST FALLIDO: la segunda carga generó relaciones nuevas.',
                  1;
        END;


        PRINT 'OK - La segunda ejecución no generó duplicados.';


        ----------------------------------------------------
        -- RESULTADO FINAL
        ----------------------------------------------------

        PRINT '';
        PRINT '=============================================';
        PRINT 'TODOS LOS TESTS DE PIEZA PARA REGION OK';
        PRINT '=============================================';


        SELECT
            PR.id_pieza,
            P.nombre AS pieza,
            A.nombre AS anunciante,
            PR.id_region,
            R.nombre AS region,
            R.idioma,
            R.huso_horario,
            R.hora_prime_inicio,
            R.hora_prime_fin

        FROM dbo.Pieza_Para_Region PR

        INNER JOIN dbo.Pieza_Publicitaria P
            ON P.id_pieza = PR.id_pieza

        INNER JOIN dbo.Campania C
            ON C.id_campania = P.id_campania

        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante

        INNER JOIN dbo.Region R
            ON R.id_region = PR.id_region

        ORDER BY PR.id_pieza;


        SELECT
            COUNT(*) AS cantidad_relaciones
        FROM dbo.Pieza_Para_Region;

    END TRY

    BEGIN CATCH

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST PIEZA PARA REGION FALLIDO';
        PRINT '=============================================';


        SELECT
            ERROR_NUMBER() AS numero_error,
            ERROR_MESSAGE() AS mensaje_error,
            ERROR_LINE() AS linea_error;


        THROW;

    END CATCH;

END;
GO


EXEC test.Cargar_Pieza_Para_Region_Test;
GO