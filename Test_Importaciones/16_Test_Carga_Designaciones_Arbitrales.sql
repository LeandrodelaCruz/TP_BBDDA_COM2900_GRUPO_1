/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Ejecutar en MUNDIALDEFUTBOL con Partido y Arbitro vacias; conserva su escenario.
IF EXISTS(SELECT 1 FROM dbo.Seleccion WHERE pais LIKE N'TA[_]%')
    THROW 59990,N'El escenario TA_ ya existe en MUNDIALDEFUTBOL. Revise esos datos antes de ejecutar.',1;
SET XACT_ABORT OFF;
-- La carga confirma cada partido: este test requiere tablas vacias y conserva
-- su escenario SIMULADO en MUNDIALDEFUTBOL para inspeccion. No borra datos previos.
IF EXISTS(SELECT 1 FROM dbo.Partido) OR EXISTS(SELECT 1 FROM dbo.Arbitro)
    THROW 59990,N'La prueba de carga requiere partidos y arbitros vacios.',1;

    DECLARE @vacios INT,@vaciosO INT,@vaciosE INT;
    EXEC carga.Cargar_Designaciones_Arbitrales @completados=@vacios OUTPUT,@omitidos=@vaciosO OUTPUT,@errores=@vaciosE OUTPUT;
    IF @vacios<>0 OR @vaciosO<>0 OR @vaciosE<>0 THROW 59999,N'Fallo lote vacio.',1;
    DECLARE @sede INT,@sa INT,@sb INT,@sc INT,@sd INT,@p INT,@q INT;
    INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario) VALUES(N'TA_Estadio',N'TA_Ciudad',N'TA_Sede',50000,'UTC');
    SET @sede=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_A','UEFA','A'); SET @sa=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_B','UEFA','B'); SET @sb=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_C','UEFA','C'); SET @sc=SCOPE_IDENTITY();
    INSERT dbo.Seleccion(pais,confederacion,grupo_asignado) VALUES(N'TA_D','UEFA','D'); SET @sd=SCOPE_IDENTITY();
    DECLARE @ids TABLE(id INT);
    INSERT @ids EXEC abm.Partidos_Alta @sede,@sa,@sb,'20260701','20260701 12:00','20260701 12:00','CUARTOS';
    SELECT @p=id FROM @ids; DELETE @ids;
    INSERT @ids EXEC abm.Partidos_Alta @sede,@sc,@sd,'20260701','20260701 18:00','20260701 18:00','CUARTOS';
    SELECT @q=id FROM @ids; DELETE @ids;
    DECLARE @conflicto INT,@externo INT,@futuro INT,@asistente INT,@otro INT,@var INT,@avar INT;
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Conflicto',N'TA_A','Principal'); SET @conflicto=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Externo',N'TA_X','Principal'); SET @externo=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Futuro',N'TA_C','Principal'); SET @futuro=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Asistente1',N'TA_X','Asistente'); SET @asistente=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_Asistente2',N'TA_Y','Asistente'); SET @otro=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_VAR',N'TA_X','VAR'); SET @var=SCOPE_IDENTITY();
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_AVAR',N'TA_Y','VAR'); SET @avar=SCOPE_IDENTITY();

    DECLARE @completos INT,@omitidos INT,@errores INT,@rechazos INT;
    EXEC carga.Cargar_Designaciones_Arbitrales @p,1,@completos OUTPUT,@omitidos OUTPUT,@errores OUTPUT,@rechazos OUTPUT;
    IF @completos<>1 OR @errores<>0 OR @rechazos<1
        THROW 59999,N'FALLO: carga con rechazo y reemplazante.',1;
    DECLARE @antes TABLE(id INT PRIMARY KEY,rol VARCHAR(30));
    INSERT @antes SELECT id_arbitro,rol_arbitro FROM dbo.Designacion_Arbitral WHERE id_partido=@p;
    EXEC carga.Cargar_Designaciones_Arbitrales @p,1,@completos OUTPUT,@omitidos OUTPUT,@errores OUTPUT,@rechazos OUTPUT;
    IF @completos<>0 OR @omitidos<>1 OR @errores<>0
       OR EXISTS(SELECT id_arbitro,rol_arbitro FROM dbo.Designacion_Arbitral WHERE id_partido=@p EXCEPT SELECT id,rol FROM @antes)
        THROW 59999,N'FALLO: repeticion modifico el equipo.',1;
    -- Retirar AVAR de la nomina para que falte un candidato: no afecta al primer partido.
    EXEC abm.Designacion_Arbitral_Baja @p,@avar;
    EXEC abm.Arbitro_Baja @avar;
    EXEC carga.Cargar_Designaciones_Arbitrales @q,0,@completos OUTPUT,@omitidos OUTPUT,@errores OUTPUT,@rechazos OUTPUT;
    IF @errores<>1 OR EXISTS(SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@q)
        THROW 59999,N'FALLO: no se revirtio el equipo incompleto.',1;
    IF (SELECT COUNT(*) FROM dbo.Designacion_Arbitral WHERE id_partido=@p)<>5
        THROW 59999,N'FALLO: se alteraron datos de otro partido.',1;
    -- Reponer candidato y completar solamente el puesto faltante del primer partido.
    INSERT dbo.Arbitro(apellido,pais,puesto) VALUES(N'TA_AVAR2',N'TA_Z','VAR');
    EXEC carga.Cargar_Designaciones_Arbitrales @p,0,@completos OUTPUT,@omitidos OUTPUT,@errores OUTPUT,@rechazos OUTPUT;
    IF @completos<>1 OR @errores<>0 OR (SELECT COUNT(*) FROM dbo.Designacion_Arbitral WHERE id_partido=@p)<>6
        THROW 59999,N'FALLO: completar equipo parcial.',1;
    EXEC carga.Cargar_Designaciones_Arbitrales NULL,0,@completos OUTPUT,@omitidos OUTPUT,@errores OUTPUT,@rechazos OUTPUT;
    IF @completos<>1 OR @omitidos<>1 OR @errores<>0
        THROW 59999,N'FALLO: no se continuo correctamente con los demas partidos.',1;
    PRINT N'OK: carga, rechazo, reemplazante, repeticion, rollback y equipo parcial';
GO
