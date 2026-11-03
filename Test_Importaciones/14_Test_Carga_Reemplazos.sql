/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - Comision 01-2900
    Integrantes: Caro, Nicolas Dario; Clara, Lucas Nicolas;
                 de la Cruz, Leandro Ariel; Rodriguez, Elias Uriel.
    Fecha: 03/11/2026
    Objetivo: verificar preparacion atomica, errores parciales y repeticion.
    SOLO ejecutar en una base AISLADA y vacia cuyo nombre comience por
    MUNDIALDEFUTBOL_Test_Reemplazos_. Seleccionar esa base en SSMS.
    Requiere tablas, esquemas, ABM 03/04/10/13/14 y negocio 14 e importaciones 14.
    Crea datos minimos, un fixture y un trigger transitorio de fallo.
    Conserva la evidencia en la base de pruebas; no limpia tablas ajenas.
*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
IF DB_NAME() NOT LIKE N'MUNDIALDEFUTBOL[_]Test[_]Reemplazos[_]%'
    THROW 51700, N'Seleccione una base aislada MUNDIALDEFUTBOL_Test_Reemplazos_ antes de ejecutar.', 1;
IF @@TRANCOUNT <> 0 OR EXISTS (SELECT 1 FROM dbo.Jugador) OR EXISTS (SELECT 1 FROM dbo.Seleccion)
    THROW 51700, N'El test requiere una base vacia y sin transacciones abiertas.', 1;

DECLARE @plantillas TABLE
(pais NVARCHAR(80), confederacion NVARCHAR(50), dorsal TINYINT,
 nombre NVARCHAR(60), apellido NVARCHAR(60), nacimiento DATE,
 club NVARCHAR(100), posicion VARCHAR(40), debut DATE);
INSERT INTO @plantillas VALUES
(N'Argentina',N'CONMEBOL',2,N'Marcos Nicolás',N'SENESI BARON','19970510',N'AFC Bournemouth (ENG)','Defensa','20260616'),
(N'Brazil',N'CONMEBOL',2,N'Éderson José',N'DOS SANTOS LOURENÇO DA SILVA','19990707',N'Atalanta Bergamo (ITA)','Mediocentro','20260613'),
(N'Germany',N'UEFA',25,N'Forzan Assan',N'OUÉDRAOGO','20060509',N'RB Leipzig (GER)','Mediocentro','20260614'),
(N'Austria',N'UEFA',19,N'Dejan',N'LJUBIČIĆ','19971008',N'FC Schalke 04 (GER)','Mediocentro','20260616'),
(N'England',N'UEFA',12,N'Trevoh Tom',N'CHALOBAH','19990705',N'Chelsea FC (ENG)','Defensa','20260617');

EXEC abm.Seleccion_Alta N'Rival de prueba',N'UEFA','L';
EXEC abm.Sede_Alta N'Estadio de prueba',N'Ciudad',N'Pais',50000,'UTC';
DECLARE @rival INT = (SELECT id_seleccion FROM dbo.Seleccion WHERE pais = N'Rival de prueba'),
        @sede INT = (SELECT id_sede FROM dbo.Sede WHERE nombre_estadio = N'Estadio de prueba'),
        @pais NVARCHAR(80), @conf NVARCHAR(50), @dorsal TINYINT,
        @nombre NVARCHAR(60), @apellido NVARCHAR(60), @nacimiento DATE,
        @club NVARCHAR(100), @posicion VARCHAR(40), @debut DATE,
        @seleccion INT, @horario DATETIME2(0);
DECLARE plantillas CURSOR LOCAL FAST_FORWARD FOR SELECT * FROM @plantillas;
OPEN plantillas;
FETCH NEXT FROM plantillas INTO @pais,@conf,@dorsal,@nombre,@apellido,@nacimiento,@club,@posicion,@debut;
WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC abm.Seleccion_Alta @pais,@conf,'A';
    SELECT @seleccion = id_seleccion FROM dbo.Seleccion WHERE pais = @pais;
    EXEC abm.Jugador_Alta @nacimiento,@club,@apellido,@nombre,@posicion,@dorsal,@seleccion;
    SET @horario = CONVERT(DATETIME2(0),@debut);
    EXEC abm.Partidos_Alta @sede,@seleccion,@rival,@debut,@horario,@horario,'GRUPOS';
    FETCH NEXT FROM plantillas INTO @pais,@conf,@dorsal,@nombre,@apellido,@nacimiento,@club,@posicion,@debut;
END;
CLOSE plantillas;
DEALLOCATE plantillas;

DECLARE @a INT, @o INT, @e INT;
-- Caso 1: sin habilitar reconstruccion, 5 errores y ninguna escritura.
EXEC carga.Cargar_Reemplazos_Manuales 0,@a OUTPUT,@o OUTPUT,@e OUTPUT;
IF @a <> 0 OR @o <> 0 OR @e <> 5
    THROW 51701, N'Fallo el control de reconstruccion explicita.', 1;
IF (SELECT COUNT(*) FROM dbo.Jugador) <> 5 OR EXISTS (SELECT 1 FROM dbo.Reemplazo)
    THROW 51701, N'La validacion inicial altero datos.', 1;
