/*
    Universidad: Universidad Nacional de La Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 01/11/2026

    Descripción:
    Test de importación de formaciones desde JSON (formaciones_mundial_2026.json).
    Se ejecuta la importación dos veces para verificar la lógica de UPSERT
    basada en la clave natural (id_partido, id_seleccion).

    Precondición:
    - Los partidos deben estar cargados previamente (Importar_Partido_JSON),
      porque el SP resuelve el partido por clave natural
      (fecha, horario_UTC, id_seleccion_1, id_seleccion_2).
    - Las selecciones deben existir en dbo.Seleccion (pais).

    Resultado esperado:
    - Primera ejecución: las formaciones inexistentes se insertan.
      (Si la DB ya tiene formaciones cargadas, se actualizan en vez de insertarse.)
    - Segunda ejecución: TODAS las formaciones ya existentes se actualizan,
      insertadas = 0.
    - La consulta final de duplicados debe devolver 0 filas.
    - NO se inserta nada en dbo.Formacion_Jugador (el JSON no trae jugadores).
*/


USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Importar_Formacion_JSON_Test
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== PRIMERA IMPORTACION DE FORMACIONES =====';
    EXEC importacion.Importar_Formacion_JSON
        @archivo = @archivo;

    PRINT '===== SEGUNDA IMPORTACION - PRUEBA DE UPSERT =====';
    EXEC importacion.Importar_Formacion_JSON
        @archivo = @archivo;

    PRINT '===== FORMACIONES CARGADAS (RESUMEN POR ESQUEMA TACTICO) =====';
    SELECT
        esquema_tactico,
        COUNT(*) AS cantidad_formaciones
    FROM dbo.Formacion
    GROUP BY esquema_tactico
    ORDER BY esquema_tactico;

    PRINT '===== FORMACIONES CARGADAS (DETALLE) =====';
    SELECT
        f.id_formacion,
        p.id_partido,
        p.fecha,
        p.horario_UTC,
        p.fase,
        sl.pais                     AS seleccion_local,
        sv.pais                     AS seleccion_visitante,
        s.pais                      AS seleccion_formacion,
        f.esquema_tactico
    FROM dbo.Formacion f
    INNER JOIN dbo.Partido   p  ON p.id_partido    = f.id_partido
    INNER JOIN dbo.Seleccion s  ON s.id_seleccion  = f.id_seleccion
    INNER JOIN dbo.Seleccion sl ON sl.id_seleccion = p.id_seleccion_1
    INNER JOIN dbo.Seleccion sv ON sv.id_seleccion = p.id_seleccion_2
    ORDER BY p.fecha, p.horario_UTC, s.pais;

    PRINT '===== DUPLICADOS EN FORMACION (RESULTADO ESPERADO: 0 FILAS) =====';
    SELECT
        id_partido,
        id_seleccion,
        COUNT(*) AS cantidad
    FROM dbo.Formacion
    GROUP BY id_partido, id_seleccion
    HAVING COUNT(*) > 1;

    PRINT '===== VERIFICACION: Formacion_Jugador NO debe tener filas nuevas =====';
    SELECT
        COUNT(*) AS total_formacion_jugador
    FROM dbo.Formacion_Jugador;
END;
GO

/*
    Ruta esperada si SQL Server corre en el contenedor Docker "sqlserver":
    /var/opt/mssql/import/formaciones_mundial_2026.json

    Si corrés el motor en Windows local, reemplazá por la ruta real, por ej.:
    N'C:\Import\formaciones_mundial_2026.json'
*/
EXEC test.Importar_Formacion_JSON_Test
    @archivo = N'C:\TP_BBDDA_COM2900_GRUPO_1-main\Archivos_Importacion\formaciones_mundial_2026.json';
GO