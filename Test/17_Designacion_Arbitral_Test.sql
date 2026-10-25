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
    Script de testing COMPLETO para todos los procedimientos de Designación Arbitral
    Incluye pruebas exitosas y pruebas de validaciones fallidas
    
    PROCEDIMIENTOS A PROBAR:
    - sp_Designacion_Arbitral_Alta (con validación de país)
    - sp_Designacion_Arbitral_GetByPartido
    - sp_Designacion_Arbitral_GetByArbitro
    - sp_Designacion_Arbitral_Modificacion
    - sp_Designacion_Arbitral_Baja
    
    Estructura correcta:
    PK: (id_partido, id_arbitro)
    Campos: id_partido, id_arbitro, rol_arbitro
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   LIMPIEZA: Eliminar datos previos de pruebas anteriores
   =========================================================
   Se eliminan en orden inverso respetando las FK
   ========================================================= */

PRINT '=== Limpiando datos de pruebas anteriores ===';
GO

-- Eliminar designaciones arbitrales de pruebas anteriores
DELETE FROM dbo.Designacion_Arbitral 
WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

-- Eliminar árbitros de prueba
DELETE FROM dbo.Arbitro 
WHERE nombre LIKE N'%ArbitroTest%';

-- Eliminar relaciones Partido_Seleccion
DELETE FROM dbo.Partido_Seleccion 
WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

-- Eliminar partido de prueba
DELETE FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL';

-- Eliminar selecciones de prueba
DELETE FROM dbo.Seleccion WHERE pais LIKE N'%Test Arbitral%';

-- Eliminar sede de prueba
DELETE FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Arbitral';

GO

/* =========================================================
   PREPARACIÓN: datos mínimos de apoyo
   =========================================================
   Se insertan: sede, selecciones, partido, árbitros
   ========================================================= */

PRINT '=== Preparando datos de prueba ===';
GO

-- Sede de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Arbitral')
    INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
    VALUES (N'Estadio Testing Arbitral', N'Ciudad Test', N'País Test', 50000, 'UTC-03:00');

-- Selecciones de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Selección Test Arbitral 1')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test Arbitral 1', N'TEST', 'A');

IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Selección Test Arbitral 2')
    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test Arbitral 2', N'TEST', 'A');

DECLARE @id_sede_test INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Arbitral');
DECLARE @id_sel_test1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test Arbitral 1');
DECLARE @id_sel_test2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test Arbitral 2');

-- Partido de prueba
IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL')
    INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico)
    VALUES (@id_sede_test, '2026-06-20', '2026-06-20 18:00:00', '2026-06-20 21:00:00', 'GRUPOS', N'TEST-ARBITRAL', 40000);

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

-- Relación partido-selección
IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test1)
    INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion) VALUES (@id_partido_test, @id_sel_test1);

IF NOT EXISTS (SELECT 1 FROM dbo.Partido_Seleccion WHERE id_partido = @id_partido_test AND id_seleccion = @id_sel_test2)
    INSERT INTO dbo.Partido_Seleccion (id_partido, id_seleccion) VALUES (@id_partido_test, @id_sel_test2);

