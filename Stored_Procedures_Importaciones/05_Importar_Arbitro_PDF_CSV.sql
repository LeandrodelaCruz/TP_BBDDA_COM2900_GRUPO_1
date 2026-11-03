/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-11-02

    Descripción:
    Importa árbitros desde el archivo generado por el extractor
    01_Extraer_Arbitros_FIFA_PDF.py a partir del PDF oficial de FIFA
    "MEDIA-FWC26-Arbitros.pdf".

    El proceso:
    - recibe la ruta del CSV como parámetro;
    - carga el archivo a una tabla temporal de staging;
    - transforma el puesto al dominio esperado por dbo.Arbitro;
    - normaliza país y fecha de nacimiento;
    - hace UPSERT reutilizando los ABM de la Entrega 5:
        - abm.Arbitro_Alta
        - abm.Arbitro_Modificar
    - continúa procesando si una fila falla;
    - informa resumen y detalle de errores.

    CSV esperado:
        nombre,apellido,fecha_nacimiento,pais,puesto,idiomas

    SQL dinámico:
    Se usa únicamente para parametrizar la ruta de BULK INSERT.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.Importar_Arbitro_PDF_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@archivo)), N'') IS NULL
        THROW 51400, N'Debe indicar la ruta del archivo CSV.', 1;

    IF OBJECT_ID(N'dbo.Arbitro', N'U') IS NULL
        THROW 51401, N'No existe dbo.Arbitro. Debe crear la tabla antes de ejecutar esta importación.', 1;

    IF OBJECT_ID(N'abm.Arbitro_Alta', N'P') IS NULL
       OR OBJECT_ID(N'abm.Arbitro_Modificar', N'P') IS NULL
        THROW 51402, N'No existen los ABM requeridos: abm.Arbitro_Alta / abm.Arbitro_Modificar.', 1;

    /* ----------------------------------------------------------------------
       1. Staging: recibe el CSV tal cual viene.
       Las columnas son amplias para detectar errores de longitud antes de
       invocar los ABM.
    ---------------------------------------------------------------------- */
    CREATE TABLE #Arbitro_Staging
    (
        nombre           NVARCHAR(150) NULL,
        apellido         NVARCHAR(150) NULL,
        fecha_nacimiento NVARCHAR(30)  NULL,
        pais             NVARCHAR(100) NULL,
        puesto           NVARCHAR(100) NULL,
        idiomas          NVARCHAR(200) NULL  -- Presente en el CSV; no se utiliza en la importacion.
    );

    CREATE TABLE #Errores
    (
        numero_fila      INT           NOT NULL,
        nombre           NVARCHAR(150) NULL,
        apellido         NVARCHAR(150) NULL,
        mensaje          NVARCHAR(2048) NOT NULL
    );

    /* ----------------------------------------------------------------------
       2. BULK INSERT con SQL dinámico únicamente para la ruta.
    ---------------------------------------------------------------------- */
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N'
        BULK INSERT #Arbitro_Staging
        FROM ''' + REPLACE(@archivo, '''', '''''') + N'''
        WITH
        (
            FIRSTROW = 2,
            FIELDTERMINATOR = '','',
            ROWTERMINATOR = ''\n'',
            CODEPAGE = ''65001'',
            DATAFILETYPE = ''char''
        );';

    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @mensaje_lectura NVARCHAR(2048) =
            N'No se pudo leer el archivo indicado. Detalle: ' + ERROR_MESSAGE();
        THROW 51403, @mensaje_lectura, 1;
    END CATCH;

    /* ----------------------------------------------------------------------
       3. Cursor de procesamiento fila por fila.
    ---------------------------------------------------------------------- */
    DECLARE
        @numero_fila      INT = 0,
        @nombre_raw       NVARCHAR(150),
        @apellido_raw     NVARCHAR(150),
        @fecha_raw        NVARCHAR(30),
        @pais_raw         NVARCHAR(100),
        @puesto_raw       NVARCHAR(100),
        @idiomas_raw      NVARCHAR(200),

        @nombre           NVARCHAR(60),
        @apellido         NVARCHAR(60),
        @fecha_nacimiento DATE,
        @pais             NVARCHAR(80),
        @puesto           VARCHAR(50),
        @idiomas          NVARCHAR(200),

        @id_arbitro       INT,
        @insertados       INT = 0,
        @actualizados     INT = 0,
        @errores          INT = 0;

    DECLARE cursor_arbitros CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            nombre,
            apellido,
            fecha_nacimiento,
            pais,
            puesto,
            idiomas
        FROM #Arbitro_Staging;

    OPEN cursor_arbitros;

    FETCH NEXT FROM cursor_arbitros INTO
        @nombre_raw, @apellido_raw, @fecha_raw, @pais_raw, @puesto_raw, @idiomas_raw;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @numero_fila += 1;

        BEGIN TRY
            SET @id_arbitro = NULL;
            SET @nombre = NULLIF(LTRIM(RTRIM(@nombre_raw)), N'');
            SET @apellido = NULLIF(LTRIM(RTRIM(@apellido_raw)), N'');
            SET @pais = LTRIM(RTRIM(@pais_raw));
            SET @puesto = LTRIM(RTRIM(@puesto_raw));
            SET @idiomas = NULLIF(LTRIM(RTRIM(@idiomas_raw)), N'');

            /* Transformación del puesto al dominio del modelo. */
            SET @puesto = CASE UPPER(@puesto)
                WHEN N'PRINCIPAL'     THEN N'Principal'
                WHEN N'ASISTENTE'     THEN N'Asistente'
                WHEN N'VAR'           THEN N'VAR'
                WHEN N'ARBITRO'       THEN N'Principal'
                WHEN N'ARBITRO ASISTENTE' THEN N'Asistente'
                WHEN N'ARBITRO VIDEO'     THEN N'VAR'
                ELSE @puesto
            END;

            /*
               Fecha de nacimiento: se acepta ISO (YYYY-MM-DD) y DD/MM/YYYY.
               El PDF oficial no incluye esta información, por lo que el campo
               puede venir vacío y se almacena como NULL. dbo.Arbitro permite
               NULL en fecha_nacimiento.
            */
            SET @fecha_nacimiento = TRY_CONVERT(DATE, NULLIF(LTRIM(RTRIM(@fecha_raw)), N''), 23);
            IF @fecha_nacimiento IS NULL AND NULLIF(LTRIM(RTRIM(@fecha_raw)), N'') IS NOT NULL
                SET @fecha_nacimiento = TRY_CONVERT(DATE, @fecha_raw, 103);

            /*
               Validaciones de formato previas al ABM.
               Convención acordada:
                 - Apellido: obligatorio.
                 - Nombre: opcional. Si viene vacío se importa como NULL/empty
                   (los árbitros del PDF a veces solo traen apellido).
                 - Fecha de nacimiento: opcional.
            */
            IF NULLIF(@apellido, N'') IS NULL
                THROW 51410, N'El apellido del árbitro está vacío.', 1;

            IF LEN(@apellido) > 60
                THROW 51411, N'El apellido supera los 60 caracteres permitidos.', 1;

            IF LEN(@nombre) > 60
                THROW 51413, N'El nombre supera los 60 caracteres permitidos.', 1;

            IF NULLIF(@pais, N'') IS NULL
                THROW 51415, N'El país del árbitro está vacío.', 1;

            IF LEN(@pais) > 80
                THROW 51416, N'El país supera los 80 caracteres permitidos.', 1;

            IF NULLIF(@puesto, N'') IS NULL
                THROW 51417, N'El puesto del árbitro está vacío.', 1;

            IF LEN(@puesto) > 50
                THROW 51418, N'El puesto supera los 50 caracteres permitidos.', 1;

            /*
               Clave natural elegida para el UPSERT:
               apellido + nombre + país.
               No se incluye fecha_nacimiento porque el PDF oficial no la
               proporciona y puede ser NULL. Incluirla provocaría duplicados
               cada vez que se complete con una fecha distinta.
            */
            SELECT TOP (1)
                @id_arbitro = id_arbitro
            FROM dbo.Arbitro
            WHERE UPPER(LTRIM(RTRIM(apellido))) = UPPER(@apellido)
              AND UPPER(LTRIM(RTRIM(pais))) = UPPER(@pais)
              AND (
                    NULLIF(LTRIM(RTRIM(nombre)), N'') IS NULL AND NULLIF(@nombre, N'') IS NULL
                    OR UPPER(LTRIM(RTRIM(nombre))) = UPPER(@nombre)
                  );

            IF @id_arbitro IS NULL
            BEGIN
                EXEC abm.Arbitro_Alta
                    @nombre = @nombre,
                    @apellido = @apellido,
                    @fecha_nacimiento = @fecha_nacimiento,
                    @pais = @pais,
                    @puesto = @puesto,
                    @idiomas = @idiomas;

                SET @insertados += 1;
            END
            ELSE
            BEGIN
                EXEC abm.Arbitro_Modificar
                    @id_arbitro = @id_arbitro,
                    @nombre = @nombre,
                    @apellido = @apellido,
                    @fecha_nacimiento = @fecha_nacimiento,
                    @pais = @pais,
                    @puesto = @puesto,
                    @idiomas = @idiomas;

                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores
            (
                numero_fila,
                nombre,
                apellido,
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @nombre_raw,
                @apellido_raw,
                ERROR_MESSAGE()
            );

            SET @errores += 1;
        END CATCH;

        FETCH NEXT FROM cursor_arbitros INTO
            @nombre_raw, @apellido_raw, @fecha_raw, @pais_raw, @puesto_raw, @idiomas_raw;
    END;

    CLOSE cursor_arbitros;
    DEALLOCATE cursor_arbitros;

    /* ----------------------------------------------------------------------
       4. Resumen y detalle de errores.
    ---------------------------------------------------------------------- */
    SELECT
        @archivo          AS archivo,
        COUNT(*)          AS registros_procesados,
        @insertados       AS registros_insertados,
        @actualizados     AS registros_actualizados,
        @errores          AS registros_con_error
    FROM #Arbitro_Staging;

    SELECT
        numero_fila,
        nombre,
        apellido,
        mensaje
    FROM #Errores
    ORDER BY numero_fila;
END;
GO
