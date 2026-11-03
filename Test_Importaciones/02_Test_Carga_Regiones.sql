/*============================================================
    Test:
        test.Cargar_Regiones_Test

    Objetivo:
        Verificar la carga de las regiones utilizadas
        por el módulo publicitario.

    Se verifica:
        1. Que se carguen las 8 regiones.
        2. Que tengan idioma.
        3. Que tengan huso horario.
        4. Que tengan prime time válido.
        5. Que existan al menos 3 husos horarios diferentes.
        6. Que una segunda ejecución no genere duplicados.
============================================================*/

USE MUNDIALDEFUTBOL;
GO


IF SCHEMA_ID(N'test') IS NULL
    THROW 51910, N'Falta el esquema test. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO


CREATE OR ALTER PROCEDURE test.Cargar_Regiones_Test
AS
BEGIN

    SET NOCOUNT ON;


    PRINT '=============================================';
    PRINT 'TEST CARGA DE REGIONES';
    PRINT '=============================================';


    BEGIN TRY

        ----------------------------------------------------
        -- TEST 1
        -- PRIMERA CARGA
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 1 - Ejecutando carga de regiones...';


        EXEC carga.Cargar_Regiones;


        ----------------------------------------------------
        -- REGIONES ESPERADAS
        ----------------------------------------------------

        DECLARE @Esperadas TABLE
        (
            nombre NVARCHAR(80)
        );


        INSERT INTO @Esperadas
        (
            nombre
        )
        VALUES
            (N'Argentina'),
            (N'Brasil'),
            (N'Francia'),
            (N'Estados Unidos'),
            (N'Alemania'),
            (N'España'),
            (N'Reino Unido'),
            (N'México');


        DECLARE @cantidad_regiones INT;


        SELECT
            @cantidad_regiones = COUNT(*)
        FROM @Esperadas E
        INNER JOIN dbo.Region R
            ON UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.nombre)));


        IF @cantidad_regiones <> 8
        BEGIN
            THROW 52301,
                  'TEST FALLIDO: no se encontraron las 8 regiones esperadas.',
                  1;
        END;


        PRINT 'OK - Las 8 regiones existen.';


        ----------------------------------------------------
        -- TEST 2
        -- IDIOMA OBLIGATORIO
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 2 - Verificando idiomas...';


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Region R
            INNER JOIN @Esperadas E
                ON UPPER(LTRIM(RTRIM(R.nombre)))
                 =
                   UPPER(LTRIM(RTRIM(E.nombre)))
            WHERE
                R.idioma IS NULL
                OR LTRIM(RTRIM(R.idioma)) = N''
        )
        BEGIN
            THROW 52302,
                  'TEST FALLIDO: existe una region sin idioma.',
                  1;
        END;


        PRINT 'OK - Todas las regiones tienen idioma.';


        ----------------------------------------------------
        -- TEST 3
        -- HUSO HORARIO
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 3 - Verificando husos horarios...';


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Region R
            INNER JOIN @Esperadas E
                ON UPPER(LTRIM(RTRIM(R.nombre)))
                 =
                   UPPER(LTRIM(RTRIM(E.nombre)))
            WHERE
                R.huso_horario IS NULL
                OR LTRIM(RTRIM(R.huso_horario)) = ''
        )
        BEGIN
            THROW 52303,
                  'TEST FALLIDO: existe una region sin huso horario.',
                  1;
        END;

        PRINT 'OK - Todas las regiones tienen huso horario.';

        ----------------------------------------------------
        -- TEST 4
        -- PRIME TIME
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 4 - Verificando prime time...';


        IF EXISTS
        (
            SELECT 1
            FROM dbo.Region R
            INNER JOIN @Esperadas E
                ON UPPER(LTRIM(RTRIM(R.nombre)))
                 =
                   UPPER(LTRIM(RTRIM(E.nombre)))
            WHERE
                R.hora_prime_inicio IS NULL
                OR R.hora_prime_fin IS NULL
                OR R.hora_prime_inicio >= R.hora_prime_fin
        )
        BEGIN
            THROW 52304,
                  'TEST FALLIDO: existe una region con prime time invalido.',
                  1;
        END;


        PRINT 'OK - Todos los horarios de prime time son validos.';


        ----------------------------------------------------
        -- TEST 5
        -- AL MENOS TRES HUSOS DIFERENTES
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 5 - Verificando variedad de husos horarios...';


        DECLARE @cantidad_husos INT;


        SELECT
            @cantidad_husos =
                COUNT(DISTINCT R.huso_horario)
        FROM dbo.Region R
        INNER JOIN @Esperadas E
            ON UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.nombre)));


        IF @cantidad_husos < 3
        BEGIN
            THROW 52305,
                  'TEST FALLIDO: deben existir al menos 3 husos horarios diferentes.',
                  1;
        END;


        PRINT 'OK - Existen al menos 3 husos horarios distintos.';


        ----------------------------------------------------
        -- CANTIDAD ANTES
        ----------------------------------------------------

        DECLARE @cantidad_antes INT;


        SELECT
            @cantidad_antes = COUNT(*)
        FROM dbo.Region R
        INNER JOIN @Esperadas E
            ON UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.nombre)));


        ----------------------------------------------------
        -- TEST 6
        -- SEGUNDA CARGA / UPSERT
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 6 - Ejecutando nuevamente la carga...';

        EXEC carga.Cargar_Regiones;

        DECLARE @cantidad_despues INT;

        SELECT
            @cantidad_despues = COUNT(*)
        FROM dbo.Region R
        INNER JOIN @Esperadas E
            ON UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.nombre)));


        IF @cantidad_antes <> @cantidad_despues
        BEGIN
            THROW 52306,
                  'TEST FALLIDO: la segunda carga genero nuevas regiones.',
                  1;
        END;

        PRINT 'OK - La segunda carga no genero duplicados.';

        ----------------------------------------------------
        -- TEST 7
        -- DUPLICADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 7 - Verificando duplicados...';

        IF EXISTS
        (
            SELECT
                nombre
            FROM dbo.Region
            GROUP BY nombre
            HAVING COUNT(*) > 1
        )
        BEGIN
            THROW 52307,
                  'TEST FALLIDO: existen regiones duplicadas.',
                  1;
        END;

        PRINT 'OK - No existen regiones duplicadas.';

        ----------------------------------------------------
        -- RESULTADO
        ----------------------------------------------------

        PRINT '';
        PRINT '=============================================';
        PRINT 'TODOS LOS TESTS DE REGION FUERON EXITOSOS';
        PRINT '=============================================';

        SELECT
            R.id_region,
            R.nombre,
            R.idioma,
            R.huso_horario,
            R.hora_prime_inicio,
            R.hora_prime_fin
        FROM dbo.Region R
        INNER JOIN @Esperadas E
            ON UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.nombre)))
        ORDER BY R.id_region;


        SELECT
            COUNT(*) AS cantidad_regiones,
            COUNT(DISTINCT R.huso_horario)
                AS cantidad_husos_horarios
        FROM dbo.Region R
        INNER JOIN @Esperadas E
            ON UPPER(LTRIM(RTRIM(R.nombre)))
             =
               UPPER(LTRIM(RTRIM(E.nombre)));

    END TRY

    BEGIN CATCH

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST DE REGION FALLIDO';
        PRINT '=============================================';


        SELECT
            ERROR_NUMBER() AS numero_error,
            ERROR_MESSAGE() AS mensaje_error,
            ERROR_LINE() AS linea_error;

        THROW;

    END CATCH;

END;
GO

EXEC test.Cargar_Regiones_Test;
GO