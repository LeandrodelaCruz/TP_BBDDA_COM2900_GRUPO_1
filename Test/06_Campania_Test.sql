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
    - SP_Campania_Alta
    - SP_Campania_Modificar
    - SP_Campania_Baja
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

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
GO

/* =========================================================
   PREPARACIÓN: Datos de apoyo
   ========================================================= */

PRINT '=== Preparando datos de prueba ===';

INSERT INTO dbo.Anunciante (nombre, cuit, email, telefono)
VALUES (N'Anunciante Test ABM', N'30111111118', N'test@anunciante.com', N'1122334455');

PRINT '=== Datos de apoyo preparados ===';
GO

/* =========================================================
   PRUEBAS: ABM CAMPAÑA
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Campania';
PRINT '=============================================';
GO

-- ---------------------------------------------------------
-- CASO 1: Alta exitosa
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 1: Alta exitosa ---';

DECLARE @id_anunc INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM');

BEGIN TRY
    EXEC dbo.SP_Campania_Alta
        @descripcion = N'Campaña Test ABM Mundial 2026',
        @id_anunciante = @id_anunc;

    PRINT 'OK - Campaña dada de alta exitosamente.';
    SELECT * FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%';
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ---------------------------------------------------------
-- CASO 2: Alta fallida - Descripción vacía
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 2: Alta fallida - Descripción vacía ---';

DECLARE @id_anunc INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM');

BEGIN TRY
    EXEC dbo.SP_Campania_Alta
        @descripcion = N'   ',
        @id_anunciante = @id_anunc;

    PRINT 'ERROR: Debería haber fallado por descripción vacía.';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ---------------------------------------------------------
-- CASO 3: Modificación exitosa
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 3: Modificación exitosa ---';

DECLARE @id_anunc INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM');
DECLARE @id_campania INT = (SELECT TOP 1 id_campania FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%');

BEGIN TRY
    EXEC dbo.SP_Campania_Modificar
        @id_campania = @id_campania,
        @descripcion = N'Campaña Test ABM Mundial 2026 - Modificada',
        @id_anunciante = @id_anunc;

    PRINT 'OK - Campaña modificada correctamente.';
    SELECT * FROM dbo.Campania WHERE id_campania = @id_campania;
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ---------------------------------------------------------
-- CASO 4: Baja exitosa
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 4: Baja exitosa ---';

DECLARE @id_campania_del INT = (SELECT TOP 1 id_campania FROM dbo.Campania WHERE descripcion LIKE N'%Test%ABM%');

BEGIN TRY
    EXEC dbo.SP_Campania_Baja @id_campania = @id_campania_del;

    PRINT 'OK - Campaña eliminada correctamente.';
    IF NOT EXISTS (SELECT 1 FROM dbo.Campania WHERE id_campania = @id_campania_del)
        PRINT 'CONFIRMADO: Registro eliminado en la BD.';
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ---------------------------------------------------------
-- CASO 5: Baja fallida - ID inexistente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 5: Baja fallida - ID inexistente ---';

BEGIN TRY
    EXEC dbo.SP_Campania_Baja @id_campania = -999;
    PRINT 'ERROR: Debería haber fallado.';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '';
PRINT '=============================================';
PRINT ' FIN DE PRUEBAS: Campania';
PRINT '=============================================';
GO