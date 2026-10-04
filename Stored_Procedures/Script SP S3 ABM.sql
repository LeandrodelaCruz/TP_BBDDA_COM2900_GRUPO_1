/*
    Universidad: [Nombre Universidad]
    Materia: Bases de Datos Aplicada
    Integrantes: [Nombres]
    Fecha: 01/10/2026

    Descripción:
    Script de creación de Stored Procedures ABM (Alta, Baja, Modificación)
    para las tablas:
        - dbo.Reemplazo
        - dbo.Partido
        - dbo.Partido_Seleccion
        - dbo.Formacion
        - dbo.Formacion_Jugador

    Cada SP realiza validaciones y agrupa los errores en un único mensaje.
*/

USE MundialDB;
GO

/* =========================================================
   TABLA: dbo.Reemplazo
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_Reemplazo_Alta
    @id_jugador_baja INT,
    @id_jugador_alta INT,
    @fecha_cambio    DATE,
    @motivo          VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    -- Validación 1: jugadores distintos
    IF @id_jugador_baja = @id_jugador_alta
        SET @errores += N'- El jugador de baja y el de alta no pueden ser el mismo. ';

    -- Validación 2: existencia del jugador de baja
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador_baja)
        SET @errores += N'- No existe el jugador de baja indicado. ';

    -- Validación 3: existencia del jugador de alta
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador_alta)
        SET @errores += N'- No existe el jugador de alta indicado. ';

    -- Validación 4: mismo país (selección) para ambos jugadores
    IF EXISTS (
        SELECT 1
        FROM dbo.Jugador jb
        JOIN dbo.Jugador ja ON ja.id_jugador = @id_jugador_alta
        WHERE jb.id_jugador = @id_jugador_baja
          AND jb.id_seleccion <> ja.id_seleccion
    )
        SET @errores += N'- Ambos jugadores deben pertenecer a la misma selección. ';

    -- Validación 5: fecha no futura
    IF @fecha_cambio > CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha del cambio no puede ser futura. ';

    -- Validación 6: motivo no vacío
    IF LTRIM(RTRIM(ISNULL(@motivo, ''))) = ''
        SET @errores += N'- El motivo es obligatorio. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Reemplazo (id_jugador_baja, id_jugador_alta, fecha_cambio, motivo)
        VALUES (@id_jugador_baja, @id_jugador_alta, @fecha_cambio, @motivo);

        SELECT SCOPE_IDENTITY() AS id_reemplazo_generado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Reemplazo_Baja
    @id_reemplazo INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Reemplazo WHERE id_reemplazo = @id_reemplazo)
        SET @errores += N'- No existe el reemplazo indicado. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Reemplazo WHERE id_reemplazo = @id_reemplazo;
        SELECT @id_reemplazo AS id_reemplazo_eliminado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Reemplazo_Modificacion
    @id_reemplazo    INT,
    @id_jugador_baja INT,
    @id_jugador_alta INT,
    @fecha_cambio    DATE,
    @motivo          VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Reemplazo WHERE id_reemplazo = @id_reemplazo)
        SET @errores += N'- No existe el reemplazo indicado. ';

    IF @id_jugador_baja = @id_jugador_alta
        SET @errores += N'- El jugador de baja y el de alta no pueden ser el mismo. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador_baja)
        SET @errores += N'- No existe el jugador de baja indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador_alta)
        SET @errores += N'- No existe el jugador de alta indicado. ';

    IF EXISTS (
        SELECT 1
        FROM dbo.Jugador jb
        JOIN dbo.Jugador ja ON ja.id_jugador = @id_jugador_alta
        WHERE jb.id_jugador = @id_jugador_baja
          AND jb.id_seleccion <> ja.id_seleccion
    )
        SET @errores += N'- Ambos jugadores deben pertenecer a la misma selección. ';

    IF @fecha_cambio > CAST(GETDATE() AS DATE)
        SET @errores += N'- La fecha del cambio no puede ser futura. ';

    IF LTRIM(RTRIM(ISNULL(@motivo, ''))) = ''
        SET @errores += N'- El motivo es obligatorio. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Reemplazo
        SET id_jugador_baja = @id_jugador_baja,
            id_jugador_alta = @id_jugador_alta,
            fecha_cambio    = @fecha_cambio,
            motivo          = @motivo
        WHERE id_reemplazo = @id_reemplazo;

        SELECT @id_reemplazo AS id_reemplazo_modificado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/* =========================================================
   TABLA: dbo.Partido
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_Partido_Alta
    @id_sede           INT,
    @fecha             DATE,
    @horario_local     DATETIME2(0),
    @horario_UTC       DATETIME2(0),
    @fase              VARCHAR(30),
    @resultado_final   VARCHAR(20) = NULL,
    @asistencia_publico INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @fasesValidas TABLE (f VARCHAR(30));
    INSERT INTO @fasesValidas VALUES
        ('GRUPOS'), ('DIECISEISAVOS'), ('OCTAVOS'), ('CUARTOS'),
        ('SEMIFINAL'), ('TERCER PUESTO'), ('FINAL');

    -- Validación 1: sede existente
    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede)
        SET @errores += N'- No existe la sede indicada. ';

    -- Validación 2: fase válida
    IF NOT EXISTS (SELECT 1 FROM @fasesValidas WHERE f = @fase)
        SET @errores += N'- La fase indicada no es válida. ';

    -- Validación 3: horario local y UTC no nulos
    IF @horario_local IS NULL OR @horario_UTC IS NULL
        SET @errores += N'- Los horarios local y UTC son obligatorios. ';

    -- Validación 4: asistencia no negativa
    IF @asistencia_publico IS NOT NULL AND @asistencia_publico < 0
        SET @errores += N'- La asistencia no puede ser negativa. ';

    -- Validación 5: asistencia no supera capacidad de la sede
    IF @asistencia_publico IS NOT NULL
       AND EXISTS (
            SELECT 1 FROM dbo.Sede
            WHERE id_sede = @id_sede
              AND capacidad < @asistencia_publico
       )
        SET @errores += N'- La asistencia supera la capacidad de la sede. ';

    -- Validación 6: fecha coherente con horario local
    IF @horario_local IS NOT NULL AND CAST(@horario_local AS DATE) <> @fecha
        SET @errores += N'- La fecha no coincide con la del horario local. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC,
                                 fase, resultado_final, asistencia_publico)
        VALUES (@id_sede, @fecha, @horario_local, @horario_UTC,
                @fase, @resultado_final, @asistencia_publico);

        SELECT SCOPE_IDENTITY() AS id_partido_generado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Partido_Baja
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    -- Validación de dependencias: no borrar si tiene datos asociados
    IF EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene formaciones asociadas. ';

    IF EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene sustituciones asociadas. ';

    IF EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene incidencias asociadas. ';

    IF EXISTS (SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene designaciones arbitrales. ';

    IF EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene publicidad asignada. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        -- Primero eliminamos la relación N:N
        DELETE FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido;
        DELETE FROM dbo.Partido WHERE id_partido = @id_partido;

        SELECT @id_partido AS id_partido_eliminado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Partido_Modificacion
    @id_partido        INT,
    @id_sede           INT,
    @fecha             DATE,
    @horario_local     DATETIME2(0),
    @horario_UTC       DATETIME2(0),
    @fase              VARCHAR(30),
    @resultado_final   VARCHAR(20) = NULL,
    @asistencia_publico INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @fasesValidas TABLE (f VARCHAR(30));
    INSERT INTO @fasesValidas VALUES
        ('GRUPOS'), ('DIECISEISAVOS'), ('OCTAVOS'), ('CUARTOS'),
        ('SEMIFINAL'), ('TERCER PUESTO'), ('FINAL');

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede)
        SET @errores += N'- No existe la sede indicada. ';

    IF NOT EXISTS (SELECT 1 FROM @fasesValidas WHERE f = @fase)
        SET @errores += N'- La fase indicada no es válida. ';

    IF @horario_local IS NULL OR @horario_UTC IS NULL
        SET @errores += N'- Los horarios local y UTC son obligatorios. ';

    IF @asistencia_publico IS NOT NULL AND @asistencia_publico < 0
        SET @errores += N'- La asistencia no puede ser negativa. ';

    IF @asistencia_publico IS NOT NULL
       AND EXISTS (
            SELECT 1 FROM dbo.Sede
            WHERE id_sede = @id_sede AND capacidad < @asistencia_publico
       )
        SET @errores += N'- La asistencia supera la capacidad de la sede. ';

    IF @horario_local IS NOT NULL AND CAST(@horario_local AS DATE) <> @fecha
        SET @errores += N'- La fecha no coincide con la del horario local. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Partido
        SET id_sede            = @id_sede,
            fecha              = @fecha,
            horario_local      = @horario_local,
            horario_UTC        = @horario_UTC,
            fase               = @fase,
            resultado_final    = @resultado_final,
            asistencia_publico = @asistencia_publico
        WHERE id_partido = @id_partido;

        SELECT @id_partido AS id_partido_modificado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/* =========================================================
   TABLA: dbo.Partido_Seleccion
   ========================================================= */

