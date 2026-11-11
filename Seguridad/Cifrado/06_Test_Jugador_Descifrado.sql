/*
    TEST - MOSTRAR dbo.Jugador DESPUES DEL DESCIFRADO

    Verifica que:
      - volvieron las columnas originales;
      - ya no existen las columnas cifradas;
      - los datos son nuevamente legibles;
      - se muestra TODA la tabla en su estructura logica original.
*/

use MUNDIALDEFUTBOL;
go

create or alter procedure test.Jugador_Descifrado_Test
as
begin
    set nocount on;

    if object_id(N'dbo.Jugador', N'U') is null
        throw 54400, N'No existe dbo.Jugador.', 1;

    if col_length(N'dbo.Jugador', N'nombre') is null
       or col_length(N'dbo.Jugador', N'apellido') is null
       or col_length(N'dbo.Jugador', N'fecha_nacimiento') is null
        throw 54401, N'dbo.Jugador no se encuentra en estado descifrado.', 1;

    if col_length(N'dbo.Jugador', N'nombre_cifrado') is not null
       or col_length(N'dbo.Jugador', N'apellido_cifrado') is not null
       or col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is not null
        throw 54402, N'La tabla todavia conserva columnas cifradas.', 1;

    if not exists (
        select 1
        from dbo.Jugador
    )
    begin
        print 'ADVERTENCIA - La tabla esta descifrada correctamente, pero no contiene jugadores.';
    end
    else if exists (
        select 1
        from dbo.Jugador
        where nombre is null
           or apellido is null
           or fecha_nacimiento is null
    )
        throw 54403, N'Existe al menos un jugador con datos personales incompletos.', 1;

    print 'OK - dbo.Jugador se encuentra nuevamente en estado normal/descifrado.';
    print '';
    print '===== TODOS LOS JUGADORES - DATOS DESCIFRADOS =====';

    select
        id_jugador,
        id_seleccion,
        nombre,
        apellido,
        fecha_nacimiento,
        club_origen,
        posicion,
        dorsal
    from dbo.Jugador
    order by id_jugador;
end;
go

exec test.Jugador_Descifrado_Test;
go


