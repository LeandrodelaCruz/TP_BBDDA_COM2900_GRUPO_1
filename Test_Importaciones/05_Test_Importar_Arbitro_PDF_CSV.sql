/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-11-02

    Descripción:
    Test de importacion.Importar_Arbitro_PDF_CSV.
    Ejecuta la importación desde el CSV generado por el extractor del PDF
    oficial de FIFA 2026 y verifica que se realice el UPSERT correctamente.

    Requisitos previos:
      - Haber ejecutado 01_Extraer_Arbitros_FIFA_PDF.py para generar
        Archivos_Importacion/arbitros_fifa_pdf.csv.
      - Contar con los ABM de árbitro de la Entrega 5.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Importar_Arbitro_PDF_CSV_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST IMPORTAR ARBITRO PDF CSV =====';

    /* ------------------------------------------------------------------
       1. Ejecutar la importación desde el CSV generado por el extractor.
    ------------------------------------------------------------------ */
    EXEC importacion.Importar_Arbitro_PDF_CSV
        @archivo = N'/var/opt/mssql/import/arbitros_fifa_completo.csv';

    /* ------------------------------------------------------------------
       2. Verificar que existan árbitros importados.
    ------------------------------------------------------------------ */
    DECLARE @cantidad INT = (SELECT COUNT(*) FROM dbo.Arbitro);

    IF @cantidad > 0
        PRINT 'OK - Se importaron árbitros en dbo.Arbitro.';
    ELSE
        PRINT 'ERROR - No se importó ningún árbitro.';

    /* ------------------------------------------------------------------
       3. Segunda ejecución: debe realizar actualizaciones (Upsert) y no
          generar duplicados.
    ------------------------------------------------------------------ */
    EXEC importacion.Importar_Arbitro_PDF_CSV
        @archivo = N'/var/opt/mssql/import/arbitros_fifa_completo.csv';

    SELECT
        (SELECT COUNT(*) FROM dbo.Arbitro) AS total_arbitros,
        (SELECT COUNT(DISTINCT nombre + '|' + apellido + '|' + pais) FROM dbo.Arbitro) AS distintos;
END;
GO

EXEC test.Importar_Arbitro_PDF_CSV_Test;
GO
