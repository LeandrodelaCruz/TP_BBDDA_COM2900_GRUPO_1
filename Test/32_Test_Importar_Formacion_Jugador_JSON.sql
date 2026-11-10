/*
    Universidad: Universidad Nacional de La Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 02/11/2026

    Descripción:
    Test de importación de la relación FORMACION_JUGADOR desde JSON
    (alineaciones_extraidas.json).
    Se ejecuta la importación dos veces para verificar la lógica de UPSERT
    basada en la clave natural (id_formacion, id_jugador).

    Precondición:
    - Los partidos deben estar cargados previamente (Importar_Partido_JSON),
      porque el SP resuelve el partido por clave natural
      (fecha, horario_UTC, id_seleccion_1, id_seleccion_2).
    - Las selecciones deben existir en dbo.Seleccion (pais).
    - Las FORMACIONES (cabecera dbo.Formacion) deben existir previamente para
      cada (id_partido, id_seleccion), porque el SP NO crea la cabecera;
      sólo inserta/actualiza las filas de Formacion_Jugador.
    - Los JUGADORES deben existir en dbo.Jugador (nombre + apellido por
      selección), porque el SP los resuelve por nombre/apellido.

    Resultado esperado:
    - Primera ejecución: las filas inexistentes de Formacion_Jugador se insertan.
      (Si la DB ya tiene esas filas cargadas, se actualizan en vez de insertarse.)
    - Segunda ejecución: TODAS las filas ya existentes se actualizan,
      insertadas = 0 (salvo que la primera ejecución haya dejado errores
      por reglas de negocio del ABM, p.ej. más de 11 titulares, en cuyo caso
      esos jugadores vuelven a fallar y se reportan como errores).
    - La consulta final de duplicados debe devolver 0 filas.
    - Cada formación (partido + selección) debe tener como máximo 11 titulares
      y como máximo 26 jugadores convocados (si el ABM lo permite).
*/


USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Importar_Formacion_Jugador_JSON_Test
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== PRIMERA IMPORTACION DE FORMACION_JUGADOR =====';
    EXEC importacion.Importar_Formacion_Jugador_JSON
        @archivo = @archivo;

    PRINT '===== SEGUNDA IMPORTACION - PRUEBA DE UPSERT =====';
    EXEC importacion.Importar_Formacion_Jugador_JSON
        @archivo = @archivo;

    PRINT '===== FORMACION_JUGADOR CARGADAS (RESUMEN POR POSICION) =====';
    SELECT
        posicion_en_cancha,
        COUNT(*) AS cantidad_jugadores
    FROM dbo.Formacion_Jugador
    GROUP BY posicion_en_cancha
    ORDER BY posicion_en_cancha;

    PRINT '===== FORMACION_JUGADOR CARGADAS (RESUMEN POR TITULARIDAD) =====';
    SELECT
        es_titular,
        COUNT(*) AS cantidad_jugadores
    FROM dbo.Formacion_Jugador
    GROUP BY es_titular
    ORDER BY es_titular DESC;

    PRINT '===== FORMACION_JUGADOR CARGADAS (DETALLE POR PARTIDO/SELECCION) =====';
    SELECT
        p.id_partido,
        p.fecha,
        p.horario_UTC,
        p.fase,
        sl.pais                     AS seleccion_local,
        sv.pais                     AS seleccion_visitante,
        s.pais                      AS seleccion_formacion,
        f.esquema_tactico,
        SUM(CASE WHEN fj.es_titular = 1 THEN 1 ELSE 0 END) AS titulares,
        SUM(CASE WHEN fj.es_titular = 0 THEN 1 ELSE 0 END) AS suplentes,
        COUNT(*)                                           AS total_convocados
    FROM dbo.Formacion f
    INNER JOIN dbo.Partido             p  ON p.id_partido    = f.id_partido
    INNER JOIN dbo.Seleccion           s  ON s.id_seleccion  = f.id_seleccion
    INNER JOIN dbo.Seleccion           sl ON sl.id_seleccion = p.id_seleccion_1
    INNER JOIN dbo.Seleccion           sv ON sv.id_seleccion = p.id_seleccion_2
    LEFT  JOIN dbo.Formacion_Jugador   fj ON fj.id_formacion = f.id_formacion
    GROUP BY
        p.id_partido, p.fecha, p.horario_UTC, p.fase,
        sl.pais, sv.pais, s.pais, f.esquema_tactico
    ORDER BY p.fecha, p.horario_UTC, s.pais;

    PRINT '===== DUPLICADOS EN FORMACION_JUGADOR (RESULTADO ESPERADO: 0 FILAS) =====';
    SELECT
        id_formacion,
        id_jugador,
        COUNT(*) AS cantidad
    FROM dbo.Formacion_Jugador
    GROUP BY id_formacion, id_jugador
    HAVING COUNT(*) > 1;

    PRINT '===== VALIDACION: MAXIMO 11 TITULARES POR FORMACION (ESPERADO: 0 FILAS) =====';
    SELECT
        id_formacion,
        SUM(CASE WHEN es_titular = 1 THEN 1 ELSE 0 END) AS titulares
    FROM dbo.Formacion_Jugador
    GROUP BY id_formacion
    HAVING SUM(CASE WHEN es_titular = 1 THEN 1 ELSE 0 END) > 11;

    PRINT '===== VALIDACION: JUGADOR NO PUEDE ESTAR EN DOS FORMACIONES DEL MISMO PARTIDO (ESPERADO: 0 FILAS) =====';
    SELECT
        p.id_partido,
        fj.id_jugador,
        COUNT(*) AS veces_en_el_partido
    FROM dbo.Formacion_Jugador fj
    INNER JOIN dbo.Formacion  f ON f.id_formacion = fj.id_formacion
    INNER JOIN dbo.Partido    p ON p.id_partido   = f.id_partido
    GROUP BY p.id_partido, fj.id_jugador
    HAVING COUNT(*) > 1;

    PRINT '===== VERIFICACION: total de filas en Formacion_Jugador =====';
    SELECT
        COUNT(*) AS total_formacion_jugador,
        COUNT(DISTINCT id_formacion) AS total_formaciones_con_jugadores
    FROM dbo.Formacion_Jugador;
END;
GO

/*
    Ruta esperada si SQL Server corre en el contenedor Docker "sqlserver":
    /var/opt/mssql/import/alineaciones_extraidas.json

    Si corrés el motor en Windows local, reemplazá por la ruta real, por ej.:
    N'C:\TP_BBDDA_COM2900_GRUPO_1-main\Archivos_Importacion\alineaciones_extraidas.json'
*/
EXEC test.Importar_Formacion_Jugador_JSON_Test
    @archivo = N'/var/opt/mssql/import/alineaciones_extraidas.json';
GO