/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodríguez, Elías Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripción:
    Script de creación de Stored Procedures ABM (Alta, Baja, Modificación)
    para la tabla:
        - dbo.Reemplazo

    Cada SP realiza validaciones y agrupa los errores en un único mensaje.
*/

USE MUNDIALDEFUTBOL;
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
