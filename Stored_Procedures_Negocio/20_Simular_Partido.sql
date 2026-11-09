/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comision: Com: 01-2900
    Grupo 01:
    - Caro, Nicolas Dario
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodriguez Elias Uriel

    Descripcion:
    Simula un partido (90 minutos, mas tiempo suplementario hasta el minuto
    120 si la fase es eliminatoria y el resultado esta empatado) para un
    id_partido dado. Genera una linea de tiempo minuto a minuto y registra
    cada evento directamente con abm.Incidencia_Alta y abm.Sustitucion_Alta.
    Los registros cargados NO se borran al finalizar.

    Reglas respetadas:
    - Goles: coinciden con partido.resultado_final ("LOCAL-VISITANTE").
      id_seleccion_1 = local, id_seleccion_2 = visitante.
    - Todo protagonista pertenece a la formacion de su seleccion y esta en
      cancha en ese minuto.
    - Sustituciones: sale un jugador en cancha; entra un suplente (no titular)
      de la misma seleccion que nunca jugo.
    - Un jugador expulsado (roja directa o segunda amarilla) sale de la cancha
      y no vuelve a participar.
    - Al final debe haber al menos una AMONESTACION o EXPULSION.
    - Periodo derivado del minuto: <=45 PRIMER TIEMPO, <=90 SEGUNDO TIEMPO,
      <=105 PRIMER SUPLEMENTARIO, <=120 SEGUNDO SUPLEMENTARIO.

    Requisitos previos:
    - El partido tiene resultado_final con formato 'N-N'.
    - Existe formacion con 11 titulares para ambas selecciones.
    - El partido no tiene incidencias ni sustituciones cargadas previamente.

    Transaccion: todo el proceso es atomico. Ante un error no queda nada cargado.

    Ejemplo:
    EXEC negocio.Simular_Partido @id_partido = 1;
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE negocio.Simular_Partido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @resultado VARCHAR(20), @id_local INT, @id_visitante INT;
    DECLARE @goles_local INT, @goles_visitante INT, @guion INT;
    DECLARE @fase VARCHAR(30), @hay_suplementario BIT = 0;
    DECLARE @pos_parentesis INT, @texto_penales VARCHAR(20), @guion_penales INT;
    DECLARE @penales_local INT = NULL, @penales_visitante INT = NULL;

    -- =========================================================
    -- 1) Validar partido, resultado y formaciones
    -- =========================================================
    SELECT @resultado   = resultado_final,
           @fase        = fase,
           @id_local    = id_seleccion_1,
           @id_visitante = id_seleccion_2
    FROM dbo.Partido
    WHERE id_partido = @id_partido;

    IF @id_local IS NULL
        SET @errores += N'- No existe el partido indicado. ';

    -- Formato: 'N-N' o 'N-N (P-P)' cuando hubo tanda de penales.
    IF @resultado LIKE '%(%'
    BEGIN
        SET @pos_parentesis = CHARINDEX('(', @resultado);
        SET @texto_penales  = LTRIM(RTRIM(SUBSTRING(@resultado, @pos_parentesis + 1, 20)));
        SET @texto_penales  = LEFT(@texto_penales, LEN(@texto_penales) - 1);
        SET @guion_penales  = CHARINDEX('-', @texto_penales);
        SET @penales_local     = TRY_CAST(LEFT(@texto_penales, @guion_penales - 1) AS INT);
        SET @penales_visitante = TRY_CAST(SUBSTRING(@texto_penales, @guion_penales + 1, 20) AS INT);
        SET @resultado = LTRIM(RTRIM(LEFT(@resultado, @pos_parentesis - 1)));
        IF @penales_local IS NULL OR @penales_visitante IS NULL
           OR @penales_local = @penales_visitante
            SET @errores += N'- resultado_final tiene una tanda de penales invalida. ';
    END

    SET @guion = CHARINDEX('-', @resultado);
    IF @resultado IS NULL OR @guion <= 1
        SET @errores += N'- resultado_final no tiene formato N-N. ';
    ELSE
    BEGIN
        SET @goles_local     = TRY_CAST(LEFT(@resultado, @guion - 1) AS INT);
        SET @goles_visitante = TRY_CAST(SUBSTRING(@resultado, @guion + 1, 20) AS INT);
        IF @goles_local IS NULL OR @goles_visitante IS NULL
            SET @errores += N'- resultado_final no tiene formato N-N. ';
    END

    IF @id_local IS NOT NULL
    BEGIN
        IF (SELECT COUNT(*) FROM dbo.Formacion f
            JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion
            WHERE f.id_partido = @id_partido AND f.id_seleccion = @id_local AND fj.es_titular = 1) <> 11
            SET @errores += N'- La seleccion local no tiene 11 titulares cargados. ';

        IF (SELECT COUNT(*) FROM dbo.Formacion f
            JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion
            WHERE f.id_partido = @id_partido AND f.id_seleccion = @id_visitante AND fj.es_titular = 1) <> 11
            SET @errores += N'- La seleccion visitante no tiene 11 titulares cargados. ';

        IF EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_partido = @id_partido)
           OR EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_partido = @id_partido)
            SET @errores += N'- El partido ya tiene incidencias o sustituciones cargadas. ';
    END

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        BEGIN TRANSACTION;

        -- =========================================================
        -- 2) Estado de jugadores (formaciones del partido)
        -- =========================================================
        CREATE TABLE #jugadores
        (
            id_jugador  INT PRIMARY KEY,
            id_seleccion INT NOT NULL,
            es_titular  BIT NOT NULL,
            en_cancha   BIT NOT NULL,
            expulsado   BIT NOT NULL DEFAULT 0,
            amarillas   TINYINT NOT NULL DEFAULT 0,
            ya_jugo     BIT NOT NULL DEFAULT 0
        );

        INSERT INTO #jugadores (id_jugador, id_seleccion, es_titular, en_cancha)
        SELECT fj.id_jugador, f.id_seleccion, fj.es_titular, fj.es_titular
        FROM dbo.Formacion f
        JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion
        WHERE f.id_partido = @id_partido;

        -- =========================================================
        -- 3) Plan de eventos (minuto 1..90; tiempo suplementario 91..120 si corresponde)
        -- =========================================================
        CREATE TABLE #plan
        (
            id        INT IDENTITY(1,1) PRIMARY KEY,
            minuto    TINYINT NOT NULL,
            tipo      VARCHAR(30) NOT NULL,
            id_seleccion INT NOT NULL
        );

        DECLARE @n INT = 0;

        WHILE @n < @goles_local
        BEGIN
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(1 + ABS(CHECKSUM(NEWID()) % 90) AS TINYINT), 'GOL', @id_local);
            SET @n += 1;
        END

        SET @n = 0;
        WHILE @n < @goles_visitante
        BEGIN
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(1 + ABS(CHECKSUM(NEWID()) % 90) AS TINYINT), 'GOL', @id_visitante);
            SET @n += 1;
        END

        -- Tarjetas: entre 2 y 4 amonestaciones (la segunda amarilla de un
        -- mismo jugador se registra como EXPULSION).
        DECLARE @amonest INT = 2 + ABS(CHECKSUM(NEWID()) % 3);
        SET @n = 0;
        WHILE @n < @amonest
        BEGIN
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(1 + ABS(CHECKSUM(NEWID()) % 90) AS TINYINT), 'AMONESTACION',
                    CASE WHEN ABS(CHECKSUM(NEWID()) % 2) = 0 THEN @id_local ELSE @id_visitante END);
            SET @n += 1;
        END

        -- ~25% de probabilidad de una expulsion directa (roja)
        IF ABS(CHECKSUM(NEWID()) % 4) = 0
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(1 + ABS(CHECKSUM(NEWID()) % 90) AS TINYINT), 'EXPULSION',
                    CASE WHEN ABS(CHECKSUM(NEWID()) % 2) = 0 THEN @id_local ELSE @id_visitante END);

        -- Sustituciones regulares: entre 2 y 5 por equipo, en minutos 10..90.
        -- Varias pueden caer en la misma ventana (ver ventana al ejecutar el plan).
        DECLARE @n_sus_local INT = 2 + ABS(CHECKSUM(NEWID()) % 4);
        DECLARE @n_sus_visit INT = 2 + ABS(CHECKSUM(NEWID()) % 4);

        SET @n = 0;
        WHILE @n < @n_sus_local
        BEGIN
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(10 + ABS(CHECKSUM(NEWID()) % 81) AS TINYINT), 'SUSTITUCION', @id_local);
            SET @n += 1;
        END

        SET @n = 0;
        WHILE @n < @n_sus_visit
        BEGIN
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(10 + ABS(CHECKSUM(NEWID()) % 81) AS TINYINT), 'SUSTITUCION', @id_visitante);
            SET @n += 1;
        END

        -- Tiempo suplementario: solo en eliminatorias empatadas.
        -- 1 sustitucion por equipo en minutos 91..120.
        SET @hay_suplementario = CASE WHEN @goles_local = @goles_visitante
                                        AND @fase NOT IN (N'GRUPOS', N'FASE DE GRUPOS')
                                      THEN 1 ELSE 0 END;

        IF @hay_suplementario = 1
        BEGIN
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(91 + ABS(CHECKSUM(NEWID()) % 30) AS TINYINT), 'SUSTITUCION', @id_local);
            INSERT INTO #plan (minuto, tipo, id_seleccion)
            VALUES (CAST(91 + ABS(CHECKSUM(NEWID()) % 30) AS TINYINT), 'SUSTITUCION', @id_visitante);
        END

        -- =========================================================
        -- 4) Ejecucion cronologica del plan: cada evento se registra
        --    con su ABM y se actualiza el estado de cancha
        -- =========================================================
        DECLARE @id_inc INT, @id_sus INT, @periodo VARCHAR(30), @ventana TINYINT;
        DECLARE @minuto TINYINT, @tipo VARCHAR(30), @sel INT;
        DECLARE @jug INT, @inv INT, @sale INT, @entra INT;
        DECLARE @motivo VARCHAR(200), @id_amarilla INT;
        DECLARE @id_plan INT;

        -- Estado de ventana por equipo: ventana_actual arranca en 0 (sin cambios)
        -- y bloque_usado en 0 (ningun bloque usado todavia).
        CREATE TABLE #ventana_equipo
        (
            id_seleccion  INT NOT NULL PRIMARY KEY,
            ventana_actual INT NOT NULL,
            bloque_usado   TINYINT NOT NULL
        );
        INSERT INTO #ventana_equipo (id_seleccion, ventana_actual, bloque_usado)
        VALUES (@id_local, 0, 0), (@id_visitante, 0, 0);

        -- Copia ordenada cronologicamente; el recorrido es por la clave orden.
        CREATE TABLE #plan_orden
        (
            orden       INT NOT NULL PRIMARY KEY,
            minuto      TINYINT NOT NULL,
            tipo        VARCHAR(30) NOT NULL,
            id_seleccion INT NOT NULL
        );

        INSERT INTO #plan_orden (orden, minuto, tipo, id_seleccion)
        SELECT ROW_NUMBER() OVER (ORDER BY minuto, id), minuto, tipo, id_seleccion
        FROM #plan;

        SELECT @id_plan = MIN(orden) FROM #plan_orden;

        WHILE @id_plan IS NOT NULL
        BEGIN
            SELECT @minuto = minuto, @tipo = tipo, @sel = id_seleccion
            FROM #plan_orden WHERE orden = @id_plan;

            SET @periodo = CASE WHEN @minuto <= 45  THEN 'PRIMER TIEMPO'
                                WHEN @minuto <= 90  THEN 'SEGUNDO TIEMPO'
                                WHEN @minuto <= 105 THEN 'PRIMER SUPLEMENTARIO'
                                ELSE 'SEGUNDO SUPLEMENTARIO' END;

            IF @tipo = 'GOL'
            BEGIN
                SELECT TOP (1) @jug = id_jugador
                FROM #jugadores
                WHERE id_seleccion = @sel AND en_cancha = 1
                ORDER BY NEWID();

                SELECT TOP (1) @inv = id_jugador
                FROM #jugadores
                WHERE id_seleccion = @sel AND en_cancha = 1 AND id_jugador <> @jug
                ORDER BY NEWID();

                EXEC abm.Incidencia_Alta
                    @id_partido             = @id_partido,
                    @id_jugador             = @jug,
                    @tipo                   = 'GOL',
                    @periodo                = @periodo,
                    @minuto                 = @minuto,
                    @motivo                 = N'Gol simulado',
                    @id_jugador_involucrado = @inv,
                    @id_incidencia          = @id_inc OUTPUT;
            END

            ELSE IF @tipo IN ('AMONESTACION', 'EXPULSION')
            BEGIN
                SELECT TOP (1) @jug = id_jugador
                FROM #jugadores
                WHERE id_seleccion = @sel AND en_cancha = 1 AND expulsado = 0
                ORDER BY NEWID();

                IF @jug IS NOT NULL
                BEGIN
                    IF @tipo = 'AMONESTACION' AND (SELECT amarillas FROM #jugadores WHERE id_jugador = @jug) >= 1
                    BEGIN
                        -- Segunda amarilla: primero se registra la amonestacion y luego la
                        -- expulsion, que queda vinculada al id de esa amonestacion.
                        UPDATE #jugadores SET amarillas = amarillas + 1 WHERE id_jugador = @jug;

                        EXEC abm.Incidencia_Alta
                            @id_partido             = @id_partido,
                            @id_jugador             = @jug,
                            @tipo                   = 'AMONESTACION',
                            @periodo                = @periodo,
                            @minuto                 = @minuto,
                            @motivo                 = N'Segunda amarilla simulada (amonestacion previa a la expulsion)',
                            @id_jugador_involucrado = NULL,
                            @id_incidencia          = @id_amarilla OUTPUT;

                        UPDATE #jugadores SET expulsado = 1, en_cancha = 0 WHERE id_jugador = @jug;

                        SET @motivo = CONCAT(N'Expulsion por segunda amarilla (ver amonestacion id ',
                                             @id_amarilla, N')');

                        EXEC abm.Incidencia_Alta
                            @id_partido             = @id_partido,
                            @id_jugador             = @jug,
                            @tipo                   = 'EXPULSION',
                            @periodo                = @periodo,
                            @minuto                 = @minuto,
                            @motivo                 = @motivo,
                            @id_jugador_involucrado = NULL,
                            @id_incidencia          = @id_inc OUTPUT;
                    END
                    ELSE
                    BEGIN
                        IF @tipo = 'AMONESTACION'
                            UPDATE #jugadores SET amarillas = amarillas + 1 WHERE id_jugador = @jug;
                        ELSE
                            UPDATE #jugadores SET expulsado = 1, en_cancha = 0 WHERE id_jugador = @jug;

                        SET @motivo = CASE WHEN @tipo = 'EXPULSION'
                                           THEN N'Tarjeta roja simulada' ELSE N'Tarjeta amarilla simulada' END;

                        EXEC abm.Incidencia_Alta
                            @id_partido             = @id_partido,
                            @id_jugador             = @jug,
                            @tipo                   = @tipo,
                            @periodo                = @periodo,
                            @minuto                 = @minuto,
                            @motivo                 = @motivo,
                            @id_jugador_involucrado = NULL,
                            @id_incidencia          = @id_inc OUTPUT;
                    END
                END
            END

            ELSE IF @tipo = 'SUSTITUCION'
            BEGIN
                SET @sale = NULL;
                SET @entra = NULL;

                SELECT TOP (1) @sale = id_jugador
                FROM #jugadores
                WHERE id_seleccion = @sel AND en_cancha = 1 AND expulsado = 0
                ORDER BY NEWID();

                SELECT TOP (1) @entra = id_jugador
                FROM #jugadores
                WHERE id_seleccion = @sel AND es_titular = 0 AND en_cancha = 0
                  AND ya_jugo = 0 AND expulsado = 0
                ORDER BY NEWID();

                IF @sale IS NOT NULL AND @entra IS NOT NULL
                BEGIN
                    UPDATE #jugadores SET en_cancha = 0, ya_jugo = 1 WHERE id_jugador = @sale;
                    UPDATE #jugadores SET en_cancha = 1, ya_jugo = 1 WHERE id_jugador = @entra;

                    -- Ventana propia de cada equipo. Se avanza una ventana cuando el
                    -- equipo cambia de bloque de 30 minutos (1..30, 31..60, 61..90,
                    -- 91..120). Varias sustituciones dentro del mismo bloque comparten
                    -- numero de ventana; el equipo 2 no depende del equipo 1.
                    DECLARE @bloque TINYINT = CASE WHEN @minuto <= 30 THEN 1
                                                   WHEN @minuto <= 60 THEN 2
                                                   WHEN @minuto <= 90 THEN 3
                                                   ELSE 4 END;
                    UPDATE #ventana_equipo
                    SET ventana_actual = ventana_actual + 1, bloque_usado = @bloque
                    WHERE id_seleccion = @sel AND bloque_usado <> @bloque;
                    -- Primera sustitucion del equipo: ventana 1 (bloque inicial)
                    SELECT @ventana = ventana_actual FROM #ventana_equipo WHERE id_seleccion = @sel;

                    EXEC abm.Sustitucion_Alta
                        @id_partido       = @id_partido,
                        @id_jugador_sale  = @sale,
                        @id_jugador_entra = @entra,
                        @minuto           = @minuto,
                        @periodo          = @periodo,
                        @numero_ventana   = @ventana,
                        @motivo           = N'Cambio tactico simulado',
                        @id_sustitucion   = @id_sus OUTPUT;
                END
            END

            SELECT @id_plan = MIN(orden) FROM #plan_orden WHERE orden > @id_plan;
        END

        -- =========================================================
        -- 5) Verificaciones finales
        -- =========================================================
        IF NOT EXISTS (SELECT 1 FROM dbo.Incidencia
                       WHERE id_partido = @id_partido AND tipo IN ('AMONESTACION', 'EXPULSION'))
            THROW 50001, N'La simulacion no genero ninguna amonestacion ni expulsion.', 1;

        IF (SELECT COUNT(*) FROM dbo.Incidencia i
            JOIN dbo.Jugador j ON j.id_jugador = i.id_jugador
            WHERE i.id_partido = @id_partido AND i.tipo = 'GOL' AND j.id_seleccion = @id_local) <> @goles_local
           OR (SELECT COUNT(*) FROM dbo.Incidencia i
            JOIN dbo.Jugador j ON j.id_jugador = i.id_jugador
            WHERE i.id_partido = @id_partido AND i.tipo = 'GOL' AND j.id_seleccion = @id_visitante) <> @goles_visitante
            THROW 50002, N'Los goles simulados no coinciden con resultado_final.', 1;

        -- =========================================================
        -- 6) Tanda de penales (solo si el resultado la informa)
        -- =========================================================
        IF @penales_local IS NOT NULL AND @penales_visitante IS NOT NULL
            EXEC negocio.Simular_Penales
                @id_partido        = @id_partido,
                @id_local          = @id_local,
                @id_visitante      = @id_visitante,
                @penales_local     = @penales_local,
                @penales_visitante = @penales_visitante;

        COMMIT TRANSACTION;

        SELECT @id_partido AS id_partido,
               @resultado AS resultado_final,
               (SELECT COUNT(*) FROM dbo.Incidencia WHERE id_partido = @id_partido) AS incidencias,
               (SELECT COUNT(*) FROM dbo.Sustitucion WHERE id_partido = @id_partido) AS sustituciones;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH
END;
GO
