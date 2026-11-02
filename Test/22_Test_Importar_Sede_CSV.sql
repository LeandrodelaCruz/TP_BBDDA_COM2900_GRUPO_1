/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 26/10/2026
    Descripción:
    Test de importación de venues.csv.
    Se ejecuta la importación dos veces para verificar la lógica de UPSERT.

    Resultado esperado:
    - Primera ejecución: las sedes inexistentes se insertan.
    - Segunda ejecución: las mismas sedes se actualizan.
    - La consulta final de duplicados debe devolver 0 filas.
*/


USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.SP_Importar_Sede_CSV_Test
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== PRIMERA IMPORTACION DE SEDES =====';
    EXEC importacion.SP_Importar_Sede_CSV
        @archivo = @archivo;

    PRINT '===== SEGUNDA IMPORTACION - PRUEBA DE UPSERT =====';
    EXEC importacion.SP_Importar_Sede_CSV
        @archivo = @archivo;

    PRINT '===== SEDES CARGADAS =====';
    SELECT
        id_sede,
        nombre_estadio,
        ciudad,
        pais,
        capacidad,
        huso_horario
    FROM dbo.Sede
    ORDER BY id_sede;

    PRINT '===== DUPLICADOS (RESULTADO ESPERADO: 0 FILAS) =====';
    SELECT
        nombre_estadio,
        ciudad,
        pais,
        COUNT(*) AS cantidad
    FROM dbo.Sede
    GROUP BY nombre_estadio, ciudad, pais
    HAVING COUNT(*) > 1;
END;
GO

/*
    Ruta esperada si SQL Server corre en el contenedor Docker "sqlserver":
    /var/opt/mssql/import/venues.csv
*/
EXEC test.SP_Importar_Sede_CSV_Test
    @archivo = N'/var/opt/mssql/import/venues.csv';
GO
