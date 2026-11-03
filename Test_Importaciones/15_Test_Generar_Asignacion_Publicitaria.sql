USE MUNDIALDEFUTBOL;
GO


IF SCHEMA_ID(N'test') IS NULL
BEGIN
    EXEC(N'CREATE SCHEMA test');
END;
GO


CREATE OR ALTER PROCEDURE
    test.Generar_Asignacion_Publicitaria_Test
AS
BEGIN

    SET NOCOUNT ON;


    PRINT '=============================================';
    PRINT 'TEST GENERACION ASIGNACION PUBLICITARIA';
    PRINT '=============================================';


    BEGIN TRY

        ----------------------------------------------------
        -- 1. VERIFICAR DEPENDENCIAS
        ----------------------------------------------------

        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Partido
        )
        BEGIN
            THROW 52501,
                  'TEST FALLIDO: no existen partidos cargados.',
                  1;
        END;


        IF NOT EXISTS
        (
            SELECT 1
            FROM dbo.Pieza_Para_Region
        )
        BEGIN
            THROW 52502,
                  'TEST FALLIDO: no existen relaciones Pieza_Para_Region.',
                  1;
        END;

        ----------------------------------------------------
        -- 2. CALCULAR CANTIDAD DE CANDIDATOS
        --    PARA CADA PARTIDO
        ----------------------------------------------------

        CREATE TABLE #PartidosCandidatos 
        (
            id_partido INT NOT NULL,
            cantidad_candidatos INT NOT NULL
        );

        ;WITH RegionesConPieza AS
        (
            SELECT DISTINCT --trae solo aquellas que tengan al menos una pieza
                R.id_region,
                R.huso_horario,
                R.hora_prime_inicio,
                R.hora_prime_fin
            FROM dbo.Region R
            INNER JOIN dbo.Pieza_Para_Region PR
                ON PR.id_region = R.id_region
        ),
        PartidoRegion AS -- combina cada partido existente con todas las regiones filtradas  en el paso anterior
        (
            SELECT
                P.id_partido,
                R.id_region,
                R.hora_prime_inicio,
                R.hora_prime_fin,

                CASE R.huso_horario  -- Este case lee el horario original del partido y lo establece como punto de partida UTC.
                                                    -- Lee la columna huso_horario y con case toma el valor IANA y obtiene el equivalente en el reg de windows.
                                                    -- AT TIME ZONE,  sabe cuantas horas sumar o restar.

                    WHEN 'America/Argentina/Buenos_Aires'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'Argentina Standard Time'

                            AS DATETIME2(0)
                        )
                    WHEN 'America/Sao_Paulo'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'E. South America Standard Time'

                            AS DATETIME2(0)
                        )
                    WHEN 'Europe/Paris'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'Romance Standard Time'

                            AS DATETIME2(0)
                        )
                    WHEN 'America/New_York'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'Eastern Standard Time'

                            AS DATETIME2(0)
                        )
                    WHEN 'Europe/Berlin'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'W. Europe Standard Time'

                            AS DATETIME2(0)
                        )
                    WHEN 'Europe/Madrid'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'Romance Standard Time'

                            AS DATETIME2(0)
                        )
                    WHEN 'Europe/London'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'GMT Standard Time'
                            AS DATETIME2(0)
                        )
                    WHEN 'America/Mexico_City'
                    THEN
                        CAST
                        (
                            (
                                P.horario_UTC
                                    AT TIME ZONE 'UTC'
                            )
                            AT TIME ZONE
                                'Central Standard Time (Mexico)'
                            AS DATETIME2(0)
                        )
                END AS hora_local
            FROM dbo.Partido P
            CROSS JOIN RegionesConPieza R
        )

        INSERT INTO #PartidosCandidatos
        (
            id_partido,
            cantidad_candidatos
        )

        SELECT
            PR.id_partido,
            COUNT(*)
        FROM PartidoRegion PR
        WHERE
            PR.hora_local IS NOT NULL

            AND CAST(PR.hora_local AS TIME)
                >= PR.hora_prime_inicio
            AND CAST(PR.hora_local AS TIME)
                < PR.hora_prime_fin --verifica que este dentro del horario prime time

        GROUP BY PR.id_partido;


        ----------------------------------------------------
        -- 3. ELEGIR EL PARTIDO CON MAS CANDIDATOS
        ----------------------------------------------------

        DECLARE
            @id_partido INT,
            @cantidad_candidatos INT,
            @cantidad_asignados INT;


        SELECT TOP (1)
            @id_partido = id_partido,
            @cantidad_candidatos = cantidad_candidatos
        FROM #PartidosCandidatos
        ORDER BY
            cantidad_candidatos DESC,
            id_partido ASC;

        IF @id_partido IS NULL
        BEGIN
            THROW 52503,
                  'TEST FALLIDO: ningún partido cae en prime time en las regiones configuradas.',
                  1;
        END;

        PRINT '';
        PRINT 'Partido seleccionado para el test:';

        SELECT
            P.id_partido,
            P.fecha,
            P.horario_UTC,
            S1.pais AS seleccion_1,
            S2.pais AS seleccion_2,
            @cantidad_candidatos AS mercados_candidatos

        FROM dbo.Partido P

        INNER JOIN dbo.Seleccion S1
            ON S1.id_seleccion = P.id_seleccion_1

        INNER JOIN dbo.Seleccion S2
            ON S2.id_seleccion = P.id_seleccion_2

        WHERE P.id_partido = @id_partido;

        ----------------------------------------------------
        -- 4. PRIMERA GENERACION
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 1 - Generando asignaciones...';

        EXEC negocio.Generar_Asignacion_Publicitaria
            @id_partido = @id_partido,
            @cantidad_candidatos = @cantidad_candidatos OUTPUT,
            @cantidad_asignados = @cantidad_asignados OUTPUT;


        ----------------------------------------------------
        -- 5. MAXIMO CUATRO ESPACIOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 2 - Verificando máximo de cuatro espacios...';

        DECLARE @cantidad_bd INT;

        SELECT
            @cantidad_bd = COUNT(*)
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = @id_partido;

        IF @cantidad_bd > 4
        BEGIN
            THROW 52504,
                  'TEST FALLIDO: existen más de cuatro espacios asignados.',
                  1;
        END;

        PRINT 'OK - Nunca se asignan más de cuatro espacios.';

        ----------------------------------------------------
        -- 6. ESPACIOS VALIDOS 1..4
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 3 - Verificando números de espacio...';

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Asignacion_Publicitaria
            WHERE id_partido = @id_partido
              AND numero_espacio NOT BETWEEN 1 AND 4
        )
        BEGIN
            THROW 52505,
                  'TEST FALLIDO: existe un número de espacio inválido.',
                  1;
        END;

        PRINT 'OK - Todos los espacios están entre 1 y 4.';


        ----------------------------------------------------
        -- 7. SIN ESPACIOS DUPLICADOS
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 4 - Verificando duplicados...';

        IF EXISTS
        (
            SELECT
                numero_espacio
            FROM dbo.Asignacion_Publicitaria
            WHERE id_partido = @id_partido
            GROUP BY numero_espacio
            HAVING COUNT(*) > 1
        )
        BEGIN
            THROW 52506,
                  'TEST FALLIDO: existe un espacio duplicado.',
                  1;
        END;

        PRINT 'OK - No existen espacios duplicados.';

        ----------------------------------------------------
        -- 8. COSTO VALIDO
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 5 - Verificando costos...';

        IF EXISTS
        (
            SELECT 1
            FROM dbo.Asignacion_Publicitaria
            WHERE id_partido = @id_partido
              AND costo_aplicado < 0
        )
        BEGIN
            THROW 52507,
                  'TEST FALLIDO: existe un costo negativo.',
                  1;
        END;

        PRINT 'OK - Todos los costos son válidos.';

        ---------------------------------------------------
        -- 9. CASO DE PRIORIZACION
        ----------------------------------------------------
        PRINT '';
        PRINT 'TEST 6 - Verificando criterio de priorización...';

        IF @cantidad_candidatos > 4
        BEGIN

            IF @cantidad_bd <> 4
            BEGIN
                THROW 52508,
                      'TEST FALLIDO: con más de 4 candidatos deben elegirse exactamente 4.',
                      1;
            END;

            PRINT
                'OK - Había más de 4 mercados candidatos y se eligieron solamente 4.';
        END
        ELSE
        BEGIN
            PRINT
                'ADVERTENCIA - El juego de datos actual no posee un partido con más de 4 mercados candidatos.';

        END;

        ----------------------------------------------------
        -- 10. SEGUNDA EJECUCION / UPSERT
        ----------------------------------------------------

        PRINT '';
        PRINT 'TEST 7 - Ejecutando nuevamente la generación...';

        DECLARE @cantidad_antes INT;

        SELECT
            @cantidad_antes = COUNT(*)
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = @id_partido;

        EXEC negocio.Generar_Asignacion_Publicitaria
            @id_partido = @id_partido,
            @cantidad_candidatos = @cantidad_candidatos OUTPUT,
            @cantidad_asignados = @cantidad_asignados OUTPUT;

        DECLARE @cantidad_despues INT;

        SELECT
            @cantidad_despues = COUNT(*)
        FROM dbo.Asignacion_Publicitaria
        WHERE id_partido = @id_partido;


        IF @cantidad_antes <> @cantidad_despues
        BEGIN
            THROW 52509,
                  'TEST FALLIDO: la segunda ejecución generó duplicados.',
                  1;
        END;


        PRINT 'OK - Segunda ejecución sin duplicados.';


        ----------------------------------------------------
        -- RESULTADO FINAL
        ----------------------------------------------------

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST ASIGNACION PUBLICITARIA FINALIZADO';
        PRINT '=============================================';


        SELECT
            AP.id_asignacion,
            AP.id_partido,
            AP.numero_espacio,
            AP.id_pieza,
            PP.nombre AS pieza,
            C.descripcion AS campania,
            A.nombre AS anunciante,
            AP.costo_aplicado

        FROM dbo.Asignacion_Publicitaria AP

        INNER JOIN dbo.Pieza_Publicitaria PP
            ON PP.id_pieza = AP.id_pieza

        INNER JOIN dbo.Campania C
            ON C.id_campania = PP.id_campania

        INNER JOIN dbo.Anunciante A
            ON A.id_anunciante = C.id_anunciante

        WHERE AP.id_partido = @id_partido

        ORDER BY AP.numero_espacio;


        SELECT
            @id_partido AS id_partido_probado,
            @cantidad_candidatos AS mercados_candidatos,
            @cantidad_despues AS espacios_asignados,

            CASE
                WHEN @cantidad_candidatos > 4
                    THEN N'SI'
                ELSE N'NO'
            END AS cumple_caso_obligatorio_mas_de_4;

    END TRY

    BEGIN CATCH

        PRINT '';
        PRINT '=============================================';
        PRINT 'TEST ASIGNACION PUBLICITARIA FALLIDO';
        PRINT '=============================================';

        SELECT
            ERROR_NUMBER() AS numero_error,
            ERROR_MESSAGE() AS mensaje_error,
            ERROR_LINE() AS linea_error;


        THROW;

    END CATCH;

END;
GO

EXEC test.Generar_Asignacion_Publicitaria_Test;
GO