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
    Test de los reportes de goleadores (resultsets, sin XML):
      - reportes.Goleadores_Por_Seleccion
      - reportes.Goleadores_Por_Fase
      - reportes.Goleadores_Por_Torneo
    Cada reporte se ejecuta y se muestran las filas resultantes. Ademas se
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
    PRINT '--- Goleadores por seleccion ---';
    EXEC reportes.Goleadores_Por_Seleccion;

    /* ------------------------------------------------------------------
       2. Goleadores por fase.
    ------------------------------------------------------------------ */
    PRINT '--- Goleadores por fase ---';
    EXEC reportes.Goleadores_Por_Fase;

    /* ------------------------------------------------------------------
       3. Goleadores del torneo.
    ------------------------------------------------------------------ */
    PRINT '--- Goleadores del torneo ---';
    EXEC reportes.Goleadores_Por_Torneo;

    /* ------------------------------------------------------------------
       4. Verificacion: total de goles del torneo contra incidencias.
    ------------------------------------------------------------------ */
    DECLARE @goles_incidencias INT, @goles_torneo INT;
    DECLARE @reporte TABLE (jugador NVARCHAR(200), seleccion NVARCHAR(100), goles INT);

    INSERT INTO @reporte (jugador, seleccion, goles)
    EXEC reportes.Goleadores_Por_Torneo;

    SELECT @goles_incidencias = COUNT(*)
    FROM dbo.Incidencia
    WHERE tipo IN ('GOL', 'GOL DE PENAL')
      AND periodo <> 'PENALES';

    SELECT @goles_torneo = COALESCE(SUM(goles), 0)
    FROM @reporte;

    SELECT @goles_incidencias AS goles_en_incidencias,
           @goles_torneo      AS goles_en_reporte_torneo;

    IF @goles_incidencias = @goles_torneo
        PRINT 'OK - El total de goles del reporte coincide con las incidencias.';
    ELSE
        PRINT 'ERROR - El total de goles del reporte no coincide con las incidencias.';

    /* ------------------------------------------------------------------
       5. Verificacion de las vistas usadas por los reportes.
    ------------------------------------------------------------------ */
    DECLARE @goles_vista_jugador INT, @goles_vista_seleccion INT, @goles_vista_fase INT;

    SELECT @goles_vista_jugador = COALESCE(SUM(goles), 0)
    FROM reportes.v_Goles_Por_Jugador;

    SELECT @goles_vista_seleccion = COALESCE(SUM(total_goles), 0)
    FROM reportes.v_Goles_Por_Seleccion;

    SELECT @goles_vista_fase = COALESCE(SUM(goles), 0)
    FROM reportes.v_Goles_Por_Fase_Jugador;

    SELECT @goles_vista_jugador AS goles_vista_jugador,
           @goles_vista_seleccion AS goles_vista_seleccion,
           @goles_vista_fase AS goles_vista_fase;

    IF @goles_vista_jugador = @goles_incidencias
       AND @goles_vista_seleccion = @goles_incidencias
       AND @goles_vista_fase = @goles_incidencias
        PRINT 'OK - Las vistas de goleadores coinciden con las incidencias.';
    ELSE
        PRINT 'ERROR - Las vistas de goleadores no coinciden con las incidencias.';
END;
GO

EXEC test.Reportes_Goleadores_Test;
GO