-- Árbitros de prueba (usando datos reales de estructura)
IF NOT EXISTS (SELECT 1 FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO')
    INSERT INTO dbo.Arbitro (nombre, apellido, pais, fecha_nacimiento, puesto, idiomas)
    VALUES (N'ArbitroTestEXTRANJERO', N'Test', N'País Arbitro Externo', '1970-01-01', N'PRINCIPAL', N'Español,Inglés');

IF NOT EXISTS (SELECT 1 FROM dbo.Arbitro WHERE nombre = N'ArbitroTestPAIS1')
    INSERT INTO dbo.Arbitro (nombre, apellido, pais, fecha_nacimiento, puesto, idiomas)
    VALUES (N'ArbitroTestPAIS1', N'Test', N'Selección Test Arbitral 1', '1975-01-01', N'PRINCIPAL', N'Español');

IF NOT EXISTS (SELECT 1 FROM dbo.Arbitro WHERE nombre = N'ArbitroTestPAIS2')
    INSERT INTO dbo.Arbitro (nombre, apellido, pais, fecha_nacimiento, puesto, idiomas)
    VALUES (N'ArbitroTestPAIS2', N'Test', N'Selección Test Arbitral 2', '1980-01-01', N'PRINCIPAL', N'Español,Portugués');

GO

PRINT ''
PRINT '========================================================='
PRINT 'TESTING COMPLETO - PROCEDIMIENTOS DE DESIGNACIÓN ARBITRAL'
PRINT '========================================================='
GO

-- =========================================================
-- PASO 1: Verificar datos de prueba preparados
-- =========================================================

PRINT ''
PRINT '--- PASO 1: Verificar datos de prueba preparados ---'
GO

PRINT 'Partido de prueba:'
SELECT id_partido, fecha, resultado_final FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL';

PRINT 'Selecciones de prueba:'
SELECT id_seleccion, pais FROM dbo.Seleccion WHERE pais LIKE N'%Test Arbitral%';

PRINT 'Árbitros de prueba:'
SELECT id_arbitro, nombre, apellido, pais FROM dbo.Arbitro WHERE nombre LIKE N'%ArbitroTest%';
GO

-- =========================================================
-- PASO 2: INSERT - CASO EXITOSO
-- =========================================================

PRINT ''
PRINT '========================================================='
PRINT 'PASO 2: INSERT - Caso exitoso'
PRINT '========================================================='
GO

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
DECLARE @id_arbitro_extranjero INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

PRINT ''
PRINT '--- CASO 1: Insertar árbitro PRINCIPAL (país diferente) - EXITOSA ---'

BEGIN TRY
    EXEC dbo.sp_Designacion_Arbitral_Alta
        @id_partido = @id_partido_test,
        @id_arbitro = @id_arbitro_extranjero,
        @rol_arbitro = N'PRINCIPAL';
    
    PRINT 'ÉXITO: Árbitro designado como PRINCIPAL';
    
    -- Verificar inserción
    SELECT id_partido, id_arbitro, rol_arbitro 
    FROM dbo.Designacion_Arbitral 
    WHERE id_partido = @id_partido_test AND id_arbitro = @id_arbitro_extranjero;
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

-- =========================================================
-- PASO 3: INSERT - VALIDACIONES FALLIDAS
-- =========================================================

PRINT ''
PRINT '========================================================='
PRINT 'PASO 3: INSERT - Validaciones fallidas'
PRINT '========================================================='
GO

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
DECLARE @id_arbitro_pais1 INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestPAIS1');

PRINT ''
PRINT '--- CASO 2: Árbitro del MISMO PAÍS que selección - RECHAZADA ---'

BEGIN TRY
    EXEC dbo.sp_Designacion_Arbitral_Alta
        @id_partido = @id_partido_test,
        @id_arbitro = @id_arbitro_pais1,
        @rol_arbitro = N'ASISTENTE';
    
    PRINT 'ERROR: Debería haber fallado validación de país';
END TRY
BEGIN CATCH
    PRINT 'VALIDACIÓN CORRECTA: ' + ERROR_MESSAGE();
END CATCH
GO

-- =========================================================
-- PASO 4: GET - Árbitros designados por Partido
-- =========================================================

PRINT ''
PRINT '========================================================='
PRINT 'PASO 4: GET - Árbitros designados por Partido'
PRINT '========================================================='
GO

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

PRINT ''
PRINT '--- Árbitros designados para el partido de prueba ---'

EXEC dbo.sp_Designacion_Arbitral_GetByPartido @id_partido = @id_partido_test;
GO

-- =========================================================
-- PASO 5: GET - Partidos designados a un Árbitro
-- =========================================================

PRINT ''
PRINT '========================================================='
PRINT 'PASO 5: GET - Partidos donde arbitró'
PRINT '========================================================='
GO

DECLARE @id_arbitro_extranjero INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

PRINT ''
PRINT '--- Partidos designados al árbitro de prueba ---'

EXEC dbo.sp_Designacion_Arbitral_GetByArbitro @id_arbitro = @id_arbitro_extranjero;
GO

-- =========================================================
-- PASO 6: UPDATE - Cambiar rol del árbitro
-- =========================================================

PRINT ''
PRINT '========================================================='
PRINT 'PASO 6: UPDATE - Cambiar rol'
PRINT '========================================================='
GO

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
DECLARE @id_arbitro_extranjero INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

PRINT ''
PRINT '--- CASO 5: Cambiar rol de PRINCIPAL a VAR - EXITOSA ---'

BEGIN TRY
    EXEC dbo.sp_Designacion_Arbitral_Modificacion
        @id_partido = @id_partido_test,
        @id_arbitro = @id_arbitro_extranjero,
        @rol_arbitro = N'VAR';
    
    PRINT 'ÉXITO: Rol actualizado a VAR';
    
    -- Verificar actualización
    SELECT id_partido, id_arbitro, rol_arbitro 
    FROM dbo.Designacion_Arbitral 
    WHERE id_partido = @id_partido_test AND id_arbitro = @id_arbitro_extranjero;
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

-- =========================================================
-- PASO 7: DELETE - Eliminar designación arbitral
-- =========================================================

PRINT ''
PRINT '========================================================='
PRINT 'PASO 7: DELETE - Eliminar designación'
PRINT '========================================================='
GO

DECLARE @id_partido_test INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
DECLARE @id_arbitro_extranjero INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

PRINT ''
PRINT '--- CASO 6: Eliminar designación - EXITOSA ---'

BEGIN TRY
    EXEC dbo.sp_Designacion_Arbitral_Baja
        @id_partido = @id_partido_test,
        @id_arbitro = @id_arbitro_extranjero;
    
    PRINT 'ÉXITO: Designación eliminada';
    
    -- Verificar eliminación
    IF EXISTS (SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido = @id_partido_test AND id_arbitro = @id_arbitro_extranjero)
        PRINT 'ERROR: La designación aún existe';
    ELSE
        PRINT 'Confirmado: Registro eliminado correctamente';
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT ''
PRINT '========================================================='
PRINT 'FIN DE TESTING'
PRINT '========================================================='
GO
