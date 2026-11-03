/*
    TEST - IMPORTACIÓN DE JUGADORES DESDE PDF FIFA 2026

    Resultado esperado si dbo.Jugador comienza vacío y las 48 selecciones
    ya están cargadas:
      Primera ejecución: 1248 insertados, 0 actualizados, 0 errores.
      Segunda ejecución: 0 insertados, 1248 actualizados, 0 errores.

    Si ya existían jugadores, la primera ejecución puede mostrar actualizados.
    Lo importante es que no se generen duplicados.
*/

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER PROCEDURE test.Importar_Jugador_PDF_CSV_Test
    @archivo NVARCHAR(1000)
AS
BEGIN
    SET NOCOUNT ON;

    PRINT '===== PRIMERA IMPORTACION DE JUGADORES (PDF FIFA) =====';
    EXEC importacion.Importar_Jugador_PDF_CSV
        @archivo = @archivo;

    SELECT id_jugador, id_seleccion, nombre, apellido, fecha_nacimiento,
           club_origen, posicion, dorsal
    INTO #Jugador_Primera_Importacion
    FROM dbo.Jugador;

    PRINT '===== SEGUNDA IMPORTACION - PRUEBA DE UPSERT =====';
    EXEC importacion.Importar_Jugador_PDF_CSV
        @archivo = @archivo;

    IF EXISTS (
        SELECT * FROM #Jugador_Primera_Importacion
        EXCEPT SELECT id_jugador, id_seleccion, nombre, apellido, fecha_nacimiento,
                      club_origen, posicion, dorsal FROM dbo.Jugador
    ) OR EXISTS (
        SELECT id_jugador, id_seleccion, nombre, apellido, fecha_nacimiento,
               club_origen, posicion, dorsal FROM dbo.Jugador
        EXCEPT SELECT * FROM #Jugador_Primera_Importacion
    )
        THROW 52300, N'Repetir el CSV alteró IDs, nombres o cantidad de jugadores.', 1;

    IF EXISTS (
        SELECT id_seleccion, nombre, apellido, fecha_nacimiento FROM dbo.Jugador
        GROUP BY id_seleccion, nombre, apellido, fecha_nacimiento HAVING COUNT(*) > 1
    )
        THROW 52301, N'La importación dejó jugadores duplicados.', 1;

    PRINT '===== CANTIDAD TOTAL DE JUGADORES CARGADOS =====';
    SELECT COUNT(*) AS cantidad_jugadores
    FROM dbo.Jugador;

    PRINT '===== JUGADORES POR SELECCION =====';
    SELECT
        s.pais,
        COUNT(*) AS cantidad
    FROM dbo.Jugador j
    INNER JOIN dbo.Seleccion s
        ON s.id_seleccion = j.id_seleccion
    GROUP BY s.pais
    ORDER BY s.pais;

    PRINT '===== DUPLICADOS (RESULTADO ESPERADO: 0 FILAS) =====';
    SELECT
        s.pais,
        j.nombre,
        j.apellido,
        j.fecha_nacimiento,
        COUNT(*) AS cantidad
    FROM dbo.Jugador j
    INNER JOIN dbo.Seleccion s
        ON s.id_seleccion = j.id_seleccion
    GROUP BY
        s.pais,
        j.nombre,
        j.apellido,
        j.fecha_nacimiento
    HAVING COUNT(*) > 1;
END;
GO

/* Ruta esperada si SQL Server corre en el contenedor Docker "sqlserver":
   /var/opt/mssql/import/jugadores_fifa_pdf.csv
*/
EXEC test.Importar_Jugador_PDF_CSV_Test
    @archivo = N'/var/opt/mssql/import/jugadores_fifa_pdf.csv';
GO

select * from dbo.jugador;
