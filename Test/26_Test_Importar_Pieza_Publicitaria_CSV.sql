USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Test:
        test.SP_Test_Importar_Pieza_Publicitaria_CSV

    Objetivo:
        Verificar el proceso de importacion de piezas
        publicitarias desde publicidad_mundial_scraping.csv.

    Se verifica:
        1. Que existan las 8 campañas necesarias.
        2. Que se importen 8 piezas.
        3. Que cada pieza pertenezca a la campaña correcta.
        4. Que contenido e idioma sean obligatorios.
        5. Que el contenido tenga una URL.
        6. Que una segunda importacion no duplique.
============================================================*/


IF SCHEMA_ID(N'test') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA test');
END;
GO


CREATE OR ALTER PROCEDURE test.SP_Test_Importar_Pieza_Publicitaria_CSV
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
        campania    NVARCHAR(500),
        idioma      NVARCHAR(100)
    );


    INSERT INTO @Esperados
    (
        anunciante,
        campania,
        idioma
    )
    VALUES

        (
            N'Adidas',
            N'Seguí soñando',
            N'Español'
        ),

        (
            N'Guaraná Antarctica',
            N'A torcida tá convocada',
            N'Portugués'
        ),

        (
            N'KFC',
            N'KFC France x FFF',
            N'Francés'
        ),

        (
            N'Home Depot',
            N'Build it Like Beckham',
            N'Inglés'
        ),

        (
            N'Magenta TV',
            N'Thomas Müller',
            N'Alemán'
        ),

        (
            N'McDonald’s',
            N'Estas leyendas están listas para el Menú la Copa Mundial de la FIFA 2026 de McDonald’s el 9 de junio',
            N'Español'
        ),

        (
            N'AB InBev',
            N'Cheers to Bars',
            N'Inglés'
        ),

        (
            N'Bimbo',
            N'Venimos con hambre de ganar',
            N'Español'
        );


    PRINT '=============================================';
    PRINT 'TEST IMPORTACION PIEZA PUBLICITARIA';
    PRINT '=============================================';


    BEGIN TRY

        ----------------------------------------------------
        -- TEST 1
        -- VERIFICAR CAMPAÑAS PREVIAS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 1 - Verificando campañas existentes...';


        DECLARE @campanias_encontradas INT;


        SELECT
            @campanias_encontradas = COUNT(*)
        FROM @Esperados E

        INNER JOIN dbo.Anunciante A
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.anunciante)))

        INNER JOIN dbo.Campania C
            ON C.id_anunciante = A.id_anunciante
           AND UPPER(LTRIM(RTRIM(C.descripcion)))
             =
               UPPER(LTRIM(RTRIM(E.campania)));


        IF @campanias_encontradas <> 8
        BEGIN
            THROW 52201,
                  'TEST FALLIDO: primero deben existir las 8 campañas.',
                  1;
        END;


        PRINT 'OK - Las 8 campañas existen.';


        ----------------------------------------------------
        -- TEST 2
        -- PRIMERA IMPORTACION
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 2 - Ejecutando importacion de piezas...';


        EXEC importacion.SP_Importar_Pieza_Publicitaria_CSV
            @archivo = @archivo;


        ----------------------------------------------------
        -- COMPROBAR PIEZAS
        ----------------------------------------------------

        DECLARE @piezas_encontradas INT;


        SELECT
            @piezas_encontradas = COUNT(*)
        FROM @Esperados E

        INNER JOIN dbo.Anunciante A
            ON UPPER(LTRIM(RTRIM(A.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.anunciante)))

        INNER JOIN dbo.Campania C
            ON C.id_anunciante = A.id_anunciante
           AND UPPER(LTRIM(RTRIM(C.descripcion)))
             =
               UPPER(LTRIM(RTRIM(E.campania)))

        INNER JOIN dbo.Pieza_Publicitaria P
            ON P.id_campania = C.id_campania
           AND UPPER(LTRIM(RTRIM(P.nombre)))
             =
               UPPER(
                   LTRIM(
                       RTRIM(
                           E.campania + N' - Video'
                       )
                   )
               );


        IF @piezas_encontradas <> 8
        BEGIN
            THROW 52202,
                  'TEST FALLIDO: no se encontraron las 8 piezas esperadas.',
                  1;
        END;


        PRINT 'OK - Las 8 piezas fueron importadas.';


        ----------------------------------------------------
        -- TEST 3
        -- RELACION PIEZA / CAMPAÑA
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 3 - Verificando relaciones pieza/campaña...';


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
                   UPPER(LTRIM(RTRIM(E.campania)))

            LEFT JOIN dbo.Pieza_Publicitaria P
                ON P.id_campania = C.id_campania
               AND UPPER(LTRIM(RTRIM(P.nombre)))
                 =
                   UPPER(
                       LTRIM(
                           RTRIM(
                               E.campania + N' - Video'
                           )
                       )
                   )

            WHERE P.id_pieza IS NULL
        )
        BEGIN
            THROW 52203,
                  'TEST FALLIDO: una pieza no pertenece a la campaña esperada.',
                  1;
        END;


        PRINT 'OK - Todas las piezas tienen la campaña correcta.';


        ----------------------------------------------------
        -- TEST 4
        -- CONTENIDO E IDIOMA OBLIGATORIOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 4 - Verificando contenido e idioma...';


        IF EXISTS
        (
            SELECT 1
            FROM @Esperados E

            INNER JOIN dbo.Anunciante A
                ON UPPER(LTRIM(RTRIM(A.nombre)))
                 =
                   UPPER(LTRIM(RTRIM(E.anunciante)))

            INNER JOIN dbo.Campania C
                ON C.id_anunciante = A.id_anunciante
               AND UPPER(LTRIM(RTRIM(C.descripcion)))
                 =
                   UPPER(LTRIM(RTRIM(E.campania)))

            INNER JOIN dbo.Pieza_Publicitaria P
                ON P.id_campania = C.id_campania
               AND UPPER(LTRIM(RTRIM(P.nombre)))
                 =
                   UPPER(
                       LTRIM(
                           RTRIM(
                               E.campania + N' - Video'
                           )
                       )
                   )

            WHERE
                P.contenido IS NULL
                OR LTRIM(RTRIM(P.contenido)) = N''
                OR P.idioma IS NULL
                OR LTRIM(RTRIM(P.idioma)) = N''
        )
        BEGIN
            THROW 52204,
                  'TEST FALLIDO: una pieza tiene contenido o idioma vacio.',
                  1;
        END;


        PRINT 'OK - Todas las piezas tienen contenido e idioma.';


        ----------------------------------------------------
        -- TEST 5
        -- VERIFICAR URL
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 5 - Verificando contenido URL...';


        IF EXISTS
        (
            SELECT 1
            FROM @Esperados E

            INNER JOIN dbo.Anunciante A
                ON UPPER(LTRIM(RTRIM(A.nombre)))
                 =
                   UPPER(LTRIM(RTRIM(E.anunciante)))

            INNER JOIN dbo.Campania C
                ON C.id_anunciante = A.id_anunciante
               AND UPPER(LTRIM(RTRIM(C.descripcion)))
                 =
                   UPPER(LTRIM(RTRIM(E.campania)))

            INNER JOIN dbo.Pieza_Publicitaria P
                ON P.id_campania = C.id_campania
               AND UPPER(LTRIM(RTRIM(P.nombre)))
                 =
                   UPPER(
                       LTRIM(
                           RTRIM(
                               E.campania + N' - Video'
                           )
                       )
                   )

            WHERE
                P.contenido NOT LIKE N'http%'
        )
        BEGIN
            THROW 52205,
                  'TEST FALLIDO: una pieza no contiene una URL valida.',
                  1;
        END;


        PRINT 'OK - Todas las piezas contienen una URL.';


        ----------------------------------------------------
        -- TEST 6
        -- IDIOMAS ESPERADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 6 - Verificando idiomas...';


        IF EXISTS
        (
            SELECT 1
            FROM @Esperados E

            INNER JOIN dbo.Anunciante A
                ON UPPER(LTRIM(RTRIM(A.nombre)))
                 =
                   UPPER(LTRIM(RTRIM(E.anunciante)))

            INNER JOIN dbo.Campania C
                ON C.id_anunciante = A.id_anunciante
               AND UPPER(LTRIM(RTRIM(C.descripcion)))
                 =
                   UPPER(LTRIM(RTRIM(E.campania)))

            INNER JOIN dbo.Pieza_Publicitaria P
                ON P.id_campania = C.id_campania
               AND UPPER(LTRIM(RTRIM(P.nombre)))
                 =
                   UPPER(
                       LTRIM(
                           RTRIM(
                               E.campania + N' - Video'
                           )
                       )
                   )

            WHERE
                UPPER(LTRIM(RTRIM(P.idioma)))
                <>
                UPPER(LTRIM(RTRIM(E.idioma)))
        )
        BEGIN
            THROW 52206,
                  'TEST FALLIDO: una pieza tiene un idioma incorrecto.',
                  1;
        END;


        PRINT 'OK - Todos los idiomas son correctos.';


        ----------------------------------------------------
        -- CANTIDAD ANTES DE SEGUNDA IMPORTACION
        ----------------------------------------------------

        DECLARE @cantidad_antes INT;


        SELECT
            @cantidad_antes = COUNT(*)
        FROM dbo.Pieza_Publicitaria P

        INNER JOIN dbo.Campania C
            ON C.id_campania = P.id_campania

        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante

        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             =
               UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.campania)))
             =
               UPPER(LTRIM(RTRIM(C.descripcion)));


        ----------------------------------------------------
        -- TEST 7
        -- SEGUNDA IMPORTACION
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 7 - Ejecutando nuevamente el archivo...';


        EXEC importacion.SP_Importar_Pieza_Publicitaria_CSV
            @archivo = @archivo;


        DECLARE @cantidad_despues INT;


        SELECT
            @cantidad_despues = COUNT(*)
        FROM dbo.Pieza_Publicitaria P

        INNER JOIN dbo.Campania C
            ON C.id_campania = P.id_campania

        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante

        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             =
               UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.campania)))
             =
               UPPER(LTRIM(RTRIM(C.descripcion)));


        IF @cantidad_antes <> @cantidad_despues
        BEGIN
            THROW 52207,
                  'TEST FALLIDO: la segunda importacion genero nuevas piezas.',
                  1;
        END;


        PRINT 'OK - La segunda importacion no genero duplicados.';


        ----------------------------------------------------
        -- TEST 8
        -- DUPLICADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 8 - Verificando duplicados...';


        IF EXISTS
        (
            SELECT
                P.id_campania,
                P.nombre
            FROM dbo.Pieza_Publicitaria P
            GROUP BY
                P.id_campania,
                P.nombre
            HAVING COUNT(*) > 1
        )
        BEGIN
            THROW 52208,
                  'TEST FALLIDO: existen piezas publicitarias duplicadas.',
                  1;
        END;


        PRINT 'OK - No existen piezas duplicadas.';


        ----------------------------------------------------
        -- RESULTADO FINAL
        ----------------------------------------------------

        PRINT '';
        PRINT '=============================================';
        PRINT 'TODOS LOS TESTS DE PIEZA PUBLICITARIA OK';
        PRINT '=============================================';


        SELECT
            P.id_pieza,
            P.nombre AS pieza,
            P.idioma,
            P.contenido,
            C.id_campania,
            C.descripcion AS campania,
            A.nombre AS anunciante,
            A.pais

        FROM dbo.Pieza_Publicitaria P

        INNER JOIN dbo.Campania C
            ON C.id_campania = P.id_campania

        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante

        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             =
               UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.campania)))
             =
               UPPER(LTRIM(RTRIM(C.descripcion)))

        ORDER BY P.id_pieza;


        SELECT
            COUNT(*) AS cantidad_piezas
        FROM dbo.Pieza_Publicitaria P
        INNER JOIN dbo.Campania C
            ON C.id_campania = P.id_campania
        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante
        INNER JOIN @Esperados E
            ON UPPER(LTRIM(RTRIM(E.anunciante)))
             =
               UPPER(LTRIM(RTRIM(A.nombre)))
           AND UPPER(LTRIM(RTRIM(E.campania)))
             =
               UPPER(LTRIM(RTRIM(C.descripcion)));


    END TRY

    BEGIN CATCH

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST DE PIEZA PUBLICITARIA FALLIDO';
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

EXEC test.SP_Test_Importar_Pieza_Publicitaria_CSV
    @archivo =
    N'/var/opt/mssql/import/publicidad_mundial_scraping.csv';
GO