/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
              de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 09/11/2026. Entrega 7: resultados legibles por fase y fecha.
    El marcador del partido viene de Partido.resultado_final (fuente JSON).
    La tanda se contrasta con GOL DE PENAL / PENAL ERRADO, periodo PENALES,
    registrados por Completar_Partidos -> Simular_Partido -> Simular_Penales.
    No suma la tanda al marcador ni supone tiempo reglamentario/suplementario.
*/
USE MUNDIALDEFUTBOL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'reportes') IS NULL
    THROW 53600,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE reportes.Reporte_Resultados
    @fase VARCHAR(30)=NULL,
    @id_seleccion INT=NULL,
    @id_partido INT=NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @errores NVARCHAR(2048)=N'';
    SET @fase=UPPER(LTRIM(RTRIM(@fase)));
    IF @fase IS NOT NULL AND @fase NOT IN
        ('GRUPOS','DIECISEISAVOS','OCTAVOS','CUARTOS','SEMIFINAL','TERCER PUESTO','FINAL')
        SET @errores+=N'- La fase indicada no es valida. ';
    IF @id_seleccion IS NOT NULL AND (@id_seleccion<=0 OR NOT EXISTS(SELECT 1 FROM dbo.Seleccion WHERE id_seleccion=@id_seleccion))
        SET @errores+=N'- La seleccion indicada no existe o su identificador no es positivo. ';
    IF @id_partido IS NOT NULL AND (@id_partido<=0 OR NOT EXISTS(SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido))
        SET @errores+=N'- El partido indicado no existe o su identificador no es positivo. ';
    IF @errores<>N'' THROW 53601,@errores,1;

    ;WITH Fuente AS
    (
        SELECT p.id_partido,p.fase,p.fecha,p.horario_UTC,p.resultado_final,
               s1.pais AS seleccion_1,s2.pais AS seleccion_2,se.nombre_estadio AS sede,
               REPLACE(NULLIF(LTRIM(RTRIM(p.resultado_final)),''),' ','') AS texto,
               pen.tiros,pen.goles_1,pen.goles_2,pen.ajenos
        FROM dbo.Partido p
        JOIN dbo.Seleccion s1 ON s1.id_seleccion=p.id_seleccion_1
        JOIN dbo.Seleccion s2 ON s2.id_seleccion=p.id_seleccion_2
        JOIN dbo.Sede se ON se.id_sede=p.id_sede
        CROSS APPLY
        (
            SELECT COUNT(*) AS tiros,
                   COALESCE(SUM(CASE WHEN i.tipo='GOL DE PENAL' AND j.id_seleccion=pi.id_seleccion_1 THEN 1 ELSE 0 END),0) AS goles_1,
                   COALESCE(SUM(CASE WHEN i.tipo='GOL DE PENAL' AND j.id_seleccion=pi.id_seleccion_2 THEN 1 ELSE 0 END),0) AS goles_2,
                   COALESCE(SUM(CASE WHEN j.id_seleccion NOT IN (pi.id_seleccion_1,pi.id_seleccion_2) THEN 1 ELSE 0 END),0) AS ajenos
            FROM dbo.Incidencia i JOIN dbo.Jugador j ON j.id_jugador=i.id_jugador
            JOIN dbo.Partido pi ON pi.id_partido=i.id_partido
            WHERE i.id_partido=p.id_partido AND i.periodo='PENALES'
              AND i.tipo IN ('GOL DE PENAL','PENAL ERRADO')
        ) pen
        WHERE (@fase IS NULL OR p.fase=@fase)
          AND (@id_seleccion IS NULL OR @id_seleccion IN (p.id_seleccion_1,p.id_seleccion_2))
          AND (@id_partido IS NULL OR p.id_partido=@id_partido)
    ), Partes AS
    (
        SELECT f.*,CHARINDEX('(',texto) AS abre,CHARINDEX(')',texto) AS cierra,
               CASE WHEN CHARINDEX('(',texto)>0 THEN LEFT(texto,CHARINDEX('(',texto)-1) ELSE texto END AS marcador,
               CASE WHEN CHARINDEX('(',texto)>0 AND CHARINDEX(')',texto)>CHARINDEX('(',texto)
                    THEN SUBSTRING(texto,CHARINDEX('(',texto)+1,
                         CASE WHEN CHARINDEX(')',texto)>CHARINDEX('(',texto)
                              THEN CHARINDEX(')',texto)-CHARINDEX('(',texto)-1 ELSE 0 END) END AS tanda
        FROM Fuente f
    ), Numeros AS
    (
        SELECT p.*,
               LEFT(marcador,CASE WHEN CHARINDEX('-',marcador)>0 THEN CHARINDEX('-',marcador)-1 ELSE 0 END) AS m1,
               SUBSTRING(marcador,CHARINDEX('-',marcador)+1,LEN(marcador)) AS m2,
               LEFT(tanda,CASE WHEN CHARINDEX('-',tanda)>0 THEN CHARINDEX('-',tanda)-1 ELSE 0 END) AS t1,
               SUBSTRING(tanda,CHARINDEX('-',tanda)+1,LEN(tanda)) AS t2
        FROM Partes p
    ), Validados AS
    (
        SELECT n.*,TRY_CONVERT(INT,m1) AS g1,TRY_CONVERT(INT,m2) AS g2,
               TRY_CONVERT(INT,t1) AS p1,TRY_CONVERT(INT,t2) AS p2,
               CASE WHEN LEN(m1)>0 AND LEN(m2)>0
                          AND m1 NOT LIKE '%[^0-9]%' AND m2 NOT LIKE '%[^0-9]%'
                          AND TRY_CONVERT(INT,m1) IS NOT NULL AND TRY_CONVERT(INT,m2) IS NOT NULL
                    THEN 1 ELSE 0 END AS marcador_valido,
               CASE WHEN abre>0 AND cierra=LEN(texto) AND LEN(t1)>0 AND LEN(t2)>0
                          AND t1 NOT LIKE '%[^0-9]%' AND t2 NOT LIKE '%[^0-9]%'
                          AND TRY_CONVERT(INT,t1) IS NOT NULL AND TRY_CONVERT(INT,t2) IS NOT NULL
                          AND TRY_CONVERT(INT,t1)<>TRY_CONVERT(INT,t2)
                          AND TRY_CONVERT(INT,m1)=TRY_CONVERT(INT,m2) AND fase<>'GRUPOS'
                    THEN 1 ELSE 0 END AS tanda_valida
        FROM Numeros n
    ), Evaluados AS
    (
        SELECT v.*,
               CASE WHEN tiros>0 THEN goles_1 ELSE p1 END AS penales_1,
               CASE WHEN tiros>0 THEN goles_2 ELSE p2 END AS penales_2,
               CASE WHEN texto IS NULL AND tiros>0 THEN N'Hay una tanda registrada, pero falta el marcador del partido.'
                    WHEN texto IS NOT NULL AND marcador_valido=0 THEN N'El resultado no tiene el formato esperado N-N o N-N (P-P).'
                    WHEN (abre>0 OR cierra>0) AND tanda_valida=0 THEN N'La tanda del resultado no es valida para ese marcador o fase.'
                    WHEN ajenos>0 THEN N'Hay tiros de la tanda asociados a jugadores de otras selecciones.'
                    WHEN tiros>0 AND (fase='GRUPOS' OR g1<>g2 OR goles_1=goles_2)
                        THEN N'La tanda registrada no permite una definicion coherente con el partido.'
                    WHEN tiros>0 AND tanda_valida=1 AND (goles_1<>p1 OR goles_2<>p2)
                        THEN N'La tanda de las incidencias no coincide con el resultado importado.'
               END AS inconsistencia
        FROM Validados v
    )
    SELECT id_partido,fase,fecha,seleccion_1,
           CONVERT(NVARCHAR(80),CASE WHEN inconsistencia IS NOT NULL THEN COALESCE(NULLIF(resultado_final,''),N'Pendiente')
                WHEN texto IS NULL THEN N'Pendiente'
                WHEN tiros>0 OR tanda_valida=1 THEN CONCAT(g1,N'-',g2,N' (penales ',penales_1,N'-',penales_2,N')')
                ELSE CONCAT(g1,N'-',g2) END) AS resultado,
           seleccion_2,
           CONVERT(NVARCHAR(200),CASE WHEN inconsistencia IS NOT NULL THEN N'A revisar'
                WHEN texto IS NULL THEN N'Pendiente'
                WHEN tiros>0 OR tanda_valida=1
                    THEN CONCAT(N'Ganó ',CASE WHEN penales_1>penales_2 THEN seleccion_1 ELSE seleccion_2 END,N' por penales')
                WHEN g1>g2 THEN CONCAT(N'Ganó ',seleccion_1)
                WHEN g2>g1 THEN CONCAT(N'Ganó ',seleccion_2)
                WHEN fase='GRUPOS' THEN N'Empate'
                ELSE N'Definición no informada' END) AS definicion,
           sede,
           CONVERT(NVARCHAR(300),CASE WHEN inconsistencia IS NOT NULL THEN inconsistencia
                WHEN tanda_valida=1 AND tiros=0 THEN N'Tanda informada en el resultado; sin incidencias de penales cargadas.'
                WHEN tiros>0 AND tanda_valida=0 THEN N'Tanda registrada en incidencias; no incluida en el resultado original.'
                WHEN texto IS NOT NULL AND g1=g2 AND fase<>'GRUPOS' AND tiros=0
                    THEN N'Empate eliminatorio sin una tanda registrada.' END) AS observacion
    FROM Evaluados
    ORDER BY CASE fase WHEN 'GRUPOS' THEN 1 WHEN 'DIECISEISAVOS' THEN 2 WHEN 'OCTAVOS' THEN 3
                       WHEN 'CUARTOS' THEN 4 WHEN 'SEMIFINAL' THEN 5 WHEN 'TERCER PUESTO' THEN 6 WHEN 'FINAL' THEN 7 ELSE 8 END,
             horario_UTC,id_partido;
END;
GO
-- EXEC reportes.Reporte_Resultados;
-- EXEC reportes.Reporte_Resultados @fase='OCTAVOS';
