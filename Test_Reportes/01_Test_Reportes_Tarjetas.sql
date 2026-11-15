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
    Test de los reportes de tarjetas (resultsets, sin XML):
      - reportes.Tarjetas_Por_Seleccion
      - reportes.Tarjetas_Por_Jugador (incluye suspensiones por acumulacion)
    Cada reporte se ejecuta y se muestran las filas resultantes. Ademas se
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
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO

CREATE OR ALTER PROCEDURE test.Reportes_Tarjetas_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST REPORTES TARJETAS =====';

    DECLARE @amarillas_incidencias INT, @rojas_incidencias INT;
    DECLARE @amarillas_seleccion INT, @rojas_seleccion INT;
    DECLARE @amarillas_jugador INT, @rojas_jugador INT;
    DECLARE @reporte_seleccion TABLE (
        seleccion NVARCHAR(100), amarillas INT, rojas INT
    );
    DECLARE @reporte_jugador TABLE (
        id_jugador INT, seleccion NVARCHAR(100), jugador NVARCHAR(200), amarillas INT, rojas INT,
        id_partido_amarilla_1 INT, id_partido_amarilla_2 INT, partido_suspendido INT,
        estado_suspension NVARCHAR(20)
    );

    /* ------------------------------------------------------------------
       1. Tarjetas por seleccion.
    ------------------------------------------------------------------ */
    PRINT '--- Tarjetas por seleccion ---';
    INSERT INTO @reporte_seleccion (seleccion, amarillas, rojas)
    EXEC reportes.Tarjetas_Por_Seleccion;

    SELECT * FROM @reporte_seleccion;

    /* ------------------------------------------------------------------
       2. Tarjetas por jugador con suspensiones.
    ------------------------------------------------------------------ */
    PRINT '--- Tarjetas por jugador y suspensiones ---';
    INSERT INTO @reporte_jugador (id_jugador, seleccion, jugador, amarillas, rojas,
                                  id_partido_amarilla_1, id_partido_amarilla_2,
                                  partido_suspendido, estado_suspension)
    EXEC reportes.Tarjetas_Por_Jugador;

    SELECT * FROM @reporte_jugador;

    /* ------------------------------------------------------------------
       3. Verificacion de totales contra incidencias.
    ------------------------------------------------------------------ */
    SELECT @amarillas_incidencias = COUNT(*)
    FROM dbo.Incidencia
    WHERE tipo = 'AMONESTACION';

    SELECT @rojas_incidencias = COUNT(*)
    FROM dbo.Incidencia
    WHERE tipo = 'EXPULSION';

    /* Cada jugador se repite una fila por suspension: sumar solo una vez por jugador. */
    SELECT @amarillas_seleccion = COALESCE(SUM(amarillas), 0),
           @rojas_seleccion     = COALESCE(SUM(rojas), 0)
    FROM @reporte_seleccion;

    SELECT @amarillas_jugador = COALESCE(SUM(t.amarillas), 0),
           @rojas_jugador     = COALESCE(SUM(t.rojas), 0)
    FROM (
        SELECT DISTINCT id_jugador, amarillas, rojas
        FROM @reporte_jugador
    ) t;

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

    /* ------------------------------------------------------------------
       4. Verificacion de las vistas usadas por los reportes.
    ------------------------------------------------------------------ */
    DECLARE @amarillas_vista_jugador INT, @rojas_vista_jugador INT;
    DECLARE @amarillas_vista_seleccion INT, @rojas_vista_seleccion INT;

    SELECT @amarillas_vista_jugador = COALESCE(SUM(amarillas), 0),
           @rojas_vista_jugador     = COALESCE(SUM(rojas), 0)
    FROM reportes.v_Tarjetas_Por_Jugador;

    SELECT @amarillas_vista_seleccion = COALESCE(SUM(amarillas), 0),
           @rojas_vista_seleccion     = COALESCE(SUM(rojas), 0)
    FROM reportes.v_Tarjetas_Por_Seleccion;

    SELECT @amarillas_vista_jugador    AS amarillas_vista_jugador,
           @rojas_vista_jugador        AS rojas_vista_jugador,
           @amarillas_vista_seleccion  AS amarillas_vista_seleccion,
           @rojas_vista_seleccion      AS rojas_vista_seleccion;

    IF @amarillas_vista_jugador = @amarillas_incidencias
       AND @rojas_vista_jugador = @rojas_incidencias
       AND @amarillas_vista_seleccion = @amarillas_incidencias
       AND @rojas_vista_seleccion = @rojas_incidencias
        PRINT 'OK - Las vistas de tarjetas coinciden con las incidencias.';
    ELSE
        PRINT 'ERROR - Las vistas de tarjetas no coinciden con las incidencias.';
END;
GO

EXEC test.Reportes_Tarjetas_Test;
GO
