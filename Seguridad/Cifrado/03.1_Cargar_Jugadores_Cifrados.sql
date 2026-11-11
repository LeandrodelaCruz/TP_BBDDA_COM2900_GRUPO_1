/*
    CARGA DE JUGADORES DIRECTAMENTE CIFRADOS

    Requisitos:
    1) Haber ejecutado 01_Seguridad_Jugador.sql
    2) dbo.Jugador debe estar en estado cifrado:
       - nombre_cifrado
       - apellido_cifrado
       - fecha_nacimiento_cifrada
    3) Haber ejecutado 03_Jugador_Cifrado_ABM.sql

    Objetivo:
    Demostrar el caso en el que los jugadores NO estaban cargados
    previamente y se insertan directamente de forma cifrada mediante
    abm.Jugador_Cifrado_Alta.
*/

use MUNDIALDEFUTBOL;
go

set nocount on;
go

------------------------------------------------------------
-- VALIDACIONES PREVIAS
------------------------------------------------------------

if object_id(N'dbo.Jugador', N'U') is null
    throw 54200, N'No existe dbo.Jugador.', 1;

if col_length(N'dbo.Jugador', N'nombre_cifrado') is null
   or col_length(N'dbo.Jugador', N'apellido_cifrado') is null
   or col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is null
begin
    throw 54201,
        N'dbo.Jugador no se encuentra en estado cifrado. Ejecute primero 02_Cifrar_Jugadores_Existentes.sql.',
        1;
end;

if object_id(N'abm.Jugador_Cifrado_Alta', N'P') is null
begin
    throw 54202,
        N'No existe abm.Jugador_Cifrado_Alta. Ejecute primero 03_Jugador_Cifrado_ABM.sql.',
        1;
end;

if not exists (
    select 1
    from dbo.Seleccion
)
begin
    throw 54203,
        N'No existen selecciones cargadas en dbo.Seleccion.',
        1;
end;
go


------------------------------------------------------------
-- OBTENER ALGUNAS SELECCIONES EXISTENTES
------------------------------------------------------------

declare
    @seleccion_1 int,
    @seleccion_2 int,
    @seleccion_3 int;

select
    @seleccion_1 = min(id_seleccion)
from dbo.Seleccion;

select
    @seleccion_2 = min(id_seleccion)
from dbo.Seleccion
where id_seleccion > @seleccion_1;

select
    @seleccion_3 = min(id_seleccion)
from dbo.Seleccion
where id_seleccion > @seleccion_2;

-- Si solo hubiese una o dos selecciones,
-- reutilizamos las disponibles.
if @seleccion_2 is null
    set @seleccion_2 = @seleccion_1;

if @seleccion_3 is null
    set @seleccion_3 = @seleccion_1;


------------------------------------------------------------
-- JUGADOR 1
------------------------------------------------------------

exec abm.Jugador_Cifrado_Alta
    @fecha_nacimiento = '2000-01-15',
    @club_origen = N'Club Atletico Prueba',
    @apellido = N'Fernandez',
    @nombre = N'Martin',
    @posicion = 'Delantero',
    @dorsal = 9,
    @id_seleccion = @seleccion_1;


------------------------------------------------------------
-- JUGADOR 2
------------------------------------------------------------

exec abm.Jugador_Cifrado_Alta
    @fecha_nacimiento = '1999-05-22',
    @club_origen = N'Deportivo Ejemplo',
    @apellido = N'Gomez',
    @nombre = N'Lucas',
    @posicion = 'Mediocampista',
    @dorsal = 8,
    @id_seleccion = @seleccion_1;


------------------------------------------------------------
-- JUGADOR 3
------------------------------------------------------------

exec abm.Jugador_Cifrado_Alta
    @fecha_nacimiento = '2001-08-10',
    @club_origen = N'FC Seguridad',
    @apellido = N'Rodriguez',
    @nombre = N'Nicolas',
    @posicion = 'Defensor',
    @dorsal = 4,
    @id_seleccion = @seleccion_2;


------------------------------------------------------------
-- JUGADOR 4
------------------------------------------------------------

exec abm.Jugador_Cifrado_Alta
    @fecha_nacimiento = '1998-11-03',
    @club_origen = N'Atletico Mundial',
    @apellido = N'Lopez',
    @nombre = N'Federico',
    @posicion = 'Arquero',
    @dorsal = 1,
    @id_seleccion = @seleccion_2;


------------------------------------------------------------
-- JUGADOR 5
------------------------------------------------------------

exec abm.Jugador_Cifrado_Alta
    @fecha_nacimiento = '2002-03-18',
    @club_origen = N'Sporting Database',
    @apellido = N'Martinez',
    @nombre = N'Agustin',
    @posicion = 'Delantero',
    @dorsal = 11,
    @id_seleccion = @seleccion_3;


------------------------------------------------------------
-- RESULTADO
------------------------------------------------------------

print '';
print 'OK - Jugadores cargados directamente mediante el ABM cifrado.';
print '';
print '===== DATOS ALMACENADOS EN dbo.Jugador =====';

select
    id_jugador,
    id_seleccion,
    nombre_cifrado,
    apellido_cifrado,
    fecha_nacimiento_cifrada,
    club_origen,
    posicion,
    dorsal
from dbo.Jugador
order by id_jugador;
go
