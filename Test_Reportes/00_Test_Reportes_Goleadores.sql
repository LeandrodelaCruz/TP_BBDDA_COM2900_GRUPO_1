/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comision: Com: 01-2900
    Grupo 01:
    - Caro, Nicolas Dario
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodriguez Elias Uriel

    Descripcion:
    Test de los reportes de goleadores (XML):
      - reportes.Goleadores_Por_Seleccion
      - reportes.Goleadores_Por_Fase
      - reportes.Goleadores_Por_Torneo
    Cada reporte se ejecuta y se muestra el XML resultante. Ademas se
    verifica que el total de goles del torneo coincida con la suma de las
    incidencias GOL y GOL DE PENAL (excluyendo la tanda de penales).

    Requisitos previos:
      - Haber cargado partidos simulados (negocio.Simular_Partido o
        negocio.Completar_Partidos).

    Uso: EXEC test.Reportes_Goleadores_Test;
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'test') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO

CREATE OR ALTER PROCEDURE test.Reportes_Goleadores_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST REPORTES GOLEADORES =====';

    /* ------------------------------------------------------------------
       1. Goleadores por seleccion.
    ------------------------------------------------------------------ */
    PRINT '--- Goleadores por seleccion (XML) ---';
    EXEC reportes.Goleadores_Por_Seleccion;

    /* ------------------------------------------------------------------
       2. Goleadores por fase.
    ------------------------------------------------------------------ */
    PRINT '--- Goleadores por fase (XML) ---';
    EXEC reportes.Goleadores_Por_Fase;

    /* ------------------------------------------------------------------
       3. Goleadores del torneo.
    ------------------------------------------------------------------ */
    PRINT '--- Goleadores del torneo (XML) ---';
    EXEC reportes.Goleadores_Por_Torneo;

    /* ------------------------------------------------------------------
       4. Verificacion: total de goles del torneo contra incidencias.
    ------------------------------------------------------------------ */
    DECLARE @goles_incidencias INT, @goles_torneo INT;
    DECLARE @reporte TABLE (reporte_xml XML);

    INSERT INTO @reporte (reporte_xml)
    EXEC reportes.Goleadores_Por_Torneo;

    SELECT @goles_incidencias = COUNT(*)
    FROM dbo.Incidencia
    WHERE tipo IN ('GOL', 'GOL DE PENAL')
      AND periodo <> 'PENALES';

    SELECT @goles_torneo = COALESCE(SUM(g.n.value('@goles', 'INT')), 0)
    FROM @reporte r
    CROSS APPLY r.reporte_xml.nodes('//Goleador') AS g(n);

    SELECT @goles_incidencias AS goles_en_incidencias,
           @goles_torneo      AS goles_en_reporte_torneo;

    IF @goles_incidencias = @goles_torneo
        PRINT 'OK - El total de goles del reporte coincide con las incidencias.';
    ELSE
        PRINT 'ERROR - El total de goles del reporte no coincide con las incidencias.';
END;
GO

EXEC test.Reportes_Goleadores_Test;
GO
