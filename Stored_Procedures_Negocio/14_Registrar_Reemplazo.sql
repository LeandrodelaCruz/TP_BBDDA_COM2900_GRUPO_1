/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - Comision 01-2900
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 02/11/2026
    Objetivo: incorporar un reemplazante y registrar la baja de convocatoria
    en una transaccion, conservando ambos registros de Jugador.

    Ejecutar despues de Table/00, Table/01 y los ABM 10 y 14.
    Convocado vigente: jugador que no aparece como baja en Reemplazo.
    Un jugador ya registrado y sin bajas ya esta convocado: no puede entrar
    nuevamente. Tampoco se admite reincorporar bajas. Se permiten cadenas
    A -> B -> C con fechas no decrecientes.
    El entrante hereda el dorsal del saliente. No se borra ningun jugador.
    Esta operacion se realiza antes de cargar formaciones de la seleccion;
    el fixture puede estar cargado y la fecha debe ser anterior a su debut.
*/
USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE negocio.Registrar_Reemplazo
    @id_jugador_baja INT,
    @fecha_cambio DATE,
    @motivo VARCHAR(200),
    @nombre NVARCHAR(60),
    @apellido NVARCHAR(60),
    @fecha_nacimiento DATE,
    @club_origen NVARCHAR(100),
    @posicion VARCHAR(40),
    @mostrar_resultado BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    -- Los errores de escritura invalidan la transaccion completa.
    SET XACT_ABORT ON;

    DECLARE @transacciones_previas INT = @@TRANCOUNT,
            @id_seleccion INT, @dorsal TINYINT, @id_jugador_alta INT,
            @errores NVARCHAR(2048) = N'', @bloqueo INT;
    DECLARE @resultado TABLE (id_reemplazo NUMERIC(38,0));

    BEGIN TRY
        IF @transacciones_previas = 0 BEGIN TRANSACTION;
        ELSE SAVE TRANSACTION RegistrarReemplazo;

        -- Serializa las llamadas a esta operacion, incluso para selecciones
        -- distintas. El bloqueo se libera al finalizar la transaccion.
        EXEC @bloqueo = sys.sp_getapplock
            @Resource = N'negocio.Registrar_Reemplazo',
            @LockMode = 'Exclusive', @LockOwner = 'Transaction',
            @LockTimeout = 10000;
        IF @bloqueo < 0
            THROW 51400, N'No se pudo obtener el bloqueo para registrar el reemplazo.', 1;

        SELECT @id_seleccion = id_seleccion, @dorsal = dorsal
        FROM dbo.Jugador WITH (UPDLOCK, HOLDLOCK)
        WHERE id_jugador = @id_jugador_baja;

        IF @id_seleccion IS NULL
            SET @errores += N'- No existe el jugador de baja. ';
        IF @fecha_cambio IS NULL OR @fecha_cambio > CONVERT(DATE, GETDATE())
            SET @errores += N'- La fecha del cambio es obligatoria y no puede ser futura. ';
        IF NULLIF(LTRIM(RTRIM(@motivo)), '') IS NULL
            SET @errores += N'- El motivo es obligatorio. ';
        IF NULLIF(LTRIM(RTRIM(@nombre)), N'') IS NULL
            SET @errores += N'- El nombre es obligatorio. ';
        IF NULLIF(LTRIM(RTRIM(@apellido)), N'') IS NULL
            SET @errores += N'- El apellido es obligatorio. ';
        IF @fecha_nacimiento IS NULL OR @fecha_nacimiento >= @fecha_cambio
            SET @errores += N'- El nacimiento debe ser anterior al cambio. ';
        IF NULLIF(LTRIM(RTRIM(@club_origen)), N'') IS NULL
            SET @errores += N'- El club de origen es obligatorio. ';
        IF NULLIF(LTRIM(RTRIM(@posicion)), '') IS NULL
            SET @errores += N'- La posicion es obligatoria. ';

        IF EXISTS (SELECT 1 FROM dbo.Reemplazo WITH (UPDLOCK, HOLDLOCK)
                   WHERE id_jugador_baja = @id_jugador_baja)
            SET @errores += N'- El saliente ya fue dado de baja de la convocatoria. ';
        IF EXISTS (SELECT 1 FROM dbo.Reemplazo WITH (UPDLOCK, HOLDLOCK)
                   WHERE id_jugador_alta = @id_jugador_baja AND fecha_cambio > @fecha_cambio)
            SET @errores += N'- La baja no puede ser anterior a su incorporacion. ';

        -- Misma clave natural que el importador de jugadores.
        IF EXISTS (SELECT 1 FROM dbo.Jugador WITH (UPDLOCK, HOLDLOCK)
                   WHERE id_seleccion = @id_seleccion
                     AND fecha_nacimiento = @fecha_nacimiento
                     AND UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
                     AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(LTRIM(RTRIM(@apellido))))
            SET @errores += N'- El entrante ya esta registrado en la seleccion; no se admite duplicarlo ni reincorporarlo. ';

        IF EXISTS (SELECT 1 FROM dbo.Formacion WITH (UPDLOCK, HOLDLOCK)
                   WHERE id_seleccion = @id_seleccion)
            SET @errores += N'- Registre los reemplazos antes de cargar formaciones de esta seleccion. ';
        IF EXISTS (SELECT 1 FROM dbo.Partido WITH (UPDLOCK, HOLDLOCK)
                   WHERE (id_seleccion_1 = @id_seleccion OR id_seleccion_2 = @id_seleccion)
                     AND fecha <= @fecha_cambio)
            SET @errores += N'- La fecha del reemplazo debe ser anterior al primer partido de la seleccion. ';

        IF @errores <> N'' THROW 51401, @errores, 1;

        EXEC abm.Jugador_Alta
            @fecha_nacimiento = @fecha_nacimiento, @club_origen = @club_origen,
            @apellido = @apellido, @nombre = @nombre, @posicion = @posicion,
            @dorsal = @dorsal, @id_seleccion = @id_seleccion;

        -- SCOPE_IDENTITY del llamador no incluye el INSERT realizado por el ABM.
        SELECT @id_jugador_alta = id_jugador
        FROM dbo.Jugador
        WHERE id_seleccion = @id_seleccion AND fecha_nacimiento = @fecha_nacimiento
          AND UPPER(LTRIM(RTRIM(nombre))) = UPPER(LTRIM(RTRIM(@nombre)))
          AND UPPER(LTRIM(RTRIM(apellido))) = UPPER(LTRIM(RTRIM(@apellido)));
        IF @id_jugador_alta IS NULL
            THROW 51402, N'El ABM no genero el jugador entrante.', 1;

        INSERT INTO @resultado
        EXEC abm.Reemplazo_Alta
            @id_jugador_baja = @id_jugador_baja,
            @id_jugador_alta = @id_jugador_alta,
            @fecha_cambio = @fecha_cambio, @motivo = @motivo;

        IF NOT EXISTS (SELECT 1 FROM @resultado)
            THROW 51403, N'El ABM no genero el reemplazo.', 1;

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
        IF @mostrar_resultado = 1
        SELECT CONVERT(INT, id_reemplazo) AS id_reemplazo,
               @id_jugador_baja AS id_jugador_baja, @id_jugador_alta AS id_jugador_alta
        FROM @resultado;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0
            ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1
            ROLLBACK TRANSACTION RegistrarReemplazo;
        -- Si XACT_STATE() = -1 en una transaccion del llamador, este debe
        -- efectuar el ROLLBACK completo; no es posible volver al savepoint.
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE negocio.Listar_Convocados_Vigentes
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        THROW 51404, N'No existe la seleccion indicada.', 1;

    SELECT j.id_jugador, j.id_seleccion, j.nombre, j.apellido,
           j.fecha_nacimiento, j.club_origen, j.posicion, j.dorsal
    FROM dbo.Jugador j
    WHERE j.id_seleccion = @id_seleccion
      AND NOT EXISTS (SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja = j.id_jugador)
    ORDER BY j.dorsal, j.apellido, j.nombre;
END;
GO
