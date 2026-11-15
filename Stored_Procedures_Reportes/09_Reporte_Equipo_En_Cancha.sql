/*
    Entrega 9. Estado al cierre de un minuto acumulado del partido.
    Los períodos se ordenan antes que los minutos, incluida la adición.
    Para sustituciones del mismo minuto se usa el orden de registro.
    La reconstrucción depende de la formación y los eventos cargados.
*/
USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 53630, N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO

CREATE PROCEDURE reportes.Reporte_Equipo_En_Cancha
    @id_partido INT,
    @id_seleccion INT,
    @periodo VARCHAR(30),
    @minuto INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @periodos TABLE
    (
        periodo VARCHAR(30) PRIMARY KEY,
        orden TINYINT NOT NULL,
        minuto_inicial TINYINT NOT NULL
    );
    INSERT INTO @periodos (periodo, orden, minuto_inicial)
    VALUES ('PRIMER TIEMPO', 1, 0), ('SEGUNDO TIEMPO', 2, 45),
           ('PRIMER SUPLEMENTARIO', 3, 90), ('SEGUNDO SUPLEMENTARIO', 4, 105);

    SET @periodo = UPPER(LTRIM(RTRIM(@periodo)));

    DECLARE @orden_periodo TINYINT, @minuto_inicial TINYINT, @id_formacion INT;
    SELECT @orden_periodo = orden, @minuto_inicial = minuto_inicial
    FROM @periodos WHERE periodo = @periodo;

    IF @orden_periodo IS NULL
        THROW 53631, N'Indique un período de juego: primer o segundo tiempo, o primer o segundo suplementario.', 1;
    IF @minuto IS NULL OR @minuto NOT BETWEEN @minuto_inicial AND 255
        THROW 53632, N'Indique un minuto acumulado válido para el período.', 1;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Partido
        WHERE id_partido = @id_partido AND @id_seleccion IN (id_seleccion_1, id_seleccion_2)
    )
        THROW 53633, N'El partido debe existir y la selección debe disputarlo.', 1;

    SELECT @id_formacion = id_formacion
    FROM dbo.Formacion
    WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion;

    IF NOT EXISTS
    (
        SELECT 1 FROM dbo.Formacion_Jugador
        WHERE id_formacion = @id_formacion AND es_titular = 1
    )
        THROW 53634, N'La selección no tiene titulares registrados para ese partido.', 1;

    -- Una expulsión sin minuto de un período anterior ya ocurrió.
    -- En el período consultado, su posición respecto del corte es desconocida.
    IF EXISTS
    (
        SELECT 1
        FROM dbo.Incidencia AS i
        JOIN dbo.Jugador AS j ON j.id_jugador = i.id_jugador
        WHERE i.id_partido = @id_partido AND j.id_seleccion = @id_seleccion
          AND i.tipo = 'EXPULSION' AND i.periodo = @periodo AND i.minuto IS NULL
    )
        THROW 53635, N'Hay una expulsión de la selección sin minuto en el período consultado.', 1;

    ;WITH Movimientos AS
    (
        SELECT fj.id_jugador, 0 AS orden_periodo, 0 AS minuto,
               0 AS id_sustitucion, 1 AS en_cancha
        FROM dbo.Formacion_Jugador AS fj
        WHERE fj.id_formacion = @id_formacion AND fj.es_titular = 1

        UNION ALL

        SELECT m.id_jugador, pe.orden, su.minuto, su.id_sustitucion, m.en_cancha
        FROM dbo.Sustitucion AS su
        JOIN @periodos AS pe ON pe.periodo = su.periodo
        CROSS APPLY (VALUES (su.id_jugador_sale, 0), (su.id_jugador_entra, 1))
            AS m (id_jugador, en_cancha)
        WHERE su.id_partido = @id_partido
          AND (pe.orden < @orden_periodo OR (pe.orden = @orden_periodo AND su.minuto <= @minuto))
    ),
    Estado AS
    (
        SELECT id_jugador, en_cancha,
               ROW_NUMBER() OVER
               (
                   PARTITION BY id_jugador
                   ORDER BY orden_periodo DESC, minuto DESC, id_sustitucion DESC
               ) AS orden
        FROM Movimientos
    )
    SELECT @id_partido AS id_partido, @id_seleccion AS id_seleccion, s.pais AS seleccion,
           @periodo AS periodo, @minuto AS minuto, j.id_jugador,
           COALESCE(fj.dorsal_en_cancha, j.dorsal) AS dorsal,
           fj.posicion_en_cancha AS posicion_en_formacion,
           fj.es_titular
    FROM Estado AS e
    JOIN dbo.Jugador AS j ON j.id_jugador = e.id_jugador
    JOIN dbo.Seleccion AS s ON s.id_seleccion = j.id_seleccion
    LEFT JOIN dbo.Formacion_Jugador AS fj
        ON fj.id_formacion = @id_formacion AND fj.id_jugador = j.id_jugador
    WHERE e.orden = 1 AND e.en_cancha = 1 AND j.id_seleccion = @id_seleccion
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Incidencia AS i
          JOIN @periodos AS pe ON pe.periodo = i.periodo
          WHERE i.id_partido = @id_partido AND i.id_jugador = e.id_jugador
            AND i.tipo = 'EXPULSION'
            AND (pe.orden < @orden_periodo OR (pe.orden = @orden_periodo AND i.minuto <= @minuto))
      )
    ORDER BY dorsal, j.id_jugador;
END;
GO

-- EXEC reportes.Reporte_Equipo_En_Cancha @id_partido = 1, @id_seleccion = 1,
--     @periodo = 'SEGUNDO TIEMPO', @minuto = 60;
