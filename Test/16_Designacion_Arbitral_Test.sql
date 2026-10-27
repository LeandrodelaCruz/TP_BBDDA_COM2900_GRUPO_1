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
    Script de testing COMPLETO para todos los procedimientos de Designacion Arbitral
    Incluye pruebas exitosas y pruebas de validaciones fallidas
    
    PROCEDIMIENTOS A PROBAR:
    - Designacion_Arbitral_Alta (con validacion de pais)
    - Designacion_Arbitral_GetByPartido
    - Designacion_Arbitral_GetByArbitro
    - Designacion_Arbitral_Modificacion
    - Designacion_Arbitral_Baja
    
    Estructura correcta:
    PK: (id_partido, id_arbitro)
    Campos: id_partido, id_arbitro, rol_arbitro
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Designacion_Arbitral_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       =========================================================
       Se eliminan en orden inverso respetando las FK
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores ===';

    -- Eliminar designaciones arbitrales de pruebas anteriores
    DELETE FROM dbo.Designacion_Arbitral 
    WHERE id_partido IN (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

    -- Eliminar arbitros de prueba
    DELETE FROM dbo.Arbitro 
    WHERE nombre LIKE N'%ArbitroTest%';

    -- Eliminar partido de prueba
    DELETE FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL';

    -- Eliminar selecciones de prueba
    DELETE FROM dbo.Seleccion WHERE pais LIKE N'%Test Arbitral%';

    -- Eliminar sede de prueba
    DELETE FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Arbitral';

    /* =========================================================
       PREPARACIoN: datos minimos de apoyo
       =========================================================
       Se insertan: sede, selecciones, partido, arbitros
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    -- Sede de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Arbitral')
        INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
        VALUES (N'Estadio Testing Arbitral', N'Ciudad Test', N'Pais Test', 50000, 'UTC-03:00');

    -- Selecciones de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Seleccion Test Arbitral 1')
        INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
        VALUES (N'Seleccion Test Arbitral 1', N'TEST', 'A');

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'Seleccion Test Arbitral 2')
        INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
        VALUES (N'Seleccion Test Arbitral 2', N'TEST', 'A');

    DECLARE @id_sede_test INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Arbitral');
    DECLARE @id_sel_test1 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test Arbitral 1');
    DECLARE @id_sel_test2 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Seleccion Test Arbitral 2');

    -- Partido de prueba
    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL')
        INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico, id_seleccion_1, id_seleccion_2)
        VALUES (@id_sede_test, '2026-06-20', '2026-06-20 18:00:00', '2026-06-20 21:00:00', 'GRUPOS', N'TEST-ARBITRAL', 40000, @id_sel_test1, @id_sel_test2);

    DECLARE @id_partido_test_b6 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

    -- arbitros de prueba (usando datos reales de estructura)
    IF NOT EXISTS (SELECT 1 FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO')
        INSERT INTO dbo.Arbitro (nombre, apellido, pais, fecha_nacimiento, puesto, idiomas)
        VALUES (N'ArbitroTestEXTRANJERO', N'Test', N'Pais Arbitro Externo', '1970-01-01', N'PRINCIPAL', N'Español,Ingles');

    IF NOT EXISTS (SELECT 1 FROM dbo.Arbitro WHERE nombre = N'ArbitroTestPAIS1')
        INSERT INTO dbo.Arbitro (nombre, apellido, pais, fecha_nacimiento, puesto, idiomas)
        VALUES (N'ArbitroTestPAIS1', N'Test', N'Seleccion Test Arbitral 1', '1975-01-01', N'PRINCIPAL', N'Español');

    IF NOT EXISTS (SELECT 1 FROM dbo.Arbitro WHERE nombre = N'ArbitroTestPAIS2')
        INSERT INTO dbo.Arbitro (nombre, apellido, pais, fecha_nacimiento, puesto, idiomas)
        VALUES (N'ArbitroTestPAIS2', N'Test', N'Seleccion Test Arbitral 2', '1980-01-01', N'PRINCIPAL', N'Español,Portugues');

    PRINT ''
    PRINT '========================================================='
    PRINT 'TESTING COMPLETO - PROCEDIMIENTOS DE DESIGNACIoN ARBITRAL'
    PRINT '========================================================='

    -- =========================================================
    -- PASO 1: Verificar datos de prueba preparados
    -- =========================================================

    PRINT ''
    PRINT '--- PASO 1: Verificar datos de prueba preparados ---'

    PRINT 'Partido de prueba:'
    SELECT id_partido, fecha, resultado_final FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL';

    PRINT 'Selecciones de prueba:'
    SELECT id_seleccion, pais FROM dbo.Seleccion WHERE pais LIKE N'%Test Arbitral%';

    PRINT 'arbitros de prueba:'
    SELECT id_arbitro, nombre, apellido, pais FROM dbo.Arbitro WHERE nombre LIKE N'%ArbitroTest%';

    -- =========================================================
    -- PASO 2: INSERT - CASO EXITOSO
    -- =========================================================

    PRINT ''
    PRINT '========================================================='
    PRINT 'PASO 2: INSERT - Caso exitoso'
    PRINT '========================================================='

    DECLARE @id_partido_test_b11 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
    DECLARE @id_arbitro_extranjero_b11 INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

    PRINT ''
    PRINT '--- CASO 1: Insertar arbitro PRINCIPAL (pais diferente) - EXITOSA ---'

    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Alta
            @id_partido = @id_partido_test_b11,
            @id_arbitro = @id_arbitro_extranjero_b11,
            @rol_arbitro = N'PRINCIPAL';

        PRINT 'eXITO: arbitro designado como PRINCIPAL';

        -- Verificar insercion
        SELECT id_partido, id_arbitro, rol_arbitro 
        FROM dbo.Designacion_Arbitral 
        WHERE id_partido = @id_partido_test_b11 AND id_arbitro = @id_arbitro_extranjero_b11;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- =========================================================
    -- PASO 3: INSERT - VALIDACIONES FALLIDAS
    -- =========================================================

    PRINT ''
    PRINT '========================================================='
    PRINT 'PASO 3: INSERT - Validaciones fallidas'
    PRINT '========================================================='

    DECLARE @id_partido_test_b13 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
    DECLARE @id_arbitro_pais1 INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestPAIS1');

    PRINT ''
    PRINT '--- CASO 2: arbitro del MISMO PAiS que seleccion - RECHAZADA ---'

    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Alta
            @id_partido = @id_partido_test_b13,
            @id_arbitro = @id_arbitro_pais1,
            @rol_arbitro = N'ASISTENTE';

        PRINT 'ERROR: Deberia haber fallado validacion de pais';
    END TRY
    BEGIN CATCH
        PRINT 'VALIDACIoN CORRECTA: ' + ERROR_MESSAGE();
    END CATCH

    -- =========================================================
    -- PASO 4: GET - arbitros designados por Partido
    -- =========================================================

    PRINT ''
    PRINT '========================================================='
    PRINT 'PASO 4: GET - arbitros designados por Partido'
    PRINT '========================================================='

    DECLARE @id_partido_test_b15 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');

    PRINT ''
    PRINT '--- arbitros designados para el partido de prueba ---'

    EXEC abm.Designacion_Arbitral_GetByPartido @id_partido = @id_partido_test_b15;

    -- =========================================================
    -- PASO 5: GET - Partidos designados a un arbitro
    -- =========================================================

    PRINT ''
    PRINT '========================================================='
    PRINT 'PASO 5: GET - Partidos donde arbitro'
    PRINT '========================================================='

    DECLARE @id_arbitro_extranjero_b17 INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

    PRINT ''
    PRINT '--- Partidos designados al arbitro de prueba ---'

    EXEC abm.Designacion_Arbitral_GetByArbitro @id_arbitro = @id_arbitro_extranjero_b17;

    -- =========================================================
    -- PASO 6: UPDATE - Cambiar rol del arbitro
    -- =========================================================

    PRINT ''
    PRINT '========================================================='
    PRINT 'PASO 6: UPDATE - Cambiar rol'
    PRINT '========================================================='

    DECLARE @id_partido_test_b19 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
    DECLARE @id_arbitro_extranjero_b19 INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

    PRINT ''
    PRINT '--- CASO 5: Cambiar rol de PRINCIPAL a VAR - EXITOSA ---'

    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Modificacion
            @id_partido = @id_partido_test_b19,
            @id_arbitro = @id_arbitro_extranjero_b19,
            @rol_arbitro = N'VAR';

        PRINT 'eXITO: Rol actualizado a VAR';

        -- Verificar actualizacion
        SELECT id_partido, id_arbitro, rol_arbitro 
        FROM dbo.Designacion_Arbitral 
        WHERE id_partido = @id_partido_test_b19 AND id_arbitro = @id_arbitro_extranjero_b19;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    -- =========================================================
    -- PASO 7: DELETE - Eliminar designacion arbitral
    -- =========================================================

    PRINT ''
    PRINT '========================================================='
    PRINT 'PASO 7: DELETE - Eliminar designacion'
    PRINT '========================================================='

    DECLARE @id_partido_test_b21 INT = (SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-ARBITRAL');
    DECLARE @id_arbitro_extranjero_b21 INT = (SELECT id_arbitro FROM dbo.Arbitro WHERE nombre = N'ArbitroTestEXTRANJERO');

    PRINT ''
    PRINT '--- CASO 6: Eliminar designacion - EXITOSA ---'

    BEGIN TRY
        EXEC abm.Designacion_Arbitral_Baja
            @id_partido = @id_partido_test_b21,
            @id_arbitro = @id_arbitro_extranjero_b21;

        PRINT 'eXITO: Designacion eliminada';

        -- Verificar eliminacion
        IF EXISTS (SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido = @id_partido_test_b21 AND id_arbitro = @id_arbitro_extranjero_b21)
            PRINT 'ERROR: La designacion aun existe';
        ELSE
            PRINT 'Confirmado: Registro eliminado correctamente';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH

    PRINT ''
    PRINT '========================================================='
    PRINT 'FIN DE TESTING'
    PRINT '========================================================='
END;
GO

EXEC test.Designacion_Arbitral_Test;
GO
