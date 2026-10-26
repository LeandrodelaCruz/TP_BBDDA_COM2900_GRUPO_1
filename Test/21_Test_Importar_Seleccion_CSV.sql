/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 26/10/2026

    Descripción:
    Test manual del proceso de importación de Seleccion desde teams.csv.

    Resultado esperado de la primera ejecución sobre una tabla vacía:
      - las selecciones válidas se insertan;
      - los registros inválidos, si existen, se informan sin detener a los demás.

    Resultado esperado de la segunda ejecución del mismo archivo:
      - no se generan duplicados;
      - las selecciones existentes se actualizan mediante el UPSERT.

    IMPORTANTE:
    Reemplazar la ruta de @archivo por una ruta que sea visible para el
    servicio de SQL Server, no solamente para VS Code/SSMS.
*/

USE MUNDIALDEFUTBOL;
GO

DECLARE @archivo NVARCHAR(1000) =
    N'/var/opt/mssql/import/teams.csv';

PRINT N'===== PRIMERA IMPORTACIÓN =====';
EXEC importacion.SP_Importar_Seleccion_CSV
    @archivo = @archivo;

PRINT N'===== DATOS DESPUÉS DE LA PRIMERA IMPORTACIÓN =====';
EXEC abm.Seleccion_Listar;

PRINT N'===== SEGUNDA IMPORTACIÓN - PRUEBA DE UPSERT =====';
EXEC importacion.SP_Importar_Seleccion_CSV
    @archivo = @archivo;

PRINT N'===== VERIFICACIÓN DE DUPLICADOS =====';
SELECT
    pais,
    COUNT(*) AS cantidad
FROM dbo.Seleccion
GROUP BY pais
HAVING COUNT(*) > 1;

-- Resultado esperado: 0 filas.
GO
