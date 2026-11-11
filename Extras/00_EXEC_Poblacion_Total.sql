/*
    UNLaM - Bases de Datos Aplicada - Comision 01-2900 - Grupo 01
    POBLACION TOTAL DE MUNDIALDEFUTBOL - 10/11/2026

    Ejecutar de arriba hacia abajo, en SSMS, sobre una BD recien instalada.
    Este archivo ejecuta los SP existentes; no instala tablas ni procedimientos.
    Antes: instalar Table/00 y Table/01, los ABM, los procedimientos de negocio
    y los de Stored_Procedures_Importaciones, con sus dependencias resueltas.

    CONFIGURACION: ajustar @carpeta a una ruta que pueda LEER EL SERVIDOR SQL.
    Si SQL Server esta en Docker/Linux, usar su ruta montada, no la ruta Windows.

    MODO PREDETERMINADO: SIMULACION.
    Genera incidencias y sustituciones mediante negocio.Completar_Partidos.
    MODO ALTERNATIVO: CSV. Incluye el EXEC de importacion de match_events.csv,
    pero requiere revisar previamente que match_id/team_id/player_id correspondan
    a los IDs reales de esta BD. La reconstruccion de reemplazos cambia IDs de
    jugadores. NO asumir correspondencia por tratarse de una BD vacia.
    Completar_Partidos omite partidos que ya tienen incidencias o sustituciones:
    en modo CSV no completa las sustituciones de esos encuentros.

    No ejecutar ambos modos sobre los mismos partidos ni reimportar el CSV sobre
    eventos simulados. Reemplazos, designaciones, sanciones y eventos de negocio
    son escenarios del TP; no representan hechos ni designaciones oficiales.

    Sin transaccion global: las cargas confirman sus casos por separado.
    Un error puede dejar pasos anteriores cargados. Revisar resumen y detalle de
    cada SP; corregir y retomar desde el paso correspondiente. No borrar datos.
    Este archivo fue revisado contra los fuentes; su creacion no ejecuta la BD.
*/
USE MUNDIALDEFUTBOL;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;

DECLARE @carpeta NVARCHAR(1000) =
    N'/home/proyecto/';
DECLARE @modo_eventos VARCHAR(10) = 'SIMULACION'; -- SIMULACION / CSV

-- Las rutas se calculan antes de EXEC: T-SQL no admite concatenarlas en el argumento.
DECLARE @publicidad NVARCHAR(1000) = @carpeta + N'publicidad_mundial_scraping.csv',
        @selecciones NVARCHAR(1000) = @carpeta + N'teams.csv',
        @sedes NVARCHAR(1000) = @carpeta + N'venues.csv',
        @arbitros NVARCHAR(1000) = @carpeta + N'arbitros_fifa_pdf.csv',
        @tecnicos NVARCHAR(1000) = @carpeta + N'personal_tecnico.csv',
        @jugadores NVARCHAR(1000) = @carpeta + N'jugadores_fifa_pdf.csv',
        @partidos NVARCHAR(1000) = @carpeta + N'partidos_mundial_2026.json',
        @formaciones NVARCHAR(1000) = @carpeta + N'formaciones_mundial_2026.json',
        @alineaciones NVARCHAR(1000) = @carpeta + N'alineaciones_extraidas.json',
        @incidencias NVARCHAR(1000) = @carpeta + N'match_events.csv';

