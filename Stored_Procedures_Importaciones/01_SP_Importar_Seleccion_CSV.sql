/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 6
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 26/10/2026

    Descripción:
    Importa selecciones desde el archivo teams.csv.
    El archivo se carga primero en una tabla temporal de staging.
    Luego se aplica lógica de UPSERT reutilizando los SP de la Entrega 5:
        - abm.Seleccion_Alta
        - abm.Seleccion_Modificar

    Una fila inválida no cancela el procesamiento de las demás.
    El nombre/ruta del archivo se recibe mediante el parámetro @archivo.

    Nota sobre SQL dinámico:
    Se utiliza únicamente para BULK INSERT porque SQL Server no permite
    parametrizar directamente la ruta del archivo en esa sentencia.
    El resto de la lógica es T-SQL estático.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE importacion.SP_Importar_Seleccion_CSV
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Validar el parametro de entrada.

    IF @archivo IS NULL OR LTRIM(RTRIM(@archivo)) = N''
        THROW 51001, N'Debe indicar la ruta del archivo CSV a importar.', 1; -- Aca verificamos que sea valido el archivo de entrada

    -------------------------------------------------------------------------
    -- 2. Staging: recibe el archivo tal como viene.
    --    Se usan tam amplios para poder detectar errores de longitud
    --    antes de invocar los ABM de la Entrega 5.

    CREATE TABLE #Seleccion_Staging -- Esta tabla temporal absorbe toda la informacion
    (
        team_id                      NVARCHAR(50)  NULL,
        team_name                    NVARCHAR(200) NULL,
        fifa_code                    NVARCHAR(50)  NULL,
        group_letter                 NVARCHAR(50)  NULL,
        confederation                NVARCHAR(100) NULL,
        fifa_ranking_pre_tournament  NVARCHAR(50)  NULL,
        elo_rating                   NVARCHAR(50)  NULL,
        manager_name                 NVARCHAR(200) NULL
    );

    -- 3. Tabla temporal para informar errores sin detener toda la carga.

    CREATE TABLE #Errores_Importacion --Esta tabla funciona como una bitacora. Si alguna fila puntutal tiene problemas, se almacena aca
    (                                                               -- y no interrumpe la carga.
        team_id       NVARCHAR(50)   NULL,
        team_name     NVARCHAR(200)  NULL,
        numero_error  INT            NOT NULL,
        mensaje_error NVARCHAR(2048) NOT NULL
    );


    -- 4. Cargar el CSV.
    --
    --    BULK INSERT exige que la ruta sea un literal dentro de la sentencia.
    --    Por eso este bloque puntual requiere SQL dinámico para poder cumplir
    --    con la consigna de recibir el archivo como parámetro.
 -- El BULK INSERT es mucho mas rapido que un INSERT normal
    DECLARE @sql NVARCHAR(MAX);

    SET @sql = N' 
        BULK INSERT #Seleccion_Staging 
        FROM ''' + REPLACE(@archivo, N'''', N'''''') + N'''
        WITH
        (
            FORMAT = ''CSV'',
            FIRSTROW = 2, 
            FIELDQUOTE = ''"'',
            TABLOCK
        );';

    BEGIN TRY
        EXEC sys.sp_executesql @sql;
    END TRY
    BEGIN CATCH
        DECLARE @mensajeCarga NVARCHAR(2048) =
            N'No se pudo leer el archivo indicado. Detalle: ' + ERROR_MESSAGE();

        THROW 51002, @mensajeCarga, 1;
    END CATCH;

    -- 5. Variables de procesamiento y contadores.

    DECLARE
        @team_id          NVARCHAR(50),
        @pais             NVARCHAR(200),
        @confederacion    NVARCHAR(100),
        @grupo_asignado   NVARCHAR(50),
        @id_seleccion     INT,
        @procesados       INT = 0,
        @insertados       INT = 0,
        @actualizados     INT = 0,
        @cantidad_errores INT = 0;


    -- Estas tablas variables capturan los SELECT que devuelven los ABM.

    DECLARE @ResultadoAlta TABLE
    (
        id_seleccion_creada INT
    );

    DECLARE @ResultadoModificacion TABLE
    (
        id_seleccion   INT,
        pais           NVARCHAR(80),
        confederacion  NVARCHAR(50),
        grupo_asignado VARCHAR(5)
    );

    -- 6. Se procesa fila por fila porque la consigna exige reutilizar los
    --    Stored Procedures ABM de la Entrega 5 para cada registro.

    DECLARE cur_selecciones CURSOR LOCAL FAST_FORWARD FOR
        SELECT
            team_id,
            team_name,
            confederation,
            group_letter
        FROM #Seleccion_Staging;

    OPEN cur_selecciones;

    FETCH NEXT FROM cur_selecciones
    INTO @team_id, @pais, @confederacion, @grupo_asignado;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @procesados += 1;

        BEGIN TRY

            -- 6.1 Validaciones previas necesarias para evitar que SQL Server
            --     trunque parámetros antes de llegar al ABM.
            --     Las reglas de negocio siguen siendo responsabilidad del ABM.

            IF @pais IS NULL OR LTRIM(RTRIM(@pais)) = N''
                THROW 51101, N'El país de la selección está vacío.', 1;

            IF LEN(@pais) > 80
                THROW 51102, N'El país supera los 80 caracteres permitidos.', 1;

            IF @confederacion IS NULL OR LTRIM(RTRIM(@confederacion)) = N''
                THROW 51103, N'La confederación está vacía.', 1;

            IF LEN(@confederacion) > 50
                THROW 51104, N'La confederación supera los 50 caracteres permitidos.', 1;

            IF @grupo_asignado IS NULL OR LTRIM(RTRIM(@grupo_asignado)) = N''
                THROW 51105, N'El grupo asignado está vacío.', 1;

            IF LEN(@grupo_asignado) > 5
                THROW 51106, N'El grupo asignado supera los 5 caracteres permitidos.', 1;


            -- 6.2 Buscar por la clave natural elegida para el UPSERT: país.

            SET @id_seleccion = NULL;

            SELECT @id_seleccion = id_seleccion
            FROM dbo.Seleccion
            WHERE UPPER(LTRIM(RTRIM(pais))) = UPPER(LTRIM(RTRIM(@pais)));

            -- 6.3 UPSERT reutilizando exclusivamente los ABM de Entrega 5.
            IF @id_seleccion IS NULL -- Si no encontro el pais, va insertando
            BEGIN
                DELETE FROM @ResultadoAlta;

                INSERT INTO @ResultadoAlta (id_seleccion_creada)
                EXEC abm.Seleccion_Alta
                    @pais = @pais,
                    @confederacion = @confederacion,
                    @grupo_asignado = @grupo_asignado;

                SET @insertados += 1;
            END
            ELSE
            BEGIN
                DELETE FROM @ResultadoModificacion;

                INSERT INTO @ResultadoModificacion
                (
                    id_seleccion,
                    pais,
                    confederacion,
                    grupo_asignado
                )
                EXEC abm.Seleccion_Modificar
                    @id_seleccion = @id_seleccion,
                    @pais = @pais,
                    @confederacion = @confederacion,
                    @grupo_asignado = @grupo_asignado;

                SET @actualizados += 1;
            END;
        END TRY
        BEGIN CATCH
            INSERT INTO #Errores_Importacion
            (
                team_id,
                team_name,
                numero_error,
                mensaje_error
            )
            VALUES
            (
                @team_id,
                @pais,
                ERROR_NUMBER(),
                ERROR_MESSAGE()
            );

            SET @cantidad_errores += 1;
        END CATCH;

        FETCH NEXT FROM cur_selecciones
        INTO @team_id, @pais, @confederacion, @grupo_asignado;
    END;

    CLOSE cur_selecciones;
    DEALLOCATE cur_selecciones;

    -- 7. Resumen final de la importación.
    SELECT
        @archivo          AS archivo,
        @procesados       AS registros_procesados,
        @insertados       AS registros_insertados,
        @actualizados     AS registros_actualizados,
        @cantidad_errores AS registros_con_error;

    -- 8. Detalle de errores. Si no hubo errores, devuelve cero filas.
    SELECT
        team_id,
        team_name,
        numero_error,
        mensaje_error
    FROM #Errores_Importacion
    ORDER BY team_id;
END;
GO
