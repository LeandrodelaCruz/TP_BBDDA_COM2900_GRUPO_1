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
    Script de testing COMPLETO para todos los procedimientos de Sanción Arbitral
    Incluye borrado inicial, datos de prueba y pruebas exitosas/validaciones fallidas.
    Cada caso de prueba define sus variables dentro de su propio lote (GO) para poder
    ejecutarse individualmente o corriendo todo el archivo.
    
    PROCEDIMIENTOS A PROBAR:
    - SP_Sancion_Arbitral_Alta (con validaciones)
    - SP_Sancion_Arbitral_GetById
    - SP_Sancion_Arbitral_GetByArbitro
    - SP_Sancion_Arbitral_GetByPartido
    - SP_Sancion_Arbitral_Modificacion
    - SP_Sancion_Arbitral_Baja
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO

/* =========================================================
   LIMPIEZA: Eliminar datos previos de pruebas anteriores
   ========================================================= */

PRINT '=== Limpiando datos de pruebas anteriores ===';

-- 1. Eliminar sanciones de prueba (dependen de partido y árbitro)
DELETE FROM dbo.Sancion_Arbitral
WHERE id_partido IN (
    SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB'
)
OR id_arbitro IN (
    SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion'
);

-- 2. Eliminar designaciones de prueba (dependen de partido y árbitro)
DELETE FROM dbo.Designacion_Arbitral
WHERE id_partido IN (
    SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB'
)
OR id_arbitro IN (
    SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion'
);

-- 3. Eliminar selecciones asociadas al partido de prueba
DELETE FROM dbo.Partido_Seleccion
WHERE id_partido IN (
    SELECT id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB'
);

-- 4. Eliminar el partido de prueba
DELETE FROM dbo.Partido
WHERE resultado_final = N'TEST-SANCION-ARB';

-- 5. Eliminar árbitros de prueba
DELETE FROM dbo.Arbitro
WHERE apellido = N'Test Sancion';

-- 6. Finalmente, eliminar la sede de prueba
DELETE FROM dbo.Sede
WHERE nombre_estadio = N'Estadio Testing Sancion';

PRINT '=== Limpieza completada ===';
GO

/* =========================================================
   PREPARACIÓN: datos mínimos de apoyo
   ========================================================= */

PRINT '=== Preparando datos de prueba ===';
GO

-- Sede de prueba
INSERT INTO dbo.Sede (nombre_estadio, ciudad, pais, capacidad, huso_horario)
VALUES (N'Estadio Testing Sancion', N'Ciudad Test', N'País Test', 50000, 'UTC-03:00');
GO

DECLARE @id_sede_test INT = (SELECT TOP 1 id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio Testing Sancion' ORDER BY id_sede DESC);

-- Partido de prueba
INSERT INTO dbo.Partido (id_sede, fecha, horario_local, horario_UTC, fase, resultado_final, asistencia_publico)
VALUES (@id_sede_test, '2026-06-10', '2026-06-10 18:00:00', '2026-06-10 21:00:00', 'GRUPOS', N'TEST-SANCION-ARB', 30000);
GO

DECLARE @id_partido_test INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);

-- Árbitros de prueba
INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
VALUES (N'Árbitro1', N'Test Sancion', '1980-01-01', N'País Test', N'PRINCIPAL', N'Español');

INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
VALUES (N'Árbitro2', N'Test Sancion', '1985-01-01', N'País Test', N'ASISTENTE', N'Inglés');

INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
VALUES (N'Árbitro3', N'Test Sancion', '1982-01-01', N'País Test', N'VAR', N'Español, Inglés');
GO

DECLARE @id_arbitro_designado INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_arbitro_no_designado INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro2' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_arbitro_sin_partido INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro3' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_partido_test INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);

-- Designación arbitral para el partido de prueba
INSERT INTO dbo.Designacion_Arbitral (id_partido, id_arbitro, rol_arbitro)
VALUES (@id_partido_test, @id_arbitro_designado, N'PRINCIPAL');

INSERT INTO dbo.Designacion_Arbitral (id_partido, id_arbitro, rol_arbitro)
VALUES (@id_partido_test, @id_arbitro_no_designado, N'ASISTENTE');

