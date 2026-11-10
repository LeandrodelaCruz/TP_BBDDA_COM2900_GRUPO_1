/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
              de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 09/11/2026. Entrega 7: designaciones, partidos y tarjetas en XML.
    Regla: las incidencias AMONESTACION y EXPULSION se atribuyen al PRINCIPAL.
    Los demas roles se muestran sin atribuirles tarjetas. No modifica datos.
*/
USE MUNDIALDEFUTBOL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'reportes') IS NULL
    THROW 53400,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE reportes.Reporte_Designaciones_Arbitrales_XML
    @id_arbitro INT=NULL,
    @id_partido INT=NULL,
    @reporte XML=NULL OUTPUT,
    @devolver BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET @reporte=NULL;
    DECLARE @errores NVARCHAR(2048)=N'';
    IF @id_arbitro IS NOT NULL AND (@id_arbitro<=0 OR NOT EXISTS(SELECT 1 FROM dbo.Arbitro WHERE id_arbitro=@id_arbitro))
        SET @errores+=N'- El arbitro indicado no existe o su identificador no es positivo. ';
    IF @id_partido IS NOT NULL AND (@id_partido<=0 OR NOT EXISTS(SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido))
        SET @errores+=N'- El partido indicado no existe o su identificador no es positivo. ';
    IF @devolver IS NULL SET @errores+=N'- Indique si se devuelve el XML como resultado. ';
    IF @errores<>N'' THROW 53401,@errores,1;

    -- Una fila por designacion; los conteos se obtienen antes de anidar el detalle.
    -- No unir los eventos a todos los roles: multiplicaria las tarjetas del partido.
    SELECT d.id_arbitro,LTRIM(RTRIM(CONCAT(a.nombre,N' ',a.apellido))) AS nombre,
           a.pais,d.id_partido,p.fecha,p.fase,p.horario_UTC,
           s1.pais AS seleccion_1,s2.pais AS seleccion_2,d.rol_arbitro,
           CASE WHEN d.rol_arbitro='PRINCIPAL' THEN c.amonestaciones END AS amonestaciones,
           CASE WHEN d.rol_arbitro='PRINCIPAL' THEN c.expulsiones END AS expulsiones
    INTO #Designaciones_Reporte
    FROM dbo.Designacion_Arbitral d
    JOIN dbo.Arbitro a ON a.id_arbitro=d.id_arbitro
    JOIN dbo.Partido p ON p.id_partido=d.id_partido
    JOIN dbo.Seleccion s1 ON s1.id_seleccion=p.id_seleccion_1
    JOIN dbo.Seleccion s2 ON s2.id_seleccion=p.id_seleccion_2
    CROSS APPLY
    (
        SELECT COALESCE(SUM(CASE WHEN i.tipo='AMONESTACION' THEN 1 ELSE 0 END),0) AS amonestaciones,
               COALESCE(SUM(CASE WHEN i.tipo='EXPULSION' THEN 1 ELSE 0 END),0) AS expulsiones
        FROM dbo.Incidencia i WHERE i.id_partido=d.id_partido
    ) c
    WHERE (@id_arbitro IS NULL OR d.id_arbitro=@id_arbitro)
      AND (@id_partido IS NULL OR d.id_partido=@id_partido);

    -- El modelo permite escrituras directas con dos principales. No elegir uno arbitrariamente.
    IF EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral d
              WHERE d.rol_arbitro='PRINCIPAL'
                AND EXISTS(SELECT 1 FROM #Designaciones_Reporte r WHERE r.id_partido=d.id_partido)
              GROUP BY d.id_partido HAVING COUNT(*)>1)
        THROW 53402,N'Hay un partido del reporte con mas de un principal; corrija las designaciones.',1;

    SET @reporte=
    (
        SELECT a.id_arbitro AS [@id],a.nombre AS Nombre,a.pais AS Pais,
            (
                SELECT COUNT(*) AS [@partidosAsignados],
                       COALESCE(SUM(CASE WHEN d.rol_arbitro='PRINCIPAL' THEN 1 ELSE 0 END),0) AS [@partidosComoPrincipal],
                       COALESCE(SUM(COALESCE(d.amonestaciones,0)),0) AS [@amonestaciones],
                       COALESCE(SUM(COALESCE(d.expulsiones,0)),0) AS [@expulsiones]
                FROM #Designaciones_Reporte d WHERE d.id_arbitro=a.id_arbitro
                FOR XML PATH('Resumen'),TYPE
            ),
            (
                SELECT p.id_partido AS [@id],p.fecha AS Fecha,p.fase AS Fase,
                       p.seleccion_1 AS Seleccion1,p.seleccion_2 AS Seleccion2,p.rol_arbitro AS Rol,
                    (
                        SELECT p.amonestaciones AS [@amonestaciones],p.expulsiones AS [@expulsiones]
                        WHERE p.rol_arbitro='PRINCIPAL'
                        FOR XML PATH('Resumen'),TYPE
                    ),
                    (
                        SELECT CASE WHEN p.rol_arbitro='PRINCIPAL' THEN 'true' ELSE 'false' END AS [@atribuibles],
                            (
                                SELECT i.id_incidencia AS [@idIncidencia],i.tipo AS Tipo,
                                       j.id_jugador AS [Jugador/@id],
                                       LTRIM(RTRIM(CONCAT(j.nombre,N' ',j.apellido))) AS [Jugador],
                                       s.pais AS Seleccion,i.minuto AS Minuto,i.periodo AS Periodo,i.motivo AS Motivo
                                FROM dbo.Incidencia i
                                JOIN dbo.Jugador j ON j.id_jugador=i.id_jugador
                                JOIN dbo.Seleccion s ON s.id_seleccion=j.id_seleccion
                                WHERE i.id_partido=p.id_partido AND p.rol_arbitro='PRINCIPAL'
                                  AND i.tipo IN ('AMONESTACION','EXPULSION')
                                ORDER BY CASE i.periodo WHEN 'PRIMER TIEMPO' THEN 1 WHEN 'SEGUNDO TIEMPO' THEN 2
                                             WHEN 'PRIMER SUPLEMENTARIO' THEN 3 WHEN 'SEGUNDO SUPLEMENTARIO' THEN 4 ELSE 5 END,
                                         CASE WHEN i.minuto IS NULL THEN 1 ELSE 0 END,i.minuto,i.id_incidencia
                                FOR XML PATH('Tarjeta'),TYPE
                            )
                        FOR XML PATH('Tarjetas'),TYPE
                    )
                FROM #Designaciones_Reporte p WHERE p.id_arbitro=a.id_arbitro
                ORDER BY p.horario_UTC,p.id_partido
                FOR XML PATH('Partido'),ROOT('Partidos'),TYPE
            )
        FROM (SELECT DISTINCT id_arbitro,nombre,pais FROM #Designaciones_Reporte) a
        ORDER BY a.id_arbitro
        FOR XML PATH('Arbitro'),ROOT('ReporteDesignacionesArbitrales'),TYPE
    );
    IF @devolver=1 SELECT @reporte AS reporte_xml;
END;
GO
-- Ejecucion completa: EXEC reportes.Reporte_Designaciones_Arbitrales_XML;
-- Filtros opcionales: @id_arbitro y @id_partido. Ambos restringen el mismo conjunto.
