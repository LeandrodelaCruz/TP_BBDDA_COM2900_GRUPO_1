/*
    TEST - MOSTRAR dbo.Jugador EN ESTADO CIFRADO

    Objetivo:
      - verificar que los tres atributos sensibles existan cifrados;
      - comprobar que no queden NULL;
      - mostrar TODOS los jugadores con esos campos en VARBINARY y
        el resto de la informacion sin cifrar.
*/

use MUNDIALDEFUTBOL;
go


create or alter procedure test.Jugador_Cifrado_Test
as
begin
    set nocount on;

    if object_id(N'dbo.Jugador', N'U') is null
        throw 54200, N'No existe dbo.Jugador.', 1;

    if col_length(N'dbo.Jugador', N'nombre_cifrado') is null
       or col_length(N'dbo.Jugador', N'apellido_cifrado') is null
       or col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is null
        throw 54201, N'dbo.Jugador no se encuentra en estado cifrado.', 1;

    if col_length(N'dbo.Jugador', N'nombre') is not null
       or col_length(N'dbo.Jugador', N'apellido') is not null
       or col_length(N'dbo.Jugador', N'fecha_nacimiento') is not null
        throw 54202, N'La tabla conserva columnas sensibles en texto plano.', 1;

    if not exists (
        select 1
        from dbo.Jugador
    )
        throw 54203, N'No hay jugadores cargados para mostrar.', 1;

    if exists (
        select 1
        from dbo.Jugador
        where nombre_cifrado is null
           or apellido_cifrado is null
           or fecha_nacimiento_cifrada is null
    )
        throw 54204, N'Existe al menos un jugador con datos sensibles sin cifrar.', 1;

    print 'OK - dbo.Jugador se encuentra en estado cifrado.';
    print 'OK - Nombre, apellido y fecha de nacimiento estan almacenados como VARBINARY.';
    print '';
    print '===== TODOS LOS JUGADORES - DATOS CIFRADOS =====';

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
end;
go

exec test.Jugador_Cifrado_Test;
go