PRINT '=== Datos de apoyo preparados ===';
GO

/* =========================================================
   PRUEBAS: SANCIÓN ARBITRAL
   ========================================================= */

PRINT '=============================================';
PRINT ' PRUEBAS TABLA: dbo.Sancion_Arbitral';
PRINT '=============================================';
GO

-- ---------------------------------------------------------
-- CASO 1: Inserción exitosa - Sanción con partido designado
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 1: Inserción exitosa - Sanción con partido designado ---';

DECLARE @id_arbitro_designado INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_partido_test INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);
DECLARE @id_sancion1 INT;

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Alta
        @id_arbitro = @id_arbitro_designado,
        @id_partido = @id_partido_test,
        @fecha = '2026-06-10',
        @motivo = N'Falta grave en el partido',
        @tipo_sancion = 'SUSPENSION',
        @id_sancion = @id_sancion1 OUTPUT;

    PRINT 'OK - Sanción insertada con ID: ' + CAST(@id_sancion1 AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 2: Inserción exitosa - Sanción sin partido
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 2: Inserción exitosa - Sanción sin partido ---';

DECLARE @id_arbitro_sin_partido INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro3' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_sancion2 INT;

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Alta
        @id_arbitro = @id_arbitro_sin_partido,
        @id_partido = NULL,
        @fecha = '2026-06-01',
        @motivo = N'Comportamiento inapropiado fuera del partido',
        @tipo_sancion = 'ADVERTENCIA',
        @id_sancion = @id_sancion2 OUTPUT;

    PRINT 'OK - Sanción insertada con ID: ' + CAST(@id_sancion2 AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 3: Inserción exitosa - Otra sanción para el mismo árbitro
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 3: Inserción exitosa - Otra sanción mismo árbitro ---';

DECLARE @id_arbitro_designado INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_partido_test INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);
DECLARE @id_sancion3 INT;

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Alta
        @id_arbitro = @id_arbitro_designado,
        @id_partido = @id_partido_test,
        @fecha = '2026-06-10',
        @motivo = N'Llegada tardía al campo de juego',
        @tipo_sancion = 'MULTA',
        @id_sancion = @id_sancion3 OUTPUT;

    PRINT 'OK - Sanción insertada con ID: ' + CAST(@id_sancion3 AS VARCHAR(10));
END TRY
BEGIN CATCH
    PRINT 'ERROR: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 4: Validación fallida - Árbitro no designado para el partido
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 6: Validación fallida - Árbitro no designado ---';

DECLARE @id_arbitro_sin_partido INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro3' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_partido_test INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);
DECLARE @id_sancion_fail1 INT;

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Alta
        @id_arbitro = @id_arbitro_sin_partido,
        @id_partido = @id_partido_test,
        @fecha = '2026-06-10',
        @motivo = N'Árbitro no designado',
        @tipo_sancion = 'SUSPENSION',
        @id_sancion = @id_sancion_fail1 OUTPUT;

    PRINT 'ERROR: Debería haber fallado';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 5: Validación fallida - Partido inexistente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 5: Validación fallida - Partido inexistente ---';

DECLARE @id_arbitro_designado INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);
DECLARE @id_sancion_fail2 INT;

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Alta
        @id_arbitro = @id_arbitro_designado,
        @id_partido = 999999,
        @fecha = '2026-06-10',
        @motivo = N'Partido inexistente',
        @tipo_sancion = 'SUSPENSION',
        @id_sancion = @id_sancion_fail2 OUTPUT;

    PRINT 'ERROR: Debería haber fallado';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 6: GET por ID
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 9: GET por ID ---';

