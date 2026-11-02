/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada - Com 01-2900
    Grupo 01: Caro, Nicolás; Clara, Lucas; De La Cruz, Leandro; Rodríguez, Elías.
    Fecha: 01/11/2026. Objetivo: pruebas de importación de Personal_Tecnico.
    Requiere Seleccion cargada y los ABM con @nombre_completo.
    Todas las escrituras de esta prueba se revierten con ROLLBACK.
    1. CSV real: primera carga 147 altas si la tabla comienza vacía y el archivo
       conserva los 147 registros actuales. Segunda carga: 0 altas y 147 updates.
    2. Mismos IDs y cantidad tras repetir; sin duplicados de selección + nombre.
    3. Fixture opcional: 7 registros, 1 insertado, 1 actualizado, 5 errores.
       Demuestra cambio de rol, interino normalizado, nombre de una palabra,
       selección inexistente, nombre vacío/largo, rol y fecha inválidos.
    CSV de ejemplo: Test/Datos_Importacion/personal_tecnico_casos.csv.
    El archivo debe ser visible para SQL Server (copiar también el fixture).
*/
USE MUNDIALDEFUTBOL;
GO
CREATE OR ALTER PROCEDURE test.SP_Importar_Personal_Tecnico_CSV_Test
    @archivo NVARCHAR(1000),
    @archivo_casos NVARCHAR(1000) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT <> 0
        THROW 52400, N'Ejecute esta prueba sin una transacción externa.', 1;
    BEGIN TRY
        BEGIN TRANSACTION;
        PRINT N'Primera importación: revisar resumen y errores (esperados: 0).';
        EXEC importacion.SP_Importar_Personal_Tecnico_CSV @archivo = @archivo;
        SELECT id_personal, id_seleccion, nombre_completo, rol
        INTO #Primera FROM dbo.Personal_Tecnico;

        PRINT N'Segunda importación: mismas personas, sin nuevas altas.';
        EXEC importacion.SP_Importar_Personal_Tecnico_CSV @archivo = @archivo;
        IF EXISTS (
            SELECT id_personal, id_seleccion, nombre_completo, rol FROM #Primera
            EXCEPT SELECT id_personal, id_seleccion, nombre_completo, rol FROM dbo.Personal_Tecnico
        ) OR EXISTS (
            SELECT id_personal, id_seleccion, nombre_completo, rol FROM dbo.Personal_Tecnico
            EXCEPT SELECT id_personal, id_seleccion, nombre_completo, rol FROM #Primera
        )
            THROW 52401, N'Repetir el CSV alteró los IDs, datos o cantidad de personas.', 1;
        IF EXISTS (
            SELECT id_seleccion, UPPER(LTRIM(RTRIM(nombre_completo)))
            FROM dbo.Personal_Tecnico
            GROUP BY id_seleccion, UPPER(LTRIM(RTRIM(nombre_completo))) HAVING COUNT(*) > 1
        )
            THROW 52402, N'Existen personas duplicadas.', 1;
        IF NOT EXISTS (SELECT 1 FROM dbo.Personal_Tecnico)
            THROW 52403, N'La prueba no cargó personas; revise el archivo y las selecciones.', 1;

        IF @archivo_casos IS NOT NULL
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE pais = N'USA')
                THROW 52404, N'El fixture requiere la selección USA.', 1;
            IF EXISTS (SELECT 1 FROM dbo.Personal_Tecnico WHERE nombre_completo LIKE N'__TEST_PERSONAL[_]%')
                THROW 52405, N'Hay datos reservados del fixture. Use una base de pruebas limpia.', 1;
            -- Preparar el rol anterior en una operación separada del CSV:
            -- la comprobación no depende del orden de lectura de la staging.
            DECLARE @id_usa INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'USA');
            EXEC abm.Personal_Tecnico_Alta
                @nombre_completo = N'__TEST_PERSONAL_Cambio',
                @rol = N'Entrenador Asistente', @id_seleccion = @id_usa;
            DECLARE @id_cambio INT = (SELECT id_personal FROM dbo.Personal_Tecnico
                WHERE nombre_completo = N'__TEST_PERSONAL_Cambio' AND id_seleccion = @id_usa);
            EXEC importacion.SP_Importar_Personal_Tecnico_CSV @archivo = @archivo_casos;
            IF (SELECT COUNT(*) FROM dbo.Personal_Tecnico WHERE nombre_completo LIKE N'__TEST_PERSONAL[_]%') <> 2
                THROW 52406, N'La carga parcial no conservó exactamente las dos personas válidas.', 1;
            IF NOT EXISTS (SELECT 1 FROM dbo.Personal_Tecnico WHERE id_personal = @id_cambio AND nombre_completo = N'__TEST_PERSONAL_Cambio' AND rol = 'Entrenador')
                THROW 52407, N'El interino no actualizó el rol de la persona existente.', 1;
            IF NOT EXISTS (SELECT 1 FROM dbo.Personal_Tecnico WHERE nombre_completo = N'__TEST_PERSONAL_Xavi' AND rol = 'Entrenador Asistente')
                THROW 52408, N'No continuó con la fila válida después de los errores.', 1;
        END;
        SELECT s.pais, p.nombre_completo, p.rol
        FROM dbo.Personal_Tecnico p JOIN dbo.Seleccion s ON s.id_seleccion = p.id_seleccion
        ORDER BY s.pais, p.nombre_completo;
        ROLLBACK TRANSACTION;
        PRINT N'OK: UPSERT y verificaciones completadas. Cambios de prueba revertidos.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
-- Ejemplo (ejecutar por separado):
EXEC test.SP_Importar_Personal_Tecnico_CSV_Test
    @archivo = N'/home/proyecto/personal_tecnico.csv';
/* Prueba con errores parciales: copiar primero el CSV de ejemplo a /home/proyecto.
EXEC test.SP_Importar_Personal_Tecnico_CSV_Test
    @archivo = N'/home/proyecto/personal_tecnico.csv',
    @archivo_casos = N'/home/proyecto/personal_tecnico_casos.csv';
-- Esperado para el archivo de casos: 1 alta, 1 actualización y 5 errores.
*/
