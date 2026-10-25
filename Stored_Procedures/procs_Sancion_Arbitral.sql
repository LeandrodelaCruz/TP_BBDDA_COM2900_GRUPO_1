/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01: 
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel

    Descripción:
    Stored Procedures ABM para la tabla Sancion_Arbitral
    
    Validaciones:
    - El árbitro debe tener una designación arbitral para el partido indicado
      (si se proporciona id_partido).
    - La fecha de la sanción debe coincidir con la fecha del partido (si se
      proporciona id_partido).
    - Los tipos de sanción permitidos son: SUSPENSIÓN, MULTA, ADVERTENCIA y
      RETIRO DE LICENCIA.
    - La fecha de la sanción no puede ser futura.

    PROCEDIMIENTOS INCLUIDOS:
    - SP_Sancion_Arbitral_Alta (con validaciones)
    - SP_Sancion_Arbitral_Modificacion
    - SP_Sancion_Arbitral_Baja
    - SP_Sancion_Arbitral_GetById
    - SP_Sancion_Arbitral_GetByArbitro
    - SP_Sancion_Arbitral_GetByPartido
*/

USE MUNDIALDEFUTBOL;
GO

-- =========================================================
-- CREATE - Insertar una nueva sanción arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sancion_Arbitral_Alta
    @id_arbitro INT,
    @id_partido INT = NULL,
    @fecha DATE,
    @motivo VARCHAR(300),
    @tipo_sancion VARCHAR(50),
    @id_sancion INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @errores NVARCHAR(MAX) = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        
        -- Validar datos del partido (si se indica)
        IF @id_partido IS NOT NULL
        BEGIN
            DECLARE @fecha_partido DATE;

            -- Validar que el árbitro tenga designación para el partido
            IF NOT EXISTS (
                SELECT 1 
                FROM dbo.Designacion_Arbitral 
                WHERE id_arbitro = @id_arbitro AND id_partido = @id_partido
            )
            BEGIN
                SET @errores = @errores + 'El árbitro no tiene una designación arbitral para el partido especificado. ';
            END
            
            SELECT @fecha_partido = fecha
            FROM dbo.Partido
            WHERE id_partido = @id_partido;
            
            IF @fecha_partido IS NULL
            BEGIN
                SET @errores = @errores + 'El partido especificado no existe. ';
            END
            ELSE
            BEGIN
                -- Validar que la fecha de la sanción coincida con la del partido
                IF @fecha <> @fecha_partido
                BEGIN
                    SET @errores = @errores + 'La fecha de la sanción debe coincidir con la fecha del partido. ';
                END
            END         
        END
        
        -- Si hay errores, lanzar excepción
        IF @errores <> ''
        BEGIN
            RAISERROR(@errores, 16, 1);
        END
        
        -- =========================================================
        -- INSERCIÓN
        -- =========================================================
        INSERT INTO dbo.Sancion_Arbitral (
            id_arbitro,
            id_partido,
            fecha,
            motivo,
            tipo_sancion
        ) VALUES (
            @id_arbitro,
            @id_partido,
            @fecha,
            @motivo,
            @tipo_sancion
        );
        
        SET @id_sancion = SCOPE_IDENTITY();
        
        COMMIT TRANSACTION;
        PRINT 'Sanción arbitral registrada exitosamente. ID: ' + CAST(@id_sancion AS VARCHAR(10));
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX);
        DECLARE @error_number INT;
        DECLARE @error_severity INT;
        DECLARE @error_state INT;
        
        SET @error_number = ERROR_NUMBER();
        SET @error_severity = ERROR_SEVERITY();
        SET @error_state = ERROR_STATE();
        SET @error_message = ERROR_MESSAGE();
        
        RAISERROR(
            'Error al registrar sanción arbitral: %s (Código de error: %d)',
            @error_severity,
            @error_state,
            @error_message,
            @error_number
        );
    END CATCH
    
