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
    Stored Procedures ABM para la tabla Incidencia
    
    Tipos de incidencias:
    - GOL: Gol marcado por id_jugador, id_jugador_involucrado es asistencia (opcional)
    - AMONESTACION: Tarjeta amarilla a id_jugador, id_jugador_involucrado es agredido
    - EXPULSION: Tarjeta roja a id_jugador, id_jugador_involucrado es agredido

    PROCEDIMIENTOS INCLUIDOS:
    - SP_Incidencia_Insert (con validaciones)
    - SP_Incidencia_Update (solo motivo)
    - SP_Incidencia_Delete
    
    GET especializados:
    - SP_Incidencia_GetGoles: Muestra goles con asistencias
    - SP_Incidencia_GetAmonestaciones: Muestra amarillas con agredido
    - SP_Incidencia_GetExpulsiones: Muestra rojas con agredido
    - SP_Incidencia_GetByPartido:Muestra todas las incidencias de un partido
*/

USE MUNDIALDEFUTBOL;
GO

-- =========================================================
-- CREATE - Insertar una nueva incidencia
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_Insert
    @id_partido INT,
    @id_jugador INT,
    @tipo VARCHAR(30),
    @periodo VARCHAR(30),
    @minuto TINYINT = NULL,
    @motivo VARCHAR(200) = NULL,
    @id_jugador_involucrado INT = NULL,
    @id_incidencia INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @errores NVARCHAR(MAX) = '';
    DECLARE @id_seleccion_jugador INT;
    DECLARE @id_seleccion_involucrado INT;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- =========================================================
        -- Obtener selecciones de ambos jugadores
        -- =========================================================
        SELECT @id_seleccion_jugador = id_seleccion 
        FROM dbo.Jugador 
        WHERE id_jugador = @id_jugador;
        
        IF @id_jugador_involucrado IS NOT NULL
        BEGIN
            SELECT @id_seleccion_involucrado = id_seleccion 
            FROM dbo.Jugador 
            WHERE id_jugador = @id_jugador_involucrado;
        END
        
        -- =========================================================
        -- VALIDACIÓN DE NEGOCIO: Lógica según tipo de incidencia
        -- =========================================================
        
        -- GOL: involucrado debe ser MISMA selección (asistencia)
        IF @tipo = 'GOL' AND @id_jugador_involucrado IS NOT NULL
        BEGIN
            IF @id_seleccion_jugador <> @id_seleccion_involucrado
                SET @errores = @errores + 'GOL: el asistente debe ser de la misma selección. ';
        END
        
        -- AMONESTACION y EXPULSION: involucrado debe ser DIFERENTE selección (agredido)
        IF @tipo IN ('AMONESTACION', 'EXPULSION')
        BEGIN
            IF @id_jugador_involucrado IS NULL
                SET @errores = @errores + 'Para ' + @tipo + ' debe especificar el jugador agredido. ';
            ELSE IF @id_seleccion_jugador = @id_seleccion_involucrado
                SET @errores = @errores + @tipo + ': el jugador agredido debe ser de la selección opuesta. ';
        END
        
        -- Si hay errores, lanzar excepción
        IF @errores <> ''
        BEGIN
            RAISERROR(@errores, 16, 1);
        END
        
        -- =========================================================
        -- INSERCIÓN
        -- =========================================================
        INSERT INTO dbo.Incidencia (
            id_partido,
            id_jugador,
            id_jugador_involucrado,
            tipo,
            motivo,
            minuto,
            periodo
        ) VALUES (
            @id_partido,
            @id_jugador,
            @id_jugador_involucrado,
            @tipo,
            @motivo,
            @minuto,
            @periodo
        );
        
        SET @id_incidencia = SCOPE_IDENTITY();
        
        COMMIT TRANSACTION;
        PRINT 'Incidencia registrada exitosamente. ID: ' + CAST(@id_incidencia AS VARCHAR(10));
        
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
            'Error al registrar incidencia: %s (Código de error: %d)',
            @error_severity,
            @error_state,
            @error_message,
            @error_number
        );
    END CATCH
    
END;
GO

-- =========================================================
-- READ - Obtener GOLES por partido con asistencias
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_GetGoles
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        i.id_incidencia,
        i.id_partido,
        i.minuto,
        i.periodo,
        i.id_jugador,
        j.nombre + ' ' + j.apellido AS goleador,
        j.id_seleccion,
        s.pais AS seleccion_goleador,
        i.id_jugador_involucrado,
        CASE WHEN i.id_jugador_involucrado IS NOT NULL 
             THEN ja.nombre + ' ' + ja.apellido 
             ELSE 'Sin asistencia'
        END AS asistencia,
        i.tipo,
        i.motivo
    FROM dbo.Incidencia i
    INNER JOIN dbo.Jugador j ON i.id_jugador = j.id_jugador
    INNER JOIN dbo.Seleccion s ON j.id_seleccion = s.id_seleccion
    LEFT JOIN dbo.Jugador ja ON i.id_jugador_involucrado = ja.id_jugador
    WHERE i.id_partido = @id_partido AND i.tipo = 'GOL'
    ORDER BY i.minuto ASC;
