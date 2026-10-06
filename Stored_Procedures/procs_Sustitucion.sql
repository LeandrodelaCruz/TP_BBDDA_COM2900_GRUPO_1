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
    Stored Procedures ABM para la tabla Sustitucion

    PROCEDIMIENTOS INCLUIDOS:
    - sp_Sustitucion_Alta (con validaciones)
    - sp_Sustitucion_GetById
    - sp_Sustitucion_GetByPartido
    - sp_Sustitucion_Modificacion
    - sp_Sustitucion_Baja
    
    Validaciones de NEGOCIO:
    - El jugador que entra NO puede ser TITULAR (debe ser SUPLENTE)
    - Máximo 5 sustituciones por equipo por partido dentro de 3 ventanas
      (4 en tiempo reglamentario, 1 extra en tiempo suplementario)
*/

USE MUNDIALDEFUTBOL;
GO

-- =========================================================
-- CREATE - Insertar una nueva sustitución
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sustitucion_Alta
    @id_partido INT,
    @id_jugador_sale INT,
    @id_jugador_entra INT,
    @minuto TINYINT,
    @periodo VARCHAR(30),
    @numero_ventana TINYINT,
    @motivo VARCHAR(100) = NULL,
    @id_sustitucion INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @errores NVARCHAR(MAX) = '';
    
    -- Variables para jugador que ENTRA
    DECLARE @id_seleccion_entra INT;
    DECLARE @id_formacion_entra INT;
    DECLARE @es_titular_entra BIT;
    
    -- Variables para jugador que SALE
    DECLARE @id_seleccion_sale INT;
    DECLARE @id_formacion_sale INT;
    
    -- Variables para validaciones
    DECLARE @hay_suplementario BIT = 0;
    DECLARE @limite_ventanas INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- VALIDACIÓN 1: Obtener datos del JUGADOR QUE ENTRA
        -- (selección, formación, si es titular)
        -- =========================================================
        SELECT @id_seleccion_entra = j.id_seleccion,
               @id_formacion_entra = f.id_formacion,
               @es_titular_entra = fj.es_titular
        FROM dbo.Jugador j
        LEFT JOIN dbo.Formacion f ON f.id_partido = @id_partido AND f.id_seleccion = j.id_seleccion
        LEFT JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion AND fj.id_jugador = j.id_jugador
        WHERE j.id_jugador = @id_jugador_entra;
        
        -- =========================================================
        -- VALIDACIÓN 2: Obtener datos del JUGADOR QUE SALE
        -- (selección, formación)
        -- =========================================================
        SELECT @id_seleccion_sale = j.id_seleccion,
               @id_formacion_sale = f.id_formacion
        FROM dbo.Jugador j
        LEFT JOIN dbo.Formacion f ON f.id_partido = @id_partido AND f.id_seleccion = j.id_seleccion
        LEFT JOIN dbo.Formacion_Jugador fj ON fj.id_formacion = f.id_formacion AND fj.id_jugador = j.id_jugador
        WHERE j.id_jugador = @id_jugador_sale;
        
        -- =========================================================
        -- VALIDACIÓN 3: Ambos jugadores deben pertenecer a la misma selección
        -- =========================================================
        IF @id_seleccion_sale <> @id_seleccion_entra
        BEGIN
            SET @errores = @errores + 'Los jugadores deben pertenecer a la misma selección. ';
        END
        
        -- =========================================================
        -- VALIDACIÓN 4: Ambos jugadores deben estar en la formación del partido
        -- =========================================================
        IF @id_formacion_entra IS NULL
        BEGIN
            SET @errores = @errores + 'El jugador que entra no está inscrito en la formación del partido. ';
        END
        
        IF @id_formacion_sale IS NULL
        BEGIN
            SET @errores = @errores + 'El jugador que sale no está inscrito en la formación del partido. ';
        END
        
        -- =========================================================
        -- VALIDACIÓN 5: El jugador que ENTRA NO puede ser TITULAR
        -- (Debe ser SUPLENTE) - VALIDACIÓN DE NEGOCIO
        -- =========================================================
        IF @es_titular_entra = 1
        BEGIN
            SET @errores = @errores + 'El jugador que entra debe ser un SUPLENTE. ';
        END
        
        
        -- =========================================================
        -- VALIDACIÓN 6: Validar número de ventana según período
        -- Detectar si hay suplementario
        -- =========================================================
        IF @periodo IN ('PRIMER SUPLEMENTARIO', 'SEGUNDO SUPLEMENTARIO')
            SET @hay_suplementario = 1;
        
        -- Límite de ventanas: 3 en reglamentario, 4 en suplementario
        SET @limite_ventanas = CASE WHEN @hay_suplementario = 1 THEN 4 ELSE 3 END;
        
        -- Validar que el número de ventana no exceda el límite
        IF @numero_ventana IS NULL
        BEGIN
            SET @errores = @errores + 'Debe especificar el número de ventana. ';
        END
        ELSE IF @numero_ventana < 1
        BEGIN
            SET @errores = @errores + 'El número de ventana debe ser mayor a 0. ';
        END
        ELSE IF @numero_ventana > @limite_ventanas
        BEGIN
            IF @hay_suplementario = 1
                SET @errores = @errores + 'El número de ventana no puede exceder 4 en tiempo suplementario. ';
            ELSE
                SET @errores = @errores + 'El número de ventana no puede exceder 3 en tiempo reglamentario. ';
        END
        
        -- =========================================================
        -- VALIDACIÓN 7: Validar cantidad de sustituciones
        -- Máximo 5 en tiempo reglamentario, 6 en tiempo suplementario
        -- =========================================================
        DECLARE @contar_sustituciones INT;
        DECLARE @limite_sustituciones INT;
        
        SELECT @contar_sustituciones = COUNT(*) 
        FROM dbo.Sustitucion s
        INNER JOIN dbo.Jugador j ON s.id_jugador_sale = j.id_jugador
        WHERE s.id_partido = @id_partido AND j.id_seleccion = @id_seleccion_sale;
        
        -- Límite de sustituciones: 6 en suplementario, 5 en reglamentario
        SET @limite_sustituciones = CASE WHEN @hay_suplementario = 1 THEN 6 ELSE 5 END;
        
        IF @contar_sustituciones >= @limite_sustituciones
        BEGIN
            IF @hay_suplementario = 1
                SET @errores = @errores + 'Ya se alcanzó el límite de 6 sustituciones para este equipo (con tiempo suplementario). ';
            ELSE
                SET @errores = @errores + 'Ya se alcanzó el límite de 5 sustituciones para este equipo en tiempo reglamentario. ';
        END
        
        -- =========================================================
        -- Si hay errores acumulados, lanzar excepción
        -- =========================================================
        IF @errores <> ''
        BEGIN
            RAISERROR(@errores, 16, 1);
        END
        
        -- =========================================================
        -- INSERCIÓN - Todo validado correctamente
        -- =========================================================
        INSERT INTO dbo.Sustitucion (
            id_partido,
            id_jugador_sale,
            id_jugador_entra,
            minuto,
            periodo,
            motivo,
            numero_ventana
        ) VALUES (
            @id_partido,
            @id_jugador_sale,
            @id_jugador_entra,
            @minuto,
            @periodo,
            @motivo,
            @numero_ventana
        );
        
        SET @id_sustitucion = SCOPE_IDENTITY();
        
        COMMIT TRANSACTION;
        PRINT 'Sustitución registrada exitosamente. ID: ' + CAST(@id_sustitucion AS VARCHAR(10));
        
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
        
        -- Capturar error de constraint o de lógica
        RAISERROR(
            'Error al registrar sustitución: %s (Código de error: %d)',
            @error_severity,
            @error_state,
            @error_message,
            @error_number
        );
    END CATCH
    
