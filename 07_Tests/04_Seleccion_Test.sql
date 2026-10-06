/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Casos de prueba de dbo.Seleccion. Deja un registro TEST_ para inspección; 99_Limpiar_Tests.sql lo elimina.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


PRINT '===== TEST SELECCION =====';

DECLARE @id_prev INT = (
    SELECT TOP 1 id_seleccion FROM dbo.Seleccion
    WHERE pais IN (N'TEST_PAIS_SELECCION', N'TEST_PAIS_SELECCION_MOD', N'TEST_PAIS_SELECCION_BAJA')
    ORDER BY id_seleccion
);
WHILE @id_prev IS NOT NULL
BEGIN
    EXEC dbo.SP_Seleccion_Baja @id_prev;
    SET @id_prev = (
        SELECT TOP 1 id_seleccion FROM dbo.Seleccion
        WHERE pais IN (N'TEST_PAIS_SELECCION', N'TEST_PAIS_SELECCION_MOD', N'TEST_PAIS_SELECCION_BAJA')
        ORDER BY id_seleccion
    );
END;

-- 1) Alta exitosa
EXEC dbo.SP_Seleccion_Alta N'TEST_PAIS_SELECCION', N'CONMEBOL', 'A';
DECLARE @id INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'TEST_PAIS_SELECCION');

-- 2) Consulta
EXEC dbo.SP_Seleccion_ConsultarPorId @id;

-- 3) Modificación
EXEC dbo.SP_Seleccion_Modificar @id, N'TEST_PAIS_SELECCION_MOD', N'CONMEBOL', 'B';

-- 4) Listado
EXEC dbo.SP_Seleccion_Listar;

-- 5) Baja sobre un segundo registro
EXEC dbo.SP_Seleccion_Alta N'TEST_PAIS_SELECCION_BAJA', N'UEFA', 'C';
DECLARE @id_baja INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'TEST_PAIS_SELECCION_BAJA');
EXEC dbo.SP_Seleccion_Baja @id_baja;

-- VALIDACIÓN: confederación inválida
BEGIN TRY
    EXEC dbo.SP_Seleccion_Alta N'TEST_PAIS_ERROR', N'CONFEDERACION_INEXISTENTE', 'D';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: confederación inválida' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- VALIDACIÓN: país duplicado
BEGIN TRY
    EXEC dbo.SP_Seleccion_Alta N'TEST_PAIS_SELECCION_MOD', N'CONMEBOL', 'E';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: selección duplicada' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT * FROM dbo.Seleccion WHERE pais LIKE N'TEST_PAIS_SELECCION%';
GO
