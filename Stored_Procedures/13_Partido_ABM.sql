/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes:
				Rodriguez, Elias Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripcion:
    Script de creacion de Stored Procedures ABM (Alta, Baja, Modificacion)
    para la tabla:
        - dbo.Partido

    Cada SP realiza validaciones y agrupa los errores en un unico mensaje.
*/

USE MUNDIALDEFUTBOL;
GO

/* =========================================================
   TABLA: dbo.Partido
   ========================================================= */

CREATE OR ALTER PROCEDURE abm.Partidos_Alta
    @id_sede           INT,
	@id_seleccion_1     INT = NULL,
    @id_seleccion_2     INT = NULL,
    @fecha             DATE,
    @horario_local     DATETIME2(0),
    @horario_UTC       DATETIME2(0),
    @fase              VARCHAR(30),
    @resultado_final   VARCHAR(20) = NULL,
    @asistencia_publico INT = NULL,
    @devolver BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF; -- Los rechazos previstos permiten volver al punto de guardado.
    DECLARE @tr INT = @@TRANCOUNT, @lock INT;
    BEGIN TRY
        IF @tr = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION PartidoAlta;
        EXEC @lock = sys.sp_getapplock @Resource=N'negocio.CuadroArbitral',
            @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
        IF @lock < 0 THROW 51690, N'No se pudo bloquear el cuadro arbitral.', 1;


    DECLARE @errores NVARCHAR(2048) = N'';
    DECLARE @fasesValidas TABLE (f VARCHAR(30));
    INSERT INTO @fasesValidas VALUES
        ('GRUPOS'), ('DIECISEISAVOS'), ('OCTAVOS'), ('CUARTOS'),
        ('SEMIFINAL'), ('TERCER PUESTO'), ('FINAL');

    -- Validación 1: sede existente
    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede)
        SET @errores += N'- No existe la sede indicada. ';

	-- Validación 2: selección 1 existente
    IF @id_seleccion_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_1)
        SET @errores += N'- No existe la selección 1 indicada. ';

    -- Validación 3: selección 2 existente
    IF @id_seleccion_2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_2)
        SET @errores += N'- No existe la selección 2 indicada. ';

    -- Validación 4: selecciones distintas
    IF @id_seleccion_1 = @id_seleccion_2
        SET @errores += N'- Las dos selecciones del partido deben ser distintas. ';

    -- Validación 5: fase valida
    IF NOT EXISTS (SELECT 1 FROM @fasesValidas WHERE f = @fase)
        SET @errores += N'- La fase indicada no es valida. ';

    -- Validación 6: horario local y UTC no nulos
    IF @horario_local IS NULL OR @horario_UTC IS NULL
        SET @errores += N'- Los horarios local y UTC son obligatorios. ';

    -- Validación 7: asistencia no negativa
    IF @asistencia_publico IS NOT NULL AND @asistencia_publico < 0
        SET @errores += N'- La asistencia no puede ser negativa. ';

    -- Validación 9: fecha coherente con horario local
    IF @horario_local IS NOT NULL AND CAST(@horario_local AS DATE) <> @fecha
        SET @errores += N'- La fecha no coincide con la del horario local. ';

    SET @resultado_final = NULLIF(LTRIM(RTRIM(@resultado_final)), '');
    IF @resultado_final IS NOT NULL AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL)
        SET @errores += N'- Un resultado requiere ambas selecciones. ';
    IF @fecha IS NULL SET @errores += N'- La fecha es obligatoria. ';
    IF @errores <> N'' THROW 51301, @errores, 1;

        INSERT INTO dbo.Partido (id_sede, id_seleccion_1, id_seleccion_2, fecha, horario_local, horario_UTC,
                                 fase, resultado_final, asistencia_publico)
        VALUES (@id_sede, @id_seleccion_1, @id_seleccion_2, @fecha, @horario_local, @horario_UTC,
                @fase, @resultado_final, @asistencia_publico);

        IF @devolver=1 SELECT SCOPE_IDENTITY() AS id_partido_generado;


        IF @tr = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tr = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @tr > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION PartidoAlta;
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE abm.Partidos_Baja
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(2048) = N'';

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    -- Validación de dependencias
    IF EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene formaciones asociadas. ';

    IF EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene sustituciones asociadas. ';

    IF EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene incidencias asociadas. ';

    IF EXISTS (SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene designaciones arbitrales. ';

    IF EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_partido = @id_partido)
        SET @errores += N'- No se puede eliminar: el partido tiene publicidad asignada. ';

    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_origen=@id_partido OR id_partido_destino=@id_partido)
        SET @errores += N'- No se puede eliminar: el partido pertenece al cuadro de cruces. ';
    IF @errores <> N'' THROW 51301, @errores, 1;

    BEGIN TRY
        -- Primero eliminamos la relación N:N
		DELETE FROM dbo.Partido WHERE id_partido = @id_partido;

        SELECT @id_partido AS id_partido_eliminado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE abm.Partidos_Modificacion
    @id_partido        INT,
    @id_sede           INT,
	@id_seleccion_1     INT = NULL,
    @id_seleccion_2     INT = NULL,
    @fecha             DATE,
    @horario_local     DATETIME2(0),
    @horario_UTC       DATETIME2(0),
    @fase              VARCHAR(30),
    @resultado_final   VARCHAR(20) = NULL,
    @asistencia_publico INT = NULL,
    @devolver BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT OFF; -- Los rechazos previstos permiten volver al punto de guardado.
    DECLARE @tr INT = @@TRANCOUNT, @lock INT;
    BEGIN TRY
        IF @tr = 0 BEGIN TRANSACTION; ELSE SAVE TRANSACTION PartidoModificacion;
        EXEC @lock = sys.sp_getapplock @Resource=N'negocio.CuadroArbitral',
            @LockMode='Exclusive', @LockOwner='Transaction', @LockTimeout=10000;
        IF @lock < 0 THROW 51690, N'No se pudo bloquear el cuadro arbitral.', 1;


    DECLARE @errores NVARCHAR(2048) = N'';
    DECLARE @fasesValidas TABLE (f VARCHAR(30));
    INSERT INTO @fasesValidas VALUES
        ('GRUPOS'), ('DIECISEISAVOS'), ('OCTAVOS'), ('CUARTOS'),
        ('SEMIFINAL'), ('TERCER PUESTO'), ('FINAL');

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede)
        SET @errores += N'- No existe la sede indicada. ';

	IF @id_seleccion_1 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_1)
        SET @errores += N'- No existe la selección 1 indicada. ';

    IF @id_seleccion_2 IS NOT NULL AND NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_2)
        SET @errores += N'- No existe la selección 2 indicada. ';

    IF @id_seleccion_1 = @id_seleccion_2
        SET @errores += N'- Las dos selecciones del partido deben ser distintas. ';

    IF NOT EXISTS (SELECT 1 FROM @fasesValidas WHERE f = @fase)
        SET @errores += N'- La fase indicada no es válida. ';

    IF @horario_local IS NULL OR @horario_UTC IS NULL
        SET @errores += N'- Los horarios local y UTC son obligatorios. ';

    IF @asistencia_publico IS NOT NULL AND @asistencia_publico < 0
        SET @errores += N'- La asistencia no puede ser negativa. ';

    IF @horario_local IS NOT NULL AND CAST(@horario_local AS DATE) <> @fecha
        SET @errores += N'- La fecha no coincide con la del horario local. ';

    SET @resultado_final = NULLIF(LTRIM(RTRIM(@resultado_final)), '');
    IF @resultado_final IS NOT NULL AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL)
        SET @errores += N'- Un resultado requiere ambas selecciones. ';
    IF @fecha IS NULL SET @errores += N'- La fecha es obligatoria. ';
    IF EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido AND
          (ISNULL(id_seleccion_1,-1) <> ISNULL(@id_seleccion_1,-1)
           OR ISNULL(id_seleccion_2,-1) <> ISNULL(@id_seleccion_2,-1)))
    BEGIN
        IF EXISTS (SELECT 1 FROM dbo.Formacion WHERE id_partido=@id_partido)
           OR EXISTS (SELECT 1 FROM dbo.Incidencia WHERE id_partido=@id_partido)
           OR EXISTS (SELECT 1 FROM dbo.Sustitucion WHERE id_partido=@id_partido)
           OR EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_partido=@id_partido)
           OR EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido AND resultado_final IS NOT NULL)
            SET @errores += N'- No se pueden cambiar participantes con datos dependientes o resultado. ';
        IF EXISTS (SELECT 1 FROM dbo.Designacion_Arbitral WHERE id_partido=@id_partido)
           AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL)
            SET @errores += N'- Hay arbitros designados: no se pueden dejar participantes pendientes. ';
    END;
    IF EXISTS (SELECT 1 FROM dbo.Designacion_Arbitral d JOIN dbo.Arbitro a ON a.id_arbitro=d.id_arbitro
        JOIN dbo.Seleccion se ON se.id_seleccion IN (@id_seleccion_1,@id_seleccion_2)
        WHERE d.id_partido=@id_partido AND negocio.Pais_Arbitral_Normalizado(a.pais)=negocio.Pais_Arbitral_Normalizado(se.pais))
        SET @errores += N'- Los participantes generan un conflicto de nacionalidad arbitral. ';
    IF EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido AND id_seleccion_ganadora IS NOT NULL
        AND (ISNULL(resultado_final,'')<>ISNULL(@resultado_final,'') OR fase<>@fase))
        SET @errores += N'- El resultado confirmado se administra desde negocio.Confirmar_Resultado_Eliminatorio. ';
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido WHERE id_partido_origen=@id_partido OR id_partido_destino=@id_partido)
       AND EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido=@id_partido AND (fase<>@fase OR horario_UTC<>@horario_UTC))
        SET @errores += N'- No cambie fase u horario de un partido vinculado sin retirar sus cruces. ';
    -- Si el origen aun no tiene ganador, un destino conocido debe pertenecer a sus participantes.
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido c JOIN dbo.Partido o ON o.id_partido=c.id_partido_origen
        WHERE c.id_partido_destino=@id_partido AND o.id_seleccion_1 IS NOT NULL AND o.id_seleccion_2 IS NOT NULL
          AND CASE c.posicion_destino WHEN 1 THEN @id_seleccion_1 ELSE @id_seleccion_2 END NOT IN (o.id_seleccion_1,o.id_seleccion_2))
        SET @errores += N'- El participante no pertenece al partido de origen. ';
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido c JOIN dbo.Partido d ON d.id_partido=c.id_partido_destino
        WHERE c.id_partido_origen=@id_partido
          AND CASE c.posicion_destino WHEN 1 THEN d.id_seleccion_1 ELSE d.id_seleccion_2 END IS NOT NULL
          AND (@id_seleccion_1 IS NULL OR @id_seleccion_2 IS NULL OR
               CASE c.posicion_destino WHEN 1 THEN d.id_seleccion_1 ELSE d.id_seleccion_2 END NOT IN (@id_seleccion_1,@id_seleccion_2)))
        SET @errores += N'- El cambio contradice un participante del partido siguiente. ';
    -- Un lugar con origen conocido solo puede contener al clasificado confirmado.
    IF EXISTS (SELECT 1 FROM dbo.Cruce_Partido c JOIN dbo.Partido o ON o.id_partido=c.id_partido_origen
        WHERE c.id_partido_destino=@id_partido AND
        ISNULL(CASE c.posicion_destino WHEN 1 THEN @id_seleccion_1 ELSE @id_seleccion_2 END,-1) <>
        ISNULL(CASE WHEN o.id_seleccion_ganadora IS NULL THEN
                 CASE c.posicion_destino WHEN 1 THEN @id_seleccion_1 ELSE @id_seleccion_2 END
             WHEN c.tipo_clasificado='GANADOR' THEN o.id_seleccion_ganadora
             WHEN o.id_seleccion_ganadora=o.id_seleccion_1 THEN o.id_seleccion_2 ELSE o.id_seleccion_1 END,-1))
        SET @errores += N'- El participante contradice el clasificado del partido de origen. ';
    IF @errores <> N'' THROW 51301, @errores, 1;

        UPDATE dbo.Partido
        SET id_sede            = @id_sede,
		    id_seleccion_1     = @id_seleccion_1,
            id_seleccion_2     = @id_seleccion_2,
            fecha              = @fecha,
            horario_local      = @horario_local,
            horario_UTC        = @horario_UTC,
            fase               = @fase,
            resultado_final    = @resultado_final,
            asistencia_publico = @asistencia_publico
        WHERE id_partido = @id_partido;

        IF @devolver=1 SELECT @id_partido AS id_partido_modificado;


        IF @tr = 0 COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @tr = 0 AND XACT_STATE() <> 0 ROLLBACK TRANSACTION;
        ELSE IF @tr > 0 AND XACT_STATE() = 1 ROLLBACK TRANSACTION PartidoModificacion;
        THROW;
    END CATCH
END;
GO

-- LEFT JOIN conserva los partidos con participantes pendientes.
CREATE OR ALTER PROCEDURE abm.Partidos_Listar
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.*, s1.pais AS seleccion_1, s2.pais AS seleccion_2
    FROM dbo.Partido p
    LEFT JOIN dbo.Seleccion s1 ON s1.id_seleccion=p.id_seleccion_1
    LEFT JOIN dbo.Seleccion s2 ON s2.id_seleccion=p.id_seleccion_2
    ORDER BY p.horario_UTC,p.id_partido;
END;
GO
