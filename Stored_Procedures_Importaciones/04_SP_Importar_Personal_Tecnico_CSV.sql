/*
    Universidad Nacional de La Matanza - Bases de Datos Aplicada - Com 01-2900
    Grupo 01: Caro, Nicolás; Clara, Lucas; De La Cruz, Leandro; Rodríguez, Elías.
    Fecha: 01/11/2026. Entrega 6.
    Objetivo: importar personal_tecnico.csv generado por scraping de Transfermarkt.
    Columnas: seleccion,nombre_completo,rol,fecha_extraccion_utc (UTF-8).
    Requiere dbo.Personal_Tecnico.nombre_completo NVARCHAR(120) y ABM actualizados.
    UPSERT por selección + nombre completo. El rol NO integra la identidad.
    El CSV describe el cuerpo técnico actual. La fecha de extracción es metadato
    del archivo; no se persiste porque la tabla de negocio no tiene esa columna.
    No elimina personas ausentes del CSV ni reconstruye el historial del Mundial.
    SQL dinámico limitado a la ruta de BULK INSERT, que exige un literal.
*/
USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.SP_Importar_Personal_Tecnico_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@archivo)), N'') IS NULL
        THROW 51400, N'Debe indicar la ruta del CSV de personal técnico.', 1;
    IF OBJECT_ID(N'dbo.Seleccion', N'U') IS NULL
       OR OBJECT_ID(N'dbo.Personal_Tecnico', N'U') IS NULL
        THROW 51401, N'Deben existir las tablas Seleccion y Personal_Tecnico.', 1;
    IF COL_LENGTH(N'dbo.Personal_Tecnico', N'nombre_completo') IS NULL
        THROW 51402, N'Debe migrar Personal_Tecnico a nombre_completo antes de importar.', 1;
    IF OBJECT_ID(N'abm.Personal_Tecnico_Alta', N'P') IS NULL
       OR OBJECT_ID(N'abm.Personal_Tecnico_Modificar', N'P') IS NULL
        THROW 51403, N'Deben existir los ABM de alta y modificación de Personal_Tecnico.', 1;
    IF NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'abm.Personal_Tecnico_Alta') AND name = N'@nombre_completo')
       OR NOT EXISTS (SELECT 1 FROM sys.parameters WHERE object_id = OBJECT_ID(N'abm.Personal_Tecnico_Modificar') AND name = N'@nombre_completo')
        THROW 51404, N'Debe actualizar los ABM para recibir @nombre_completo.', 1;

    -- El CSV es UTF-8. La intercalación de esta staging permite leerlo en
    -- SQL Server 2019+ sin cambiar la base. RAW conserva los bytes del CSV.
    -- Límites de entrada amplios para validar contra el modelo definitivo.
    -- VARCHAR UTF-8 mide bytes; el cursor convierte a NVARCHAR con igual n
    -- para que ningún valor admitido por staging se recorte antes de validar.
    CREATE TABLE #Personal_Staging
    (
        seleccion VARCHAR(400) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        nombre_completo VARCHAR(1000) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        rol VARCHAR(200) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL,
        fecha_extraccion_utc VARCHAR(100) COLLATE Latin1_General_100_CI_AS_SC_UTF8 NULL
    );
    CREATE TABLE #Errores
    (
        registro_procesado INT NOT NULL,
        seleccion NVARCHAR(400) NULL,
        nombre_completo NVARCHAR(1000) NULL,
        rol NVARCHAR(200) NULL,
        numero_error INT NOT NULL,
        mensaje NVARCHAR(2048) NOT NULL
    );

    DECLARE @sql NVARCHAR(MAX) = N'
        BULK INSERT #Personal_Staging
        FROM ''' + REPLACE(@archivo, N'''', N'''''') + N'''
        WITH (FORMAT = ''CSV'', FIRSTROW = 2, FIELDQUOTE = ''"'',
              CODEPAGE = ''RAW'', DATAFILETYPE = ''char'');';
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @error_lectura NVARCHAR(2048) = LEFT(
            N'No se pudo leer el CSV. Verifique ruta, permisos, UTF-8 y sus cuatro columnas. Detalle: ' + ERROR_MESSAGE(), 2048);
        THROW 51405, @error_lectura, 1;
    END CATCH;

    DECLARE @seleccion NVARCHAR(400), @nombre NVARCHAR(1000), @rol NVARCHAR(200),
            @fecha NVARCHAR(100), @id_seleccion INT, @id_personal INT,
            @coincidencias INT, @procesados INT = 0, @insertados INT = 0,
            @actualizados INT = 0, @errores INT = 0;

    DECLARE cur_personal CURSOR LOCAL FAST_FORWARD FOR
        SELECT seleccion, nombre_completo, rol, fecha_extraccion_utc
        FROM #Personal_Staging;
    OPEN cur_personal;
    FETCH NEXT FROM cur_personal INTO @seleccion, @nombre, @rol, @fecha;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @procesados += 1;
        BEGIN TRY
            SET @id_seleccion = NULL;
            SET @id_personal = NULL;
            SET @seleccion = LTRIM(RTRIM(@seleccion));
            SET @nombre = LTRIM(RTRIM(@nombre));
            SET @rol = LTRIM(RTRIM(@rol));
            SET @fecha = LTRIM(RTRIM(REPLACE(@fecha, NCHAR(13), N'')));

            IF NULLIF(@seleccion, N'') IS NULL
                THROW 51410, N'La selección es obligatoria.', 1;
            IF DATALENGTH(@seleccion) > 160
                THROW 51411, N'La selección supera la capacidad de NVARCHAR(80).', 1;
            IF NULLIF(@nombre, N'') IS NULL
                THROW 51412, N'El nombre completo es obligatorio.', 1;
            IF DATALENGTH(@nombre) > 240
                THROW 51413, N'El nombre completo supera la capacidad de NVARCHAR(120).', 1;
            IF @rol = N'Entrenador Interino' SET @rol = N'Entrenador';
            IF @rol IS NULL OR @rol NOT IN (N'Entrenador', N'Entrenador Asistente')
                THROW 51414, N'Rol inválido: se admite Entrenador o Entrenador Asistente.', 1;
            IF NULLIF(@fecha, N'') IS NULL OR TRY_CONVERT(DATETIMEOFFSET(0), @fecha, 127) IS NULL
                THROW 51415, N'La fecha de extracción debe ser una fecha ISO 8601 válida.', 1;

            SELECT @coincidencias = COUNT(*), @id_seleccion = MIN(id_seleccion)
            FROM dbo.Seleccion
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(@seleccion);
            IF @coincidencias = 0
                THROW 51416, N'La selección no existe. Cargue Seleccion antes de importar.', 1;
            IF @coincidencias > 1
                THROW 51417, N'Hay varias selecciones coincidentes; debe resolver la ambigüedad.', 1;

            SELECT @coincidencias = COUNT(*), @id_personal = MIN(id_personal)
            FROM dbo.Personal_Tecnico
            WHERE id_seleccion = @id_seleccion
              AND UPPER(LTRIM(RTRIM(nombre_completo))) = UPPER(@nombre);
            IF @coincidencias > 1
                THROW 51418, N'Hay personas duplicadas para esa selección y nombre completo.', 1;

            IF @id_personal IS NULL
            BEGIN
                EXEC abm.Personal_Tecnico_Alta
                    @nombre_completo = @nombre, @rol = @rol, @id_seleccion = @id_seleccion;
                SET @insertados += 1;
            END
            ELSE
            BEGIN
                EXEC abm.Personal_Tecnico_Modificar
                    @id_personal = @id_personal, @nombre_completo = @nombre,
                    @rol = @rol, @id_seleccion = @id_seleccion;
                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores VALUES
                (@procesados, @seleccion, @nombre, @rol, ERROR_NUMBER(), ERROR_MESSAGE());
            SET @errores += 1;
        END CATCH;
        FETCH NEXT FROM cur_personal INTO @seleccion, @nombre, @rol, @fecha;
    END;
    CLOSE cur_personal;
    DEALLOCATE cur_personal;

    SELECT @archivo AS archivo, @procesados AS registros_procesados,
           @insertados AS registros_insertados, @actualizados AS registros_actualizados,
           @errores AS registros_con_error;
    -- Número de procesamiento, no número físico de línea del CSV.
    SELECT registro_procesado, seleccion, nombre_completo, rol, numero_error, mensaje
    FROM #Errores ORDER BY registro_procesado;
END;
GO