END;
GO

-- =========================================================
-- READ - Obtener AMONESTACIONES (tarjetas amarillas)
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_GetAmonestaciones
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        i.id_incidencia,
        i.id_partido,
        i.minuto,
        i.periodo,
        i.id_jugador,
        j.nombre + ' ' + j.apellido AS jugador_amonestado,
        j.id_seleccion,
        s.pais AS seleccion_amonestado,
        i.id_jugador_involucrado,
        ja.nombre + ' ' + ja.apellido AS jugador_agredido,
        sa.pais AS seleccion_agredido,
        i.tipo AS tarjeta,
        i.motivo
    FROM dbo.Incidencia i
    INNER JOIN dbo.Jugador j ON i.id_jugador = j.id_jugador
    INNER JOIN dbo.Seleccion s ON j.id_seleccion = s.id_seleccion
    INNER JOIN dbo.Jugador ja ON i.id_jugador_involucrado = ja.id_jugador
    INNER JOIN dbo.Seleccion sa ON ja.id_seleccion = sa.id_seleccion
    WHERE i.id_partido = @id_partido AND i.tipo = 'AMONESTACION'
    ORDER BY i.minuto ASC;
END;
GO

-- =========================================================
-- READ - Obtener EXPULSIONES (tarjetas rojas)
-- =========================================================
CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_GetExpulsiones
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        i.id_incidencia,
        i.id_partido,
        i.minuto,
        i.periodo,
        i.id_jugador,
        j.nombre + ' ' + j.apellido AS jugador_expulsado,
        j.id_seleccion,
        s.pais AS seleccion_expulsado,
        i.id_jugador_involucrado,
        ja.nombre + ' ' + ja.apellido AS jugador_agredido,
        sa.pais AS seleccion_agredido,
        i.tipo AS tarjeta,
        i.motivo
    FROM dbo.Incidencia i
    INNER JOIN dbo.Jugador j ON i.id_jugador = j.id_jugador
    INNER JOIN dbo.Seleccion s ON j.id_seleccion = s.id_seleccion
    INNER JOIN dbo.Jugador ja ON i.id_jugador_involucrado = ja.id_jugador
    INNER JOIN dbo.Seleccion sa ON ja.id_seleccion = sa.id_seleccion
    WHERE i.id_partido = @id_partido AND i.tipo = 'EXPULSION'
    ORDER BY i.minuto ASC;
END;
GO

-- =========================================================
-- READ - Obtener todas las incidencias de un partido
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_GetByPartido
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;
    
    SELECT 
        i.id_incidencia,
        i.id_partido,
        i.minuto,
        i.periodo,
        i.tipo,
        j.nombre + ' ' + j.apellido AS jugador,
        s.pais AS seleccion_jugador,
        CASE WHEN i.id_jugador_involucrado IS NOT NULL 
             THEN ja.nombre + ' ' + ja.apellido 
             ELSE 'N/A'
        END AS jugador_involucrado,
        i.motivo
    FROM dbo.Incidencia i
    INNER JOIN dbo.Jugador j ON i.id_jugador = j.id_jugador
    INNER JOIN dbo.Seleccion s ON j.id_seleccion = s.id_seleccion
    LEFT JOIN dbo.Jugador ja ON i.id_jugador_involucrado = ja.id_jugador
    WHERE i.id_partido = @id_partido
    ORDER BY i.minuto ASC;
END;
GO

-- =========================================================
-- UPDATE - Actualizar incidencia (solo motivo)
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_Update
    @id_incidencia INT,
    @motivo VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Validar que la incidencia existe
        IF NOT EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_incidencia = @id_incidencia)
        BEGIN
            RAISERROR('La incidencia especificada no existe.', 16, 1);
        END
        
        -- Actualizar solo el motivo
        UPDATE dbo.Incidencia
        SET motivo = @motivo
        WHERE id_incidencia = @id_incidencia;
        
        COMMIT TRANSACTION;
        PRINT 'Incidencia actualizada exitosamente.';
        
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
-- DELETE - Eliminar incidencia
-- =========================================================

CREATE OR ALTER PROCEDURE dbo.SP_Incidencia_Delete
    @id_incidencia INT
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        IF NOT EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_incidencia = @id_incidencia)
        BEGIN
            RAISERROR('La incidencia especificada no existe.', 16, 1);
        END
        
        DELETE FROM dbo.Incidencia WHERE id_incidencia = @id_incidencia;
        
        COMMIT TRANSACTION;
        PRINT 'Incidencia eliminada exitosamente.';
        
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        
        DECLARE @error_message NVARCHAR(MAX) = ERROR_MESSAGE();
        RAISERROR(@error_message, 16, 1);
    END CATCH
END;
GO
