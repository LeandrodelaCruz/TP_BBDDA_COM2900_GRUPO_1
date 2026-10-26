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
    Script de testing COMPLETO para los procedimientos ABM de Campania.
    Incluye pruebas exitosas y validaciones de errores.

    PROCEDIMIENTOS A PROBAR:
    - Campania_Alta
    - Campania_Modificar
    - Campania_Baja
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Campania_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores (Campaña) ===';

    DELETE FROM dbo.Pieza_Publicitaria
    WHERE id_campania IN (SELECT id_campania FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%');

    DELETE FROM dbo.Campania 
    WHERE descripcion LIKE N'%Test%ABM%';

    DELETE FROM dbo.Anunciante 
    WHERE nombre LIKE N'%Test%ABM%';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIÓN: Datos de apoyo
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    INSERT INTO dbo.Anunciante (nombre, cuit, email, telefono)
    VALUES (N'Anunciante Test ABM', N'30111111118', N'test@anunciante.com', N'1122334455');

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: ABM CAMPAÑA
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Campania';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Alta exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Alta exitosa ---';

    DECLARE @id_anunc_b6 INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM');

    BEGIN TRY
        EXEC abm.Campania_Alta
            @descripcion = N'Campaña Test ABM Mundial 2026',
            @id_anunciante = @id_anunc_b6;

        PRINT 'OK - Campaña dada de alta exitosamente.';
        SELECT * FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 2: Alta fallida - Descripción vacía
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Alta fallida - Descripción vacía ---';

    DECLARE @id_anunc_b7 INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM');

    BEGIN TRY
        EXEC abm.Campania_Alta
            @descripcion = N'   ',
            @id_anunciante = @id_anunc_b7;

        PRINT 'ERROR: Debería haber fallado por descripción vacía.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 3: Modificación exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Modificación exitosa ---';

    DECLARE @id_anunc_b8 INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM');
    DECLARE @id_campania INT = (SELECT TOP 1 id_campania FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%');

    BEGIN TRY
        EXEC abm.Campania_Modificar
            @id_campania = @id_campania,
            @descripcion = N'Campaña Test ABM Mundial 2026 - Modificada',
            @id_anunciante = @id_anunc_b8;

        PRINT 'OK - Campaña modificada correctamente.';
        SELECT * FROM dbo.Campania WHERE id_campania = @id_campania;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 4: Baja exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 4: Baja exitosa ---';

    DECLARE @id_campania_del INT = (SELECT TOP 1 id_campania FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%');

    BEGIN TRY
        EXEC abm.Campania_Baja @id_campania = @id_campania_del;

        PRINT 'OK - Campaña eliminada correctamente.';
        IF NOT EXISTS (SELECT 1 FROM dbo.Campania WHERE id_campania = @id_campania_del)
            PRINT 'CONFIRMADO: Registro eliminado en la BD.';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 5: Baja fallida - ID inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 5: Baja fallida - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Campania_Baja @id_campania = -999;
        PRINT 'ERROR: Debería haber fallado.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    PRINT '';
    PRINT '=============================================';
    PRINT ' FIN DE PRUEBAS: Campania';
    PRINT '=============================================';
END;
GO

EXEC test.Campania_Test;
GO
