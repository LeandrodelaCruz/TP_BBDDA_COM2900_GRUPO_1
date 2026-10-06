/*
    Universidad: Universidad Nacional de la Matanza
    Materia: Bases de Datos Aplicada - Com 01-2900
    Trabajo Práctico: Entrega 5
    Integrantes: Rodríguez, Elías Uriel - Clara, Lucas Nicolas - Caro, Nicolas Dario - de la Cruz, Leandro Ariel
    Fecha: 2026-10-04

    Descripción:
    Limpieza de los datos generados por los casos de prueba. Usa los SP de Baja; no hace DELETE directo.
*/
SET NOCOUNT ON;
GO


PRINT '===== LIMPIEZA DE DATOS DE TEST =====';

DECLARE @id INT;

/* ANUNCIANTE */
SET @id = (
    SELECT TOP 1 id_anunciante FROM dbo.Anunciante
    WHERE nombre LIKE N'TEST_ANUNCIANTE%'
    ORDER BY id_anunciante
);
WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.SP_Anunciante_Baja @id;
    SET @id = (
        SELECT TOP 1 id_anunciante FROM dbo.Anunciante
        WHERE nombre LIKE N'TEST_ANUNCIANTE%'
        ORDER BY id_anunciante
    );
END;

/* REGION */
SET @id = (
    SELECT TOP 1 id_region FROM dbo.Region
    WHERE nombre LIKE N'TEST_REGION%'
    ORDER BY id_region
);
WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.SP_Region_Baja @id;
    SET @id = (
        SELECT TOP 1 id_region FROM dbo.Region
        WHERE nombre LIKE N'TEST_REGION%'
        ORDER BY id_region
    );
END;

/* SEDE */
SET @id = (
    SELECT TOP 1 id_sede FROM dbo.Sede
    WHERE nombre_estadio LIKE N'TEST_ESTADIO%'
    ORDER BY id_sede
);
WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.SP_Sede_Baja @id;
    SET @id = (
        SELECT TOP 1 id_sede FROM dbo.Sede
        WHERE nombre_estadio LIKE N'TEST_ESTADIO%'
        ORDER BY id_sede
    );
END;

/* SELECCION */
SET @id = (
    SELECT TOP 1 id_seleccion FROM dbo.Seleccion
    WHERE pais LIKE N'TEST_PAIS_SELECCION%'
    ORDER BY id_seleccion
);
WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.SP_Seleccion_Baja @id;
    SET @id = (
        SELECT TOP 1 id_seleccion FROM dbo.Seleccion
        WHERE pais LIKE N'TEST_PAIS_SELECCION%'
        ORDER BY id_seleccion
    );
END;

/* ARBITRO */
SET @id = (
    SELECT TOP 1 id_arbitro FROM dbo.Arbitro
    WHERE nombre LIKE N'TEST_ARBITRO%'
    ORDER BY id_arbitro
);
WHILE @id IS NOT NULL
BEGIN
    EXEC dbo.SP_Arbitro_Baja @id;
    SET @id = (
        SELECT TOP 1 id_arbitro FROM dbo.Arbitro
        WHERE nombre LIKE N'TEST_ARBITRO%'
        ORDER BY id_arbitro
    );
END;

PRINT 'Limpieza finalizada.';

SELECT 'Anunciante' AS tabla, COUNT(*) AS test_restantes FROM dbo.Anunciante WHERE nombre LIKE N'TEST_%'
UNION ALL
SELECT 'Region', COUNT(*) FROM dbo.Region WHERE nombre LIKE N'TEST_%'
UNION ALL
SELECT 'Sede', COUNT(*) FROM dbo.Sede WHERE nombre_estadio LIKE N'TEST_%'
UNION ALL
SELECT 'Seleccion', COUNT(*) FROM dbo.Seleccion WHERE pais LIKE N'TEST_%'
UNION ALL
SELECT 'Arbitro', COUNT(*) FROM dbo.Arbitro WHERE nombre LIKE N'TEST_%';
GO