CREATE PROCEDURE OR ALTER dbo.SP_PartidoSeleccion_Alta
    @id_partido   INT,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selección indicada. ';

    -- Validación: no más de 2 selecciones por partido
    IF (SELECT COUNT(*) FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido) >= 2
        SET @errores += N'- El partido ya tiene dos selecciones asignadas. ';

    -- Validación: evitar duplicado exacto
    IF EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selección ya está asignada a este partido. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion)
        VALUES (@id_partido, @id_seleccion);

        SELECT @id_partido AS id_partido, @id_seleccion AS id_seleccion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_PartidoSeleccion_Baja
    @id_partido   INT,
    @id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la relación partido-selección indicada. ';

    -- No eliminar si hay formaciones asociadas
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- No se puede eliminar: existe una formación asociada. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Partido_Seleccion
        WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion;

        SELECT @id_partido AS id_partido, @id_seleccion AS id_seleccion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_PartidoSeleccion_Modificacion
    @id_partido       INT,
    @id_seleccion     INT,
    @nuevo_id_partido INT,
    @nueva_id_seleccion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la relación partido-selección original. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @nuevo_id_partido)
        SET @errores += N'- No existe el nuevo partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @nueva_id_seleccion)
        SET @errores += N'- No existe la nueva selección indicada. ';

    IF (@id_partido <> @nuevo_id_partido OR @id_seleccion <> @nueva_id_seleccion)
       AND EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @nuevo_id_partido AND id_seleccion = @nueva_id_seleccion)
        SET @errores += N'- Ya existe la nueva relación partido-selección. ';

    IF (SELECT COUNT(*) FROM dbo.Partido_Seleccion
        WHERE id_partido = @nuevo_id_partido
          AND NOT (id_partido = @id_partido AND id_seleccion = @id_seleccion)) >= 2
        SET @errores += N'- El nuevo partido ya tiene dos selecciones asignadas. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Partido_Seleccion
        SET id_partido   = @nuevo_id_partido,
            id_seleccion = @nueva_id_seleccion
        WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion;

        SELECT @nuevo_id_partido AS id_partido, @nueva_id_seleccion AS id_seleccion;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/* =========================================================
   TABLA: dbo.Formacion
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_Formacion_Alta
    @id_partido       INT,
    @id_seleccion     INT,
    @esquema_tactico  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selección indicada. ';

    -- Validación: la selección debe estar asociada al partido
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selección no participa en el partido indicado. ';

    -- Validación: no repetir formación para el mismo partido-selección
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- Ya existe una formación para ese partido y selección. ';

    -- Validación: esquema táctico obligatorio
    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema táctico es obligatorio. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Formacion (id_partido, id_seleccion, esquema_tactico)
        VALUES (@id_partido, @id_seleccion, @esquema_tactico);

        SELECT SCOPE_IDENTITY() AS id_formacion_generado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Formacion_Baja
    @id_formacion INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formación indicada. ';

    -- No borrar si tiene jugadores asociados
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador WHERE id_formacion = @id_formacion)
        SET @errores += N'- No se puede eliminar: la formación tiene jugadores asociados. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Formacion WHERE id_formacion = @id_formacion;
        SELECT @id_formacion AS id_formacion_eliminada;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_Formacion_Modificacion
    @id_formacion     INT,
    @id_partido       INT,
    @id_seleccion     INT,
    @esquema_tactico  VARCHAR(10)
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formación indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion)
        SET @errores += N'- No existe la selección indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion
                   WHERE id_partido = @id_partido AND id_seleccion = @id_seleccion)
        SET @errores += N'- La selección no participa en el partido indicado. ';

    -- No permitir cambiar a una combinación ya usada por otra formación
    IF EXISTS (SELECT 1 FROM dbo.Formacion
               WHERE id_partido = @id_partido
                 AND id_seleccion = @id_seleccion
                 AND id_formacion <> @id_formacion)
        SET @errores += N'- Ya existe otra formación para ese partido y selección. ';

    IF LTRIM(RTRIM(ISNULL(@esquema_tactico, ''))) = ''
        SET @errores += N'- El esquema táctico es obligatorio. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Formacion
        SET id_partido      = @id_partido,
            id_seleccion    = @id_seleccion,
            esquema_tactico = @esquema_tactico
        WHERE id_formacion = @id_formacion;

        SELECT @id_formacion AS id_formacion_modificada;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO


/* =========================================================
   TABLA: dbo.Formacion_Jugador
   ========================================================= */

