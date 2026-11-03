USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Universidad:
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Test:
        test.Test_Importar_Anunciante_CSV

    Objetivo:
        Verificar el funcionamiento del proceso de importación
        de anunciantes desde el CSV generado por scraping.

    Se verifica:
        1. Que se carguen los 8 anunciantes esperados.
        2. Que los países se normalicen correctamente.
        3. Que existan al menos 6 países diferentes.
        4. Que una segunda importación no genere duplicados.
        5. Que el proceso sea idempotente respecto de la
           cantidad de anunciantes importados.
============================================================*/


------------------------------------------------------------
-- CREAR ESQUEMA TEST SI NO EXISTE
------------------------------------------------------------

IF SCHEMA_ID(N'test') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA test');
END;
GO


---`---------------------------------------------------------
-- CREAR TEST
------------------------------------------------------------

CREATE OR ALTER PROCEDURE test.Test_Importar_Anunciante_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN

    SET NOCOUNT ON;

    --------------------------------------------------------
    -- DATOS ESPERADOS
    --------------------------------------------------------

    DECLARE @Esperados TABLE
    (
        nombre NVARCHAR(120),
        pais   NVARCHAR(80)
    );


    INSERT INTO @Esperados
    (
        nombre,
        pais
    )
    VALUES
        (N'Adidas',             N'Argentina'),
        (N'Guaraná Antarctica', N'Brasil'),
        (N'KFC',                N'Francia'),
        (N'Home Depot',         N'Estados Unidos'),
        (N'Magenta TV',         N'Alemania'),
        (N'McDonald’s',         N'España'),
        (N'AB InBev',           N'Reino Unido'),
        (N'Bimbo',              N'México');


    PRINT '=============================================';
    PRINT 'TEST IMPORTACION ANUNCIANTE';
    PRINT '=============================================';


    BEGIN TRY

        ----------------------------------------------------
        -- TEST 1
        -- PRIMERA EJECUCION
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 1 - Ejecutando primera importacion...';

        EXEC importacion.Importar_Anunciante_CSV
            @archivo = @archivo;


        ----------------------------------------------------
        -- COMPROBAR LOS 8 ANUNCIANTES
        ----------------------------------------------------

        DECLARE @cantidad_encontrados INT;


        SELECT
            @cantidad_encontrados = COUNT(*)
        FROM @Esperados E
        INNER JOIN dbo.Anunciante A
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.nombre)))
           AND UPPER(LTRIM(RTRIM(A.pais)))
             = UPPER(LTRIM(RTRIM(E.pais)));


        IF @cantidad_encontrados <> 8
        BEGIN
            THROW 52001,
                  'TEST FALLIDO: no se encontraron los 8 anunciantes esperados.',
                  1;
        END;


        PRINT 'OK - Los 8 anunciantes fueron encontrados.';


        ----------------------------------------------------
        -- TEST 2
        -- COMPROBAR PAISES DISTINTOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 2 - Verificando paises diferentes...';


        DECLARE @cantidad_paises INT;


        SELECT
            @cantidad_paises = COUNT(DISTINCT A.pais)
        FROM dbo.Anunciante A
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.nombre)));


        IF @cantidad_paises < 6
        BEGIN
            THROW 52002,
                  'TEST FALLIDO: existen menos de 6 paises diferentes.',
                  1;
        END;


        PRINT 'OK - Se cumple el minimo de 6 paises diferentes.';


        ----------------------------------------------------
        -- GUARDAR CANTIDAD ANTES DE SEGUNDA IMPORTACION
        ----------------------------------------------------

        DECLARE @cantidad_antes INT;


        SELECT
            @cantidad_antes = COUNT(*)
        FROM dbo.Anunciante A
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.nombre)));


        ----------------------------------------------------
        -- TEST 3
        -- SEGUNDA EJECUCION: UPSERT
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 3 - Ejecutando nuevamente el mismo archivo...';


        EXEC importacion.Importar_Anunciante_CSV
            @archivo = @archivo;


        DECLARE @cantidad_despues INT;


        SELECT
            @cantidad_despues = COUNT(*)
        FROM dbo.Anunciante A
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.nombre)));


        IF @cantidad_antes <> @cantidad_despues
        BEGIN
            THROW 52003,
                  'TEST FALLIDO: la segunda importacion modifico la cantidad de anunciantes.',
                  1;
        END;


        PRINT 'OK - La segunda importacion no genero nuevos registros.';


        ----------------------------------------------------
        -- TEST 4
        -- VERIFICAR DUPLICADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 4 - Verificando duplicados...';


        IF EXISTS
        (
            SELECT
                A.nombre
            FROM dbo.Anunciante A
            INNER JOIN @Esperados E
                ON UPPER(LTRIM(RTRIM(A.nombre)))
                 = UPPER(LTRIM(RTRIM(E.nombre)))
            GROUP BY A.nombre
            HAVING COUNT(*) > 1
        )
        BEGIN
            THROW 52004,
                  'TEST FALLIDO: existen anunciantes duplicados.',
                  1;
        END;


        PRINT 'OK - No existen anunciantes duplicados.';


        ----------------------------------------------------
        -- TEST 5
        -- VERIFICAR PAIS CORRECTO DE CADA ANUNCIANTE
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 5 - Verificando normalizacion de paises...';


        IF EXISTS
        (
            SELECT 1
            FROM @Esperados E
            LEFT JOIN dbo.Anunciante A
                ON UPPER(LTRIM(RTRIM(A.nombre)))
                 = UPPER(LTRIM(RTRIM(E.nombre)))
               AND UPPER(LTRIM(RTRIM(A.pais)))
                 = UPPER(LTRIM(RTRIM(E.pais)))
            WHERE A.id_anunciante IS NULL
        )
        BEGIN
            THROW 52005,
                  'TEST FALLIDO: uno o mas anunciantes tienen un pais incorrecto.',
                  1;
        END;


        PRINT 'OK - Todos los paises fueron normalizados correctamente.';


        ----------------------------------------------------
        -- RESULTADO FINAL
        ----------------------------------------------------

        PRINT '';
        PRINT '=============================================';
        PRINT 'TODOS LOS TESTS DE ANUNCIANTE FUERON EXITOSOS';
        PRINT '=============================================';


        SELECT
            A.id_anunciante,
            A.nombre,
            A.pais
        FROM dbo.Anunciante A
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.nombre)))
        ORDER BY A.id_anunciante;


        SELECT
            COUNT(*) AS cantidad_anunciantes,
            COUNT(DISTINCT A.pais) AS cantidad_paises
        FROM dbo.Anunciante A
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             = UPPER(LTRIM(RTRIM(E.nombre)));


    END TRY

    BEGIN CATCH

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST DE ANUNCIANTE FALLIDO';
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

EXEC test.Test_Importar_Anunciante_CSV
    @archivo =
    N'/var/opt/mssql/import/publicidad_mundial_scraping.csv';
GO