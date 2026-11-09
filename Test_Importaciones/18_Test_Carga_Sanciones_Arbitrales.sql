/*
    Universidad: Universidad Nacional de La Matanza - UNLaM.
    Materia: Bases de Datos Aplicada - Comision 01-2900. Grupo 01.
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 08/11/2026.
    Objetivo: probar cinco sanciones SIMULADAS contra designaciones del dataset local.
    Requiere MUNDIALDEFUTBOL con fixture y designaciones; conserva los cinco casos.
    Esperado: 5 altas, repeticion 0 altas/5 omitidas, sin cambiar filas ajenas.
*/
USE MUNDIALDEFUTBOL;
GO
IF @@TRANCOUNT<>0 THROW 59990,N'Ejecute sin transaccion previa.',1;
IF EXISTS(SELECT 1 FROM dbo.Sancion_Arbitral WHERE LEFT(motivo,13)='[SIMULADO SA-')
    THROW 59990,N'El test requiere que estos casos simulados aun no esten cargados.',1;
SELECT * INTO #Sanciones_Antes FROM dbo.Sancion_Arbitral;
SELECT * INTO #Designaciones_Antes FROM dbo.Designacion_Arbitral;
DECLARE @i INT,@o INT,@e INT;
EXEC carga.Cargar_Sanciones_Arbitrales_Manuales @i OUTPUT,@o OUTPUT,@e OUTPUT;
IF @i<>5 OR @o<>0 OR @e<>0 THROW 59999,N'Fallo la primera carga de cinco casos.',1;
SELECT * INTO #Despues FROM dbo.Sancion_Arbitral;
EXEC carga.Cargar_Sanciones_Arbitrales_Manuales @i OUTPUT,@o OUTPUT,@e OUTPUT;
IF @i<>0 OR @o<>5 OR @e<>0 THROW 59999,N'Fallo la repeticion de la carga.',1;
IF EXISTS(SELECT * FROM #Despues EXCEPT SELECT * FROM dbo.Sancion_Arbitral)
 OR EXISTS(SELECT * FROM dbo.Sancion_Arbitral EXCEPT SELECT * FROM #Despues)
    THROW 59999,N'La repeticion cambio las sanciones.',1;
IF EXISTS(SELECT 1 FROM dbo.Sancion_Arbitral s
          WHERE LEFT(s.motivo,13)='[SIMULADO SA-'
            AND NOT EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral d
                           WHERE d.id_partido=s.id_partido AND d.id_arbitro=s.id_arbitro))
    THROW 59999,N'Hay una sancion sin designacion correspondiente.',1;
IF EXISTS(SELECT 1 FROM dbo.Sancion_Arbitral s JOIN dbo.Partido p ON p.id_partido=s.id_partido
          WHERE LEFT(s.motivo,13)='[SIMULADO SA-' AND s.fecha<>p.fecha)
    THROW 59999,N'Una sancion tiene fecha distinta a la del partido.',1;
IF EXISTS(SELECT * FROM #Sanciones_Antes EXCEPT SELECT * FROM dbo.Sancion_Arbitral)
 OR EXISTS(SELECT * FROM #Designaciones_Antes EXCEPT SELECT * FROM dbo.Designacion_Arbitral)
 OR EXISTS(SELECT * FROM dbo.Designacion_Arbitral EXCEPT SELECT * FROM #Designaciones_Antes)
    THROW 59999,N'Se modificaron sanciones ajenas o designaciones.',1;
-- Una correccion manual se conserva: no duplicar ni sobrescribir el caso.
DECLARE @sancion INT,@motivo VARCHAR(300),@tipo VARCHAR(50);
SELECT @sancion=id_sancion,@motivo=motivo,@tipo=tipo_sancion
FROM dbo.Sancion_Arbitral WHERE LEFT(motivo,LEN('[SIMULADO SA-01]'))='[SIMULADO SA-01]';
BEGIN TRY
    EXEC abm.Sancion_Arbitral_Modificacion @sancion,@motivo,'MULTA';
    EXEC carga.Cargar_Sanciones_Arbitrales_Manuales @i OUTPUT,@o OUTPUT,@e OUTPUT;
    IF @i<>0 OR @o<>4 OR @e<>1
        THROW 59999,N'No se detecto el caso modificado sin sobrescribirlo.',1;
    IF NOT EXISTS(SELECT 1 FROM dbo.Sancion_Arbitral WHERE id_sancion=@sancion AND tipo_sancion='MULTA')
        THROW 59999,N'La carga sobrescribio la correccion manual.',1;
    EXEC abm.Sancion_Arbitral_Modificacion @sancion,@motivo,@tipo;
END TRY
BEGIN CATCH
    EXEC abm.Sancion_Arbitral_Modificacion @sancion,@motivo,@tipo;
    THROW;
END CATCH;
IF @@TRANCOUNT<>0 THROW 59999,N'Quedo una transaccion abierta.',1;
PRINT N'OK: cinco sanciones simuladas, designaciones y fechas validas, repeticion estable, correccion manual respetada y datos previos conservados.';
GO
