/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 01/11/2026

    Descripción:
    Test de importación de partidos desde JSON (partidos_mundial_2026.json).
    Se ejecuta la importación dos veces para verificar la lógica de UPSERT
    basada en la clave natural (fecha, horario_UTC, id_seleccion_1, id_seleccion_2).

    Resultado esperado:
    - Primera ejecución: los partidos inexistentes se insertan.
      (Si la DB ya tiene partidos cargados, se actualizan en vez de insertarse.)
    - Segunda ejecución: TODOS los partidos ya existentes se actualizan,
      insertados = 0.
    - La consulta final de duplicados debe devolver 0 filas.
*/


USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Importar_Partido_JSON_Test
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== PRIMERA IMPORTACION DE PARTIDOS =====';
    EXEC importacion.Importar_Partido_JSON
        @archivo = @archivo;

    PRINT '===== SEGUNDA IMPORTACION - PRUEBA DE UPSERT =====';
    EXEC importacion.Importar_Partido_JSON
        @archivo = @archivo;

    PRINT '===== PARTIDOS CARGADOS (RESUMEN POR FASE) =====';
    SELECT
        fase,
        COUNT(*) AS cantidad_partidos
    FROM dbo.Partido
    GROUP BY fase
    ORDER BY fase;

    PRINT '===== PARTIDOS CARGADOS (DETALLE) =====';
    SELECT
        p.id_partido,
        s.nombre_estadio            AS sede,
        p.fecha,
        p.horario_local,
        p.horario_UTC,
        p.fase,
        sl.pais                     AS seleccion_local,
        sv.pais                     AS seleccion_visitante,
        p.resultado_final,
        p.asistencia_publico
    FROM dbo.Partido p
    INNER JOIN dbo.Sede      s  ON s.id_sede       = p.id_sede
    INNER JOIN dbo.Seleccion sl ON sl.id_seleccion = p.id_seleccion_1
    INNER JOIN dbo.Seleccion sv ON sv.id_seleccion = p.id_seleccion_2
    ORDER BY p.fecha, p.horario_UTC;

    PRINT '===== DUPLICADOS (RESULTADO ESPERADO: 0 FILAS) =====';
    SELECT
        fecha,
        horario_UTC,
        id_seleccion_1,
        id_seleccion_2,
        COUNT(*) AS cantidad
    FROM dbo.Partido
    GROUP BY fecha, horario_UTC, id_seleccion_1, id_seleccion_2
    HAVING COUNT(*) > 1;
END;
GO

/*
    Ruta esperada si SQL Server corre en el contenedor Docker "sqlserver":
    /var/opt/mssql/import/partidos_mundial_2026.json

    Si corrés el motor en Windows local, reemplazá por la ruta real, por ej.:
    N'C:\Import\partidos_mundial_2026.json'
*/
EXEC test.Importar_Partido_JSON_Test
    @archivo = N'C:\TP_BBDDA_COM2900_GRUPO_1-main\Archivos_Importacion\partidos_mundial_2026.json';
GO
