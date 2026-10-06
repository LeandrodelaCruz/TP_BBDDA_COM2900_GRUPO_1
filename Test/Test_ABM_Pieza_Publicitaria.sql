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
    Script de testing COMPLETO para los procedimientos ABM de Pieza_Publicitaria.
    Incluye pruebas exitosas y validaciones de errores.

    PROCEDIMIENTOS A PROBAR:
    - SP_Pieza_Publicitaria_Alta
    - SP_Pieza_Publicitaria_Modificar
    - SP_Pieza_Publicitaria_Baja
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   LIMPIEZA: Eliminar datos previos de pruebas anteriores
   ========================================================= */

PRINT '=== Limpiando datos de pruebas anteriores (Pieza Publicitaria) ===';

DELETE FROM dbo.Pieza_Publicitaria 
WHERE nombre LIKE N'%Test%ABM%';

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
VALUES (N'Anunciante Test ABM Pieza', N'30222222228', N'pieza@test.com', N'1133445566');

DECLARE @id_anunc INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'Anunciante Test ABM Pieza');

INSERT INTO dbo.Campania (descripcion, id_anunciante)
VALUES (N'Campaña Test ABM Pieza', @id_anunc);

PRINT '=== Datos de apoyo preparados ===';
GO

/* =========================================================
   PRUEBAS: ABM PIEZA PUBLICITARIA
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Pieza_Publicitaria';
PRINT '=============================================';
GO

-- ---------------------------------------------------------
-- CASO 1: Alta exitosa
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 1: Alta exitosa ---';

DECLARE @id_camp INT = (SELECT id_campania FROM dbo.Campania WHERE descripcion = N'Campaña Test ABM Pieza');

BEGIN TRY
    EXEC dbo.SP_Pieza_Publicitaria_Alta
        @id_campania = @id_camp,
        @nombre = N'Banner Test ABM 1',
        @contenido = N'Texto publicitario promocional',
        @idioma = N'Español';

    PRINT 'OK - Pieza publicitaria dada de alta exitosamente.';
    SELECT * FROM dbo.Pieza_Publicitaria WHERE nombre LIKE N'%Test%ABM%';
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ---------------------------------------------------------
-- CASO 2: Alta fallida - Campaña inexistente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 2: Alta fallida - Campaña inexistente ---';

BEGIN TRY
    EXEC dbo.SP_Pieza_Publicitaria_Alta
        @id_campania = -999,
        @nombre = N'Banner Invalido',
        @contenido = N'Contenido',
        @idioma = N'Español';

    PRINT 'ERROR: Debería haber fallado por campaña inexistente.';
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

DECLARE @id_camp INT = (SELECT id_campania FROM dbo.Campania WHERE descripcion = N'Campaña Test ABM Pieza');
DECLARE @id_pieza INT = (SELECT TOP 1 id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre LIKE N'%Test%ABM%');

BEGIN TRY
    EXEC dbo.SP_Pieza_Publicitaria_Modificar
        @id_pieza = @id_pieza,
        @id_campania = @id_camp,
        @nombre = N'Banner Test ABM 1 - Actualizado',
        @contenido = N'Nuevo texto promocional 2026',
        @idioma = N'Inglés';

    PRINT 'OK - Pieza publicitaria modificada correctamente.';
    SELECT * FROM dbo.Pieza_Publicitaria WHERE id_pieza = @id_pieza;
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

DECLARE @id_pieza_del INT = (SELECT TOP 1 id_pieza FROM dbo.Pieza_Publicitaria WHERE nombre LIKE N'%Test%ABM%');

BEGIN TRY
    EXEC dbo.SP_Pieza_Publicitaria_Baja @id_pieza = @id_pieza_del;

    PRINT 'OK - Pieza publicitaria eliminada correctamente.';
    IF NOT EXISTS (SELECT 1 FROM dbo.Pieza_Publicitaria WHERE id_pieza = @id_pieza_del)
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
    EXEC dbo.SP_Pieza_Publicitaria_Baja @id_pieza = -999;
    PRINT 'ERROR: Debería haber fallado.';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '';
PRINT '=============================================';
PRINT ' FIN DE PRUEBAS: Pieza_Publicitaria';
PRINT '=============================================';
GO