PRINT 'OK - Reconstruccion explicita requerida.';

-- Caso 2: forzar fallo del quinto caso DESPUES de retirar al entrante,
-- incorporar al saliente y recrear al entrante. Los otros cuatro confirman.
DECLARE @chalobah_original INT = (SELECT id_jugador FROM dbo.Jugador WHERE apellido = N'CHALOBAH');
EXEC(N'CREATE TRIGGER dbo.Test_Fallo_Lote_Reemplazos ON dbo.Reemplazo AFTER INSERT AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted r JOIN dbo.Jugador j ON j.id_jugador = r.id_jugador_baja
               WHERE j.apellido = N''Livramento'')
        THROW 51702, ''Fallo simulado al registrar el reemplazo ingles.'', 1;
END;');
BEGIN TRY
    EXEC carga.Cargar_Reemplazos_Manuales 1,@a OUTPUT,@o OUTPUT,@e OUTPUT;
    IF @a <> 4 OR @o <> 0 OR @e <> 1
        THROW 51703, N'No se procesaron correctamente los errores parciales.', 1;
    IF (SELECT COUNT(*) FROM dbo.Reemplazo) <> 4 OR (SELECT COUNT(*) FROM dbo.Jugador) <> 9
        THROW 51703, N'El lote parcial dejo cantidades inesperadas.', 1;
    IF NOT EXISTS (SELECT 1 FROM dbo.Jugador WHERE id_jugador = @chalobah_original AND apellido = N'CHALOBAH')
       OR EXISTS (SELECT 1 FROM dbo.Jugador WHERE apellido = N'Livramento')
        THROW 51704, N'No se restauro la convocatoria inglesa al fallar el reemplazo.', 1;
    IF @@TRANCOUNT <> 0 THROW 51704, N'Quedo una transaccion abierta.', 1;
    PRINT 'OK - Cuatro casos confirmados; quinto caso completamente revertido.';
END TRY
BEGIN CATCH
    IF OBJECT_ID(N'dbo.Test_Fallo_Lote_Reemplazos',N'TR') IS NOT NULL
        DROP TRIGGER dbo.Test_Fallo_Lote_Reemplazos;
    THROW;
END CATCH;
DROP TRIGGER dbo.Test_Fallo_Lote_Reemplazos;

-- Caso 3: reintentar aplica solo Inglaterra y omite los cuatro exitosos.
EXEC carga.Cargar_Reemplazos_Manuales 1,@a OUTPUT,@o OUTPUT,@e OUTPUT;
IF @a <> 1 OR @o <> 4 OR @e <> 0
    THROW 51705, N'Fallo el reintento despues del error parcial.', 1;
IF (SELECT COUNT(*) FROM dbo.Reemplazo) <> 5 OR (SELECT COUNT(*) FROM dbo.Jugador) <> 10
    THROW 51705, N'El lote final no conservo cinco altas y cinco bajas.', 1;
IF (SELECT COUNT(*) FROM dbo.Jugador j WHERE NOT EXISTS
    (SELECT 1 FROM dbo.Reemplazo r WHERE r.id_jugador_baja = j.id_jugador)) <> 5
    THROW 51705, N'Cambio la cantidad de convocados vigentes.', 1;
PRINT 'OK - Reintento aplica solo el caso pendiente.';

-- Caso 4: repeticion completa sin duplicados ni cambio de identidades.
DECLARE @max_jugador INT = (SELECT MAX(id_jugador) FROM dbo.Jugador),
        @max_reemplazo INT = (SELECT MAX(id_reemplazo) FROM dbo.Reemplazo);
EXEC carga.Cargar_Reemplazos_Manuales 1,@a OUTPUT,@o OUTPUT,@e OUTPUT;
IF @a <> 0 OR @o <> 5 OR @e <> 0
    THROW 51706, N'La repeticion no omitio los cinco casos.', 1;
IF (SELECT MAX(id_jugador) FROM dbo.Jugador) <> @max_jugador
   OR (SELECT MAX(id_reemplazo) FROM dbo.Reemplazo) <> @max_reemplazo
   OR (SELECT COUNT(*) FROM dbo.Jugador) <> 10
   OR (SELECT COUNT(*) FROM dbo.Reemplazo) <> 5
    THROW 51706, N'La repeticion modifico el historial.', 1;
PRINT 'OK - Repeticion sin duplicados y con identidades estables.';

SELECT s.pais,r.fecha_cambio,b.nombre AS nombre_baja,b.apellido AS apellido_baja,
       a.nombre AS nombre_alta,a.apellido AS apellido_alta,a.dorsal,r.motivo
FROM dbo.Reemplazo r JOIN dbo.Jugador b ON b.id_jugador = r.id_jugador_baja
JOIN dbo.Jugador a ON a.id_jugador = r.id_jugador_alta
JOIN dbo.Seleccion s ON s.id_seleccion = a.id_seleccion ORDER BY s.pais;
PRINT 'OK - Todas las pruebas de carga manual finalizaron correctamente.';
GO
