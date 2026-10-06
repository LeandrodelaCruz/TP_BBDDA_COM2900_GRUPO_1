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
    Script de testing COMPLETO para los procedimientos ABM de Personal_Tecnico.
    Incluye pruebas exitosas y validaciones de errores.

    PROCEDIMIENTOS A PROBAR:
    - SP_Personal_Tecnico_Alta
    - SP_Personal_Tecnico_Modificar
    - SP_Personal_Tecnico_Baja
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   LIMPIEZA: Eliminar datos previos de pruebas anteriores
   ========================================================= */

PRINT '=== Limpiando datos de pruebas anteriores (Personal Técnico) ===';

DELETE FROM dbo.Personal_Tecnico 
WHERE id_seleccion IN (SELECT id_seleccion FROM dbo.Seleccion WHERE pais LIKE N'%Test%ABM%');

DELETE FROM dbo.Seleccion 
WHERE pais LIKE N'%Test%ABM%';

PRINT '=== Limpieza completada ===';
GO

/* =========================================================
   PREPARACIÓN: Datos de apoyo
   ========================================================= */

PRINT '=== Preparando datos de prueba ===';

INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
VALUES (N'Selección Test ABM Personal', N'TEST', 'Z');

PRINT '=== Datos de apoyo preparados ===';
GO

/* =========================================================
   PRUEBAS: ABM PERSONAL TÉCNICO
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Personal_Tecnico';
PRINT '=============================================';
GO

-- ---------------------------------------------------------
-- CASO 1: Alta exitosa
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 1: Alta exitosa ---';

DECLARE @id_sel INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Personal');

BEGIN TRY
    EXEC dbo.SP_Personal_Tecnico_Alta
        @nombre = N'Lionel',
        @apellido = N'Scaloni',
        @rol = N'Director Técnico',
        @id_seleccion = @id_sel;

    PRINT 'OK - Personal técnico dado de alta exitosamente.';
    SELECT * FROM dbo.Personal_Tecnico WHERE id_seleccion = @id_sel;
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH;
GO

-- ---------------------------------------------------------
-- CASO 2: Alta fallida - Nombre/Apellido obligatorio
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 2: Alta fallida - Nombre vacío ---';

DECLARE @id_sel INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Personal');

BEGIN TRY
    EXEC dbo.SP_Personal_Tecnico_Alta
        @nombre = N'   ',
        @apellido = N'Aimar',
        @rol = N'Ayudante Campo',
        @id_seleccion = @id_sel;

    PRINT 'ERROR: Debería haber fallado por nombre vacío.';
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

DECLARE @id_sel INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Personal');
DECLARE @id_personal INT = (SELECT TOP 1 id_personal FROM dbo.Personal_Tecnico WHERE id_seleccion = @id_sel);

BEGIN TRY
    EXEC dbo.SP_Personal_Tecnico_Modificar
        @id_personal = @id_personal,
        @nombre = N'Lionel Sebastián',
        @apellido = N'Scaloni',
        @rol = N'Director Técnico Principal',
        @id_seleccion = @id_sel;

    PRINT 'OK - Personal técnico modificado correctamente.';
    SELECT * FROM dbo.Personal_Tecnico WHERE id_personal = @id_personal;
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

DECLARE @id_sel INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Personal');
DECLARE @id_personal_del INT = (SELECT TOP 1 id_personal FROM dbo.Personal_Tecnico WHERE id_seleccion = @id_sel);

BEGIN TRY
    EXEC dbo.SP_Personal_Tecnico_Baja @id_personal = @id_personal_del;

    PRINT 'OK - Personal técnico eliminado correctamente.';
    IF NOT EXISTS (SELECT 1 FROM dbo.Personal_Tecnico WHERE id_personal = @id_personal_del)
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
    EXEC dbo.SP_Personal_Tecnico_Baja @id_personal = -999;
    PRINT 'ERROR: Debería haber fallado.';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH;
GO

PRINT '';
PRINT '=============================================';
PRINT ' FIN DE PRUEBAS: Personal_Tecnico';
PRINT '=============================================';
GO