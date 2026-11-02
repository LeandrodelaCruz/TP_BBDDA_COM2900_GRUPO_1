/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: Com: 01-2900
    Grupo 01:
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez Elías Uriel

    Descripción:
    Test del proceso de importación de Jugador obtenido mediante scraping.

    Resultado esperado:
    - Primera ejecución: inserta jugadores que todavía no existen.
    - Segunda ejecución: actualiza los mismos jugadores y no los duplica.
    - Los registros incompatibles con el modelo se informan como errores
      sin impedir que continúe el resto de la importación.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.SP_Importar_Jugador_Scraping_CSV_Test
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== PRIMERA IMPORTACION DE JUGADORES (SCRAPING) =====';
    EXEC importacion.SP_Importar_Jugador_Scraping_CSV @archivo = @archivo;

    PRINT '===== SEGUNDA IMPORTACION - PRUEBA DE UPSERT =====';
    EXEC importacion.SP_Importar_Jugador_Scraping_CSV @archivo = @archivo;

    PRINT '===== CANTIDAD TOTAL DE JUGADORES CARGADOS =====';
    SELECT COUNT(*) AS cantidad_jugadores
    FROM dbo.Jugador;

    PRINT '===== MUESTRA DE JUGADORES =====';
    SELECT TOP (30)
        j.id_jugador,
        s.pais AS seleccion,
        j.dorsal,
        j.nombre,
        j.apellido,
        j.fecha_nacimiento,
        j.posicion,
        j.club_origen
    FROM dbo.Jugador j
    INNER JOIN dbo.Seleccion s ON s.id_seleccion = j.id_seleccion
    ORDER BY s.pais, j.dorsal;

    PRINT '===== DUPLICADOS (RESULTADO ESPERADO: 0 FILAS) =====';
    SELECT
        j.id_seleccion,
        j.nombre,
        j.apellido,
        j.fecha_nacimiento,
        COUNT(*) AS cantidad
    FROM dbo.Jugador j
    GROUP BY j.id_seleccion, j.nombre, j.apellido, j.fecha_nacimiento
    HAVING COUNT(*) > 1;
END;
GO

/*
Ruta esperada si SQL Server corre dentro del contenedor Docker "sqlserver":
/var/opt/mssql/import/jugadores_scraping.csv
*/
EXEC test.SP_Importar_Jugador_Scraping_CSV_Test
    @archivo = N'/var/opt/mssql/import/jugadores_scraping.csv';
GO