DECLARE @id_sancion_get INT = (
    SELECT TOP 1 id_sancion
    FROM dbo.Sancion_Arbitral
    WHERE id_arbitro IN (SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion')
    ORDER BY id_sancion
);

IF @id_sancion_get IS NOT NULL
BEGIN
    EXEC dbo.SP_Sancion_Arbitral_GetById @id_sancion = @id_sancion_get;
END
ELSE
    PRINT 'No hay sanciones para consultar';
GO

-- ---------------------------------------------------------
-- CASO 7: GET por árbitro
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 10: GET por árbitro ---';

DECLARE @id_arbitro_get INT = (SELECT TOP 1 id_arbitro FROM dbo.Arbitro WHERE nombre = N'Árbitro1' AND apellido = N'Test Sancion' ORDER BY id_arbitro DESC);

IF @id_arbitro_get IS NOT NULL
BEGIN
    EXEC dbo.SP_Sancion_Arbitral_GetByArbitro @id_arbitro = @id_arbitro_get;
END
ELSE
    PRINT 'No hay árbitro de prueba para consultar';
GO

-- ---------------------------------------------------------
-- CASO 8: GET por partido
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 11: GET por partido ---';

DECLARE @id_partido_get INT = (SELECT TOP 1 id_partido FROM dbo.Partido WHERE resultado_final = N'TEST-SANCION-ARB' ORDER BY id_partido DESC);

IF @id_partido_get IS NOT NULL
BEGIN
    EXEC dbo.SP_Sancion_Arbitral_GetByPartido @id_partido = @id_partido_get;
END
ELSE
    PRINT 'No hay partido de prueba para consultar';
GO

-- ---------------------------------------------------------
-- CASO 9: UPDATE - Cambiar motivo
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 9: UPDATE - Cambiar motivo ---';

DECLARE @id_sancion_update INT = (
    SELECT TOP 1 id_sancion
    FROM dbo.Sancion_Arbitral
    WHERE id_arbitro IN (SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion')
    ORDER BY id_sancion
);

IF @id_sancion_update IS NOT NULL
BEGIN
    BEGIN TRY
        PRINT 'Datos antes:';
        EXEC dbo.SP_Sancion_Arbitral_GetById @id_sancion = @id_sancion_update;

        EXEC dbo.SP_Sancion_Arbitral_Modificacion
            @id_sancion = @id_sancion_update,
            @motivo = N'Motivo actualizado por revisión';

        PRINT 'Datos después:';
        EXEC dbo.SP_Sancion_Arbitral_GetById @id_sancion = @id_sancion_update;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT 'No hay sanciones para actualizar';
GO

-- ---------------------------------------------------------
-- CASO 10: UPDATE fallido - ID inexistente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 10: UPDATE fallido - ID inexistente ---';

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Modificacion
        @id_sancion = 999999,
        @motivo = N'Sanción inexistente';

    PRINT 'ERROR: Debería haber fallado';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH
GO

-- ---------------------------------------------------------
-- CASO 11: DELETE - Eliminar sanción
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 11: DELETE - Eliminar sanción ---';

DECLARE @id_sancion_delete INT = (
    SELECT TOP 1 id_sancion
    FROM dbo.Sancion_Arbitral
    WHERE id_arbitro IN (SELECT id_arbitro FROM dbo.Arbitro WHERE apellido = N'Test Sancion')
    ORDER BY id_sancion DESC
);

IF @id_sancion_delete IS NOT NULL
BEGIN
    BEGIN TRY
        EXEC dbo.SP_Sancion_Arbitral_Baja @id_sancion = @id_sancion_delete;

        PRINT 'OK - Sanción eliminada';

        IF NOT EXISTS (SELECT 1 FROM dbo.Sancion_Arbitral WHERE id_sancion = @id_sancion_delete)
            PRINT 'CONFIRMADO: Sanción ya no existe en la BD';
        ELSE
            PRINT 'ERROR: Sanción aún existe';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH
END
ELSE
    PRINT 'No hay sanciones para eliminar';
GO

-- ---------------------------------------------------------
-- CASO 13: DELETE fallido - ID inexistente
-- ---------------------------------------------------------
PRINT '';
PRINT '--- CASO 12: DELETE fallido - ID inexistente ---';

BEGIN TRY
    EXEC dbo.SP_Sancion_Arbitral_Baja @id_sancion = 999999;

    PRINT 'ERROR: Debería haber fallado';
END TRY
BEGIN CATCH
    PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
END CATCH
GO

PRINT '';
PRINT '=============================================';
PRINT ' FIN DE PRUEBAS';
PRINT '=============================================';
GO
