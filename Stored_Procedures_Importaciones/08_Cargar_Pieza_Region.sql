USE MUNDIALDEFUTBOL;
GO

/*============================================================
    Universidad: Universidad Nacional de La Matanza
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        carga.Cargar_Pieza_Para_Region

    Objetivo:
        Asociar las piezas publicitarias cargadas previamente
        con las regiones/mercados donde pueden utilizarse.

    Dependencias:
        - dbo.Anunciante
        - dbo.Campania
        - dbo.Pieza_Publicitaria
        - dbo.Region

    La relación es una configuración interna del sistema.
============================================================*/


IF SCHEMA_ID(N'carga') IS NULL
    THROW 51910, N'Falta el esquema carga. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
GO


CREATE OR ALTER PROCEDURE carga.Cargar_Pieza_Para_Region
AS
BEGIN

    SET NOCOUNT ON;


    --------------------------------------------------------
    -- 1. RELACIONES A CONFIGURAR
    --------------------------------------------------------

    DECLARE @Relaciones TABLE
    (
        numero_fila INT IDENTITY(1,1),
        anunciante  NVARCHAR(120),
        campania    NVARCHAR(500),
        region      NVARCHAR(80)
    );


    INSERT INTO @Relaciones
    (
        anunciante,
        campania,
        region
    )
    VALUES
        (
            N'Adidas',
            N'Seguí soñando',
            N'Argentina'
        ),

        (
            N'Guaraná Antarctica',
            N'A torcida tá convocada',
            N'Brasil'
        ),

        (
            N'KFC',
            N'KFC France x FFF',
            N'Francia'
        ),

        (
            N'Home Depot',
            N'Build it Like Beckham',
            N'Estados Unidos'
        ),

        (
            N'Magenta TV',
            N'Thomas Müller',
            N'Alemania'
        ),

        (
            N'McDonald’s',
            N'Estas leyendas están listas para el Menú la Copa Mundial de la FIFA 2026 de McDonald’s el 9 de junio',
            N'España'
        ),

        (
            N'AB InBev',
            N'Cheers to Bars',
            N'Reino Unido'
        ),

        (
            N'Bimbo',
            N'Venimos con hambre de ganar',
            N'México'
        );


    --------------------------------------------------------
    -- 2. ERRORES
    --------------------------------------------------------

    DECLARE @TablaErrores TABLE
    (
        numero_fila INT,
        anunciante  NVARCHAR(120),
        campania    NVARCHAR(500),
        region      NVARCHAR(80),
        mensaje     NVARCHAR(2048)
    );


    --------------------------------------------------------
    -- 3. CONTADORES
    --------------------------------------------------------

    DECLARE
        @procesados INT = 0,
        @insertados INT = 0,
        @existentes INT = 0,
        @errores INT = 0;


    --------------------------------------------------------
    -- 4. VARIABLES
    --------------------------------------------------------

    DECLARE
        @numero_fila INT,
        @anunciante NVARCHAR(120),
        @campania NVARCHAR(500),
        @region NVARCHAR(80),

        @id_anunciante INT,
        @id_campania INT,
        @id_pieza INT,
        @id_region INT;


    --------------------------------------------------------
    -- 5. CURSOR
    --------------------------------------------------------

    DECLARE cursor_relaciones CURSOR LOCAL FAST_FORWARD
    FOR
        SELECT
            numero_fila,
            anunciante,
            campania,
            region
        FROM @Relaciones
        ORDER BY numero_fila;


    OPEN cursor_relaciones;


    FETCH NEXT FROM cursor_relaciones
    INTO
        @numero_fila,
        @anunciante,
        @campania,
        @region;


    WHILE @@FETCH_STATUS = 0
    BEGIN

        SET @procesados += 1;

        SET @id_anunciante = NULL;
        SET @id_campania = NULL;
        SET @id_pieza = NULL;
        SET @id_region = NULL;


        BEGIN TRY

            ------------------------------------------------
            -- 6. BUSCAR ANUNCIANTE
            ------------------------------------------------

            SELECT
                @id_anunciante = id_anunciante
            FROM dbo.Anunciante
            WHERE
                UPPER(LTRIM(RTRIM(nombre)))
                =
                UPPER(LTRIM(RTRIM(@anunciante)));


            IF @id_anunciante IS NULL
            BEGIN
                THROW 51401,
                      'No existe el anunciante indicado.',
                      1;
            END;


            ------------------------------------------------
            -- 7. BUSCAR CAMPAÑA
            ------------------------------------------------

            SELECT
                @id_campania = id_campania
            FROM dbo.Campania
            WHERE
                id_anunciante = @id_anunciante
                AND UPPER(LTRIM(RTRIM(descripcion)))
                    =
                    UPPER(LTRIM(RTRIM(@campania)));


            IF @id_campania IS NULL
            BEGIN
                THROW 51402,
                      'No existe la campaña indicada para el anunciante.',
                      1;
            END;


            ------------------------------------------------
            -- 8. BUSCAR PIEZA
            --
            -- Nuestro juego inicial tiene una pieza
            -- publicitaria por campaña.
            ------------------------------------------------

            SELECT
                @id_pieza = id_pieza
            FROM dbo.Pieza_Publicitaria
            WHERE id_campania = @id_campania;


            IF @id_pieza IS NULL
            BEGIN
                THROW 51403,
                      'La campaña indicada no posee una pieza publicitaria.',
                      1;
            END;


            ------------------------------------------------
            -- Seguridad:
            -- si por error hubiera más de una pieza
            -- para la campaña, no elegimos arbitrariamente.
            ------------------------------------------------

            IF
            (
                SELECT COUNT(*)
                FROM dbo.Pieza_Publicitaria
                WHERE id_campania = @id_campania
            ) <> 1
            BEGIN
                THROW 51404,
                      'La campaña posee una cantidad de piezas distinta de uno.',
                      1;
            END;


            ------------------------------------------------
            -- 9. BUSCAR REGION
            ------------------------------------------------

            SELECT
                @id_region = id_region
            FROM dbo.Region
            WHERE
                UPPER(LTRIM(RTRIM(nombre)))
                =
                UPPER(LTRIM(RTRIM(@region)));


            IF @id_region IS NULL
            BEGIN
                THROW 51405,
                      'No existe la región indicada.',
                      1;
            END;


            ------------------------------------------------
            -- 10. UPSERT DE LA RELACION
            --
            -- Como la tabla solo posee las dos FK,
            -- si la relación ya existe no hay atributos
            -- adicionales para actualizar.
            ------------------------------------------------

            IF NOT EXISTS
            (
                SELECT 1
                FROM dbo.Pieza_Para_Region
                WHERE id_pieza = @id_pieza
                  AND id_region = @id_region
            )
            BEGIN

                EXEC abm.Pieza_Para_Region_Alta
                    @id_pieza = @id_pieza,
                    @id_region = @id_region;


                SET @insertados += 1;

            END
            ELSE
            BEGIN

                SET @existentes += 1;

            END;

        END TRY

        BEGIN CATCH

            SET @errores += 1;


            INSERT INTO @TablaErrores
            (
                numero_fila,
                anunciante,
                campania,
                region,
                mensaje
            )
            VALUES
            (
                @numero_fila,
                @anunciante,
                @campania,
                @region,
                ERROR_MESSAGE()
            );

        END CATCH;


        FETCH NEXT FROM cursor_relaciones
        INTO
            @numero_fila,
            @anunciante,
            @campania,
            @region;

    END;


    CLOSE cursor_relaciones;
    DEALLOCATE cursor_relaciones;


    --------------------------------------------------------
    -- 11. RESUMEN
    --------------------------------------------------------

    SELECT
        @procesados AS procesados,
        @insertados AS insertados,
        @existentes AS existentes,
        @errores AS errores;


    --------------------------------------------------------
    -- 12. ERRORES
    --------------------------------------------------------

    SELECT
        numero_fila,
        anunciante,
        campania,
        region,
        mensaje
    FROM @TablaErrores
    ORDER BY numero_fila;

END;
GO