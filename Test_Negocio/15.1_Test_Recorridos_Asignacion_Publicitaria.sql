/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - Comision 01-2900
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 07/11/2026
    Objetivo: validar los dos recorridos WHILE de asignacion publicitaria.
    Ejecutar en MUNDIALDEFUTBOL con los datos del repo:
    partidos, regiones, publicidad, relaciones, ABM y negocio 15 instalados.
    Modifica horarios prime time de prueba y conserva evidencia en MUNDIALDEFUTBOL.
    Esperado: 4 espacios, costo sin cambiar IDs, cambio de pieza, rollback
    completo ante fallo en la ultima baja, y retiro de los 4 al reintentar.
*/
USE MUNDIALDEFUTBOL;
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
IF @@TRANCOUNT <> 0
    THROW 51800, N'Ejecute sin una transaccion externa.', 1;
IF (SELECT COUNT(*) FROM dbo.Region) <> 8
   OR (SELECT COUNT(*) FROM dbo.Pieza_Para_Region) <> 8
   OR NOT EXISTS (SELECT 1 FROM dbo.Partido)
    THROW 51800, N'Cargue los datos de partidos, regiones y publicidad del repo.', 1;
IF OBJECT_ID(N'dbo.Test_Fallo_Ultima_Baja_Publicitaria',N'TR') IS NOT NULL
    THROW 51800, N'Ya existe el trigger reservado de la prueba.', 1;

SELECT * INTO #Regiones_Recorrido FROM dbo.Region;
DECLARE @region INT, @nombre NVARCHAR(80), @idioma NVARCHAR(50), @huso VARCHAR(100),
        @partido INT = (SELECT MIN(id_partido) FROM dbo.Partido),
        @candidatos INT, @asignados INT;
SELECT @region = MIN(id_region) FROM #Regiones_Recorrido;
WHILE @region IS NOT NULL
BEGIN
    SELECT @nombre = nombre, @idioma = idioma, @huso = huso_horario
    FROM #Regiones_Recorrido WHERE id_region = @region;
    EXEC abm.Region_Modificar @region,@nombre,@idioma,@huso,'00:00:01','23:59:59';
    SELECT @region = MIN(id_region) FROM #Regiones_Recorrido WHERE id_region > @region;
END;

EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido,
    @cantidad_candidatos = @candidatos OUTPUT, @cantidad_asignados = @asignados OUTPUT;
IF @candidatos <= 4 OR @asignados <> 4
    THROW 51801, N'No se seleccionaron cuatro espacios entre mas de cuatro candidatos.', 1;
SELECT id_asignacion,id_pieza,numero_espacio INTO #Antes_Costo
FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido;
EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido, @costo_espacio_1 = 12345;
IF EXISTS (SELECT * FROM #Antes_Costo EXCEPT
           SELECT id_asignacion,id_pieza,numero_espacio FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido)
   OR (SELECT COUNT(*) FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido) <> 4
   OR NOT EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria
                  WHERE id_partido = @partido AND numero_espacio = 1 AND costo_aplicado = 12345)
    THROW 51802, N'Cambiar el costo altero los IDs o no actualizo el importe.', 1;
PRINT 'OK - Publicidad: ranking, cuatro espacios y cambio de costo con IDs estables.';

-- Quitar una relacion elegida obliga a reemplazar al menos una pieza.
DECLARE @pieza_retirada INT = (SELECT MIN(id_pieza) FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido),
        @region_retirada INT;
SELECT @region_retirada = MIN(id_region) FROM dbo.Pieza_Para_Region WHERE id_pieza = @pieza_retirada;
EXEC abm.Pieza_Para_Region_Baja @id_pieza = @pieza_retirada, @id_region = @region_retirada;
EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido;
IF (SELECT COUNT(*) FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido) <> 4
   OR EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido AND id_pieza = @pieza_retirada)
    THROW 51803, N'No se sustituyo la pieza que dejo de ser candidata.', 1;
EXEC abm.Pieza_Para_Region_Alta @id_pieza = @pieza_retirada, @id_region = @region_retirada;
EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido;
PRINT 'OK - Publicidad: cambio de pieza mediante baja y alta.';

SELECT * INTO #Antes_Fallo_Bajas FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido;
DECLARE @ultima_baja INT = (SELECT MAX(id_asignacion) FROM #Antes_Fallo_Bajas),
        @fallo BIT = 0, @sql_prueba NVARCHAR(MAX);

-- La hora del primer partido del dataset queda fuera de este intervalo
-- minimo en los ocho mercados: lista vacia de seleccionados, cuatro bajas.
SELECT @region = MIN(id_region) FROM #Regiones_Recorrido;
WHILE @region IS NOT NULL
BEGIN
    SELECT @nombre = nombre, @idioma = idioma, @huso = huso_horario
    FROM #Regiones_Recorrido WHERE id_region = @region;
    EXEC abm.Region_Modificar @region,@nombre,@idioma,@huso,'00:00:01','00:00:02';
    SELECT @region = MIN(id_region) FROM #Regiones_Recorrido WHERE id_region > @region;
END;

-- CREATE TRIGGER requiere su propio lote; el ID es un entero de esta prueba.
SET @sql_prueba = N'CREATE TRIGGER dbo.Test_Fallo_Ultima_Baja_Publicitaria
ON dbo.Asignacion_Publicitaria AFTER DELETE AS
BEGIN
    IF EXISTS (SELECT 1 FROM deleted WHERE id_asignacion = '
    + CONVERT(NVARCHAR(20),@ultima_baja) + N')
        THROW 51804, ''Fallo simulado en la ultima baja.'', 1;
END;';
EXEC sys.sp_executesql @sql_prueba;
BEGIN TRY
    BEGIN TRY
        EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido;
    END TRY
    BEGIN CATCH
        SET @fallo = 1;
    END CATCH;
    IF @fallo = 0 OR @@TRANCOUNT <> 0
        THROW 51805, N'No se produjo el fallo esperado o quedo una transaccion abierta.', 1;
    IF EXISTS (SELECT * FROM #Antes_Fallo_Bajas EXCEPT
               SELECT * FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido)
       OR EXISTS (SELECT * FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido EXCEPT
                  SELECT * FROM #Antes_Fallo_Bajas)
        THROW 51805, N'El fallo no restauro todas las asignaciones previas.', 1;
    DROP TRIGGER dbo.Test_Fallo_Ultima_Baja_Publicitaria;
END TRY
BEGIN CATCH
    IF XACT_STATE() <> 0 ROLLBACK TRANSACTION;
    IF OBJECT_ID(N'dbo.Test_Fallo_Ultima_Baja_Publicitaria',N'TR') IS NOT NULL
        DROP TRIGGER dbo.Test_Fallo_Ultima_Baja_Publicitaria;
    THROW;
END CATCH;
PRINT 'OK - Publicidad: fallo en la ultima baja revierte las bajas anteriores.';

EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido,
    @cantidad_candidatos = @candidatos OUTPUT, @cantidad_asignados = @asignados OUTPUT;
IF @candidatos <> 0 OR @asignados <> 0
   OR EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido)
    THROW 51806, N'El reintento con seleccion vacia no elimino las cuatro asignaciones.', 1;
EXEC negocio.Generar_Asignacion_Publicitaria @id_partido = @partido;
IF EXISTS (SELECT 1 FROM dbo.Asignacion_Publicitaria WHERE id_partido = @partido)
    THROW 51806, N'Repetir el caso vacio genero asignaciones.', 1;
PRINT 'OK - Publicidad: seleccion vacia retira todas las bajas y puede repetirse.';
GO
