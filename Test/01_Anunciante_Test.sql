/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Casos de prueba de dbo.Anunciante. Deja un registro TEST_ para inspección; 99_Limpiar_Tests.sql lo elimina.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Anunciante_Test
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== TEST ANUNCIANTE =====';

    ---------------------------------------------------------
    -- LIMPIEZA PREVENTIVA
    ---------------------------------------------------------

    DECLARE @id_prev INT;

    SELECT TOP 1
        @id_prev = id_anunciante
    FROM dbo.Anunciante
    WHERE nombre IN
    (
        N'TEST_ANUNCIANTE_PRINCIPAL',
        N'TEST_ANUNCIANTE_MODIFICADO',
        N'TEST_ANUNCIANTE_BAJA'
    )
    ORDER BY id_anunciante;


    WHILE @id_prev IS NOT NULL
    BEGIN

        EXEC abm.Anunciante_Baja
            @id_anunciante = @id_prev;


        SET @id_prev = NULL;


        SELECT TOP 1
            @id_prev = id_anunciante
        FROM dbo.Anunciante
        WHERE nombre IN
        (
            N'TEST_ANUNCIANTE_PRINCIPAL',
            N'TEST_ANUNCIANTE_MODIFICADO',
            N'TEST_ANUNCIANTE_BAJA'
        )
        ORDER BY id_anunciante;

    END;


    ---------------------------------------------------------
    -- 1. ALTA EXITOSA
    ---------------------------------------------------------

    PRINT '1) Alta exitosa';


    DECLARE @id INT;


    EXEC abm.Anunciante_Alta
        @nombre = N'TEST_ANUNCIANTE_PRINCIPAL',
        @pais = N'Argentina',
        @id_anunciante = @id OUTPUT;


    IF @id IS NULL
        THROW 53001,
              'TEST FALLIDO: el alta no devolvio id_anunciante.',
              1;


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Anunciante
        WHERE id_anunciante = @id
          AND nombre = N'TEST_ANUNCIANTE_PRINCIPAL'
          AND pais = N'Argentina'
    )
        THROW 53002,
              'TEST FALLIDO: el anunciante no fue creado correctamente.',
              1;


    PRINT 'OK - Alta correcta';

    ---------------------------------------------------------
    -- 2. CONSULTA POR ID
    ---------------------------------------------------------

    PRINT '2) Consulta por ID';


    EXEC abm.Anunciante_ConsultarPorId
        @id_anunciante = @id;


    PRINT 'OK - Consulta correcta';

    ---------------------------------------------------------
    -- 3. MODIFICACION EXITOSA
    ---------------------------------------------------------

    PRINT '3) Modificacion exitosa';


    EXEC abm.Anunciante_Modificar
        @id_anunciante = @id,
        @nombre = N'TEST_ANUNCIANTE_MODIFICADO',
        @pais = N'Uruguay';


    IF NOT EXISTS
    (
        SELECT 1
        FROM dbo.Anunciante
        WHERE id_anunciante = @id
          AND nombre = N'TEST_ANUNCIANTE_MODIFICADO'
          AND pais = N'Uruguay'
    )
        THROW 53003,
              'TEST FALLIDO: la modificacion no se realizo correctamente.',
              1;


    PRINT 'OK - Modificacion correcta';

    ---------------------------------------------------------
    -- 4. LISTADO
    ---------------------------------------------------------

    PRINT '4) Listado';


    EXEC abm.Anunciante_Listar;


    PRINT 'OK - Listado ejecutado';

    ---------------------------------------------------------
    -- 5. BAJA EXITOSA
    ---------------------------------------------------------

    PRINT '5) Baja exitosa';


    DECLARE @id_baja INT;


    EXEC abm.Anunciante_Alta
        @nombre = N'TEST_ANUNCIANTE_BAJA',
        @pais = N'Brasil',
        @id_anunciante = @id_baja OUTPUT;


    EXEC abm.Anunciante_Baja
        @id_anunciante = @id_baja;


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Anunciante
        WHERE id_anunciante = @id_baja
    )
        THROW 53004,
              'TEST FALLIDO: el anunciante no fue eliminado.',
              1;


    PRINT 'OK - Baja correcta';

    --------------------------------------------------------
    -- 6. VALIDACION: NOMBRE VACIO
    ---------------------------------------------------------

    PRINT '6) Validacion nombre vacio';


    BEGIN TRY

        DECLARE @id_error_nombre INT;

        EXEC abm.Anunciante_Alta
            @nombre = N'',
            @pais = N'Argentina',
            @id_anunciante = @id_error_nombre OUTPUT;


        THROW 53005,
              'TEST FALLIDO: se permitio nombre vacio.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 53005
            THROW;

        SELECT
            'OK - error esperado: nombre vacio' AS prueba,
            ERROR_MESSAGE() AS mensaje;

    END CATCH;

    ---------------------------------------------------------
    -- 7. VALIDACION: PAIS VACIO
    ---------------------------------------------------------

    PRINT '7) Validacion pais vacio';


    BEGIN TRY

        DECLARE @id_error_pais_vacio INT;

        EXEC abm.Anunciante_Alta
            @nombre = N'TEST_PAIS_VACIO',
            @pais = N'',
            @id_anunciante = @id_error_pais_vacio OUTPUT;


        THROW 53006,
              'TEST FALLIDO: se permitio pais vacio.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 53006
            THROW;

        SELECT
            'OK - error esperado: pais vacio' AS prueba,
            ERROR_MESSAGE() AS mensaje;

    END CATCH;

    ---------------------------------------------------------
    -- 8. VALIDACION: PAIS NULL
    ---------------------------------------------------------

    PRINT '8) Validacion pais NULL';


    BEGIN TRY

        DECLARE @id_error_pais_null INT;

        EXEC abm.Anunciante_Alta
            @nombre = N'TEST_PAIS_NULL',
            @pais = NULL,
            @id_anunciante = @id_error_pais_null OUTPUT;


        THROW 53007,
              'TEST FALLIDO: se permitio pais NULL.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 53007
            THROW;

        SELECT
            'OK - error esperado: pais NULL' AS prueba,
            ERROR_MESSAGE() AS mensaje;

    END CATCH;

    ---------------------------------------------------------
    -- 9. VALIDACION: NOMBRE DUPLICADO
    ---------------------------------------------------------

    PRINT '9) Validacion nombre duplicado';


    BEGIN TRY

        DECLARE @id_duplicado INT;

        EXEC abm.Anunciante_Alta
            @nombre = N'TEST_ANUNCIANTE_MODIFICADO',
            @pais = N'Chile',
            @id_anunciante = @id_duplicado OUTPUT;


        THROW 53008,
              'TEST FALLIDO: se permitio anunciante duplicado.',
              1;

    END TRY
    BEGIN CATCH

        IF ERROR_NUMBER() = 53008
            THROW;

        SELECT
            'OK - error esperado: anunciante duplicado' AS prueba,
            ERROR_MESSAGE() AS mensaje;

    END CATCH;

    ---------------------------------------------------------
    -- 10. VALIDAR QUE PAIS NO SEA NULL
    ---------------------------------------------------------

    PRINT '10) Verificando pais obligatorio';


    IF EXISTS
    (
        SELECT 1
        FROM dbo.Anunciante
        WHERE nombre LIKE N'TEST_ANUNCIANTE%'
          AND (
                pais IS NULL
                OR LTRIM(RTRIM(pais)) = N''
              )
    )
        THROW 53009,
              'TEST FALLIDO: existe un anunciante de prueba sin pais.',
              1;


    PRINT 'OK - Ningun anunciante de prueba tiene pais NULL o vacio';

    ---------------------------------------------------------
    -- RESULTADO FINAL
    ---------------------------------------------------------

    PRINT '';
    PRINT '=====================================';
    PRINT 'TODOS LOS TESTS DE ANUNCIANTE OK';
    PRINT '=====================================';


    SELECT
        id_anunciante,
        nombre,
        pais
    FROM dbo.Anunciante
    WHERE nombre LIKE N'TEST_ANUNCIANTE%'
    ORDER BY id_anunciante;

END;
GO

EXEC test.Anunciante_Test;
GO