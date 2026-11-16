/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
              de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 09/11/2026. Entrega 7: selecciones, convocados y bajas en XML.
    Se incluyen todos los jugadores; estado BAJA si figura como saliente
    en Reemplazo, CONVOCADO en otro caso. No modifica datos.
*/
USE MUNDIALDEFUTBOL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'reportes') IS NULL
    THROW 53500,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE reportes.Reporte_Selecciones_Plantillas_XML
    @id_seleccion INT=NULL,
    @reporte XML=NULL OUTPUT,
    @devolver BIT=1
AS
BEGIN
    SET NOCOUNT ON;
    SET @reporte=NULL;
    DECLARE @errores NVARCHAR(2048)=N'';
    IF @id_seleccion IS NOT NULL
       AND (@id_seleccion<=0 OR NOT EXISTS(SELECT 1 FROM dbo.Seleccion WHERE id_seleccion=@id_seleccion))
        SET @errores+=N'- La seleccion indicada no existe o su identificador no es positivo. ';
    IF @devolver IS NULL SET @errores+=N'- Indique si se devuelve el XML como resultado. ';
    IF @errores<>N'' THROW 53501,@errores,1;

    ;WITH Plantillas AS
    (
        SELECT j.id_jugador,j.id_seleccion,j.nombre,j.apellido,j.posicion,j.club_origen,j.dorsal,
               CASE WHEN EXISTS(SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja=j.id_jugador)
                    THEN 'BAJA' ELSE 'CONVOCADO' END AS estado
        FROM dbo.Jugador j
    )
    SELECT @reporte=
    (
        SELECT s.id_seleccion AS [@id],s.pais AS Pais,
               s.confederacion AS Confederacion,s.grupo_asignado AS Grupo,
            (
                SELECT (SELECT COUNT(*) FROM Plantillas c WHERE c.id_seleccion=s.id_seleccion AND c.estado='CONVOCADO') AS [@convocadosVigentes],
                       (SELECT COUNT(*) FROM Plantillas c WHERE c.id_seleccion=s.id_seleccion AND c.estado='BAJA') AS [@jugadoresDadosDeBaja],
                    (
                        SELECT j.id_jugador AS [@id],j.estado AS [@estado],
                               LTRIM(RTRIM(CONCAT(j.nombre,N' ',j.apellido))) AS Nombre,
                               j.posicion AS Posicion,j.club_origen AS Club,j.dorsal AS Dorsal,
                            (
                                SELECT r.fecha_cambio AS [@fecha],r.id_jugador_alta AS [@idReemplazante],
                                       r.motivo AS Motivo
                                FROM dbo.Reemplazo r WHERE r.id_jugador_baja=j.id_jugador
                                ORDER BY r.fecha_cambio,r.id_reemplazo
                                FOR XML PATH('Baja'),TYPE
                            )
                        FROM Plantillas j WHERE j.id_seleccion=s.id_seleccion
                        ORDER BY j.dorsal,j.apellido,j.nombre,j.id_jugador
                        FOR XML PATH('Jugador'),TYPE
                    )
                FOR XML PATH('Plantilla'),TYPE
            )
        FROM dbo.Seleccion s
        WHERE @id_seleccion IS NULL OR s.id_seleccion=@id_seleccion
        ORDER BY s.pais,s.id_seleccion
        FOR XML PATH('Seleccion'),ROOT('ReporteSeleccionesPlantillas'),TYPE
    );
    IF @devolver=1 SELECT @reporte AS reporte_xml;
END;
GO
-- EXEC reportes.Reporte_Selecciones_Plantillas_XML;
-- Filtro opcional: @id_seleccion, reemplazar por un identificador existente.
