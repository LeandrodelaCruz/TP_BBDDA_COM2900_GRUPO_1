/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Alias observados en los datasets locales. No modifica los datos de origen.
CREATE OR ALTER FUNCTION negocio.Pais_Arbitral_Normalizado(@pais NVARCHAR(80))
RETURNS NVARCHAR(80)
AS
BEGIN
    DECLARE @p NVARCHAR(80)=UPPER(LTRIM(RTRIM(@pais)));
    RETURN CASE @p WHEN N'USA' THEN N'UNITED STATES' WHEN N'UNITED STATES OF AMERICA' THEN N'UNITED STATES'
        WHEN N'IR IRAN' THEN N'IRAN' WHEN N'KOREA REPUBLIC' THEN N'SOUTH KOREA'
        WHEN N'IVORY COAST' THEN N'CÔTE D''IVOIRE' ELSE @p END;
END;
GO

-- Resultado conservador: distingue conflicto potencial y cobertura incompleta.
CREATE OR ALTER PROCEDURE negocio.Evaluar_Cruce_Arbitral
    @id_partido INT, @id_arbitro INT, @advertencia NVARCHAR(2048) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @advertencia=N'';
    DECLARE @fase VARCHAR(30),@pais NVARCHAR(80);
    SELECT @fase=fase FROM dbo.Partido WHERE id_partido=@id_partido;
    SELECT @pais=pais FROM dbo.Arbitro WHERE id_arbitro=@id_arbitro;
    IF @fase IS NULL OR @pais IS NULL THROW 51610,N'Partido o arbitro inexistente.',1;
    IF @fase='GRUPOS' RETURN;

    DECLARE @posibles TABLE(partido INT,posicion TINYINT,seleccion INT,PRIMARY KEY(partido,posicion,seleccion));
    ;WITH Posibles AS
    (
        SELECT p.id_partido AS partido, v.posicion, v.seleccion
        FROM dbo.Partido p CROSS APPLY (VALUES(CAST(1 AS TINYINT),p.id_seleccion_1),
                                              (CAST(2 AS TINYINT),p.id_seleccion_2)) v(posicion,seleccion)
        WHERE v.seleccion IS NOT NULL AND p.fase<>'GRUPOS'
        UNION ALL
        SELECT c.id_partido_destino,c.posicion_destino,x.seleccion
        FROM Posibles x JOIN dbo.Cruce_Partido c ON c.id_partido_origen=x.partido
        JOIN dbo.Partido o ON o.id_partido=c.id_partido_origen
        JOIN dbo.Partido d ON d.id_partido=c.id_partido_destino
        WHERE (o.id_seleccion_ganadora IS NULL
            OR (c.tipo_clasificado='GANADOR' AND x.seleccion=o.id_seleccion_ganadora)
            OR (c.tipo_clasificado='PERDEDOR' AND x.seleccion<>o.id_seleccion_ganadora))
          AND (CASE c.posicion_destino WHEN 1 THEN d.id_seleccion_1 ELSE d.id_seleccion_2 END IS NULL
            OR CASE c.posicion_destino WHEN 1 THEN d.id_seleccion_1 ELSE d.id_seleccion_2 END=x.seleccion)
    )
    INSERT @posibles SELECT DISTINCT partido,posicion,seleccion FROM Posibles OPTION(MAXRECURSION 16);

    DECLARE @ruta TABLE(partido INT,posicion TINYINT,seleccion INT,PRIMARY KEY(partido,posicion,seleccion));
    ;WITH Ruta AS
    (
        SELECT partido,posicion,seleccion FROM @posibles WHERE partido=@id_partido
        UNION ALL
        SELECT c.id_partido_destino,c.posicion_destino,x.seleccion
        FROM Ruta x JOIN dbo.Cruce_Partido c ON c.id_partido_origen=x.partido
        JOIN dbo.Partido o ON o.id_partido=x.partido
        JOIN @posibles d ON d.partido=c.id_partido_destino AND d.posicion=c.posicion_destino AND d.seleccion=x.seleccion
        WHERE o.id_seleccion_ganadora IS NULL
           OR (c.tipo_clasificado='GANADOR' AND x.seleccion=o.id_seleccion_ganadora)
           OR (c.tipo_clasificado='PERDEDOR' AND x.seleccion<>o.id_seleccion_ganadora)
    )
    INSERT @ruta SELECT DISTINCT partido,posicion,seleccion FROM Ruta OPTION(MAXRECURSION 16);
    DECLARE @cruce INT;
    SELECT @cruce=MIN(r.partido) FROM @ruta r JOIN @posibles q ON q.partido=r.partido AND q.posicion<>r.posicion
        JOIN dbo.Seleccion se ON se.id_seleccion=q.seleccion
        WHERE r.partido<>@id_partido AND negocio.Pais_Arbitral_Normalizado(se.pais)=negocio.Pais_Arbitral_Normalizado(@pais);
    IF @cruce IS NOT NULL SET @advertencia=CONCAT(N'POSIBLE CRUCE: ',@pais,
        N' puede enfrentar a un participante en el partido ',@cruce,N'. No impide designar. ');

    -- Subcuadro relevante: destinos estructurales, y todos sus origenes.
    DECLARE @relevantes TABLE(id INT PRIMARY KEY);
    ;WITH Destinos AS (SELECT @id_partido AS id UNION ALL
        SELECT c.id_partido_destino FROM Destinos d JOIN dbo.Cruce_Partido c ON c.id_partido_origen=d.id)
    INSERT @relevantes SELECT DISTINCT id FROM Destinos OPTION(MAXRECURSION 16);
    ;WITH Origenes AS (SELECT id FROM @relevantes UNION ALL
        SELECT c.id_partido_origen FROM Origenes d JOIN dbo.Cruce_Partido c ON c.id_partido_destino=d.id)
    INSERT @relevantes SELECT DISTINCT id FROM Origenes WHERE id NOT IN(SELECT id FROM @relevantes) OPTION(MAXRECURSION 16);
    IF EXISTS (SELECT 1 FROM @relevantes r JOIN dbo.Partido p ON p.id_partido=r.id
        WHERE (p.fase NOT IN ('DIECISEISAVOS','GRUPOS') AND
               (SELECT COUNT(*) FROM dbo.Cruce_Partido c WHERE c.id_partido_destino=p.id_partido)<>2)
           OR (p.fase IN ('DIECISEISAVOS','OCTAVOS','CUARTOS') AND
               NOT EXISTS(SELECT 1 FROM dbo.Cruce_Partido c WHERE c.id_partido_origen=p.id_partido AND c.tipo_clasificado='GANADOR'))
           OR (p.fase='SEMIFINAL' AND (SELECT COUNT(*) FROM dbo.Cruce_Partido c WHERE c.id_partido_origen=p.id_partido)<>2)
           OR (p.fase='DIECISEISAVOS' AND (p.id_seleccion_1 IS NULL OR p.id_seleccion_2 IS NULL)))
        SET @advertencia+=N'EVALUACION INCOMPLETA: faltan cruces o participantes de entrada. ';
    IF EXISTS (SELECT 1 FROM @relevantes r JOIN dbo.Partido p ON p.id_partido=r.id
               WHERE p.id_seleccion_ganadora IS NULL AND p.fase NOT IN ('FINAL','TERCER PUESTO'))
        SET @advertencia+=N'Hay avances sin confirmar: los cruces se consideran potenciales segun el cuadro.';
END;
GO
