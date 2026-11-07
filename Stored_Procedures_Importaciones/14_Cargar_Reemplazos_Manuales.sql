/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - Comision 01-2900
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 03/11/2026
    Objetivo: carga manual en lote de cinco reemplazos documentados.
    Cada fila usa los ABM y negocio.Registrar_Reemplazo en una transaccion.
    Fechas SIMULADAS acordadas para el TP; no son fechas historicas verificadas.
    Entrantes: identidades y datos exactos de jugadores_fifa_pdf.csv.
    Salientes: Wikipedia, clubes correspondientes a junio de 2026.
    Dorsales: se conserva el del entrante del PDF como supuesto del escenario.
    Fuentes y reglas completas: README_Reemplazos_Manuales.md.
    Crear despues de negocio 14. Este archivo no ejecuta la carga.
*/
USE MUNDIALDEFUTBOL;
GO

-- Mismo esquema de las cargas manuales de Region y Pieza_Para_Region.
IF SCHEMA_ID(N'carga') IS NULL
    THROW 51910, N'Falta el esquema carga. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO

CREATE OR ALTER PROCEDURE carga.Cargar_Reemplazos_Manuales
    @reconstruir_convocatoria BIT = 0,
    @aplicados INT = 0 OUTPUT,
    @omitidos INT = 0 OUTPUT,
    @errores INT = 0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- Necesita confirmar cada caso por separado para permitir errores parciales.
    IF @@TRANCOUNT <> 0
        THROW 51600, N'Ejecute la carga sin una transaccion externa abierta.', 1;
    IF @reconstruir_convocatoria IS NULL
        THROW 51600, N'Indique si se permite reconstruir la convocatoria.', 1;
    SELECT @aplicados = 0, @omitidos = 0, @errores = 0;

    DECLARE @casos TABLE
    (
        orden INT PRIMARY KEY, pais NVARCHAR(80), fecha DATE,
        nombre_baja NVARCHAR(60), apellido_baja NVARCHAR(60), nacimiento_baja DATE,
        club_baja NVARCHAR(100), posicion_baja VARCHAR(40), dorsal TINYINT,
        nombre_alta NVARCHAR(60), apellido_alta NVARCHAR(60), nacimiento_alta DATE,
        club_alta NVARCHAR(100), posicion_alta VARCHAR(40)
    );
    INSERT INTO @casos VALUES
    (1,N'Argentina','20260615',N'Leonardo Julián',N'Balerdi Rosa','19990126',
     N'Olympique Marseille (FRA)','Defensa',2,
     N'Marcos Nicolás',N'SENESI BARON','19970510',N'AFC Bournemouth (ENG)','Defensa'),
    (2,N'Brazil','20260612',N'Wesley Vinícius',N'França Lima','20030906',
     N'AS Roma (ITA)','Defensa',2,
     N'Éderson José',N'DOS SANTOS LOURENÇO DA SILVA','19990707',N'Atalanta Bergamo (ITA)','Mediocentro'),
    (3,N'Germany','20260613',N'Lennart',N'Karl','20080222',
     N'FC Bayern München (GER)','Mediocentro',25,
     N'Forzan Assan',N'OUÉDRAOGO','20060509',N'RB Leipzig (GER)','Mediocentro'),
    (4,N'Austria','20260615',N'Christoph',N'Baumgartner','19990801',
     N'RB Leipzig (GER)','Mediocentro',19,
     N'Dejan',N'LJUBIČIĆ','19971008',N'FC Schalke 04 (GER)','Mediocentro'),
    (5,N'England','20260616',N'Valentino Francisco',N'Livramento','20021112',
     N'Newcastle United (ENG)','Defensa',12,
     N'Trevoh Tom',N'CHALOBAH','19990705',N'Chelsea FC (ENG)','Defensa');

    DECLARE @resultado TABLE
    (orden INT, seleccion NVARCHAR(80), estado VARCHAR(20), id_reemplazo INT,
     numero_error INT, detalle NVARCHAR(2048));
    DECLARE @orden INT, @pais NVARCHAR(80), @fecha DATE, @dorsal TINYINT,
        @nb NVARCHAR(60), @ab NVARCHAR(60), @fb DATE, @cb NVARCHAR(100), @pb VARCHAR(40),
        @na NVARCHAR(60), @aa NVARCHAR(60), @fa DATE, @ca NVARCHAR(100), @pa VARCHAR(40),
        @seleccion INT, @baja INT, @alta INT, @reemplazo INT, @cantidad INT,
        @bloqueo INT, @reconstruido BIT, @vigentes_antes INT, @vigentes_despues INT;
    DECLARE @motivo VARCHAR(200) = 'Reemplazo por lesion (escenario de carga manual; fecha simulada).';
    SELECT @orden = MIN(orden) FROM @casos;
    WHILE @orden IS NOT NULL
    BEGIN
        SELECT @pais = pais, @fecha = fecha, @nb = nombre_baja,
               @ab = apellido_baja, @fb = nacimiento_baja, @cb = club_baja,
               @pb = posicion_baja, @dorsal = dorsal, @na = nombre_alta,
               @aa = apellido_alta, @fa = nacimiento_alta,
               @ca = club_alta, @pa = posicion_alta
        FROM @casos WHERE orden = @orden;
        SELECT @seleccion = NULL, @baja = NULL, @alta = NULL,
               @reemplazo = NULL, @reconstruido = 0;
        BEGIN TRY
            BEGIN TRANSACTION;
            -- Mismo recurso que Registrar_Reemplazo: preparacion y aplicacion
            -- quedan serializadas con las operaciones individuales.
            EXEC @bloqueo = sys.sp_getapplock
                @Resource = N'negocio.Registrar_Reemplazo', @LockMode = 'Exclusive',
                @LockOwner = 'Transaction', @LockTimeout = 10000;
            IF @bloqueo < 0 THROW 51601, N'No se pudo obtener el bloqueo del reemplazo.', 1;

            SELECT @cantidad = COUNT(*), @seleccion = MIN(id_seleccion)
            FROM dbo.Seleccion WITH (UPDLOCK,HOLDLOCK)
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(@pais);
            IF @cantidad <> 1 THROW 51602, N'Debe existir exactamente una seleccion para el pais del caso.', 1;

            SELECT @cantidad = COUNT(*), @baja = MIN(id_jugador)
            FROM dbo.Jugador WITH (UPDLOCK,HOLDLOCK)
            WHERE id_seleccion = @seleccion AND fecha_nacimiento = @fb
              AND UPPER(LTRIM(RTRIM(nombre))) = UPPER(@nb)
              AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(@ab);
            IF @cantidad > 1 THROW 51603, N'La identidad del saliente es ambigua.', 1;
            SELECT @cantidad = COUNT(*), @alta = MIN(id_jugador)
            FROM dbo.Jugador WITH (UPDLOCK,HOLDLOCK)
            WHERE id_seleccion = @seleccion AND fecha_nacimiento = @fa
              AND UPPER(LTRIM(RTRIM(nombre))) = UPPER(@na)
              AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(@aa);
            IF @cantidad > 1 THROW 51603, N'La identidad del entrante es ambigua.', 1;

            SELECT @cantidad = COUNT(*), @reemplazo = MIN(id_reemplazo)
            FROM dbo.Reemplazo WITH (UPDLOCK,HOLDLOCK)
            WHERE id_jugador_baja = @baja AND id_jugador_alta = @alta
              AND fecha_cambio = @fecha AND motivo = @motivo;
            IF @cantidad > 1 THROW 51604, N'Hay reemplazos duplicados; revise el historial.', 1;
            IF @cantidad = 1
            BEGIN
                -- No se retiran jugadores ni se revisa actividad posterior:
                -- el caso exacto ya fue aplicado y se conserva su historial.
                COMMIT TRANSACTION;
                SET @omitidos += 1;
                INSERT INTO @resultado VALUES (@orden,@pais,'YA APLICADO',@reemplazo,NULL,N'Se conserva el reemplazo existente.');
            END
            ELSE
            BEGIN
                IF EXISTS (SELECT 1 FROM dbo.Formacion WITH (UPDLOCK,HOLDLOCK) WHERE id_seleccion = @seleccion)
                    THROW 51605, N'La seleccion ya tiene formaciones; no se puede preparar este escenario.', 1;
                IF EXISTS (SELECT 1 FROM dbo.Partido WITH (UPDLOCK,HOLDLOCK)
                           WHERE (id_seleccion_1 = @seleccion OR id_seleccion_2 = @seleccion) AND fecha <= @fecha)
                    THROW 51606, N'La fecha simulada no es anterior al debut registrado.', 1;
                IF @baja IS NULL AND @alta IS NULL
                    THROW 51607, N'No existe el saliente ni el entrante; cargue primero las plantillas.', 1;
                IF @baja IS NOT NULL AND @alta IS NOT NULL
                    THROW 51608, N'Ambos jugadores existen sin el reemplazo esperado; revise la convocatoria.', 1;
                IF EXISTS (SELECT 1 FROM dbo.Reemplazo WITH (UPDLOCK,HOLDLOCK)
                           WHERE id_jugador_baja IN (@baja,@alta) OR id_jugador_alta IN (@baja,@alta))
                    THROW 51609, N'Los jugadores tienen otro historial de reemplazos; no se reconstruye automaticamente.', 1;

                SELECT @vigentes_antes = COUNT(*) FROM dbo.Jugador j WITH (UPDLOCK,HOLDLOCK)
                WHERE id_seleccion = @seleccion
                  AND NOT EXISTS (SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja = j.id_jugador);

                IF @baja IS NULL
                BEGIN
                    IF @reconstruir_convocatoria = 0
                        THROW 51610, N'La fuente ya tiene al entrante. Habilite la reconstruccion para este escenario manual.', 1;
                    -- No borrar un registro con datos distintos de la fuente.
                    IF EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @alta
                               AND (dorsal <> @dorsal OR club_origen <> @ca OR posicion <> @pa))
                        THROW 51611, N'Los datos del entrante difieren del CSV de referencia; revise el caso.', 1;
                    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador WITH (UPDLOCK,HOLDLOCK) WHERE id_jugador = @alta)
                       OR EXISTS (SELECT 1 FROM dbo.Incidencia WITH (UPDLOCK,HOLDLOCK) WHERE id_jugador = @alta OR id_jugador_involucrado = @alta)
                       OR EXISTS (SELECT 1 FROM dbo.Sustitucion WITH (UPDLOCK,HOLDLOCK) WHERE id_jugador_sale = @alta OR id_jugador_entra = @alta)
                        THROW 51612, N'El entrante tiene actividad registrada; no se puede reconstruir la convocatoria.', 1;

                    EXEC abm.Jugador_Baja @id_jugador = @alta;
                    EXEC abm.Jugador_Alta @fecha_nacimiento = @fb, @club_origen = @cb,
                        @apellido = @ab, @nombre = @nb, @posicion = @pb,
                        @dorsal = @dorsal, @id_seleccion = @seleccion;
                    SELECT @baja = id_jugador FROM dbo.Jugador
                    WHERE id_seleccion = @seleccion AND fecha_nacimiento = @fb
                      AND nombre = @nb AND apellido = @ab;
                    SET @reconstruido = 1;
                END;
                IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @baja AND dorsal = @dorsal)
                    THROW 51613, N'El saliente no tiene el dorsal esperado para el escenario.', 1;

                EXEC negocio.Registrar_Reemplazo @id_jugador_baja = @baja,
                    @fecha_cambio = @fecha, @motivo = @motivo,
                    @nombre = @na, @apellido = @aa, @fecha_nacimiento = @fa,
                    @club_origen = @ca, @posicion = @pa, @mostrar_resultado = 0;

                SELECT @reemplazo = r.id_reemplazo FROM dbo.Reemplazo r
                WHERE r.id_jugador_baja = @baja;
                IF @reemplazo IS NULL THROW 51614, N'No se genero el reemplazo esperado.', 1;
                SELECT @vigentes_despues = COUNT(*) FROM dbo.Jugador j
                WHERE id_seleccion = @seleccion
                  AND NOT EXISTS (SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja = j.id_jugador);
                IF @vigentes_antes <> @vigentes_despues
                    THROW 51615, N'La operacion altero la cantidad de convocados vigentes.', 1;
                COMMIT TRANSACTION;
                SET @aplicados += 1;
                INSERT INTO @resultado VALUES (@orden,@pais,'APLICADO',@reemplazo,NULL,
                    CASE WHEN @reconstruido = 1 THEN N'Convocatoria inicial reconstruida y reemplazo registrado.'
                         ELSE N'Reemplazo registrado sobre la convocatoria inicial existente.' END);
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
            SET @errores += 1;
            INSERT INTO @resultado VALUES (@orden,@pais,'ERROR',NULL,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        -- La clave avanza incluso si el caso anterior hizo ROLLBACK.
        SELECT @orden = MIN(orden) FROM @casos WHERE orden > @orden;
    END;
    SELECT 5 AS casos_procesados, @aplicados AS aplicados,
           @omitidos AS ya_aplicados, @errores AS errores;
    SELECT seleccion,estado,id_reemplazo,numero_error,detalle FROM @resultado ORDER BY orden;
END;
GO
