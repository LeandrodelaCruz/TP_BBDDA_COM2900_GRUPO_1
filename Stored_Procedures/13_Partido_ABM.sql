/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada
    Integrantes: 
				Rodr�guez, El�as Uriel 44143869
				Clara, Lucas Nicolas 46265738
				Caro, Nicolas Dario 40766722
				de la Cruz, Leandro Ariel 42022547
    Fecha: 06/10/2026

    Descripci�n:
    Script de creaci�n de Stored Procedures ABM (Alta, Baja, Modificaci�n)
    para la tabla:
        - dbo.Partido

    Cada SP realiza validaciones y agrupa los errores en un �nico mensaje.
*/

USE MUNDIALDEFUTBOL;
GO

/* =========================================================
   TABLA: dbo.Partido
   ========================================================= */

CREATE OR ALTER PROCEDURE abm.Partidos_Alta
    @id_sede           INT,
	@id_seleccion_1     INT,
    @id_seleccion_2     INT,
    @fecha             DATE,
    @horario_local     DATETIME2(0),
    @horario_UTC       DATETIME2(0),
    @fase              VARCHAR(30),
    @resultado_final   VARCHAR(20) = NULL,
    @asistencia_publico INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @fasesValidas TABLE (f VARCHAR(30));
    INSERT INTO @fasesValidas VALUES
        ('GRUPOS'), ('DIECISEISAVOS'), ('OCTAVOS'), ('CUARTOS'),
        ('SEMIFINAL'), ('TERCER PUESTO'), ('FINAL');

    -- Validación 1: sede existente
    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede)
        SET @errores += N'- No existe la sede indicada. ';

	-- Validación 2: selección 1 existente
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_1)
        SET @errores += N'- No existe la selección 1 indicada. ';

    -- Validación 3: selección 2 existente
    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_2)
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

    -- Validación 8: asistencia no supera capacidad de la sede
    IF @asistencia_publico IS NOT NULL
       AND EXISTS (
            SELECT 1 FROM dbo.Sede
            WHERE id_sede = @id_sede
              AND capacidad < @asistencia_publico
       )
        SET @errores += N'- La asistencia supera la capacidad de la sede. ';

    -- Validación 9: fecha coherente con horario local
    IF @horario_local IS NOT NULL AND CAST(@horario_local AS DATE) <> @fecha
        SET @errores += N'- La fecha no coincide con la del horario local. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
        INSERT INTO dbo.Partido (id_sede, id_seleccion_1, id_seleccion_2, fecha, horario_local, horario_UTC,
                                 fase, resultado_final, asistencia_publico)
        VALUES (@id_sede, @id_seleccion_1, @id_seleccion_2, @fecha, @horario_local, @horario_UTC,
                @fase, @resultado_final, @asistencia_publico);

        SELECT SCOPE_IDENTITY() AS id_partido_generado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO

CREATE OR ALTER PROCEDURE abm.Partidos_Baja
    @id_partido INT
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';

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

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

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
	@id_seleccion_1     INT,
    @id_seleccion_2     INT,
    @fecha             DATE,
    @horario_local     DATETIME2(0),
    @horario_UTC       DATETIME2(0),
    @fase              VARCHAR(30),
    @resultado_final   VARCHAR(20) = NULL,
    @asistencia_publico INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @errores NVARCHAR(MAX) = N'';
    DECLARE @fasesValidas TABLE (f VARCHAR(30));
    INSERT INTO @fasesValidas VALUES
        ('GRUPOS'), ('DIECISEISAVOS'), ('OCTAVOS'), ('CUARTOS'),
        ('SEMIFINAL'), ('TERCER PUESTO'), ('FINAL');

    IF NOT EXISTS (SELECT 1 FROM dbo.Partido WHERE id_partido = @id_partido)
        SET @errores += N'- No existe el partido indicado. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Sede WHERE id_sede = @id_sede)
        SET @errores += N'- No existe la sede indicada. ';

	IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_1)
        SET @errores += N'- No existe la selección 1 indicada. ';

    IF NOT EXISTS (SELECT 1 FROM dbo.Seleccion WHERE id_seleccion = @id_seleccion_2)
        SET @errores += N'- No existe la selección 2 indicada. ';

    IF @id_seleccion_1 = @id_seleccion_2
        SET @errores += N'- Las dos selecciones del partido deben ser distintas. ';

    IF NOT EXISTS (SELECT 1 FROM @fasesValidas WHERE f = @fase)
        SET @errores += N'- La fase indicada no es válida. ';

    IF @horario_local IS NULL OR @horario_UTC IS NULL
        SET @errores += N'- Los horarios local y UTC son obligatorios. ';

    IF @asistencia_publico IS NOT NULL AND @asistencia_publico < 0
        SET @errores += N'- La asistencia no puede ser negativa. ';

    IF @asistencia_publico IS NOT NULL
       AND EXISTS (
            SELECT 1 FROM dbo.Sede
            WHERE id_sede = @id_sede AND capacidad < @asistencia_publico
       )
        SET @errores += N'- La asistencia supera la capacidad de la sede. ';

    IF @horario_local IS NOT NULL AND CAST(@horario_local AS DATE) <> @fecha
        SET @errores += N'- La fecha no coincide con la del horario local. ';

    IF @errores <> N''
    BEGIN
        RAISERROR(@errores, 16, 1);
        RETURN;
    END

    BEGIN TRY
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

        SELECT @id_partido AS id_partido_modificado;
    END TRY
    BEGIN CATCH
        THROW;
    END CATCH
END;
GO
