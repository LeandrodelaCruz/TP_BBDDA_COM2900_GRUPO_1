/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6 - Procesos de Importación
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-11-02

    Descripción:
    Variante set-based (sin cursores) de la importación de árbitros desde el
    CSV generado por 01_Extraer_Arbitros_FIFA_PDF.py.

    El proceso:
    - recibe la ruta del CSV como parámetro;
    - carga el archivo a una tabla temporal de staging;
    - transforma y valida todo el conjunto mediante operaciones SET;
    - hace UPSERT en dbo.Arbitro directamente (INSERT + UPDATE).

    Ventajas respecto a la versión con cursor:
    - mayor rendimiento;
    - menos locking;
    - todo el procesamiento queda dentro del motor relacional.

    CSV esperado:
        nombre,apellido,fecha_nacimiento,pais,puesto

    SQL dinámico:
    Se usa únicamente para parametrizar la ruta de BULK INSERT.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.SP_Importar_Arbitro_PDF_CSV_SetBased
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@archivo)), N'') IS NULL
        THROW 51400, N'Debe indicar la ruta del archivo CSV.', 1;

    IF OBJECT_ID(N'dbo.Arbitro', N'U') IS NULL
        THROW 51401, N'No existe dbo.Arbitro. Debe crear la tabla antes de ejecutar esta importación.', 1;

    /* ----------------------------------------------------------------------
       1. Staging: recibe el CSV tal cual viene.
    ---------------------------------------------------------------------- */
    CREATE TABLE #Arbitro_Staging
    (
        numero_fila      INT IDENTITY(1,1) NOT NULL,
        nombre           NVARCHAR(150) NULL,
        apellido         NVARCHAR(150) NULL,
        fecha_nacimiento NVARCHAR(30)  NULL,
        pais             NVARCHAR(100) NULL,
        puesto           NVARCHAR(100) NULL,
        idiomas          NVARCHAR(200) NULL
    );

    CREATE TABLE #Errores
    (
        numero_fila      INT            NOT NULL,
        nombre           NVARCHAR(150)  NULL,
        apellido         NVARCHAR(150)  NULL,
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
            FORMAT = ''CSV'',
            FIRSTROW = 2,
            FIELDQUOTE = ''"''
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
       3. Validaciones de formato previas al upsert.
       Se cargan los errores en #Errores; las filas sin error pasan limpias.
    ---------------------------------------------------------------------- */
    INSERT INTO #Errores (numero_fila, nombre, apellido, mensaje)
    SELECT
        s.numero_fila,
        s.nombre,
        s.apellido,
        CASE
            WHEN NULLIF(LTRIM(RTRIM(s.apellido)), N'') IS NULL
                THEN N'El apellido del árbitro está vacío.'
            WHEN LEN(LTRIM(RTRIM(s.apellido))) > 60
                THEN N'El apellido supera los 60 caracteres permitidos.'
            WHEN NULLIF(LTRIM(RTRIM(s.nombre)), N'') IS NOT NULL
                 AND LEN(LTRIM(RTRIM(s.nombre))) > 60
                THEN N'El nombre supera los 60 caracteres permitidos.'
            WHEN NULLIF(LTRIM(RTRIM(s.pais)), N'') IS NULL
                THEN N'El país del árbitro está vacío.'
            WHEN LEN(LTRIM(RTRIM(s.pais))) > 80
                THEN N'El país supera los 80 caracteres permitidos.'
            WHEN NULLIF(LTRIM(RTRIM(s.puesto)), N'') IS NULL
                THEN N'El puesto del árbitro está vacío.'
            WHEN LEN(LTRIM(RTRIM(s.puesto))) > 50
                THEN N'El puesto supera los 50 caracteres permitidos.'
            WHEN NULLIF(LTRIM(RTRIM(s.fecha_nacimiento)), N'') IS NOT NULL
                 AND TRY_CONVERT(DATE, s.fecha_nacimiento, 23) IS NULL
                 AND TRY_CONVERT(DATE, s.fecha_nacimiento, 103) IS NULL
                THEN N'La fecha de nacimiento no tiene un formato válido.'
            WHEN NULLIF(LTRIM(RTRIM(s.idiomas)), N'') IS NOT NULL
                 AND LEN(LTRIM(RTRIM(s.idiomas))) > 200
                THEN N'Los idiomas superan los 200 caracteres permitidos.'
        END
    FROM #Arbitro_Staging s
    WHERE
        NULLIF(LTRIM(RTRIM(s.apellido)), N'') IS NULL
        OR LEN(LTRIM(RTRIM(s.apellido))) > 60
        OR (NULLIF(LTRIM(RTRIM(s.nombre)), N'') IS NOT NULL AND LEN(LTRIM(RTRIM(s.nombre))) > 60)
        OR NULLIF(LTRIM(RTRIM(s.pais)), N'') IS NULL
        OR LEN(LTRIM(RTRIM(s.pais))) > 80
        OR NULLIF(LTRIM(RTRIM(s.puesto)), N'') IS NULL
        OR LEN(LTRIM(RTRIM(s.puesto))) > 50
        OR (NULLIF(LTRIM(RTRIM(s.fecha_nacimiento)), N'') IS NOT NULL
            AND TRY_CONVERT(DATE, s.fecha_nacimiento, 23) IS NULL
            AND TRY_CONVERT(DATE, s.fecha_nacimiento, 103) IS NULL)
        OR (NULLIF(LTRIM(RTRIM(s.idiomas)), N'') IS NOT NULL
            AND LEN(LTRIM(RTRIM(s.idiomas))) > 200);

    /* ----------------------------------------------------------------------
       4. CTE con datos limpios y normalizados, excluyendo las filas erróneas.
    ---------------------------------------------------------------------- */
    WITH StagingLimpio AS
    (
        SELECT
            s.numero_fila,
            nombre          = LTRIM(RTRIM(s.nombre)),
            apellido        = LTRIM(RTRIM(s.apellido)),
            fecha_nacimiento = CASE
                WHEN NULLIF(LTRIM(RTRIM(s.fecha_nacimiento)), N'') IS NULL THEN NULL
                ELSE COALESCE(
                    TRY_CONVERT(DATE, s.fecha_nacimiento, 23),
                    TRY_CONVERT(DATE, s.fecha_nacimiento, 103)
                )
            END,
            pais            = LTRIM(RTRIM(s.pais)),
            puesto_normalizado = CASE UPPER(LTRIM(RTRIM(s.puesto)))
                WHEN N'PRINCIPAL'          THEN N'Principal'
                WHEN N'ASISTENTE'          THEN N'Asistente'
                WHEN N'VAR'                THEN N'VAR'
                WHEN N'ARBITRO'            THEN N'Principal'
                WHEN N'ARBITRO ASISTENTE'  THEN N'Asistente'
                WHEN N'ARBITRO VIDEO'      THEN N'VAR'
                ELSE LTRIM(RTRIM(s.puesto))
            END
        FROM #Arbitro_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM #Errores e WHERE e.numero_fila = s.numero_fila
        )
    ),
    /* ----------------------------------------------------------------------
       5. Emparejamiento por clave natural: apellido + país + nombre.
          Se permite nombre vacío/NULL.
    ---------------------------------------------------------------------- */
    ConIdArbitro AS
    (
        SELECT
            sl.*,
            a.id_arbitro
        FROM StagingLimpio sl
        LEFT JOIN dbo.Arbitro a
            ON UPPER(LTRIM(RTRIM(a.apellido))) = UPPER(sl.apellido)
            AND UPPER(LTRIM(RTRIM(a.pais))) = UPPER(sl.pais)
            AND (
                (NULLIF(LTRIM(RTRIM(a.nombre)), N'') IS NULL AND NULLIF(sl.nombre, N'') IS NULL)
                OR UPPER(LTRIM(RTRIM(a.nombre))) = UPPER(sl.nombre)
            )
    )
    /* ----------------------------------------------------------------------
       6. UPDATE de los registros existentes.
    ---------------------------------------------------------------------- */
    UPDATE a
    SET
        a.nombre           = NULLIF(LTRIM(RTRIM(sl.nombre)), N''),
        a.apellido         = LTRIM(RTRIM(sl.apellido)),
        a.fecha_nacimiento = sl.fecha_nacimiento,
        a.pais             = LTRIM(RTRIM(sl.pais)),
        a.puesto           = sl.puesto_normalizado,
        a.idiomas          = NULLIF(LTRIM(RTRIM(sl.idiomas)), N'')
    FROM dbo.Arbitro a
    INNER JOIN ConIdArbitro sl
        ON a.id_arbitro = sl.id_arbitro;

    DECLARE @actualizados INT = @@ROWCOUNT;

    /* ----------------------------------------------------------------------
       7. INSERT de los registros nuevos.
    ---------------------------------------------------------------------- */
    WITH StagingLimpio AS
    (
        SELECT
            s.numero_fila,
            nombre          = LTRIM(RTRIM(s.nombre)),
            apellido        = LTRIM(RTRIM(s.apellido)),
            fecha_nacimiento = CASE
                WHEN NULLIF(LTRIM(RTRIM(s.fecha_nacimiento)), N'') IS NULL THEN NULL
                ELSE COALESCE(
                    TRY_CONVERT(DATE, s.fecha_nacimiento, 23),
                    TRY_CONVERT(DATE, s.fecha_nacimiento, 103)
                )
            END,
            pais            = LTRIM(RTRIM(s.pais)),
            puesto_normalizado = CASE UPPER(LTRIM(RTRIM(s.puesto)))
                WHEN N'PRINCIPAL'          THEN N'Principal'
                WHEN N'ASISTENTE'          THEN N'Asistente'
                WHEN N'VAR'                THEN N'VAR'
                WHEN N'ARBITRO'            THEN N'Principal'
                WHEN N'ARBITRO ASISTENTE'  THEN N'Asistente'
                WHEN N'ARBITRO VIDEO'      THEN N'VAR'
                ELSE LTRIM(RTRIM(s.puesto))
            END
        FROM #Arbitro_Staging s
        WHERE NOT EXISTS (
            SELECT 1 FROM #Errores e WHERE e.numero_fila = s.numero_fila
        )
    ),
    ConIdArbitro AS
    (
        SELECT
            sl.*,
            a.id_arbitro
        FROM StagingLimpio sl
        LEFT JOIN dbo.Arbitro a
            ON UPPER(LTRIM(RTRIM(a.apellido))) = UPPER(sl.apellido)
            AND UPPER(LTRIM(RTRIM(a.pais))) = UPPER(sl.pais)
            AND (
                (NULLIF(LTRIM(RTRIM(a.nombre)), N'') IS NULL AND NULLIF(sl.nombre, N'') IS NULL)
                OR UPPER(LTRIM(RTRIM(a.nombre))) = UPPER(sl.nombre)
            )
    )
    INSERT INTO dbo.Arbitro (nombre, apellido, fecha_nacimiento, pais, puesto, idiomas)
    SELECT
        NULLIF(LTRIM(RTRIM(sl.nombre)), N''),
        LTRIM(RTRIM(sl.apellido)),
        sl.fecha_nacimiento,
        LTRIM(RTRIM(sl.pais)),
        sl.puesto_normalizado,
        NULLIF(LTRIM(RTRIM(sl.idiomas)), N'')
    FROM ConIdArbitro sl
    WHERE sl.id_arbitro IS NULL;

    DECLARE @insertados INT = @@ROWCOUNT;
    DECLARE @errores INT = (SELECT COUNT(*) FROM #Errores);

    /* ----------------------------------------------------------------------
       8. Limpieza de posibles duplicados dejados por concurrencia o reruns.
          Se conserva el registro con id_arbitro más bajo.
    ---------------------------------------------------------------------- */
    WITH Duplicados AS (
        SELECT
            id_arbitro,
            ROW_NUMBER() OVER (
                PARTITION BY UPPER(LTRIM(RTRIM(apellido))),
                             UPPER(LTRIM(RTRIM(pais))),
                             UPPER(LTRIM(RTRIM(ISNULL(nombre, N''))))
                ORDER BY id_arbitro
            ) AS rn
        FROM dbo.Arbitro
    )
    DELETE FROM Duplicados WHERE rn > 1;

    /* ----------------------------------------------------------------------
       9. Resumen y detalle de errores.
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
