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
    Test de los reportes de tarjetas (XML):
      - reportes.Tarjetas_Por_Seleccion
      - reportes.Tarjetas_Por_Jugador (incluye suspensiones por acumulacion)
    Cada reporte se ejecuta y se muestra el XML resultante. Ademas se
    verifica que los totales de amarillas y rojas de ambos reportes coincidan
    con las incidencias AMONESTACION y EXPULSION.

    Requisitos previos:
      - Haber cargado partidos simulados (negocio.Simular_Partido o
        negocio.Completar_Partidos).

    Uso: EXEC test.Reportes_Tarjetas_Test;
*/

USE MUNDIALDEFUTBOL;
GO

IF SCHEMA_ID(N'test') IS NULL
    EXEC (N'CREATE SCHEMA test');
GO

CREATE OR ALTER PROCEDURE test.Reportes_Tarjetas_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST REPORTES TARJETAS =====';

    DECLARE @amarillas_incidencias INT, @rojas_incidencias INT;
    DECLARE @amarillas_seleccion INT, @rojas_seleccion INT;
    DECLARE @amarillas_jugador INT, @rojas_jugador INT;
    DECLARE @reporte_seleccion TABLE (reporte_xml XML);
    DECLARE @reporte_jugador TABLE (reporte_xml XML);

    /* ------------------------------------------------------------------
       1. Tarjetas por seleccion (XML).
    ------------------------------------------------------------------ */
    PRINT '--- Tarjetas por seleccion (XML) ---';
    INSERT INTO @reporte_seleccion (reporte_xml)
    EXEC reportes.Tarjetas_Por_Seleccion;

    SELECT r.reporte_xml AS tarjetas_por_seleccion
    FROM @reporte_seleccion r;

    /* ------------------------------------------------------------------
       2. Tarjetas por jugador con suspensiones (XML).
    ------------------------------------------------------------------ */
    PRINT '--- Tarjetas por jugador y suspensiones (XML) ---';
    INSERT INTO @reporte_jugador (reporte_xml)
    EXEC reportes.Tarjetas_Por_Jugador;

    SELECT r.reporte_xml AS tarjetas_por_jugador
    FROM @reporte_jugador r;

    /* ------------------------------------------------------------------
       3. Verificacion de totales contra incidencias.
    ------------------------------------------------------------------ */
    SELECT @amarillas_incidencias = COUNT(*)
    FROM dbo.Incidencia
    WHERE tipo = 'AMONESTACION';

    SELECT @rojas_incidencias = COUNT(*)
    FROM dbo.Incidencia
    WHERE tipo = 'EXPULSION';

    SELECT @amarillas_seleccion = COALESCE(SUM(t.n.value('@amarillas', 'INT')), 0),
           @rojas_seleccion     = COALESCE(SUM(t.n.value('@rojas', 'INT')), 0)
    FROM @reporte_seleccion r
    CROSS APPLY r.reporte_xml.nodes('//Seleccion') AS t(n);

    SELECT @amarillas_jugador = COALESCE(SUM(t.n.value('@amarillas', 'INT')), 0),
           @rojas_jugador     = COALESCE(SUM(t.n.value('@rojas', 'INT')), 0)
    FROM @reporte_jugador r
    CROSS APPLY r.reporte_xml.nodes('//Jugador') AS t(n);

    SELECT @amarillas_incidencias AS amarillas_incidencias,
           @rojas_incidencias     AS rojas_incidencias,
           @amarillas_seleccion   AS amarillas_por_seleccion,
           @rojas_seleccion       AS rojas_por_seleccion,
           @amarillas_jugador     AS amarillas_por_jugador,
           @rojas_jugador         AS rojas_por_jugador;

    IF @amarillas_incidencias = @amarillas_seleccion
       AND @amarillas_incidencias = @amarillas_jugador
       AND @rojas_incidencias = @rojas_seleccion
       AND @rojas_incidencias = @rojas_jugador
        PRINT 'OK - Los totales de tarjetas de ambos reportes coinciden con las incidencias.';
    ELSE
        PRINT 'ERROR - Los totales de tarjetas no coinciden con las incidencias.';
END;
GO

EXEC test.Reportes_Tarjetas_Test;
GO
