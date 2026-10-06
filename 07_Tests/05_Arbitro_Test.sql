/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Casos de prueba de dbo.Arbitro. Deja un registro TEST_ para inspección; 99_Limpiar_Tests.sql lo elimina.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;
GO


PRINT '===== TEST ARBITRO =====';

DECLARE @id_prev INT = (
    SELECT TOP 1 id_arbitro FROM dbo.Arbitro
    WHERE nombre IN (N'TEST_ARBITRO', N'TEST_ARBITRO_MOD', N'TEST_ARBITRO_BAJA')
    ORDER BY id_arbitro
);
WHILE @id_prev IS NOT NULL
BEGIN
    EXEC dbo.SP_Arbitro_Baja @id_prev;
    SET @id_prev = (
        SELECT TOP 1 id_arbitro FROM dbo.Arbitro
        WHERE nombre IN (N'TEST_ARBITRO', N'TEST_ARBITRO_MOD', N'TEST_ARBITRO_BAJA')
        ORDER BY id_arbitro
    );
END;

-- 1) Alta exitosa
EXEC dbo.SP_Arbitro_Alta
     N'TEST_ARBITRO', N'PRUEBA', '1985-05-10', N'TEST_PAIS', 'FIFA', N'Español, Inglés';
DECLARE @id INT = (
    SELECT id_arbitro FROM dbo.Arbitro
    WHERE nombre = N'TEST_ARBITRO' AND apellido = N'PRUEBA'
);

-- 2) Consulta
EXEC dbo.SP_Arbitro_ConsultarPorId @id;

-- 3) Modificación
EXEC dbo.SP_Arbitro_Modificar
     @id, N'TEST_ARBITRO_MOD', N'PRUEBA', '1985-05-10', N'TEST_PAIS', 'FIFA', N'Español, Inglés';

-- 4) Listado
EXEC dbo.SP_Arbitro_Listar;

-- 5) Baja sobre un segundo registro
EXEC dbo.SP_Arbitro_Alta
     N'TEST_ARBITRO_BAJA', N'PRUEBA', '1990-01-01', N'TEST_PAIS', 'FIFA', N'Español';
DECLARE @id_baja INT = (
    SELECT id_arbitro FROM dbo.Arbitro
    WHERE nombre = N'TEST_ARBITRO_BAJA' AND apellido = N'PRUEBA'
);
EXEC dbo.SP_Arbitro_Baja @id_baja;

-- VALIDACIÓN: fecha futura
BEGIN TRY
    EXEC dbo.SP_Arbitro_Alta
         N'TEST_ARBITRO_ERROR', N'FUTURO', '2099-01-01', N'TEST_PAIS', 'FIFA', N'Español';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: fecha futura' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

-- VALIDACIÓN: árbitro duplicado
BEGIN TRY
    EXEC dbo.SP_Arbitro_Alta
         N'TEST_ARBITRO_MOD', N'PRUEBA', '1985-05-10', N'TEST_PAIS', 'FIFA', N'Español';
END TRY
BEGIN CATCH
    SELECT 'OK - error esperado: árbitro duplicado' AS prueba, ERROR_MESSAGE() AS mensaje;
END CATCH;

SELECT * FROM dbo.Arbitro WHERE nombre LIKE N'TEST_ARBITRO%';
GO
