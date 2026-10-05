/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5 - Base de Datos
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Casos de prueba de dbo.Region. Deja un registro TEST_ para inspección; 99_Limpiar_Tests.sql lo elimina.
*/

USE MundialDB;
GO

SET NOCOUNT ON;
GO


PRINT '===== TEST REGION =====';

DECLARE @id_prev INT = (
    SELECT TOP 1 id_region FROM dbo.Region
    WHERE nombre IN (N'TEST_REGION_PRINCIPAL', N'TEST_REGION_MODIFICADA', N'TEST_REGION_BAJA')
    ORDER BY id_region
);
WHILE @id_prev IS NOT NULL
BEGIN
    EXEC dbo.sp_Region_Baja @id_prev;
    SET @id_prev = (
        SELECT TOP 1 id_region FROM dbo.Region
        WHERE nombre IN (N'TEST_REGION_PRINCIPAL', N'TEST_REGION_MODIFICADA', N'TEST_REGION_BAJA')
        ORDER BY id_region
    );
END;

-- 1) Alta exitosa
EXEC dbo.sp_Region_Alta N'TEST_REGION_PRINCIPAL', N'Español', 'UTC-03:00', '19:00', '23:00';
DECLARE @id INT = (SELECT id_region FROM dbo.Region WHERE nombre = N'TEST_REGION_PRINCIPAL');

-- 2) Consulta
EXEC dbo.sp_Region_ConsultarPorId @id;

-- 3) Modificación
EXEC dbo.sp_Region_Modificar @id, N'TEST_REGION_MODIFICADA', N'Español', 'UTC-03:00', '18:00', '22:00';

-- 4) Listado
EXEC dbo.sp_Region_Listar;

-- 5) Baja sobre un segundo registro
EXEC dbo.sp_Region_Alta N'TEST_REGION_BAJA', N'Inglés', 'UTC-05:00', '19:00', '23:00';
DECLARE @id_baja INT = (SELECT id_region FROM dbo.Region WHERE nombre = N'TEST_REGION_BAJA');
EXEC dbo.sp_Region_Baja @id_baja;

-- VALIDACIÓN: rango prime time inválido
BEGIN TRY
    EXEC dbo.sp_Region_Alta N'TEST_REGION_ERROR', N'Español', 'UTC-03:00', '23:00', '19:00';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: prime time inválido' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- VALIDACIÓN: región duplicada
BEGIN TRY
    EXEC dbo.sp_Region_Alta N'TEST_REGION_MODIFICADA', N'Español', 'UTC-03:00', '19:00', '23:00';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: región duplicada' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT * FROM dbo.Region WHERE nombre LIKE N'TEST_REGION%';
GO
