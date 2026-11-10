/*
    Universidad: Universidad Nacional de La Matanza - UNLaM.
    Materia: Bases de Datos Aplicada - Comision 01-2900. Grupo 01.
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 08/11/2026.
    Objetivo: poblar Sancion_Arbitral con cinco casos FICTICIOS para el TP.
    No representan hechos reales ni sanciones oficiales contra los arbitros.
    Ejecutar despues de importar el fixture local y cargar las designaciones.
    Reutiliza abm.Sancion_Arbitral_Alta; no modifica el modelo ni las designaciones.
    Cada caso es independiente; repetir conserva las sanciones ya cargadas.
    Este archivo solo instala el procedimiento, no ejecuta la carga.
*/
USE MUNDIALDEFUTBOL;
GO
IF SCHEMA_ID(N'carga') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
GO
CREATE OR ALTER PROCEDURE carga.Cargar_Sanciones_Arbitrales_Manuales
    @insertadas INT=0 OUTPUT,@omitidas INT=0 OUTPUT,@errores INT=0 OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;
    -- El ABM heredado revierte su transaccion completa ante un error.
    -- No aceptar trabajo previo del llamador; cada caso tiene su propia transaccion.
    IF @@TRANCOUNT<>0
        THROW 51800,N'Ejecute esta carga sin una transaccion externa abierta.',1;
    SELECT @insertadas=0,@omitidas=0,@errores=0;

    -- UTC y selecciones son referencias del archivo LOCAL, nunca IDs internos.
    -- El asistente elegido es el de menor ID entre los designados como ASISTENTE.
    DECLARE @casos TABLE
    (orden INT PRIMARY KEY,utc DATETIME2(0),local NVARCHAR(80),visitante NVARCHAR(80),
     rol VARCHAR(30),marca VARCHAR(25),motivo VARCHAR(300),tipo VARCHAR(50));
    INSERT @casos VALUES
    (1,'2026-06-11T19:00:00',N'Mexico',N'South Africa','PRINCIPAL','[SIMULADO SA-01]',
     '[SIMULADO SA-01] Multiples tarjetas amarillas incorrectas por faltas leves; advertencia por criterio disciplinario inconsistente.','ADVERTENCIA'),
    (2,'2026-06-12T02:00:00',N'South Korea',N'Czechia','ASISTENTE','[SIMULADO SA-02]',
     '[SIMULADO SA-02] Fuera de juego incorrecto que interrumpio una ocasion manifiesta de ataque.','ADVERTENCIA'),
    (3,'2026-06-12T19:00:00',N'Canada',N'Bosnia and Herzegovina','VAR','[SIMULADO SA-03]',
     '[SIMULADO SA-03] Omision de recomendar la revision de un posible penal pese a disponer de imagenes concluyentes.','SUSPENSION'),
    (4,'2026-06-13T01:00:00',N'USA',N'Paraguay','CUARTO ARBITRO','[SIMULADO SA-04]',
     '[SIMULADO SA-04] Demora injustificada al verificar una sustitucion y errores reiterados en el control del area tecnica.','ADVERTENCIA'),
    (5,'2026-06-13T19:00:00',N'Qatar',N'Switzerland','PRINCIPAL','[SIMULADO SA-05]',
     '[SIMULADO SA-05] Omision de una segunda amonestacion y entrega de un informe postpartido incompleto.','MULTA');

    DECLARE @detalle TABLE
    (caso INT,estado VARCHAR(15),id_sancion INT,id_partido INT,id_arbitro INT,
     rol VARCHAR(30),numero_error INT,detalle NVARCHAR(2048));
    DECLARE @orden INT,@utc DATETIME2(0),@local NVARCHAR(80),@visitante NVARCHAR(80),
        @rol VARCHAR(30),@marca VARCHAR(25),@motivo VARCHAR(300),@tipo VARCHAR(50),
        @partido INT,@arbitro INT,@fecha DATE,@sancion INT,@cantidad INT;
    SELECT @orden=MIN(orden) FROM @casos;
    WHILE @orden IS NOT NULL
    BEGIN
        SELECT @partido=NULL,@arbitro=NULL,@fecha=NULL,@sancion=NULL;
        SELECT @utc=utc,@local=local,@visitante=visitante,@rol=rol,
               @marca=marca,@motivo=motivo,@tipo=tipo FROM @casos WHERE orden=@orden;
        BEGIN TRY
            BEGIN TRANSACTION;
            SELECT @cantidad=COUNT(*),@partido=MIN(p.id_partido)
            FROM dbo.Partido p
            JOIN dbo.Seleccion s1 ON s1.id_seleccion=p.id_seleccion_1
            JOIN dbo.Seleccion s2 ON s2.id_seleccion=p.id_seleccion_2
            WHERE p.horario_UTC=@utc AND p.fase='GRUPOS'
              AND negocio.Pais_Arbitral_Normalizado(s1.pais)=negocio.Pais_Arbitral_Normalizado(@local)
              AND negocio.Pais_Arbitral_Normalizado(s2.pais)=negocio.Pais_Arbitral_Normalizado(@visitante);
            IF @cantidad<>1
                THROW 51801,N'No se encontro un unico partido del caso. Importe primero el fixture local.',1;
            SELECT @fecha=fecha FROM dbo.Partido WHERE id_partido=@partido;
            IF @fecha>CONVERT(DATE,GETDATE())
                THROW 51802,N'El partido aun no se disputo: no se carga la sancion simulada.',1;
            SELECT @cantidad=COUNT(*),@arbitro=MIN(id_arbitro)
            FROM dbo.Designacion_Arbitral WHERE id_partido=@partido AND rol_arbitro=@rol;
            IF (@rol='ASISTENTE' AND @cantidad NOT BETWEEN 1 AND 2)
               OR (@rol<>'ASISTENTE' AND @cantidad<>1)
                THROW 51803,N'Falta una designacion valida para el rol del caso. Cargue primero las designaciones.',1;

            -- La marca identifica el caso, incluso si luego cambian las designaciones.
            -- No generar otra sancion ni trasladar silenciosamente la anterior a otra persona.
            SELECT @cantidad=COUNT(*),@sancion=MIN(id_sancion)
            FROM dbo.Sancion_Arbitral WHERE LEFT(motivo,LEN(@marca))=@marca;
            IF @cantidad>1
                THROW 51804,N'El caso simulado ya aparece duplicado. Revise sus sanciones antes de reintentar.',1;
            IF @cantidad=1
            BEGIN
                IF NOT EXISTS(SELECT 1 FROM dbo.Sancion_Arbitral
                    WHERE id_sancion=@sancion AND id_arbitro=@arbitro AND id_partido=@partido
                      AND fecha=@fecha AND motivo=@motivo AND tipo_sancion=@tipo)
                    THROW 51805,N'El caso ya existe con otros datos o fue reasignado. No se modifica la sancion anterior.',1;
                COMMIT TRANSACTION;
                SET @omitidas+=1;
                INSERT @detalle VALUES(@orden,'YA EXISTE',@sancion,@partido,@arbitro,@rol,NULL,N'Se conserva el caso simulado existente.');
            END
            ELSE
            BEGIN
                EXEC abm.Sancion_Arbitral_Alta
                    @id_arbitro=@arbitro,@id_partido=@partido,@fecha=@fecha,
                    @motivo=@motivo,@tipo_sancion=@tipo,@id_sancion=@sancion OUTPUT;
                COMMIT TRANSACTION;
                SET @insertadas+=1;
                INSERT @detalle VALUES(@orden,'CARGADA',@sancion,@partido,@arbitro,@rol,NULL,CONVERT(NVARCHAR(300),@motivo));
            END;
        END TRY
        BEGIN CATCH
            IF XACT_STATE()<>0 ROLLBACK TRANSACTION;
            SET @errores+=1;
            INSERT @detalle VALUES(@orden,'ERROR',NULL,@partido,@arbitro,@rol,ERROR_NUMBER(),ERROR_MESSAGE());
        END CATCH;
        SELECT @orden=MIN(orden) FROM @casos WHERE orden>@orden;
    END;
    SELECT @insertadas AS sanciones_insertadas,@omitidas AS casos_ya_existentes,@errores AS casos_con_error;
    SELECT d.caso,d.estado,d.id_sancion,d.id_partido,d.id_arbitro,
           CONCAT(a.nombre,N' ',a.apellido) AS arbitro,d.rol,
           sa.fecha,sa.tipo_sancion,d.numero_error,d.detalle
    FROM @detalle d LEFT JOIN dbo.Arbitro a ON a.id_arbitro=d.id_arbitro
    LEFT JOIN dbo.Sancion_Arbitral sa ON sa.id_sancion=d.id_sancion
    ORDER BY d.caso;
END;
GO
-- Luego de importar partidos y cargar designaciones:
-- EXEC carga.Cargar_Sanciones_Arbitrales_Manuales;
