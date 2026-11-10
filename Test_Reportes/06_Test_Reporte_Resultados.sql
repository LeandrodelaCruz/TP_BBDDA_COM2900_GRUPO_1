/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
    Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
              de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 09/11/2026. Entrega 7: resultados y definiciones por penales.
    Ejecuta Simular_Penales en un caso controlado y verifica el reporte.
    Datos propios en MUNDIALDEFUTBOL con ROLLBACK al terminar o fallar.
*/
USE MUNDIALDEFUTBOL;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
IF SCHEMA_ID(N'test') IS NULL
    THROW 53600,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE test.Reporte_Resultados_Test
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF;
    IF @@TRANCOUNT<>0 THROW 53690,N'Ejecute el test sin una transaccion previa.',1;
    IF OBJECT_ID(N'reportes.Reporte_Resultados',N'P') IS NULL
       OR OBJECT_ID(N'negocio.Simular_Penales',N'P') IS NULL
        THROW 53690,N'Instale el reporte y negocio.Simular_Penales antes del test.',1;
    BEGIN TRANSACTION;
    BEGIN TRY
        DECLARE @marca NVARCHAR(40)=N'RES_'+CONVERT(NVARCHAR(36),NEWID());
        DECLARE @sede INT,@s1 INT,@s2 INT,@j1 INT,@j2 INT,@p_penales INT,@p_conflicto INT,@p_incidencias INT,@p_regular INT;
        INSERT dbo.Sede(nombre_estadio,ciudad,pais,capacidad,huso_horario)
            VALUES(@marca,N'Ciudad de prueba',N'Pais de prueba',1000,'UTC'); SET @sede=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' Local','UEFA','A'); SET @s1=SCOPE_IDENTITY();
        INSERT dbo.Seleccion(pais,confederacion,grupo_asignado)
            VALUES(@marca+N' Visitante','UEFA','B'); SET @s2=SCOPE_IDENTITY();
        INSERT dbo.Jugador(id_seleccion,nombre,apellido,fecha_nacimiento,club_origen,posicion,dorsal)
            SELECT s.id,CONCAT(N'Jugador ',n.numero),@marca,'19950101',N'Club de prueba','Mediocentro',n.numero
            FROM (VALUES(@s1),(@s2)) s(id)
            CROSS JOIN (VALUES(1),(2),(3),(4),(5),(6),(7),(8),(9),(10),(11)) n(numero);
        SELECT @j1=MIN(id_jugador) FROM dbo.Jugador WHERE id_seleccion=@s1;
        SELECT @j2=MIN(id_jugador) FROM dbo.Jugador WHERE id_seleccion=@s2;
        DECLARE @casos TABLE(caso INT PRIMARY KEY,fase VARCHAR(30),resultado VARCHAR(20));
        INSERT @casos VALUES
            (1,'GRUPOS','2-0'),(2,'GRUPOS','1-1'),(3,'CUARTOS','1-1 (3-4)'),
            (4,'FINAL','0-0 (4-3)'),(5,'GRUPOS',NULL),(6,'OCTAVOS','0-0'),
            (7,'GRUPOS','Texto inesperado'),(8,'CUARTOS','1-1 (3-4)'),
            (9,'GRUPOS','2-1'),(10,'SEMIFINAL','1-1');
        INSERT dbo.Partido(id_sede,fecha,horario_local,horario_UTC,fase,id_seleccion_1,id_seleccion_2,resultado_final)
            SELECT @sede,DATEADD(DAY,c.caso,CONVERT(DATE,'20260601')),
                   DATEADD(DAY,c.caso,CONVERT(DATETIME2(0),'20260601 12:00')),
                   DATEADD(DAY,c.caso,CONVERT(DATETIME2(0),'20260601 12:00')),
                   c.fase,@s1,@s2,c.resultado FROM @casos c;
        SELECT c.caso,p.id_partido INTO #Casos_Resultados FROM @casos c JOIN dbo.Partido p
            ON p.id_sede=@sede AND p.fecha=DATEADD(DAY,c.caso,CONVERT(DATE,'20260601'));
        SELECT @p_penales=id_partido FROM #Casos_Resultados WHERE caso=3;
        SELECT @p_conflicto=id_partido FROM #Casos_Resultados WHERE caso=8;
        SELECT @p_regular=id_partido FROM #Casos_Resultados WHERE caso=9;
        SELECT @p_incidencias=id_partido FROM #Casos_Resultados WHERE caso=10;
        INSERT dbo.Formacion(id_partido,id_seleccion,esquema_tactico)
            VALUES(@p_penales,@s1,'4-4-2'),(@p_penales,@s2,'4-4-2');
        INSERT dbo.Formacion_Jugador(id_formacion,id_jugador,posicion_en_cancha,dorsal_en_cancha,es_titular)
            SELECT f.id_formacion,j.id_jugador,j.posicion,j.dorsal,1
            FROM dbo.Formacion f JOIN dbo.Jugador j ON j.id_seleccion=f.id_seleccion
            WHERE f.id_partido=@p_penales;
        -- Mismo procedimiento que llama Simular_Partido al procesar el marcador importado.
        EXEC negocio.Simular_Penales @p_penales,@s1,@s2,3,4;
        INSERT dbo.Incidencia(id_partido,id_jugador,tipo,periodo,minuto)
            VALUES(@p_conflicto,@j1,'GOL DE PENAL','PENALES',NULL),
                  (@p_conflicto,@j2,'PENAL ERRADO','PENALES',NULL),
                  (@p_regular,@j1,'GOL DE PENAL','PRIMER TIEMPO',22),
                  (@p_incidencias,@j1,'GOL DE PENAL','PENALES',NULL),
                  (@p_incidencias,@j1,'GOL DE PENAL','PENALES',NULL),
                  (@p_incidencias,@j2,'GOL DE PENAL','PENALES',NULL);
        CREATE TABLE #Reporte
        (id_partido INT,fase VARCHAR(30),fecha DATE,seleccion_1 NVARCHAR(80),resultado NVARCHAR(80),
         seleccion_2 NVARCHAR(80),definicion NVARCHAR(200),sede NVARCHAR(100),observacion NVARCHAR(300));
        INSERT #Reporte EXEC reportes.Reporte_Resultados @id_seleccion=@s1;
        IF (SELECT COUNT(*) FROM #Reporte)<>10 THROW 53691,N'El filtro por seleccion no recupero todos sus partidos.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte r JOIN #Casos_Resultados c ON c.id_partido=r.id_partido
                      WHERE c.caso=1 AND r.resultado=N'2-0' AND r.definicion=N'Ganó '+r.seleccion_1 AND r.observacion IS NULL)
            THROW 53691,N'Victoria simple incorrecta.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte r JOIN #Casos_Resultados c ON c.id_partido=r.id_partido
                      WHERE c.caso=2 AND r.definicion=N'Empate' AND r.observacion IS NULL)
            THROW 53691,N'Empate de grupos incorrecto.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte WHERE id_partido=@p_penales
                      AND resultado=N'1-1 (penales 3-4)' AND definicion=N'Ganó '+seleccion_2+N' por penales' AND observacion IS NULL)
            THROW 53691,N'La tanda simulada no coincide con la definicion del reporte.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte r JOIN #Casos_Resultados c ON c.id_partido=r.id_partido
                      WHERE c.caso=4 AND r.resultado=N'0-0 (penales 4-3)'
                        AND r.definicion=N'Ganó '+r.seleccion_1+N' por penales' AND r.observacion LIKE N'%sin incidencias%')
            THROW 53691,N'No se conservo la tanda de la fuente antes de simularla.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte r JOIN #Casos_Resultados c ON c.id_partido=r.id_partido
                      WHERE c.caso=5 AND r.resultado=N'Pendiente' AND r.definicion=N'Pendiente')
            THROW 53691,N'Partido pendiente incorrecto.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte r JOIN #Casos_Resultados c ON c.id_partido=r.id_partido
                      WHERE c.caso=6 AND r.definicion=N'Definición no informada')
            THROW 53691,N'Se invento el ganador de un empate eliminatorio.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte r JOIN #Casos_Resultados c ON c.id_partido=r.id_partido
                      WHERE c.caso=7 AND r.resultado=N'Texto inesperado' AND r.definicion=N'A revisar')
            THROW 53691,N'El formato desconocido no se conservo sin interpretar.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte WHERE id_partido=@p_conflicto
                      AND definicion=N'A revisar' AND observacion LIKE N'%no coincide%')
            THROW 53691,N'No se detecto la discrepancia entre tanda y marcador.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte WHERE id_partido=@p_regular
                      AND resultado=N'2-1' AND definicion=N'Ganó '+seleccion_1 AND observacion IS NULL)
            THROW 53691,N'Un penal durante el partido se conto como tanda.',1;
        IF NOT EXISTS(SELECT 1 FROM #Reporte WHERE id_partido=@p_incidencias
                      AND resultado=N'1-1 (penales 2-1)' AND definicion=N'Ganó '+seleccion_1+N' por penales'
                      AND observacion LIKE N'%no incluida%')
            THROW 53691,N'No se recupero la tanda de las incidencias.',1;
        SELECT * INTO #Ejemplo FROM #Reporte;
        DELETE #Reporte;
        INSERT #Reporte EXEC reportes.Reporte_Resultados @fase=' grupos ',@id_seleccion=@s2;
        IF (SELECT COUNT(*) FROM #Reporte)<>5 OR EXISTS(SELECT 1 FROM #Reporte WHERE fase<>'GRUPOS')
            THROW 53691,N'Filtros combinados o seleccion visitante incorrectos.',1;
        DELETE #Reporte;
        INSERT #Reporte EXEC reportes.Reporte_Resultados @id_partido=@p_penales;
        IF (SELECT COUNT(*) FROM #Reporte)<>1 THROW 53691,N'El filtro por partido devolvio otras filas.',1;
        DELETE #Reporte;
        INSERT #Reporte EXEC reportes.Reporte_Resultados @fase='FINAL',@id_partido=@p_penales;
        IF EXISTS(SELECT 1 FROM #Reporte) THROW 53691,N'Los filtros sin coincidencias devolvieron filas.',1;
        BEGIN TRY
            EXEC reportes.Reporte_Resultados @fase='FASE INVALIDA',@id_seleccion=-1,@id_partido=-1;
            THROW 53691,N'Se aceptaron filtros invalidos.',1;
        END TRY
        BEGIN CATCH
            IF ERROR_NUMBER()<>53601 THROW;
            IF ERROR_MESSAGE() NOT LIKE N'%fase%' OR ERROR_MESSAGE() NOT LIKE N'%seleccion%' OR ERROR_MESSAGE() NOT LIKE N'%partido%' THROW;
        END CATCH;
        IF @@TRANCOUNT<>1 THROW 53691,N'El reporte altero la transaccion del test.',1;
        -- Emitir el ejemplo antes de revertir: #Ejemplo tambien pertenece a la transaccion.
        SELECT * FROM #Ejemplo
        ORDER BY CASE fase WHEN 'GRUPOS' THEN 1 WHEN 'OCTAVOS' THEN 3 WHEN 'CUARTOS' THEN 4
                           WHEN 'SEMIFINAL' THEN 5 WHEN 'FINAL' THEN 7 ELSE 8 END,fecha,id_partido;
        ROLLBACK TRANSACTION;
        PRINT N'OK: resultados por fase, formatos de fuente, tanda simulada, discrepancias, pendientes y filtros. Datos revertidos.';
    END TRY
    BEGIN CATCH
        IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO
EXEC test.Reporte_Resultados_Test;
GO
