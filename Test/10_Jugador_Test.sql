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
    Script de testing COMPLETO para los procedimientos ABM de Jugador.
    Incluye pruebas exitosas y validaciones de errores.

    PROCEDIMIENTOS A PROBAR:
    - Jugador_Alta
    - Jugador_Modificar
    - Jugador_Baja
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Jugador_Test
AS
BEGIN
    SET NOCOUNT ON;

    /* =========================================================
       LIMPIEZA: Eliminar datos previos de pruebas anteriores
       ========================================================= */

    PRINT '=== Limpiando datos de pruebas anteriores (Jugador) ===';

    DELETE FROM dbo.Jugador 
    WHERE id_seleccion IN (SELECT id_seleccion FROM dbo.Seleccion WHERE pais LIKE N'%Test%ABM%');

    DELETE FROM dbo.Seleccion 
    WHERE pais LIKE N'%Test%ABM%';

    PRINT '=== Limpieza completada ===';

    /* =========================================================
       PREPARACIÓN: Datos de apoyo
       ========================================================= */

    PRINT '=== Preparando datos de prueba ===';

    INSERT INTO dbo.Seleccion (pais, confederacion, grupo_asignado)
    VALUES (N'Selección Test ABM Jugador', N'TEST', 'Z');

    PRINT '=== Datos de apoyo preparados ===';

    /* =========================================================
       PRUEBAS: ABM JUGADOR
       ========================================================= */

    PRINT '=============================================';
    PRINT ' PRUEBAS TABLA: dbo.Jugador';
    PRINT '=============================================';

    -- ---------------------------------------------------------
    -- CASO 1: Alta exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 1: Alta exitosa ---';

    DECLARE @id_sel_b6 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Jugador');

    BEGIN TRY
        EXEC abm.Jugador_Alta
            @fecha_nacimiento = '1998-05-10',
            @club_origen = N'Club Testing',
            @apellido = N'Messi',
            @nombre = N'Lionel',
            @posicion = 'Delantero',
            @dorsal = 10,
            @id_seleccion = @id_sel_b6;

        PRINT 'OK - Jugador dado de alta exitosamente.';
        SELECT * FROM dbo.Jugador WHERE id_seleccion = @id_sel_b6 AND dorsal = 10;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 2: Alta fallida - Dorsal fuera de rango
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 2: Alta fallida - Dorsal fuera de rango (99) ---';

    DECLARE @id_sel_b7 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Jugador');

    BEGIN TRY
        EXEC abm.Jugador_Alta
            @fecha_nacimiento = '2000-01-01',
            @club_origen = N'Club Testing',
            @apellido = N'Pérez',
            @nombre = N'Juan',
            @posicion = 'Mediocampista',
            @dorsal = 99,
            @id_seleccion = @id_sel_b7;

        PRINT 'ERROR: Debería haber fallado por dorsal fuera de rango.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 3: Alta fallida - Selección inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 3: Alta fallida - Selección inexistente ---';

    BEGIN TRY
        EXEC abm.Jugador_Alta
            @fecha_nacimiento = '2000-01-01',
            @club_origen = N'Club Testing',
            @apellido = N'Gómez',
            @nombre = N'Carlos',
            @posicion = 'Defensa',
            @dorsal = 2,
            @id_seleccion = -999;

        PRINT 'ERROR: Debería haber fallado por selección inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 4: Modificación exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 4: Modificación exitosa ---';

    DECLARE @id_sel_b9 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Jugador');
    DECLARE @id_jugador INT = (SELECT TOP 1 id_jugador FROM dbo.Jugador WHERE id_seleccion = @id_sel_b9);

    BEGIN TRY
        EXEC abm.Jugador_Modificar
            @id_jugador = @id_jugador,
            @fecha_nacimiento = '1998-05-10',
            @club_origen = N'Inter Miami CF',
            @apellido = N'Messi',
            @nombre = N'Lionel Andrés',
            @posicion = 'Delantero',
            @dorsal = 10,
            @id_seleccion = @id_sel_b9;

        PRINT 'OK - Jugador modificado correctamente.';
        SELECT * FROM dbo.Jugador WHERE id_jugador = @id_jugador;
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 5: Modificación fallida - Jugador inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 5: Modificación fallida - Jugador inexistente ---';

    DECLARE @id_sel_b10 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Jugador');

    BEGIN TRY
        EXEC abm.Jugador_Modificar
            @id_jugador = -999,
            @fecha_nacimiento = '1998-05-10',
            @club_origen = N'Club',
            @apellido = N'Inexistente',
            @nombre = N'Test',
            @posicion = 'Delantero',
            @dorsal = 10,
            @id_seleccion = @id_sel_b10;

        PRINT 'ERROR: Debería haber fallado por ID inexistente.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 6: Baja exitosa
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 6: Baja exitosa ---';

    DECLARE @id_sel_b11 INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Selección Test ABM Jugador');
    DECLARE @id_jugador_del INT = (SELECT TOP 1 id_jugador FROM dbo.Jugador WHERE id_seleccion = @id_sel_b11);

    BEGIN TRY
        EXEC abm.Jugador_Baja @id_jugador = @id_jugador_del;

        PRINT 'OK - Jugador eliminado correctamente.';
        IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @id_jugador_del)
            PRINT 'CONFIRMADO: El registro ya no existe en la BD.';
    END TRY
    BEGIN CATCH
        PRINT 'ERROR: ' + ERROR_MESSAGE();
    END CATCH;

    -- ---------------------------------------------------------
    -- CASO 7: Baja fallida - ID inexistente
    -- ---------------------------------------------------------
    PRINT '';
    PRINT '--- CASO 7: Baja fallida - ID inexistente ---';

    BEGIN TRY
        EXEC abm.Jugador_Baja @id_jugador = -999;
        PRINT 'ERROR: Debería haber fallado.';
    END TRY
    BEGIN CATCH
        PRINT 'OK - Validación correcta: ' + ERROR_MESSAGE();
    END CATCH;

    PRINT '';
    PRINT '=============================================';
    PRINT ' FIN DE PRUEBAS: Jugador';
    PRINT '=============================================';
END;
GO

EXEC test.Jugador_Test;
GO
