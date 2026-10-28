/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comision: Com: 01-2900
    Grupo 01: 
    - Caro, Nicolas Dario
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodriguez Elias Uriel

    Descripcion:
    Stored Procedures ABM para la tabla Designacion_Arbitral
    
    Validaciones de NEGOCIO:
    - Un arbitro NO puede ser del mismo pais que las selecciones que juegan el partido
    - Rol de arbitro debe ser valido (PRINCIPAL, ASISTENTE, CUARTO ARBITRO, VAR, AVAR)
    
    Procedimientos:
    - Designacion_Arbitral_Alta: Inserta designacion con validaciones
    - Designacion_Arbitral_GetByPartido: Obtiene arbitros designados para un partido
    - Designacion_Arbitral_GetByArbitro: Obtiene partidos donde arbitro
    - Designacion_Arbitral_Modificacion: Actualiza rol del arbitro
    - Designacion_Arbitral_Baja: Elimina designacion
*/

USE MUNDIALDEFUTBOL;
GO

-- =========================================================
-- CREATE - Insertar una nueva designacion arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Alta
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
        -- Obtener pais del arbitro
        -- =========================================================
        SELECT @pais_arbitro = pais
        FROM dbo.Arbitro
        WHERE id_arbitro = @id_arbitro;
        
        -- =========================================================
        -- Obtener paises de las selecciones que juegan el partido
        -- =========================================================

        SELECT 
            @pais_seleccion1 = s1.pais,
            @pais_seleccion2 = s2.pais
        FROM dbo.Partido p
        INNER JOIN dbo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion
        INNER JOIN dbo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion
        WHERE p.id_partido = @id_partido;
        
        -- =========================================================
        -- VALIDACIoN DE NEGOCIO: arbitro no puede ser del mismo pais
        -- =========================================================
        IF @pais_arbitro = @pais_seleccion1 OR @pais_arbitro = @pais_seleccion2
        BEGIN
            SET @errores = @errores + 'El arbitro no puede ser del mismo pais que una de las selecciones que juegan. ';
        END
        
        -- Si hay errores, lanzar excepcion
        IF @errores <> ''
        BEGIN
            RAISERROR(@errores, 16, 1);
        END
        
        -- =========================================================
        -- INSERCIoN
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
        PRINT 'Designacion arbitral registrada exitosamente.';
        
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
            'Error al registrar designacion arbitral: %s (Codigo de error: %d)',
            @error_severity,
            @error_state,
            @error_message,
            @error_number
        );
    END CATCH
END;
GO

-- =========================================================
-- READ - Obtener arbitros por partido
-- =========================================================

CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
        SELECT 
            da.id_partido,
            da.id_arbitro,
            a.nombre + ' ' + a.apellido AS nombre_arbitro,
            a.pais AS pais_arbitro,
            da.rol_arbitro,
            p.fecha,
            s1.pais AS seleccion_1,
            s2.pais AS seleccion_2
        FROM dbo.Designacion_Arbitral da
        INNER JOIN dbo.Arbitro a ON da.id_arbitro = a.id_arbitro
        INNER JOIN dbo.Partido p ON da.id_partido = p.id_partido
        INNER JOIN dbo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion
        INNER JOIN dbo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion
        WHERE da.id_partido = @id_partido
        ORDER BY da.rol_arbitro;
END;
GO

-- =========================================================
-- READ - Obtener partidos donde arbitro un arbitro
-- =========================================================

CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_GetByArbitro
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
    INNER JOIN dbo.Seleccion s1 ON p.id_seleccion_1 = s1.id_seleccion
    INNER JOIN dbo.Seleccion s2 ON p.id_seleccion_2 = s2.id_seleccion
    WHERE da.id_arbitro = @id_arbitro
    ORDER BY p.fecha DESC;
END;
GO

-- =========================================================
-- UPDATE - Actualizar rol del arbitro
-- =========================================================

CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Modificacion
    @id_partido INT,
    @id_arbitro INT,
    @rol_arbitro VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- Validar que existe la designacion
        -- =========================================================
        IF NOT EXISTS (
            SELECT 1 FROM dbo.Designacion_Arbitral 
            WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro
        )
        BEGIN
            RAISERROR('La designacion arbitral especificada no existe.', 16, 1);
        END
        
        -- =========================================================
        -- Actualizar rol
        -- =========================================================
        UPDATE dbo.Designacion_Arbitral
        SET rol_arbitro = @rol_arbitro
        WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro;
        
        COMMIT TRANSACTION;
        PRINT 'Rol de arbitro actualizado exitosamente.';
        
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
-- DELETE - Eliminar designacion arbitral
-- =========================================================

CREATE OR ALTER PROCEDURE abm.Designacion_Arbitral_Baja
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
            RAISERROR('La designacion arbitral especificada no existe.', 16, 1);
        END
        
        DELETE FROM dbo.Designacion_Arbitral 
        WHERE id_partido = @id_partido AND id_arbitro = @id_arbitro;
        
        COMMIT TRANSACTION;
        PRINT 'Designacion arbitral eliminada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO
