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
    Simula la tanda de penales de un partido que termino empatado tras los
    120 minutos. Se llama desde negocio.Simular_Partido al finalizar el tiempo
    regular y el suplementario (los partidos con resultado_final del tipo
    'N-N (P-P)', por ejemplo '0-0 (4-3)').

    Reglas:
    - Cada seleccion ejecuta al menos 5 penales, alternando local y visitante.
      Si alguna necesita mas penales para llegar a su marcador, la tanda sigue
      hasta cubrir el mayor de los dos marcadores.
    - Los tiradores son titulares de la formacion que no fueron expulsados ni
      sustituidos durante el partido.
    - Cada penal se registra con abm.Incidencia_Alta:
        GOL DE PENAL  (anotado)  o  PENAL ERRADO (no gol)
      con periodo 'PENALES' y minuto NULL.
    - La cantidad de GOL DE PENAL de cada seleccion coincide con su marcador
      de penales.

    Transaccion: la maneja el procedimiento que lo llama (Simular_Partido).

    Ejemplo:
    EXEC negocio.Simular_Penales
         @id_partido = 1, @id_local = 1, @id_visitante = 2,
         @penales_local = 4, @penales_visitante = 3;
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE negocio.Simular_Penales
    @id_partido        INT,
    @id_local          INT,
    @id_visitante      INT,
    @penales_local     INT,
    @penales_visitante INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @penales_local IS NULL OR @penales_visitante IS NULL
        OR @penales_local < 0 OR @penales_visitante < 0
        OR @penales_local = @penales_visitante
    BEGIN
        RAISERROR(N'Marcador de penales invalido (debe haber ganador).', 16, 1);
        RETURN;
    END

    -- Tiradores de cada seleccion: titulares no expulsados ni sustituidos.
    DECLARE @tir_local TABLE (orden INT PRIMARY KEY, id_jugador INT NOT NULL);
    DECLARE @tir_visit TABLE (orden INT PRIMARY KEY, id_jugador INT NOT NULL);

    INSERT INTO @tir_local (orden, id_jugador)
    SELECT ROW_NUMBER() OVER (ORDER BY NEWID()), fj.id_jugador
    FROM dbo.Formacion f
    JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion
    WHERE f.id_partido = @id_partido
      AND f.id_seleccion = @id_local
      AND fj.es_titular = 1
      AND NOT EXISTS (SELECT 1 FROM dbo.Incidencia i
                      WHERE i.id_partido = @id_partido AND i.tipo = 'EXPULSION'
                        AND i.id_jugador = fj.id_jugador)
      AND NOT EXISTS (SELECT 1 FROM dbo.Sustitucion s
                      WHERE s.id_partido = @id_partido
                        AND s.id_jugador_sale = fj.id_jugador);

    INSERT INTO @tir_visit (orden, id_jugador)
    SELECT ROW_NUMBER() OVER (ORDER BY NEWID()), fj.id_jugador
    FROM dbo.Formacion f
    JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion
    WHERE f.id_partido = @id_partido
      AND f.id_seleccion = @id_visitante
      AND fj.es_titular = 1
      AND NOT EXISTS (SELECT 1 FROM dbo.Incidencia i
                      WHERE i.id_partido = @id_partido AND i.tipo = 'EXPULSION'
                        AND i.id_jugador = fj.id_jugador)
      AND NOT EXISTS (SELECT 1 FROM dbo.Sustitucion s
                      WHERE s.id_partido = @id_partido
                        AND s.id_jugador_sale = fj.id_jugador);

    DECLARE @cant_local INT = (SELECT COUNT(*) FROM @tir_local);
    DECLARE @cant_visit INT = (SELECT COUNT(*) FROM @tir_visit);

    IF @cant_local = 0 OR @cant_visit = 0
    BEGIN
        RAISERROR(N'No hay tiradores disponibles para la tanda de penales.', 16, 1);
        RETURN;
    END

    -- Cantidad de penales por seleccion: minimo 5, o mas si hace falta.
    DECLARE @n_tiros INT = 5;
    IF @penales_local > @n_tiros SET @n_tiros = @penales_local;
    IF @penales_visitante > @n_tiros SET @n_tiros = @penales_visitante;

    DECLARE @r INT = 1, @rem_k INT, @rem_gol_local INT = @penales_local,
            @rem_gol_visit INT = @penales_visitante, @gol BIT,
            @jug INT, @tipo VARCHAR(30), @id_inc INT;

    -- Cada ronda: un penal del local y uno del visitante.
    -- La probabilidad de gol es (goles restantes / penales restantes), asi el
    -- total de goles de cada seleccion queda exactamente en su marcador.
    WHILE @r <= @n_tiros
    BEGIN
        -- Penal local
        SET @rem_k = @n_tiros - @r + 1;
        SET @gol = CASE WHEN ABS(CHECKSUM(NEWID()) % @rem_k) < @rem_gol_local THEN 1 ELSE 0 END;
        SET @rem_gol_local -= @gol;
        SET @jug = (SELECT id_jugador FROM @tir_local WHERE orden = ((@r - 1) % @cant_local) + 1);
        SET @tipo = CASE WHEN @gol = 1 THEN 'GOL DE PENAL' ELSE 'PENAL ERRADO' END;

        EXEC abm.Incidencia_Alta
            @id_partido             = @id_partido,
            @id_jugador             = @jug,
            @tipo                   = @tipo,
            @periodo                = 'PENALES',
            @minuto                 = NULL,
            @motivo                 = N'Tanda de penales',
            @id_jugador_involucrado = NULL,
            @id_incidencia          = @id_inc OUTPUT;

        -- Penal visitante
        SET @rem_k = @n_tiros - @r + 1;
        SET @gol = CASE WHEN ABS(CHECKSUM(NEWID()) % @rem_k) < @rem_gol_visit THEN 1 ELSE 0 END;
        SET @rem_gol_visit -= @gol;
        SET @jug = (SELECT id_jugador FROM @tir_visit WHERE orden = ((@r - 1) % @cant_visit) + 1);
        SET @tipo = CASE WHEN @gol = 1 THEN 'GOL DE PENAL' ELSE 'PENAL ERRADO' END;

        EXEC abm.Incidencia_Alta
            @id_partido             = @id_partido,
            @id_jugador             = @jug,
            @tipo                   = @tipo,
            @periodo                = 'PENALES',
            @minuto                 = NULL,
            @motivo                 = N'Tanda de penales',
            @id_jugador_involucrado = NULL,
            @id_incidencia          = @id_inc OUTPUT;

        SET @r += 1;
    END

    -- Verificacion: los goles de penal coinciden con el marcador de penales.
    IF (SELECT COUNT(*) FROM dbo.Incidencia i
        JOIN dbo.Jugador j ON j.id_jugador = i.id_jugador
        WHERE i.id_partido = @id_partido AND i.periodo = 'PENALES'
          AND i.tipo = 'GOL DE PENAL' AND j.id_seleccion = @id_local) <> @penales_local
       OR (SELECT COUNT(*) FROM dbo.Incidencia i
        JOIN dbo.Jugador j ON j.id_jugador = i.id_jugador
        WHERE i.id_partido = @id_partido AND i.periodo = 'PENALES'
          AND i.tipo = 'GOL DE PENAL' AND j.id_seleccion = @id_visitante) <> @penales_visitante
        THROW 50003, N'Los goles de penal no coinciden con el marcador de penales.', 1;
END;
GO
