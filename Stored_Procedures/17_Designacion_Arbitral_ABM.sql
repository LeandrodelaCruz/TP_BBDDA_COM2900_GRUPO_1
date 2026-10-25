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
    Stored Procedures ABM para la tabla Designacion_Arbitral
    
    Validaciones de NEGOCIO:
    - Un árbitro NO puede ser del mismo país que las selecciones que juegan el partido
    - Rol de árbitro debe ser válido (PRINCIPAL, ASISTENTE, CUARTO ARBITRO, VAR, AVAR)
    
    Procedimientos:
    - SP_Designacion_Arbitral_Alta: Inserta designación con validaciones
    - SP_Designacion_Arbitral_GetByPartido: Obtiene árbitros designados para un partido
    - SP_Designacion_Arbitral_GetByArbitro: Obtiene partidos donde arbitró
    - SP_Designacion_Arbitral_Modificacion: Actualiza rol del árbitro
    - SP_Designacion_Arbitral_Baja: Elimina designación
*/

USE MUNDIALDEFUTBOL;
GO

-- =========================================================
-- CREATE - Insertar una nueva designación arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Designacion_Arbitral_Alta
    @id_partido INT,
    @id_arbitro INT,
    @rol_arbitro VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @errores NVARCHAR(MAX) = '';
    DECLARE @pais_arbitro NVARCHAR(80);
    DECLARE @pais_seleccion1 NVARCHAR(80);
    DECLARE @pais_seleccion2 NVARCHAR(80);
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- Obtener país del árbitro
        -- =========================================================
        SELECT @pais_arbitro = pais
        FROM dbo.Arbitro
        WHERE id_arbitro = @id_arbitro;
        
        -- =========================================================
        -- Obtener países de las selecciones que juegan el partido
        -- =========================================================

        SELECT @pais_seleccion1 = MIN(s.pais), @pais_seleccion2 = MAX(s.pais)
        FROM dbo.Seleccion s
        INNER JOIN dbo.Partido_Seleccion ps
        ON s.id_seleccion = ps.id_seleccion
        WHERE ps.id_partido = @id_partido;
        
        -- =========================================================
        -- VALIDACIÓN DE NEGOCIO: Árbitro no puede ser del mismo país
        -- =========================================================
        IF @pais_arbitro = @pais_seleccion1 OR @pais_arbitro = @pais_seleccion2
        BEGIN
            SET @errores = @errores + 'El árbitro no puede ser del mismo país que una de las selecciones que juegan. ';
        END
        
        -- Si hay errores, lanzar excepción
        IF @errores <> ''
        BEGIN
            RAISERROR(@errores, 16, 1);
        END
        
        -- =========================================================
        -- INSERCIÓN
        -- =========================================================
        INSERT INTO dbo.Designacion_Arbitral (
            id_partido,
            id_arbitro,
            rol_arbitro
        ) VALUES (
            @id_partido,
            @id_arbitro,
            @rol_arbitro
        );
        
        COMMIT TRANSACTION;
        PRINT 'Designación arbitral registrada exitosamente.';
        
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
            'Error al registrar designación arbitral: %s (Código de error: %d)',
            @error_severity,
            @error_state,
            @error_message,
            @error_number
        );
    END CATCH
END;
GO

-- =========================================================
-- READ - Obtener árbitros por partido
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Designacion_Arbitral_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    -- SELECT 
    --     da.id_partido,
    --     da.id_arbitro,
    --     a.nombre + ' ' + a.apellido AS nombre_arbitro,
    --     a.pais AS pais_arbitro,
    --     da.rol_arbitro,
    --     p.fecha,
    --     s1.pais AS seleccion_1,
    --     s2.pais AS seleccion_2
    -- FROM dbo.Designacion_Arbitral da
    -- INNER JOIN dbo.Arbitro a ON da.id_arbitro = a.id_arbitro
    -- INNER JOIN dbo.Partido p ON da.id_partido = p.id_partido
    -- LEFT JOIN dbo.Partido_Seleccion ps ON da.id_partido = ps.id_partido
    -- LEFT JOIN dbo.Seleccion s1 ON ps.id_seleccion = s1.id_seleccion
    -- LEFT JOIN dbo.Seleccion s2 ON ps.id_seleccion = s2.id_seleccion
    -- WHERE da.id_partido = @id_partido
    -- ORDER BY da.rol_arbitro;

        SELECT 
        da.id_partido,
        da.id_arbitro,
        a.nombre + ' ' + a.apellido AS nombre_arbitro,
        a.pais AS pais_arbitro,
        da.rol_arbitro,
        p.fecha,
            (SELECT TOP 1 pais FROM dbo.Seleccion 
            WHERE id_seleccion IN (SELECT id_seleccion FROM dbo.Partido_Seleccion WHERE id_partido = da.id_partido)
            ORDER BY id_seleccion) AS seleccion_1,
            (SELECT TOP 1 pais FROM dbo.Seleccion 
            WHERE id_seleccion IN (SELECT id_seleccion FROM dbo.Partido_Seleccion WHERE id_partido = da.id_partido)
            ORDER BY id_seleccion DESC) AS seleccion_2
        FROM dbo.Designacion_Arbitral da
        INNER JOIN dbo.Arbitro a ON da.id_arbitro = a.id_arbitro
        INNER JOIN dbo.Partido p ON da.id_partido = p.id_partido
        WHERE da.id_partido = @id_partido
        ORDER BY da.rol_arbitro;
END;
GO

-- =========================================================
-- READ - Obtener partidos donde arbitró un árbitro
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Designacion_Arbitral_GetByArbitro
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        da.id_partido,
        p.fecha,
        p.fase,
        s1.pais AS seleccion_1,
        s2.pais AS seleccion_2,
        da.id_arbitro,
        a.nombre + ' ' + a.apellido AS nombre_arbitro,
        da.rol_arbitro
    FROM dbo.Designacion_Arbitral da
    INNER JOIN dbo.Arbitro a ON da.id_arbitro = a.id_arbitro
    INNER JOIN dbo.Partido p ON da.id_partido = p.id_partido
    LEFT JOIN dbo.Partido_Seleccion ps ON da.id_partido = ps.id_partido
    LEFT JOIN dbo.Seleccion s1 ON ps.id_seleccion = s1.id_seleccion
    LEFT JOIN dbo.Seleccion s2 ON ps.id_seleccion = s2.id_seleccion
    WHERE da.id_arbitro = @id_arbitro
    ORDER BY p.fecha DESC;
END;
GO

-- =========================================================
-- UPDATE - Actualizar rol del árbitro
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Designacion_Arbitral_Modificacion
    @id_partido INT,
    @id_arbitro INT,
    @rol_arbitro VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- Validar que existe la designación
        -- =========================================================
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Designacion_Arbitral 
            WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro
        )
        BEGIN
            RAISERROR('La designación arbitral especificada no existe.', 16, 1);
        END
        
        -- =========================================================
        -- Actualizar rol
        -- =========================================================
        UPDATE dbo.Designacion_Arbitral
        SET rol_arbitro = @rol_arbitro
        WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro;
        
        COMMIT TRANSACTION;
        PRINT 'Rol de árbitro actualizado exitosamente.';
        
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
-- DELETE - Eliminar designación arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Designacion_Arbitral_Baja
    @id_partido INT,
    @id_arbitro INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Designacion_Arbitral 
            WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro
        )
        BEGIN
            RAISERROR('La designación arbitral especificada no existe.', 16, 1);
        END
        
        DELETE FROM dbo.Designacion_Arbitral 
        WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro;
        
        COMMIT TRANSACTION;
        PRINT 'Designación arbitral eliminada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO
