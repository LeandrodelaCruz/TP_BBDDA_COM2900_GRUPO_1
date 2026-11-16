/*
    Entrega 9. Fixture completo con filtros opcionales y combinables.
    @fecha corresponde al día local de la sede, guardado en Partido.fecha.
*/
USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 53610, N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO

CREATE PROCEDURE reportes.Reporte_Fixture
    @id_sede INT = NULL,
    @fase VARCHAR(30) = NULL,
    @id_seleccion INT = NULL,
    @fecha DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SET @fase = UPPER(LTRIM(RTRIM(@fase)));

    IF @fase IS NOT NULL AND @fase NOT IN
        ('GRUPOS', 'DIECISEISAVOS', 'OCTAVOS', 'CUARTOS', 'SEMIFINAL', 'TERCER PUESTO', 'FINAL')
        THROW 53611, N'La fase indicada no es válida.', 1;

    SELECT p.id_partido, p.fase, p.fecha, p.horario_local, p.horario_UTC,
           se.id_sede, se.nombre_estadio AS sede, se.ciudad, se.pais AS pais_sede,
           p.id_seleccion_1, s1.pais AS seleccion_1,
           p.id_seleccion_2, s2.pais AS seleccion_2,
           p.resultado_final, p.asistencia_publico
    FROM dbo.Partido AS p
    JOIN dbo.Sede AS se ON se.id_sede = p.id_sede
    JOIN dbo.Seleccion AS s1 ON s1.id_seleccion = p.id_seleccion_1
    JOIN dbo.Seleccion AS s2 ON s2.id_seleccion = p.id_seleccion_2
    WHERE (@id_sede IS NULL OR p.id_sede = @id_sede)
      AND (@fase IS NULL OR p.fase = @fase)
      AND (@id_seleccion IS NULL OR @id_seleccion IN (p.id_seleccion_1, p.id_seleccion_2))
      AND (@fecha IS NULL OR p.fecha = @fecha)
    ORDER BY p.horario_UTC, p.id_partido;
END;
GO

-- EXEC reportes.Reporte_Fixture;
-- EXEC reportes.Reporte_Fixture @id_sede = 1, @fase = 'GRUPOS',
--     @id_seleccion = 2, @fecha = '20260611';
