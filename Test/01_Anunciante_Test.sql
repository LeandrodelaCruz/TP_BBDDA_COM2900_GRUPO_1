/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Casos de prueba de dbo.Anunciante. Deja un registro TEST_ para inspección; 99_Limpiar_Tests.sql lo elimina.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Anunciante_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST ANUNCIANTE =====';

    -- Limpieza preventiva si el test se ejecutó antes.
    DECLARE @id_prev INT = (
        SELECT TOP 1 id_anunciante FROM dbo.Anunciante
        WHERE nombre IN (N'TEST_ANUNCIANTE_PRINCIPAL', N'TEST_ANUNCIANTE_MODIFICADO', N'TEST_ANUNCIANTE_BAJA')
        ORDER BY id_anunciante
    );
    WHILE @id_prev IS NOT NULL
    BEGIN
        EXEC abm.Anunciante_Baja @id_prev;
        SET @id_prev = (
            SELECT TOP 1 id_anunciante FROM dbo.Anunciante
            WHERE nombre IN (N'TEST_ANUNCIANTE_PRINCIPAL', N'TEST_ANUNCIANTE_MODIFICADO', N'TEST_ANUNCIANTE_BAJA')
            ORDER BY id_anunciante
        );
    END;

    -- 1) Alta exitosa
    EXEC abm.Anunciante_Alta N'TEST_ANUNCIANTE_PRINCIPAL';
    DECLARE @id INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'TEST_ANUNCIANTE_PRINCIPAL');

    -- 2) Consulta por ID
    EXEC abm.Anunciante_ConsultarPorId @id;

    -- 3) Modificación exitosa
    EXEC abm.Anunciante_Modificar @id, N'TEST_ANUNCIANTE_MODIFICADO';

    -- 4) Listado
    EXEC abm.Anunciante_Listar;

    -- 5) Baja exitosa sobre un segundo registro
    EXEC abm.Anunciante_Alta N'TEST_ANUNCIANTE_BAJA';
    DECLARE @id_baja INT = (SELECT id_anunciante FROM dbo.Anunciante WHERE nombre = N'TEST_ANUNCIANTE_BAJA');
    EXEC abm.Anunciante_Baja @id_baja;

    -- VALIDACIÓN: nombre vacío
    BEGIN TRY
        EXEC abm.Anunciante_Alta N'';
    END TRY
    BEGIN CATCH
        SELECT 'OK - error esperado: nombre vacío' AS prueba, ERROR_MESSAGE() AS mensaje;
    END CATCH;

    -- VALIDACIÓN: nombre duplicado
    BEGIN TRY
        EXEC abm.Anunciante_Alta N'TEST_ANUNCIANTE_MODIFICADO';
    END TRY
    BEGIN CATCH
        SELECT 'OK - error esperado: anunciante duplicado' AS prueba, ERROR_MESSAGE() AS mensaje;
    END CATCH;

    SELECT * FROM dbo.Anunciante WHERE nombre LIKE N'TEST_ANUNCIANTE%';
END;
GO

EXEC test.Anunciante_Test;
GO