BEGIN TRY
    IF DB_NAME() <> N'MUNDIALDEFUTBOL'
        THROW 59000, N'Seleccione MUNDIALDEFUTBOL antes de ejecutar.', 1;
    IF @@TRANCOUNT <> 0
        THROW 59000, N'Ejecute sin una transaccion externa abierta.', 1;
    IF @modo_eventos IS NULL OR @modo_eventos NOT IN ('SIMULACION','CSV')
        THROW 59000, N'El modo de eventos debe ser SIMULACION o CSV.', 1;

    -- Comprobar todos los SP de importacion/carga y negocio antes de escribir.
    DECLARE @requeridos TABLE (nombre NVARCHAR(256) PRIMARY KEY);
    INSERT @requeridos VALUES
    (N'importacion.Importar_Anunciante_CSV'),
    (N'importacion.Importar_Seleccion_CSV'),
    (N'carga.Cargar_Regiones'),
    (N'importacion.Importar_Sede_CSV'),
    (N'importacion.Importar_Arbitro_PDF_CSV'),
    (N'importacion.Importar_Campania_CSV'),
    (N'importacion.Importar_Pieza_Publicitaria_CSV'),
    (N'carga.Cargar_Pieza_Para_Region'),
    (N'importacion.Importar_Personal_Tecnico_CSV'),
    (N'importacion.Importar_Jugador_PDF_CSV'),
    (N'importacion.Importar_Partido_JSON'),
    (N'carga.Cargar_Cruces_Dataset'),
    (N'importacion.Importar_Formacion_JSON'),
    (N'importacion.Importar_Formacion_Jugador_JSON'),
    (N'carga.Cargar_Reemplazos_Manuales'),
    (N'carga.Cargar_Designaciones_Arbitrales'),
    (N'importacion.Importar_Incidencia_CSV'),
    (N'carga.Cargar_Sanciones_Arbitrales_Manuales'),
    (N'negocio.Registrar_Reemplazo'),
    (N'negocio.Listar_Convocados_Vigentes'),
    (N'negocio.Generar_Asignacion_Publicitaria'),
    (N'negocio.Evaluar_Cruce_Arbitral'),
    (N'negocio.Simular_Penales'),
    (N'negocio.Simular_Partido'),
    (N'negocio.Completar_Partidos');
    IF EXISTS (SELECT 1 FROM @requeridos WHERE OBJECT_ID(nombre,N'P') IS NULL)
    BEGIN
        SELECT nombre AS procedimiento_faltante
        FROM @requeridos WHERE OBJECT_ID(nombre,N'P') IS NULL ORDER BY nombre;
        THROW 59000, N'Instale los procedimientos faltantes antes de poblar.', 1;
    END;

    -- Evitar lanzar la poblacion inicial completa sobre datos existentes.
    IF EXISTS (SELECT 1 FROM dbo.Partido)
       OR EXISTS (SELECT 1 FROM dbo.Jugador)
       OR EXISTS (SELECT 1 FROM dbo.Seleccion)
       OR EXISTS (SELECT 1 FROM dbo.Anunciante)
       OR EXISTS (SELECT 1 FROM dbo.Sede)
       OR EXISTS (SELECT 1 FROM dbo.Arbitro)
       OR EXISTS (SELECT 1 FROM dbo.Region)
        THROW 59000, N'La poblacion inicial requiere datos base vacios. Para retomar, ejecute solo los pasos pendientes.', 1;

    PRINT N'01 - Importar anunciantes';
    EXEC importacion.Importar_Anunciante_CSV @archivo = @publicidad;

    PRINT N'02 - Cargar regiones';
    EXEC carga.Cargar_Regiones;

    PRINT N'03 - Importar sedes';
    EXEC importacion.Importar_Sede_CSV @archivo = @sedes;

    PRINT N'04 - Importar selecciones';
    EXEC importacion.Importar_Seleccion_CSV @archivo = @selecciones;

    PRINT N'05 - Importar arbitros';
    EXEC importacion.Importar_Arbitro_PDF_CSV @archivo = @arbitros;

    PRINT N'06 - Importar campanias (dependen de anunciantes)';
    EXEC importacion.Importar_Campania_CSV @archivo = @publicidad;

    PRINT N'07 - Importar piezas publicitarias (dependen de campanias)';
    EXEC importacion.Importar_Pieza_Publicitaria_CSV @archivo = @publicidad;

    PRINT N'08 - Cargar piezas por region (dependen de piezas y regiones)';
    EXEC carga.Cargar_Pieza_Para_Region;

    PRINT N'09 - Importar personal tecnico (depende de selecciones)';
    EXEC importacion.Importar_Personal_Tecnico_CSV @archivo = @tecnicos;

    PRINT N'10 - Importar jugadores (dependen de selecciones)';
    EXEC importacion.Importar_Jugador_PDF_CSV @archivo = @jugadores;

    PRINT N'11 - Cargar reemplazos ANTES de partidos, formaciones e incidencias';
    -- La fuente ya contiene entrantes. Se reconstruye el escenario inicial del TP.
    -- Ejecuta internamente negocio.Registrar_Reemplazo; no repetirlo por separado.
    DECLARE @reemplazos_aplicados INT, @reemplazos_omitidos INT, @reemplazos_errores INT;
    EXEC carga.Cargar_Reemplazos_Manuales
        @reconstruir_convocatoria = 1,
        @aplicados = @reemplazos_aplicados OUTPUT,
        @omitidos = @reemplazos_omitidos OUTPUT,
        @errores = @reemplazos_errores OUTPUT;
    IF @reemplazos_errores <> 0
        THROW 59001, N'Hay reemplazos con error. Revisar el detalle antes de continuar.', 1;

    PRINT N'12 - Importar partidos (dependen de selecciones y sedes)';
    EXEC importacion.Importar_Partido_JSON @archivo = @partidos;
    IF (SELECT COUNT(*) FROM dbo.Partido) <> 104
        THROW 59002, N'El fixture local debe cargar 104 partidos. Revisar errores de importacion.', 1;

    PRINT N'13 - Cargar mapa de cruces (depende del fixture completo)';
    EXEC carga.Cargar_Cruces_Dataset;

    PRINT N'14 - Importar formaciones (dependen de partidos y selecciones)';
    EXEC importacion.Importar_Formacion_JSON @archivo = @formaciones;

    PRINT N'15 - Importar jugadores de cada formacion';
    EXEC importacion.Importar_Formacion_Jugador_JSON @archivo = @alineaciones;
   /* IF EXISTS (
        SELECT 1 FROM dbo.Partido p
        CROSS APPLY (VALUES (p.id_seleccion_1),(p.id_seleccion_2)) s(id_seleccion)
        WHERE (SELECT COUNT(*) FROM dbo.Formacion f
               JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion
               WHERE f.id_partido = p.id_partido AND f.id_seleccion = s.id_seleccion
                 AND fj.es_titular = 1) <> 11
    )
        THROW 59003, N'Faltan los 11 titulares de alguna seleccion/partido. Revisar formaciones y alineaciones.', 1;*/

    PRINT N'16 - Cargar designaciones arbitrales de todos los partidos';
    -- Los ABM de esta carga usan negocio.Evaluar_Cruce_Arbitral.
    DECLARE @designados INT, @designaciones_omitidas INT,
            @designaciones_errores INT, @candidatos_rechazados INT;
    EXEC carga.Cargar_Designaciones_Arbitrales
        @id_partido = NULL, @demostrar_rechazo = 1,
        @completados = @designados OUTPUT,
        @omitidos = @designaciones_omitidas OUTPUT,
        @errores = @designaciones_errores OUTPUT,
        @rechazados = @candidatos_rechazados OUTPUT;
    IF @designaciones_errores <> 0
        THROW 59004, N'Hay partidos con error de designacion. Revisar el detalle.', 1;

    PRINT N'17 - Cargar sanciones arbitrales simuladas (dependen de designaciones)';
    DECLARE @sanciones_insertadas INT, @sanciones_omitidas INT, @sanciones_errores INT;
    EXEC carga.Cargar_Sanciones_Arbitrales_Manuales
        @insertadas = @sanciones_insertadas OUTPUT,
        @omitidas = @sanciones_omitidas OUTPUT,
        @errores = @sanciones_errores OUTPUT;
    IF @sanciones_errores <> 0
        THROW 59005, N'Hay sanciones con error. Revisar el detalle.', 1;

    PRINT N'18 - Negocio: generar asignaciones publicitarias para TODOS los partidos';
    -- WHILE con clave unica y avance explicito. No asumir IDs consecutivos.
    DECLARE @id_partido_publicidad INT;
    SELECT @id_partido_publicidad = MIN(id_partido) FROM dbo.Partido;
    WHILE @id_partido_publicidad IS NOT NULL
    BEGIN
        EXEC negocio.Generar_Asignacion_Publicitaria
            @id_partido = @id_partido_publicidad;
        SELECT @id_partido_publicidad = MIN(id_partido) FROM dbo.Partido
        WHERE id_partido > @id_partido_publicidad;
    END;
    -- Puede haber menos de cuatro espacios, o ninguno, segun el prime time.

    PRINT N'19 - Incidencias: elegir una fuente';
    IF @modo_eventos = 'CSV'
    BEGIN
        PRINT N'ATENCION: modo CSV. Los IDs del archivo deben estar verificados.';
        EXEC importacion.Importar_Incidencia_CSV @archivo = @incidencias;
    END;
    -- En SIMULACION se omite el CSV para generar la cronologia de cada partido.

    PRINT N'20 - Negocio: completar partidos pendientes';
    -- Ejecuta negocio.Simular_Partido por partido; este llama a Simular_Penales
    -- cuando corresponde. Carga Incidencia y Sustitucion mediante sus ABM.
    -- En CSV solo procesa encuentros sin incidencias NI sustituciones previas.
    EXEC negocio.Completar_Partidos;

    IF @modo_eventos = 'SIMULACION' AND EXISTS (
        SELECT 1 FROM dbo.Partido p WHERE p.resultado_final IS NOT NULL
          AND (NOT EXISTS (SELECT 1 FROM dbo.Incidencia i WHERE i.id_partido = p.id_partido)
            OR NOT EXISTS (SELECT 1 FROM dbo.Sustitucion s WHERE s.id_partido = p.id_partido))
    )
        THROW 59006, N'Quedaron partidos con resultado sin incidencias o sustituciones. Revisar el resumen de simulacion.', 1;

    PRINT N'21 - Conteo final de las 20 tablas';
    SELECT N'Anunciante' AS tabla, COUNT_BIG(*) AS filas FROM dbo.Anunciante
    UNION ALL SELECT N'Region', COUNT_BIG(*) FROM dbo.Region
    UNION ALL SELECT N'Sede', COUNT_BIG(*) FROM dbo.Sede
    UNION ALL SELECT N'Seleccion', COUNT_BIG(*) FROM dbo.Seleccion
    UNION ALL SELECT N'Arbitro', COUNT_BIG(*) FROM dbo.Arbitro
    UNION ALL SELECT N'Campania', COUNT_BIG(*) FROM dbo.Campania
    UNION ALL SELECT N'Pieza_Publicitaria', COUNT_BIG(*) FROM dbo.Pieza_Publicitaria
    UNION ALL SELECT N'Pieza_Para_Region', COUNT_BIG(*) FROM dbo.Pieza_Para_Region
    UNION ALL SELECT N'Personal_Tecnico', COUNT_BIG(*) FROM dbo.Personal_Tecnico
    UNION ALL SELECT N'Jugador', COUNT_BIG(*) FROM dbo.Jugador
    UNION ALL SELECT N'Reemplazo', COUNT_BIG(*) FROM dbo.Reemplazo
    UNION ALL SELECT N'Partido', COUNT_BIG(*) FROM dbo.Partido
    UNION ALL SELECT N'Cruce_Partido', COUNT_BIG(*) FROM dbo.Cruce_Partido
    UNION ALL SELECT N'Formacion', COUNT_BIG(*) FROM dbo.Formacion
    UNION ALL SELECT N'Formacion_Jugador', COUNT_BIG(*) FROM dbo.Formacion_Jugador
    UNION ALL SELECT N'Designacion_Arbitral', COUNT_BIG(*) FROM dbo.Designacion_Arbitral
    UNION ALL SELECT N'Sancion_Arbitral', COUNT_BIG(*) FROM dbo.Sancion_Arbitral
    UNION ALL SELECT N'Asignacion_Publicitaria', COUNT_BIG(*) FROM dbo.Asignacion_Publicitaria
    UNION ALL SELECT N'Incidencia', COUNT_BIG(*) FROM dbo.Incidencia
    UNION ALL SELECT N'Sustitucion', COUNT_BIG(*) FROM dbo.Sustitucion;
    PRINT N'Fin del recorrido. Revisar tambien los resumenes y errores por fila de cada SP.';