END;
GO

-- =========================================================
-- READ - Obtener sustitución por ID
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.SP_Sustitucion_GetById
    @id_sustitucion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.id_sustitucion,
        s.id_partido,
        js.id_seleccion,
        sel.pais AS seleccion,
        s.id_jugador_sale,
        js.nombre + ' ' + js.apellido AS nombre_jugador_sale,
        s.id_jugador_entra,
        je.nombre + ' ' + je.apellido AS nombre_jugador_entra,
        s.minuto,
        s.periodo,
        s.motivo,
        s.numero_ventana
    FROM dbo.Sustitucion s
    INNER JOIN dbo.Jugador js ON s.id_jugador_sale = js.id_jugador
    INNER JOIN dbo.Jugador je ON s.id_jugador_entra = je.id_jugador
    INNER JOIN dbo.Seleccion sel ON js.id_seleccion = sel.id_seleccion
    WHERE s.id_sustitucion = @id_sustitucion;
END;
GO

-- =========================================================
-- READ - Obtener sustituciones por partido
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sustitucion_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        s.id_sustitucion,
        s.id_partido,
        js.id_seleccion,
        sel.pais AS seleccion,
        s.minuto,
        s.periodo,
        s.id_jugador_sale,
        js.nombre + ' ' + js.apellido AS nombre_jugador_sale,
        s.id_jugador_entra,
        je.nombre + ' ' + je.apellido AS nombre_jugador_entra,
        s.motivo,
        s.numero_ventana
    FROM dbo.Sustitucion s
    INNER JOIN dbo.Jugador js ON s.id_jugador_sale = js.id_jugador
    INNER JOIN dbo.Jugador je ON s.id_jugador_entra = je.id_jugador
    INNER JOIN dbo.Seleccion sel ON js.id_seleccion = sel.id_seleccion
    WHERE s.id_partido = @id_partido
    ORDER BY s.minuto ASC;
END;
GO

-- =========================================================
-- UPDATE - Actualizar sustitución
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sustitucion_Modificacion
    @id_sustitucion INT,
    @motivo VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- VALIDACIÓN: La sustitución debe existir
        -- =========================================================
        IF NOT EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_sustitucion = @id_sustitucion)
        BEGIN
            RAISERROR('La sustitución especificada no existe.', 16, 1);
        END
        
        -- =========================================================
        -- ACTUALIZACIÓN: Solo se permite cambiar el motivo
        -- =========================================================
        UPDATE dbo.Sustitucion
        SET motivo = @motivo
        WHERE id_sustitucion = @id_sustitucion;
        
        COMMIT TRANSACTION;
        PRINT 'Motivo de sustitución actualizado exitosamente.';
        
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
-- DELETE - Eliminar sustitución
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Sustitucion_Baja
    @id_sustitucion INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF NOT EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_sustitucion = @id_sustitucion)
        BEGIN
            RAISERROR('La sustitución especificada no existe.', 16, 1);
        END
        
        DELETE FROM dbo.Sustitucion WHERE id_sustitucion = @id_sustitucion;
        
        COMMIT TRANSACTION;
        PRINT 'Sustitución eliminada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO
