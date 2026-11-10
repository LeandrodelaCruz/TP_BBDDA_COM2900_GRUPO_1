/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
SET NOCOUNT ON;
-- Ajuste las rutas a los archivos accesibles al servidor. Ejecutar en MUNDIALDEFUTBOL.
IF EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral)
    THROW 59990,N'La prueba inicial requiere designaciones vacias.',1;

EXEC importacion.Importar_Seleccion_CSV N'/var/opt/mssql/import/teams.csv';
EXEC importacion.Importar_Sede_CSV N'/var/opt/mssql/import/venues.csv';
EXEC importacion.SP_Importar_Arbitro_PDF_CSV N'/var/opt/mssql/import/arbitros_fifa_pdf.csv';
EXEC importacion.Importar_Partido_JSON N'/var/opt/mssql/import/partidos_mundial_2026.json';
IF (SELECT COUNT(*) FROM dbo.Partido)<>104 THROW 59999,N'No se importaron 104 partidos.',1;
EXEC carga.Cargar_Cruces_Dataset;
EXEC carga.Cargar_Cruces_Dataset;
IF (SELECT COUNT(*) FROM dbo.Cruce_Partido)<>32 THROW 59999,N'El mapa debe tener 32 relaciones.',1;
DECLARE @c INT,@o INT,@e INT,@r INT,@inicio DATETIME2=SYSDATETIME();
EXEC carga.Cargar_Designaciones_Arbitrales NULL,1,@c OUTPUT,@o OUTPUT,@e OUTPUT,@r OUTPUT;
IF @c<>104 OR @e<>0 OR @r<1 THROW 59999,N'Fallo la carga masiva del fixture.',1;
SELECT DATEDIFF(MILLISECOND,@inicio,SYSDATETIME()) AS milisegundos,@c AS partidos,@r AS rechazos;
IF (SELECT COUNT(*) FROM dbo.Designacion_Arbitral)<>624 THROW 59999,N'Se esperaban 624 designaciones.',1;
IF EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral d JOIN dbo.Arbitro a ON a.id_arbitro=d.id_arbitro
    JOIN dbo.Partido p ON p.id_partido=d.id_partido JOIN dbo.Seleccion s ON s.id_seleccion IN (p.id_seleccion_1,p.id_seleccion_2)
    WHERE negocio.Pais_Arbitral_Normalizado(a.pais)=negocio.Pais_Arbitral_Normalizado(s.pais))
    THROW 59999,N'Hay designaciones con conflicto de nacionalidad.',1;
SELECT * INTO #Antes FROM dbo.Designacion_Arbitral;
EXEC carga.Cargar_Designaciones_Arbitrales NULL,1,@c OUTPUT,@o OUTPUT,@e OUTPUT,@r OUTPUT;
IF @c<>0 OR @o<>104 OR @e<>0 OR EXISTS(SELECT * FROM #Antes EXCEPT SELECT * FROM dbo.Designacion_Arbitral)
    THROW 59999,N'La repeticion altero designaciones.',1;
EXEC importacion.Importar_Partido_JSON N'/var/opt/mssql/import/partidos_mundial_2026.json';
IF (SELECT COUNT(*) FROM dbo.Partido)<>104 THROW 59999,N'La reimportacion duplico partidos.',1;
SELECT COUNT(*) AS designaciones FROM dbo.Designacion_Arbitral;
PRINT N'OK DATASET: 104 partidos, 32 cruces, 624 designaciones, cero conflictos y repeticion estable.';
GO