CREATE OR ALTER PROCEDURE dbo.SP_FormacionJugador_Alta
    @id_formacion       INT,
    @id_jugador         INT,
    @posicion_en_cancha VARCHAR(40) = NULL,
    @dorsal_en_cancha   TINYINT,
    @es_titular         BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_formacion = @id_formacion)
        SET @errores += N'- No existe la formación indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador)
        SET @errores += N'- No existe el jugador indicado. ';

    -- Validación: el jugador debe pertenecer a la selección de la formación
    IF EXISTS (
        SELECT 1
        FROM dbo.Formacion f
        JOIN dbo.Jugador j ON j.id_jugador = @id_jugador
        WHERE f.id_formacion = @id_formacion
          AND f.id_seleccion <> j.id_seleccion
    )
        SET @errores += N'- El jugador no pertenece a la selección de la formación. ';

    -- Validación: no repetir jugador en la misma formación
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- El jugador ya está cargado en esta formación. ';

    -- Validación: dorsal en cancha entre 1 y 99
    IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal en cancha debe estar entre 1 y 99. ';

    -- Validación: no repetir dorsal en la misma formación
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion AND dorsal_en_cancha = @dorsal_en_cancha)
        SET @errores += N'- El dorsal en cancha ya está usado en esta formación. ';

    -- Validación: es_titular obligatorio
    IF @es_titular IS NULL
        SET @errores += N'- Debe indicar si el jugador es titular. ';

    -- Validación: máximo 11 titulares por formación
    IF @es_titular = 1
       AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador
            WHERE id_formacion = @id_formacion AND es_titular = 1) >= 11
        SET @errores += N'- La formación ya tiene 11 titulares. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Formacion_Jugador
            (id_formacion, id_jugador, posicion_en_cancha, dorsal_en_cancha, es_titular)
        VALUES
            (@id_formacion, @id_jugador, @posicion_en_cancha, @dorsal_en_cancha, @es_titular);

        SELECT @id_formacion AS id_formacion, @id_jugador AS id_jugador;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_FormacionJugador_Baja
    @id_formacion INT,
    @id_jugador   INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                   WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- No existe la relación formación-jugador indicada. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        DELETE FROM dbo.Formacion_Jugador
        WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

        SELECT @id_formacion AS id_formacion, @id_jugador AS id_jugador;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dbo.SP_FormacionJugador_Modificacion
    @id_formacion          INT,
    @id_jugador            INT,
    @posicion_en_cancha    VARCHAR(40) = NULL,
    @dorsal_en_cancha      TINYINT,
    @es_titular            BIT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

    -- Validación 1: la relación original debe existir
    IF NOT EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
                   WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador)
        SET @errores += N'- No existe la relación formación-jugador indicada. ';

    -- Validación 2: dorsal entre 1 y 99
    IF @dorsal_en_cancha IS NULL OR @dorsal_en_cancha NOT BETWEEN 1 AND 99
        SET @errores += N'- El dorsal en cancha debe estar entre 1 y 99. ';

    -- Validación 3: no repetir dorsal en la misma formación (excluyendo el registro actual)
    IF EXISTS (SELECT 1 FROM dbo.Formacion_Jugador
               WHERE id_formacion = @id_formacion
                 AND dorsal_en_cancha = @dorsal_en_cancha
                 AND id_jugador <> @id_jugador)
        SET @errores += N'- El dorsal en cancha ya está usado en esta formación. ';

    -- Validación 4: es_titular obligatorio
    IF @es_titular IS NULL
        SET @errores += N'- Debe indicar si el jugador es titular. ';

    -- Validación 5: máximo 11 titulares por formación (si pasa a titular)
    IF @es_titular = 1
       AND (SELECT COUNT(*) FROM dbo.Formacion_Jugador
            WHERE id_formacion = @id_formacion
              AND es_titular = 1
              AND id_jugador <> @id_jugador) >= 11
        SET @errores += N'- La formación ya tiene 11 titulares. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        UPDATE dbo.Formacion_Jugador
        SET posicion_en_cancha = @posicion_en_cancha,
            dorsal_en_cancha   = @dorsal_en_cancha,
            es_titular         = @es_titular
        WHERE id_formacion = @id_formacion AND id_jugador = @id_jugador;

        SELECT @id_formacion AS id_formacion, @id_jugador AS id_jugador;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO