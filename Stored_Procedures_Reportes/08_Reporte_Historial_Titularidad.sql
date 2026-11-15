/*
    Entrega 9. Una fila por jugador registrado en la formación de un partido.
    ingreso_registrado indica que existe una sustitución que lo hizo entrar.
    Al instalar, se elige la fuente de nombre y apellido según el esquema.
    Si se aplica el cifrado después de instalar, volver a ejecutar este script.
*/
USE MUNDIALDEFUTBOL;
GO

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 53620, N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO

DECLARE @fuente_jugador NVARCHAR(128) = N'dbo.Jugador';
DECLARE @nombres NVARCHAR(150) = N'j.nombre, j.apellido';

IF COL_LENGTH(N'dbo.Jugador', N'nombre') IS NULL
   OR COL_LENGTH(N'dbo.Jugador', N'apellido') IS NULL
BEGIN
    IF OBJECT_ID(N'dbo.vw_Jugador_Descifrado', N'V') IS NOT NULL
        SET @fuente_jugador = N'dbo.vw_Jugador_Descifrado';
    ELSE
        SET @nombres = N'CAST(NULL AS NVARCHAR(60)) AS nombre, CAST(NULL AS NVARCHAR(60)) AS apellido';
END;

-- Se elige la variante al instalar. La consulta se ejecuta como el llamador.
DECLARE @sql NVARCHAR(MAX) = N'
CREATE OR ALTER PROCEDURE reportes.Reporte_Historial_Titularidad
    @id_jugador INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT fj.id_jugador, p.id_partido, p.fecha, p.horario_local, p.fase,
           f.id_seleccion, s.pais AS seleccion,
           r.id_seleccion AS id_rival, r.pais AS rival,
           fj.dorsal_en_cancha, fj.posicion_en_cancha, fj.es_titular,
           CONVERT(BIT, CASE WHEN EXISTS
           (
               SELECT 1
               FROM dbo.Sustitucion AS su
               WHERE su.id_partido = p.id_partido
                 AND su.id_jugador_entra = fj.id_jugador
           ) THEN 1 ELSE 0 END) AS ingreso_registrado,
           ' + @nombres + N'
    FROM dbo.Formacion_Jugador AS fj
    JOIN ' + @fuente_jugador + N' AS j ON j.id_jugador = fj.id_jugador
    JOIN dbo.Formacion AS f ON f.id_formacion = fj.id_formacion
    JOIN dbo.Partido AS p ON p.id_partido = f.id_partido
    JOIN dbo.Seleccion AS s ON s.id_seleccion = f.id_seleccion
    JOIN dbo.Seleccion AS r ON r.id_seleccion =
        CASE f.id_seleccion
            WHEN p.id_seleccion_1 THEN p.id_seleccion_2
            WHEN p.id_seleccion_2 THEN p.id_seleccion_1
        END
    WHERE @id_jugador IS NULL OR fj.id_jugador = @id_jugador
    ORDER BY fj.id_jugador, p.horario_UTC, p.id_partido;
END;';
EXEC sys.sp_executesql @sql;
GO

-- EXEC reportes.Reporte_Historial_Titularidad @id_jugador = 1;
-- EXEC reportes.Reporte_Historial_Titularidad;
