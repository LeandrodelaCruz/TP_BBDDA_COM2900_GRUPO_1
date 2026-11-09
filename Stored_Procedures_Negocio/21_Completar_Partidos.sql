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
    Completa todos los partidos con resultado_final cargado que todavia no
    tienen incidencias ni sustituciones: llama a negocio.Simular_Partido para
    cada uno. Cada partido se procesa en forma independiente: si uno falla
    (por ejemplo, falta de formaciones), se informa y se continua con el
    siguiente. Recorrido con WHILE (sin cursores).

    Ejemplo:
    EXEC negocio.Completar_Partidos;
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE negocio.Completar_Partidos
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @id_partido INT, @procesados INT = 0, @fallidos INT = 0;
    DECLARE @mensaje NVARCHAR(2048);

    -- Partidos pendientes (con resultado y sin cargas previas), por id_partido.
    CREATE TABLE #pendientes
    (
        orden       INT NOT NULL PRIMARY KEY,
        id_partido  INT NOT NULL
    );

    INSERT INTO #pendientes (orden, id_partido)
    SELECT ROW_NUMBER() OVER (ORDER BY p.id_partido), p.id_partido
    FROM dbo.Partido p
    WHERE p.resultado_final IS NOT NULL
      AND NOT EXISTS (SELECT 1 FROM dbo.Incidencia i WHERE i.id_partido = p.id_partido)
      AND NOT EXISTS (SELECT 1 FROM dbo.Sustitucion s WHERE s.id_partido = p.id_partido);

    DECLARE @orden INT = (SELECT MIN(orden) FROM #pendientes);

    WHILE @orden IS NOT NULL
    BEGIN
        SELECT @id_partido = id_partido FROM #pendientes WHERE orden = @orden;

        BEGIN TRY
            EXEC negocio.Simular_Partido @id_partido = @id_partido;
            SET @procesados += 1;
        END TRY
        BEGIN CATCH
            SET @fallidos += 1;
            SET @mensaje = CONCAT(N'Partido ', @id_partido, N': ', ERROR_MESSAGE());
            PRINT @mensaje;
        END CATCH

        SET @orden = (SELECT MIN(orden) FROM #pendientes WHERE orden > @orden);
    END

    DROP TABLE #pendientes;

    SELECT @procesados AS partidos_simulados,
           @fallidos   AS partidos_con_error;

    -- Detalle por partido (resultado de la carga)
    SELECT p.id_partido, p.fase, p.resultado_final,
           s1.pais AS local, s2.pais AS visitante,
           (SELECT COUNT(*) FROM dbo.Incidencia i WHERE i.id_partido = p.id_partido) AS total_incidencias,
           (SELECT COUNT(*) FROM dbo.Sustitucion su WHERE su.id_partido = p.id_partido) AS total_sustituciones
    FROM dbo.Partido p
    JOIN dbo.Seleccion s1 ON s1.id_seleccion = p.id_seleccion_1
    JOIN dbo.Seleccion s2 ON s2.id_seleccion = p.id_seleccion_2
    WHERE p.resultado_final IS NOT NULL
    ORDER BY p.id_partido;
END;
GO
