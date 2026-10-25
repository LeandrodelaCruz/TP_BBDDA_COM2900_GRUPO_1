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
    Script de testing COMPLETO para los procedimientos ABM de Pieza_Para_Region.
    Incluye pruebas exitosas y validaciones de errores.

    PROCEDIMIENTOS A PROBAR:
    - Pieza_Para_Region_Alta
    - Pieza_Para_Region_Baja
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Pieza_Para_Region_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores (Pieza para Región) ===';

    DELETE FROM dbo.Pieza_Para_Region 
    WHERE id_pieza IN (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre LIKE N'%Test%ABM%');

    DELETE FROM dbo.Pieza_Publicitaria 
    WHERE nombre LIKE N'%Test%ABM%';

    DELETE FROM dbo.Campania 
    WHERE descripcion LIKE N'%Test%ABM%';

    DELETE FROM dbo.Anunciante 
    WHERE nombre LIKE N'%Test%ABM%';

    DELETE FROM dbo.Region 
    WHERE nombre LIKE N'%Test%ABM%';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIÓN: Datos de apoyo
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    INSERT INTO dbo.Region (nombre, descripcion)
    VALUES (N'Región Test ABM', N'Descripción Región Test');

    INSERT INTO dbo.Anunciante (nombre, cuit, email, telefono)
    VALUES (N'Anunciante Test ABM Region', N'30333333338', N'region@test.com', N'1144556677');

    DECLARE @id_anunc INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM Region');

    INSERT INTO dbo.Campania (descripcion, id_anunciante)
    VALUES (N'Campaña Test ABM Region', @id_anunc);

    DECLARE @id_camp INT = (SELECT id_campania FROM dbo.Campania WHERE descripcion = N'Campaña Test ABM Region');

    INSERT INTO dbo.Pieza_Publicitaria (id_campania, nombre, contenido, idioma)
    VALUES (@id_camp, N'Pieza Test ABM Region', N'Contenido Test', N'Español');

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: ABM PIEZA PARA REGIÓN
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Pieza_Para_Region';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Alta exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Alta exitosa ---';

    DECLARE @id_pieza_b6 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test ABM Region');
    DECLARE @id_region_b6 INT = (SELECT id_region FROM dbo.Region WHERE nombre = N'Región Test ABM');

    BEGIN TRY
        EXEC abm.Pieza_Para_Region_Alta
            @id_pieza_b6 = @id_pieza_b6,
            @id_region_b6 = @id_region_b6;

        PRINT 'OK - Relación Pieza-Región asignada exitosamente.';
        SELECT * FROM dbo.Pieza_Para_Region WHERE id_pieza = @id_pieza_b6 AND id_region = @id_region_b6;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 2: Alta fallida - Región inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Alta fallida - Región inexistente ---';

    DECLARE @id_pieza_b7 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test ABM Region');

    BEGIN TRY
        EXEC abm.Pieza_Para_Region_Alta
            @id_pieza_b7 = @id_pieza_b7,
            @id_region = -999;

        PRINT 'ERROR: Debería haber fallado por región inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 3: Baja exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Baja exitosa ---';

    DECLARE @id_pieza_b8 INT = (SELECT id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre = N'Pieza Test ABM Region');
    DECLARE @id_region_b8 INT = (SELECT id_region FROM dbo.Region WHERE nombre = N'Región Test ABM');

    BEGIN TRY
        EXEC abm.Pieza_Para_Region_Baja
            @id_pieza_b8 = @id_pieza_b8,
            @id_region_b8 = @id_region_b8;

        PRINT 'OK - Relación Pieza-Región eliminada correctamente.';
        IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Para_Region WHERE id_pieza = @id_pieza_b8 AND id_region = @id_region_b8)
            PRINT 'CONFIRMADO: Registro eliminado en la BD.';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 4: Baja fallida - Registro inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 4: Baja fallida - Registro inexistente ---';

    BEGIN TRY
        EXEC abm.Pieza_Para_Region_Baja
            @id_pieza = -999,
            @id_region = -999;

        PRINT 'ERROR: Debería haber fallado por relación inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    PRINT '';
    PRINT '=============================================';
    PRINT ' FIN DE PRUEBAS: Pieza_Para_Region';
    PRINT '=============================================';
END;
GO

EXEC test.Pieza_Para_Region_Test;
GO
