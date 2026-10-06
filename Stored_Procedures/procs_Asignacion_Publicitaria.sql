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
    Stored Procedures ABM para la tabla Asignacion_Publicitaria
    
    Todas las validaciones están en constraints:
    - FK de partido y pieza
    - Costo >= 0
    - Número de espacio entre 1 y 4
    - Único (id_partido, numero_espacio)
    
    Procedimientos:
    - SP_Asignacion_Publicitaria_Alta
    - SP_Asignacion_Publicitaria_GetById
    - SP_Asignacion_Publicitaria_GetByPartido
    - SP_Asignacion_Publicitaria_Modificacion
    - SP_Asignacion_Publicitaria_Baja
*/

USE MUNDIALDEFUTBOL;
GO

-- =========================================================
-- CREATE - Insertar una nueva asignación publicitaria
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_Alta
    @id_partido INT,
    @id_pieza INT,
    @numero_espacio TINYINT,
    @costo_aplicado DECIMAL(14,2),
    @id_asignacion INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- INSERCIÓN - Constraints validan todo
        -- =========================================================
        INSERT INTO dbo.Asignacion_Publicitaria (
            id_partido,
            id_pieza,
            numero_espacio,
            costo_aplicado
        ) VALUES (
            @id_partido,
            @id_pieza,
            @numero_espacio,
            @costo_aplicado
        );
        
        SET @id_asignacion = SCOPE_IDENTITY();
        
        COMMIT TRANSACTION;
        PRINT 'Asignación publicitaria registrada exitosamente. ID: ' + CAST(@id_asignacion AS VARCHAR(10));
        
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
            'Error al registrar asignación publicitaria: %s (Código de error: %d)',
            @error_severity,
            @error_state,
            @error_message,
            @error_number
        );
    END CATCH
    
END;
GO

-- =========================================================
-- READ - Obtener asignación por ID
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_GetById
    @id_asignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ap.id_asignacion,
        ap.id_partido,
        p.fecha AS fecha_partido,
        ap.id_pieza,
        pp.nombre AS nombre_pieza,
        pp.idioma,
        c.id_campania,
        c.descripcion AS campania,
        a.id_anunciante,
        a.nombre AS anunciante,
        ap.numero_espacio,
        ap.costo_aplicado
    FROM dbo.Asignacion_Publicitaria ap
    INNER JOIN dbo.Partido p ON ap.id_partido = p.id_partido
    INNER JOIN dbo.Pieza_Publicitaria pp ON ap.id_pieza = pp.id_pieza
    INNER JOIN dbo.Campania c ON pp.id_campania = c.id_campania
    INNER JOIN dbo.Anunciante a ON c.id_anunciante = a.id_anunciante
    WHERE ap.id_asignacion = @id_asignacion;
END;
GO

-- =========================================================
-- READ - Obtener asignaciones por partido
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ap.id_asignacion,
        ap.id_partido,
        p.fecha AS fecha_partido,
        ap.numero_espacio,
        ap.id_pieza,
        pp.nombre AS nombre_pieza,
        pp.idioma,
        c.id_campania,
        c.descripcion AS campania,
        a.id_anunciante,
        a.nombre AS anunciante,
        ap.costo_aplicado
    FROM dbo.Asignacion_Publicitaria ap
    INNER JOIN dbo.Partido p ON ap.id_partido = p.id_partido
    INNER JOIN dbo.Pieza_Publicitaria pp ON ap.id_pieza = pp.id_pieza
    INNER JOIN dbo.Campania c ON pp.id_campania = c.id_campania
    INNER JOIN dbo.Anunciante a ON c.id_anunciante = a.id_anunciante
    WHERE ap.id_partido = @id_partido
    ORDER BY ap.numero_espacio ASC;
END;
GO

-- =========================================================
-- READ - Obtener historial de exhibiciones por anunciante (para facturación)
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_GetByAnunciante
    @id_anunciante INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        ap.id_asignacion,
        ap.id_partido,
        p.fecha AS fecha_partido,
        ap.numero_espacio,
        pp.nombre AS nombre_pieza,
        pp.idioma,
        c.descripcion AS campania,
        ap.costo_aplicado
    FROM dbo.Asignacion_Publicitaria ap
    INNER JOIN dbo.Partido p ON ap.id_partido = p.id_partido
    INNER JOIN dbo.Pieza_Publicitaria pp ON ap.id_pieza = pp.id_pieza
    INNER JOIN dbo.Campania c ON pp.id_campania = c.id_campania
    WHERE c.id_anunciante = @id_anunciante
    ORDER BY p.fecha DESC;
END;
GO

-- =========================================================
-- READ - Obtener totales por anunciante para facturación
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_TotalesPorAnunciante
    @id_anunciante INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        a.id_anunciante,
        a.nombre AS anunciante,
        COUNT(ap.id_asignacion) AS cantidad_exhibiciones,
        SUM(ap.costo_aplicado) AS costo_total,
        MIN(p.fecha) AS fecha_primera_exhibicion,
        MAX(p.fecha) AS fecha_ultima_exhibicion
    FROM dbo.Anunciante a
    INNER JOIN dbo.Campania c ON a.id_anunciante = c.id_anunciante
    INNER JOIN dbo.Pieza_Publicitaria pp ON c.id_campania = pp.id_campania
    INNER JOIN dbo.Asignacion_Publicitaria ap ON pp.id_pieza = ap.id_pieza
    INNER JOIN dbo.Partido p ON ap.id_partido = p.id_partido
    WHERE (@id_anunciante IS NULL OR a.id_anunciante = @id_anunciante)
    GROUP BY a.id_anunciante, a.nombre
    ORDER BY costo_total DESC;
END;
GO

-- =========================================================
-- UPDATE - Actualizar costo
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_Modificacion
    @id_asignacion INT,
    @costo_aplicado DECIMAL(14,2)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validar que la asignación existe
        IF NOT EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_asignacion = @id_asignacion)
        BEGIN
            RAISERROR('La asignación especificada no existe.', 16, 1);
        END
        
        UPDATE dbo.Asignacion_Publicitaria
        SET costo_aplicado = @costo_aplicado
        WHERE id_asignacion = @id_asignacion;
        
        COMMIT TRANSACTION;
        PRINT 'Asignación actualizada exitosamente.';
        
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
-- DELETE - Eliminar asignación
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Asignacion_Publicitaria_Baja
    @id_asignacion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF NOT EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_asignacion = @id_asignacion)
        BEGIN
            RAISERROR('La asignación especificada no existe.', 16, 1);
        END
        
        DELETE FROM dbo.Asignacion_Publicitaria WHERE id_asignacion = @id_asignacion;
        
        COMMIT TRANSACTION;
        PRINT 'Asignación eliminada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO
