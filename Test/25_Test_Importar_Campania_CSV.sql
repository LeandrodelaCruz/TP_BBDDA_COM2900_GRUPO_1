USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Test:
        test.SP_Test_Importar_Campania_CSV

    Objetivo:
        Verificar el proceso de importacion de campañas
        desde publicidad_mundial_scraping.csv.

    Se verifica:
        1. Que existan los 8 anunciantes necesarios.
        2. Que se importen las 8 campañas.
        3. Que cada campaña quede asociada al anunciante
           correcto.
        4. Que una segunda importacion no genere duplicados.
        5. Que el UPSERT mantenga la misma cantidad.
============================================================*/


IF SCHEMA_ID(N'test') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA test');
END;
GO


CREATE OR ALTER PROCEDURE test.SP_Test_Importar_Campania_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;


    --------------------------------------------------------
    -- DATOS ESPERADOS
    --------------------------------------------------------

    DECLARE @Esperados TABLE
    (
        anunciante  NVARCHAR(120),
        descripcion NVARCHAR(500)
    );


    INSERT INTO @Esperados
    (
        anunciante,
        descripcion
    )
    VALUES
        (N'Adidas',
         N'Seguí soñando'),

        (N'Guaraná Antarctica',
         N'A torcida tá convocada'),

        (N'KFC',
         N'KFC France x FFF'),

        (N'Home Depot',
         N'Build it Like Beckham'),

        (N'Magenta TV',
         N'Thomas Müller'),

        (N'McDonald’s',
         N'Estas leyendas están listas para el Menú la Copa Mundial de la FIFA 2026 de McDonald’s el 9 de junio'),

        (N'AB InBev',
         N'Cheers to Bars'),

        (N'Bimbo',
         N'Venimos con hambre de ganar');


    PRINT '=============================================';
    PRINT 'TEST IMPORTACION CAMPANIA';
    PRINT '=============================================';


    BEGIN TRY

        ----------------------------------------------------
        -- TEST 1
        -- VERIFICAR ANUNCIANTES
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 1 - Verificando anunciantes existentes...';


        DECLARE @anunciantes_encontrados INT;


        SELECT
            @anunciantes_encontrados = COUNT(*)
        FROM @Esperados E
        INNER JOIN dbo.Anunciante A
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.anunciante)));


        IF @anunciantes_encontrados <> 8
        BEGIN
            THROW 52101,
                  'TEST FALLIDO: primero deben existir los 8 anunciantes.',
                  1;
        END;


        PRINT 'OK - Los 8 anunciantes existen.';


        ----------------------------------------------------
        -- TEST 2
        -- PRIMERA IMPORTACION
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 2 - Ejecutando importacion de campañas...';


        EXEC importacion.SP_Importar_Campania_CSV
            @archivo = @archivo;


        ----------------------------------------------------
        -- COMPROBAR CAMPAÑAS
        ----------------------------------------------------

        DECLARE @campanias_encontradas INT;


        SELECT
            @campanias_encontradas = COUNT(*)
        FROM @Esperados E
        INNER JOIN dbo.Anunciante A
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.anunciante)))
        INNER JOIN dbo.Campania C
            ON C.id_anunciante = A.id_anunciante
           AND UPPER(LTRIM(RTRIM(C.descripcion)))
             = UPPER(LTRIM(RTRIM(E.descripcion)));


        IF @campanias_encontradas <> 8
        BEGIN
            THROW 52102,
                  'TEST FALLIDO: no se encontraron las 8 campañas esperadas.',
                  1;
        END;


        PRINT 'OK - Las 8 campañas fueron importadas.';


        ----------------------------------------------------
        -- TEST 3
        -- VERIFICAR RELACIONES CON ANUNCIANTE
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 3 - Verificando relaciones campaña/anunciante...';


        IF EXISTS
        (
            SELECT 1
            FROM @Esperados E

            LEFT JOIN dbo.Anunciante A
                ON UPPER(LTRIM(RTRIM(A.nombre)))
                 =
                 UPPER(LTRIM(RTRIM(E.anunciante)))

            LEFT JOIN dbo.Campania C
                ON C.id_anunciante = A.id_anunciante
               AND UPPER(LTRIM(RTRIM(C.descripcion)))
                 =
                 UPPER(LTRIM(RTRIM(E.descripcion)))

            WHERE C.id_campania IS NULL
        )
        BEGIN
            THROW 52103,
                  'TEST FALLIDO: existe una campaña asociada al anunciante incorrecto.',
                  1;
        END;


        PRINT 'OK - Todas las campañas tienen el anunciante correcto.';


        ----------------------------------------------------
        -- CANTIDAD ANTES DE SEGUNDA IMPORTACION
        ----------------------------------------------------

        DECLARE @cantidad_antes INT;


        SELECT
            @cantidad_antes = COUNT(*)
        FROM dbo.Campania C
        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             = UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.descripcion)))
             = UPPER(LTRIM(RTRIM(C.descripcion)));


        ----------------------------------------------------
        -- TEST 4
        -- SEGUNDA IMPORTACION
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 4 - Ejecutando nuevamente el archivo...';


        EXEC importacion.SP_Importar_Campania_CSV
            @archivo = @archivo;


        DECLARE @cantidad_despues INT;


        SELECT
            @cantidad_despues = COUNT(*)
        FROM dbo.Campania C
        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             = UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.descripcion)))
             = UPPER(LTRIM(RTRIM(C.descripcion)));


        IF @cantidad_antes <> @cantidad_despues
        BEGIN
            THROW 52104,
                  'TEST FALLIDO: la segunda importacion genero nuevos registros.',
                  1;
        END;


        PRINT 'OK - La segunda importacion no genero duplicados.';


        ----------------------------------------------------
        -- TEST 5
        -- DUPLICADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 5 - Verificando duplicados...';


        IF EXISTS
        (
            SELECT
                C.id_anunciante,
                C.descripcion
            FROM dbo.Campania C
            INNER JOIN dbo.Anunciante A
                ON A.id_anunciante = C.id_anunciante
            INNER JOIN @Esperados E
                ON UPPER(LTRIM(RTRIM(E.anunciante)))
                 = UPPER(LTRIM(RTRIM(A.nombre)))
               AND UPPER(LTRIM(RTRIM(E.descripcion)))
                 = UPPER(LTRIM(RTRIM(C.descripcion)))
            GROUP BY
                C.id_anunciante,
                C.descripcion
            HAVING COUNT(*) > 1
        )
        BEGIN
            THROW 52105,
                  'TEST FALLIDO: existen campañas duplicadas.',
                  1;
        END;


        PRINT 'OK - No existen campañas duplicadas.';


        ----------------------------------------------------
        -- RESULTADO FINAL
        ----------------------------------------------------

        PRINT '';
        PRINT '=============================================';
        PRINT 'TODOS LOS TESTS DE CAMPANIA FUERON EXITOSOS';
        PRINT '=============================================';


        SELECT
            C.id_campania,
            C.descripcion,
            A.id_anunciante,
            A.nombre AS anunciante,
            A.pais
        FROM dbo.Campania C
        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             = UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.descripcion)))
             = UPPER(LTRIM(RTRIM(C.descripcion)))
        ORDER BY C.id_campania;


        SELECT
            COUNT(*) AS cantidad_campanias
        FROM dbo.Campania C
        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             = UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.descripcion)))
             = UPPER(LTRIM(RTRIM(C.descripcion)));


    END TRY

    BEGIN CATCH

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST DE CAMPANIA FALLIDO';
        PRINT '=============================================';


        SELECT
            ERROR_NUMBER() AS numero_error,
            ERROR_MESSAGE() AS mensaje_error,
            ERROR_LINE() AS linea_error;


        THROW;

    END CATCH;

END;
GO


------------------------------------------------------------
-- EJECUTAR TEST
------------------------------------------------------------

EXEC test.SP_Test_Importar_Campania_CSV
    @archivo =
    N'/var/opt/mssql/import/publicidad_mundial_scraping.csv';
GO