END;
GO

-- =========================================================
-- READ - Obtener sanción por ID
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sancion_Arbitral_GetById
    @id_sancion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        sa.id_sancion,
        sa.id_arbitro,
        a.nombre + ' ' + a.apellido AS arbitro,
        a.pais AS pais_arbitro,
        sa.id_partido,
        p.fecha AS fecha_partido,
        p.fase AS fase_partido,
        sa.fecha AS fecha_sancion,
        sa.motivo,
        sa.tipo_sancion
    FROM dbo.Sancion_Arbitral sa
    INNER JOIN dbo.Arbitro a ON sa.id_arbitro = a.id_arbitro
    LEFT JOIN dbo.Partido p ON sa.id_partido = p.id_partido
    WHERE sa.id_sancion = @id_sancion;
END;
GO

-- =========================================================
-- READ - Obtener sanciones por árbitro
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sancion_Arbitral_GetByArbitro
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        sa.id_sancion,
        sa.id_arbitro,
        a.nombre + ' ' + a.apellido AS arbitro,
        sa.id_partido,
        p.fecha AS fecha_partido,
        p.fase AS fase_partido,
        sa.fecha AS fecha_sancion,
        sa.motivo,
        sa.tipo_sancion
    FROM dbo.Sancion_Arbitral sa
    INNER JOIN dbo.Arbitro a ON sa.id_arbitro = a.id_arbitro
    LEFT JOIN dbo.Partido p ON sa.id_partido = p.id_partido
    WHERE sa.id_arbitro = @id_arbitro
    ORDER BY sa.fecha DESC;
END;
GO

-- =========================================================
-- READ - Obtener sanciones por partido
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sancion_Arbitral_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        sa.id_sancion,
        sa.id_arbitro,
        a.nombre + ' ' + a.apellido AS arbitro,
        a.pais AS pais_arbitro,
        sa.id_partido,
        p.fecha AS fecha_partido,
        p.fase AS fase_partido,
        sa.fecha AS fecha_sancion,
        sa.motivo,
        sa.tipo_sancion
    FROM dbo.Sancion_Arbitral sa
    INNER JOIN dbo.Arbitro a ON sa.id_arbitro = a.id_arbitro
    INNER JOIN dbo.Partido p ON sa.id_partido = p.id_partido
    WHERE sa.id_partido = @id_partido
    ORDER BY sa.fecha DESC;
END;
GO

-- =========================================================
-- UPDATE - Actualizar sanción arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sancion_Arbitral_Modificacion
    @id_sancion INT,
    @motivo VARCHAR(300),
    @tipo_sancion VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @errores NVARCHAR(MAX) = '';
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validar que la sanción existe
        IF NOT EXISTS (SELECT 1 FROM dbo.Sancion_Arbitral WHERE id_sancion = @id_sancion)
        BEGIN
            RAISERROR('La sanción arbitral especificada no existe.', 16, 1);
        END
        
        IF @errores <> ''
        BEGIN
            RAISERROR(@errores, 16, 1);
        END
        
        -- Actualizar sanción
        UPDATE dbo.Sancion_Arbitral
        SET motivo = @motivo,
            tipo_sancion = @tipo_sancion
        WHERE id_sancion = @id_sancion;
        
        COMMIT TRANSACTION;
        PRINT 'Sanción arbitral actualizada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO

-- =========================================================
-- DELETE - Eliminar sanción arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sancion_Arbitral_Baja
    @id_sancion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF NOT EXISTS (SELECT 1 FROM dbo.Sancion_Arbitral WHERE id_sancion = @id_sancion)
        BEGIN
            RAISERROR('La sanción arbitral especificada no existe.', 16, 1);
        END
        
        DELETE FROM dbo.Sancion_Arbitral WHERE id_sancion = @id_sancion;
        
        COMMIT TRANSACTION;
        PRINT 'Sanción arbitral eliminada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO
