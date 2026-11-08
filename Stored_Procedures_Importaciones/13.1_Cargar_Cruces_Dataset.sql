/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Mapa del fixture LOCAL partidos_mundial_2026.json. No es una certificacion del cuadro oficial.
-- Relaciones explicitas revisadas contra los participantes del archivo. NO confirma ganadores.
-- Numero es referencia del archivo, nunca se supone que coincide con el IDENTITY de la BD.
CREATE OR ALTER PROCEDURE carga.Cargar_Cruces_Dataset
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF; -- Los rechazos previstos permiten volver al punto de guardado.
    -- Si el llamador abrio una transaccion, conservar su trabajo anterior.
    DECLARE @transacciones_previas INT = @@TRANCOUNT;
    BEGIN TRY
        IF @transacciones_previas = 0
            BEGIN TRANSACTION;
        ELSE
            SAVE TRANSACTION CargarCruces;

    DECLARE @referencias TABLE(numero INT PRIMARY KEY,utc DATETIME2(0),fase VARCHAR(30));
    INSERT @referencias VALUES
    (73,'2026-06-28T19:00:00','DIECISEISAVOS'),
    (74,'2026-06-29T20:30:00','DIECISEISAVOS'),
    (75,'2026-06-30T01:00:00','DIECISEISAVOS'),
    (76,'2026-06-29T17:00:00','DIECISEISAVOS'),
    (77,'2026-06-30T21:00:00','DIECISEISAVOS'),
    (78,'2026-06-30T17:00:00','DIECISEISAVOS'),
    (79,'2026-07-01T02:00:00','DIECISEISAVOS'),
    (80,'2026-07-01T16:00:00','DIECISEISAVOS'),
    (81,'2026-07-02T00:00:00','DIECISEISAVOS'),
    (82,'2026-07-01T20:00:00','DIECISEISAVOS'),
    (83,'2026-07-02T23:00:00','DIECISEISAVOS'),
    (84,'2026-07-02T19:00:00','DIECISEISAVOS'),
    (85,'2026-07-03T03:00:00','DIECISEISAVOS'),
    (86,'2026-07-03T22:00:00','DIECISEISAVOS'),
    (87,'2026-07-04T01:30:00','DIECISEISAVOS'),
    (88,'2026-07-03T18:00:00','DIECISEISAVOS'),
    (89,'2026-07-04T21:00:00','OCTAVOS'),
    (90,'2026-07-04T17:00:00','OCTAVOS'),
    (91,'2026-07-05T20:00:00','OCTAVOS'),
    (92,'2026-07-06T01:00:00','OCTAVOS'),
    (93,'2026-07-06T19:00:00','OCTAVOS'),
    (94,'2026-07-07T00:00:00','OCTAVOS'),
    (95,'2026-07-07T16:00:00','OCTAVOS'),
    (96,'2026-07-07T20:00:00','OCTAVOS'),
    (97,'2026-07-09T20:00:00','CUARTOS'),
    (98,'2026-07-10T19:00:00','CUARTOS'),
    (99,'2026-07-11T21:00:00','CUARTOS'),
    (100,'2026-07-12T01:00:00','CUARTOS'),
    (101,'2026-07-14T19:00:00','SEMIFINAL'),
    (102,'2026-07-15T19:00:00','SEMIFINAL'),
    (103,'2026-07-18T21:00:00','TERCER PUESTO'),
    (104,'2026-07-19T19:00:00','FINAL');
    DECLARE @mapa TABLE(destino INT,posicion TINYINT,origen INT,tipo VARCHAR(8),PRIMARY KEY(destino,posicion));
    INSERT @mapa VALUES
    (89,1,74,'GANADOR'),
    (89,2,77,'GANADOR'),
    (90,1,73,'GANADOR'),
    (90,2,75,'GANADOR'),
    (91,1,76,'GANADOR'),
    (91,2,78,'GANADOR'),
    (92,1,79,'GANADOR'),
    (92,2,80,'GANADOR'),
    (93,1,83,'GANADOR'),
    (93,2,84,'GANADOR'),
    (94,1,81,'GANADOR'),
    (94,2,82,'GANADOR'),
    (95,1,86,'GANADOR'),
    (95,2,88,'GANADOR'),
    (96,1,85,'GANADOR'),
    (96,2,87,'GANADOR'),
    (97,1,89,'GANADOR'),
    (97,2,90,'GANADOR'),
    (98,1,93,'GANADOR'),
    (98,2,94,'GANADOR'),
    (99,1,91,'GANADOR'),
    (99,2,92,'GANADOR'),
    (100,1,95,'GANADOR'),
    (100,2,96,'GANADOR'),
    (101,1,97,'GANADOR'),
    (101,2,98,'GANADOR'),
    (102,1,99,'GANADOR'),
    (102,2,100,'GANADOR'),
    (103,1,101,'PERDEDOR'),
    (103,2,102,'PERDEDOR'),
    (104,1,101,'GANADOR'),
    (104,2,102,'GANADOR');
    -- La resolucion por UTC/fase debe ser univoca; no se inventan partidos si faltan.
    IF EXISTS(SELECT 1 FROM @referencias r LEFT JOIN dbo.Partido p ON p.horario_UTC=r.utc AND p.fase=r.fase
        GROUP BY r.numero HAVING COUNT(p.id_partido)<>1)
        THROW 51340,N'Importe el fixture local completo. Una referencia de UTC/fase falta o es ambigua.',1;
    DECLARE @trabajo TABLE(orden INT PRIMARY KEY,destino INT,posicion TINYINT,origen INT,tipo VARCHAR(8));
    INSERT @trabajo SELECT CONVERT(INT,ROW_NUMBER() OVER(ORDER BY m.destino,m.posicion)),
        pd.id_partido,m.posicion,po.id_partido,m.tipo
    FROM @mapa m JOIN @referencias rd ON rd.numero=m.destino JOIN @referencias ro ON ro.numero=m.origen
    JOIN dbo.Partido pd ON pd.horario_UTC=rd.utc AND pd.fase=rd.fase
    JOIN dbo.Partido po ON po.horario_UTC=ro.utc AND po.fase=ro.fase;
    DECLARE @n INT,@d INT,@pos TINYINT,@o INT,@tipo VARCHAR(8);
    SELECT @n=MIN(orden) FROM @trabajo;
    WHILE @n IS NOT NULL
    BEGIN
        SELECT @d=destino,@pos=posicion,@o=origen,@tipo=tipo FROM @trabajo WHERE orden=@n;
        EXEC abm.Cruce_Partido_Alta @d,@pos,@o,@tipo;
        SELECT @n=MIN(orden) FROM @trabajo WHERE orden>@n;
    END;

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION CargarCruces;
        THROW;
    END CATCH
    SELECT 32 AS cruces_verificados;
END;
GO
