/*
    Universidad: [COMPLETAR]
    Materia: Bases de Datos Aplicada
    Trabajo Práctico: Entrega 5 - Base de Datos
    Integrantes: [COMPLETAR]
    Fecha: 2026-10-04

    Descripción:
    Casos de prueba de dbo.Sede. Deja un registro TEST_ para inspección; 99_Limpiar_Tests.sql lo elimina.
*/

USE MundialDB;
GO

SET NOCOUNT ON;
GO


PRINT '===== TEST SEDE =====';

DECLARE @id_prev INT = (
    SELECT TOP 1 id_sede FROM dbo.Sede
    WHERE nombre_estadio IN (N'TEST_ESTADIO_PRINCIPAL', N'TEST_ESTADIO_MODIFICADO', N'TEST_ESTADIO_BAJA')
    ORDER BY id_sede
);
WHILE @id_prev IS NOT NULL
BEGIN
    EXEC dbo.sp_Sede_Baja @id_prev;
    SET @id_prev = (
        SELECT TOP 1 id_sede FROM dbo.Sede
        WHERE nombre_estadio IN (N'TEST_ESTADIO_PRINCIPAL', N'TEST_ESTADIO_MODIFICADO', N'TEST_ESTADIO_BAJA')
        ORDER BY id_sede
    );
END;

-- 1) Alta exitosa
EXEC dbo.sp_Sede_Alta N'TEST_ESTADIO_PRINCIPAL', N'TEST_CIUDAD', N'TEST_PAIS', 50000, 'UTC-03:00';
DECLARE @id INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'TEST_ESTADIO_PRINCIPAL');

-- 2) Consulta
EXEC dbo.sp_Sede_ConsultarPorId @id;

-- 3) Modificación
EXEC dbo.sp_Sede_Modificar @id, N'TEST_ESTADIO_MODIFICADO', N'TEST_CIUDAD', N'TEST_PAIS', 55000, 'UTC-03:00';

-- 4) Listado
EXEC dbo.sp_Sede_Listar;

-- 5) Baja sobre un segundo registro
EXEC dbo.sp_Sede_Alta N'TEST_ESTADIO_BAJA', N'TEST_CIUDAD_2', N'TEST_PAIS', 45000, 'UTC-03:00';
DECLARE @id_baja INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'TEST_ESTADIO_BAJA');
EXEC dbo.sp_Sede_Baja @id_baja;

-- VALIDACIÓN: capacidad inválida
BEGIN TRY
    EXEC dbo.sp_Sede_Alta N'TEST_ESTADIO_ERROR', N'TEST_CIUDAD', N'TEST_PAIS', 0, 'UTC-03:00';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: capacidad inválida' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- VALIDACIÓN: país vacío
BEGIN TRY
    EXEC dbo.sp_Sede_Alta N'TEST_ESTADIO_ERROR_2', N'TEST_CIUDAD', N'', 1000, 'UTC-03:00';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: país obligatorio' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT * FROM dbo.Sede WHERE nombre_estadio LIKE N'TEST_ESTADIO%';
GO
