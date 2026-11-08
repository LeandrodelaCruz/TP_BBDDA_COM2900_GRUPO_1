/*
 Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comision 01-2900.
 Grupo 01: Caro, Nicolas Dario; Clara, Lucas Nicolas;
 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
 Fecha: 07/11/2026. Entrega 6: calendario, cruces y designacion arbitral.
*/
USE MUNDIALDEFUTBOL;
GO
-- El dataset NO necesita ganador. Confirmacion manual y explicita; no analiza marcadores.
CREATE OR ALTER PROCEDURE negocio.Confirmar_Resultado_Eliminatorio
    @id_partido INT, @id_seleccion_ganadora INT, @resultado_final VARCHAR(20)
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
            SAVE TRANSACTION ConfirmarResultado;

    DECLARE @s1 INT,@s2 INT,@anterior INT,@fase VARCHAR(30);
    SELECT @s1=id_seleccion_1,@s2=id_seleccion_2,@anterior=id_seleccion_ganadora,@fase=fase
    FROM dbo.Partido WHERE id_partido=@id_partido;
    IF @fase IS NULL OR @fase='GRUPOS' OR @s1 IS NULL OR @s2 IS NULL
        THROW 51330,N'Se requiere un partido eliminatorio con ambos participantes.',1;
    IF @id_seleccion_ganadora IS NULL OR @id_seleccion_ganadora NOT IN (@s1,@s2)
        THROW 51331,N'La ganadora debe ser una de las selecciones del partido.',1;
    IF NULLIF(LTRIM(RTRIM(@resultado_final)),'') IS NULL
        THROW 51332,N'Indique el resultado, sin inferir el ganador del marcador.',1;
    IF @anterior IS NOT NULL AND @anterior<>@id_seleccion_ganadora
        THROW 51333,N'Ya hay un ganador confirmado. No se rectifica automaticamente un cuadro utilizado.',1;
    UPDATE dbo.Partido SET id_seleccion_ganadora=@id_seleccion_ganadora,
        resultado_final=LTRIM(RTRIM(@resultado_final)) WHERE id_partido=@id_partido;
    DECLARE @destinos TABLE(id INT PRIMARY KEY);
    INSERT @destinos SELECT DISTINCT id_partido_destino FROM dbo.Cruce_Partido WHERE id_partido_origen=@id_partido;
    DECLARE @d INT,@a INT,@b INT,@sede INT,@fecha DATE,@hl DATETIME2(0),@hu DATETIME2(0),
        @f VARCHAR(30),@r VARCHAR(20),@asistencia INT,@puesto TINYINT,@clasificado INT;
    SELECT @d=MIN(id) FROM @destinos;
    WHILE @d IS NOT NULL
    BEGIN
        SELECT @a=id_seleccion_1,@b=id_seleccion_2,@sede=id_sede,@fecha=fecha,
            @hl=horario_local,@hu=horario_UTC,@f=fase,@r=resultado_final,@asistencia=asistencia_publico
        FROM dbo.Partido WHERE id_partido=@d;
        SELECT @puesto=posicion_destino,@clasificado=CASE WHEN tipo_clasificado='GANADOR' THEN @id_seleccion_ganadora
            WHEN @id_seleccion_ganadora=@s1 THEN @s2 ELSE @s1 END
        FROM dbo.Cruce_Partido WHERE id_partido_origen=@id_partido AND id_partido_destino=@d;
        IF (@puesto=1 AND @a IS NOT NULL AND @a<>@clasificado)
           OR (@puesto=2 AND @b IS NOT NULL AND @b<>@clasificado)
            THROW 51334,N'El destino ya tiene otro participante: se revierte toda la confirmacion.',1;
        IF @puesto=1 SET @a=@clasificado; ELSE SET @b=@clasificado;
        EXEC abm.Partidos_Modificacion @id_partido=@d,@id_sede=@sede,@id_seleccion_1=@a,@id_seleccion_2=@b,
            @fecha=@fecha,@horario_local=@hl,@horario_UTC=@hu,@fase=@f,@resultado_final=@r,
            @asistencia_publico=@asistencia,@devolver=0;
        SELECT @d=MIN(id) FROM @destinos WHERE id>@d;
    END;

        IF @transacciones_previas = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @transacciones_previas = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @transacciones_previas > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION ConfirmarResultado;
        THROW;
    END CATCH
END;
GO
