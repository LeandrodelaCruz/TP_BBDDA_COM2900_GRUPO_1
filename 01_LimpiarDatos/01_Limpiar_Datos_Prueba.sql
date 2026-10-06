/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04
    
    Descripción:
    Limpia exclusivamente los datos creados por los scripts de prueba
    de las cinco tablas: Anunciante, Region, Sede, Seleccion y Arbitro.

    IMPORTANTE:
    La limpieza usa los Stored Procedures de Baja.
    No realiza DELETE directo sobre las tablas.
*/

USE MUNDIALDEFUTBOL;
GO

SET NOCOUNT ON;

DECLARE @id INT;

/* =========================================================
   ANUNCIANTE
   ========================================================= */
SET @id = (
    SELECT TOP (1) id_anunciante
    FROM dbo.Anunciante
    WHERE nombre LIKE N'TEST_ANUNCIANTE%'
    ORDER BY id_anunciante
);

WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.sp_Anunciante_Baja @id_anunciante = @id;

    SET @id = (
        SELECT TOP (1) id_anunciante
        FROM dbo.Anunciante
        WHERE nombre LIKE N'TEST_ANUNCIANTE%'
        ORDER BY id_anunciante
    );
END;


/* =========================================================
   REGION
   ========================================================= */
SET @id = (
    SELECT TOP (1) id_region
    FROM dbo.Region
    WHERE nombre LIKE N'TEST_REGION%'
    ORDER BY id_region
);

WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.sp_Region_Baja @id_region = @id;

    SET @id = (
        SELECT TOP (1) id_region
        FROM dbo.Region
        WHERE nombre LIKE N'TEST_REGION%'
        ORDER BY id_region
    );
END;


/* =========================================================
   SEDE
   ========================================================= */
SET @id = (
    SELECT TOP (1) id_sede
    FROM dbo.Sede
    WHERE nombre_estadio LIKE N'TEST_ESTADIO%'
    ORDER BY id_sede
);

WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.sp_Sede_Baja @id_sede = @id;

    SET @id = (
        SELECT TOP (1) id_sede
        FROM dbo.Sede
        WHERE nombre_estadio LIKE N'TEST_ESTADIO%'
        ORDER BY id_sede
    );
END;


/* =========================================================
   SELECCION
   ========================================================= */
SET @id = (
    SELECT TOP (1) id_seleccion
    FROM dbo.Seleccion
    WHERE pais LIKE N'TEST_PAIS_SELECCION%'
    ORDER BY id_seleccion
);

WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.sp_Seleccion_Baja @id_seleccion = @id;

    SET @id = (
        SELECT TOP (1) id_seleccion
        FROM dbo.Seleccion
        WHERE pais LIKE N'TEST_PAIS_SELECCION%'
        ORDER BY id_seleccion
    );
END;


/* =========================================================
   ARBITRO
   ========================================================= */
SET @id = (
    SELECT TOP (1) id_arbitro
    FROM dbo.Arbitro
    WHERE nombre LIKE N'TEST_ARBITRO%'
    ORDER BY id_arbitro
);

WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.sp_Arbitro_Baja @id_arbitro = @id;

    SET @id = (
        SELECT TOP (1) id_arbitro
        FROM dbo.Arbitro
        WHERE nombre LIKE N'TEST_ARBITRO%'
        ORDER BY id_arbitro
    );
END;

PRINT 'Datos de prueba eliminados.';
GO


/* =========================================================
   VERIFICACION
   Si todo quedó limpio, cada cantidad debería ser 0.
   ========================================================= */

SELECT N'Anunciante' AS tabla, COUNT(*) AS registros_test
FROM dbo.Anunciante
WHERE nombre LIKE N'TEST_ANUNCIANTE%'

UNION ALL

SELECT N'Region', COUNT(*)
FROM dbo.Region
WHERE nombre LIKE N'TEST_REGION%'

UNION ALL

SELECT N'Sede', COUNT(*)
FROM dbo.Sede
WHERE nombre_estadio LIKE N'TEST_ESTADIO%'

UNION ALL

SELECT N'Seleccion', COUNT(*)
FROM dbo.Seleccion
WHERE pais LIKE N'TEST_PAIS_SELECCION%'

UNION ALL

SELECT N'Arbitro', COUNT(*)
FROM dbo.Arbitro
WHERE nombre LIKE N'TEST_ARBITRO%';
GO
