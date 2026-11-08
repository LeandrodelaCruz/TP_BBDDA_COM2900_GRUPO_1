/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- Alta idempotente: no reescribe relaciones ya utilizadas.
CREATE OR ALTER PROCEDURE abm.Cruce_Partido_Alta
    @id_partido_destino INT, @posicion_destino TINYINT,
    @id_partido_origen INT, @tipo_clasificado VARCHAR(8)
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
            SAVE TRANSACTION CruceAlta;

    DECLARE @fo VARCHAR(30), @fd VARCHAR(30), @ho DATETIME2, @hd DATETIME2,
        @s1 INT, @s2 INT, @g INT, @actual INT, @esperado INT;
    SELECT @fo=fase,@ho=horario_UTC,@s1=id_seleccion_1,@s2=id_seleccion_2,@g=id_seleccion_ganadora
        FROM dbo.Partido WHERE id_partido=@id_partido_origen;
    SELECT @fd=fase,@hd=horario_UTC,@actual=CASE @posicion_destino WHEN 1 THEN id_seleccion_1 ELSE id_seleccion_2 END
        FROM dbo.Partido WHERE id_partido=@id_partido_destino;
    SET @tipo_clasificado=UPPER(LTRIM(RTRIM(@tipo_clasificado)));
    IF @fo IS NULL OR @fd IS NULL THROW 51320,N'Los dos partidos del cruce deben existir.',1;
    IF @posicion_destino IS NULL OR @posicion_destino NOT IN (1,2)
        THROW 51321,N'La posicion debe ser 1 o 2.',1;
    IF @tipo_clasificado IS NULL OR NOT (
         (@tipo_clasificado='GANADOR' AND
          ((@fo='DIECISEISAVOS' AND @fd='OCTAVOS') OR (@fo='OCTAVOS' AND @fd='CUARTOS')
           OR (@fo='CUARTOS' AND @fd='SEMIFINAL') OR (@fo='SEMIFINAL' AND @fd='FINAL')))
         OR (@tipo_clasificado='PERDEDOR' AND @fo='SEMIFINAL' AND @fd='TERCER PUESTO'))
        THROW 51322,N'Fases o tipo de clasificado incompatibles. No se admiten ciclos ni saltos de ronda.',1;
    IF @hd<=@ho THROW 51323,N'El destino debe jugarse despues del origen.',1;
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_destino=@id_partido_destino
        AND posicion_destino<>@posicion_destino AND id_partido_origen=@id_partido_origen)
        THROW 51324,N'Un partido no puede aportar los dos participantes al mismo destino.',1;
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_origen=@id_partido_origen
        AND tipo_clasificado=@tipo_clasificado
        AND NOT(id_partido_destino=@id_partido_destino AND posicion_destino=@posicion_destino))
        THROW 51324,N'El clasificado ya tiene otro destino.',1;
    SET @esperado=CASE WHEN @g IS NULL THEN NULL WHEN @tipo_clasificado='GANADOR' THEN @g
        WHEN @g=@s1 THEN @s2 ELSE @s1 END;
    IF @actual IS NOT NULL AND ((@esperado IS NOT NULL AND @actual<>@esperado)
        OR (@s1 IS NOT NULL AND @s2 IS NOT NULL AND @actual NOT IN (@s1,@s2)))
        THROW 51325,N'El participante del destino no coincide con su origen.',1;
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_destino=@id_partido_destino AND posicion_destino=@posicion_destino)
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_destino=@id_partido_destino AND posicion_destino=@posicion_destino
            AND (id_partido_origen<>@id_partido_origen OR tipo_clasificado<>@tipo_clasificado))
            THROW 51326,N'El lugar ya tiene otro origen. Retire primero el cruce si no fue utilizado.',1;
    END
    ELSE INSERT dbo.Cruce_Partido VALUES(@id_partido_destino,@posicion_destino,@id_partido_origen,@tipo_clasificado);

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION CruceAlta;
        THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE abm.Cruce_Partido_Baja
    @id_partido_destino INT, @posicion_destino TINYINT
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
            SAVE TRANSACTION CruceBaja;

    IF NOT EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_destino=@id_partido_destino AND posicion_destino=@posicion_destino)
        THROW 51327,N'El cruce no existe.',1;
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido c JOIN dbo.Partido o ON o.id_partido=c.id_partido_origen
        JOIN dbo.Partido d ON d.id_partido=c.id_partido_destino
        WHERE c.id_partido_destino=@id_partido_destino AND c.posicion_destino=@posicion_destino
        AND (o.id_seleccion_ganadora IS NOT NULL OR d.id_seleccion_1 IS NOT NULL OR d.id_seleccion_2 IS NOT NULL))
        THROW 51328,N'El cruce ya tiene clasificados o participantes de destino; no se puede retirar.',1;
    DELETE dbo.Cruce_Partido WHERE id_partido_destino=@id_partido_destino AND posicion_destino=@posicion_destino;

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION CruceBaja;
        THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE abm.Cruce_Partido_Modificacion
    @id_partido_destino INT, @posicion_destino TINYINT,
    @id_partido_origen INT, @tipo_clasificado VARCHAR(8)
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
            SAVE TRANSACTION CruceModificar;

    EXEC abm.Cruce_Partido_Baja @id_partido_destino,@posicion_destino;
    EXEC abm.Cruce_Partido_Alta @id_partido_destino,@posicion_destino,@id_partido_origen,@tipo_clasificado;

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION CruceModificar;
        THROW;
    END CATCH
END;
GO
CREATE OR ALTER PROCEDURE abm.Cruce_Partido_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.Cruce_Partido ORDER BY id_partido_destino,posicion_destino;
END;
GO