END TRY
BEGIN CATCH
    -- No revertir cargas ya confirmadas ni continuar con pasos dependientes.
    THROW;
END CATCH;
GO

/*
    REFERENCIA DE EXEC DE NEGOCIO INDIVIDUALES (no ejecutar otra vez en lote).
    Los parametros @id_* de estos ejemplos deben resolverse desde la BD.

    -- Invocado por carga.Cargar_Reemplazos_Manuales en el paso 11:
    EXEC negocio.Registrar_Reemplazo
        @id_jugador_baja = @id_baja, @fecha_cambio = @fecha,
        @motivo = @motivo, @nombre = @nombre, @apellido = @apellido,
        @fecha_nacimiento = @nacimiento, @club_origen = @club,
        @posicion = @posicion, @mostrar_resultado = 1;

    -- Consulta opcional de la convocatoria vigente despues de reemplazos:
    EXEC negocio.Listar_Convocados_Vigentes @id_seleccion = @id_seleccion;

    -- Evaluacion utilizada por los ABM de designaciones, paso 16:
    DECLARE @advertencia NVARCHAR(2048);
    EXEC negocio.Evaluar_Cruce_Arbitral
        @id_partido = @id_partido, @id_arbitro = @id_arbitro,
        @advertencia = @advertencia OUTPUT;

    -- Alternativa individual al recorrido de Completar_Partidos, paso 20:
    EXEC negocio.Simular_Partido @id_partido = @id_partido;

    -- Invocado por Simular_Partido: no repetir una tanda ya generada.
    -- Los marcadores deben corresponder al resultado_final del encuentro.
    EXEC negocio.Simular_Penales
        @id_partido = @id_partido, @id_local = @id_local,
        @id_visitante = @id_visitante,
        @penales_local = @penales_local, @penales_visitante = @penales_visitante;
*/
