/*
    DESCIFRADO COMPLETO DE dbo.Jugador

    Devuelve la tabla a su estructura funcional original:
      nombre NVARCHAR(60)
      apellido NVARCHAR(60)
      fecha_nacimiento DATE

    Nota tecnica:
    La recreacion de columnas y su uso se separan con GO porque SQL Server
    compila un batch completo antes de ejecutarlo.
*/

use MUNDIALDEFUTBOL;
go

set nocount on;
go

/* =========================================================
   FASE 1 - VALIDAR ESTADO Y RECREAR COLUMNAS ORIGINALES
   ========================================================= */
if object_id(N'dbo.Jugador', N'U') is null
    throw 54300, N'No existe dbo.Jugador.', 1;

if not exists (
    select 1
    from sys.certificates
    where name = N'Certificado_Jugador'
)
    throw 54301, N'No existe Certificado_Jugador.', 1;

if not exists (
    select 1
    from sys.symmetric_keys
    where name = N'Clave_Jugador'
)
    throw 54302, N'No existe Clave_Jugador.', 1;

declare
    @tiene_nombre bit = case when col_length(N'dbo.Jugador', N'nombre') is not null then 1 else 0 end,
    @tiene_apellido bit = case when col_length(N'dbo.Jugador', N'apellido') is not null then 1 else 0 end,
    @tiene_fecha bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento') is not null then 1 else 0 end,
    @tiene_nombre_cifrado bit = case when col_length(N'dbo.Jugador', N'nombre_cifrado') is not null then 1 else 0 end,
    @tiene_apellido_cifrado bit = case when col_length(N'dbo.Jugador', N'apellido_cifrado') is not null then 1 else 0 end,
    @tiene_fecha_cifrada bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is not null then 1 else 0 end;

if @tiene_nombre = 1
   and @tiene_apellido = 1
   and @tiene_fecha = 1
   and @tiene_nombre_cifrado = 0
   and @tiene_apellido_cifrado = 0
   and @tiene_fecha_cifrada = 0
begin
    print 'OK - dbo.Jugador ya se encuentra en estado normal/descifrado.';
end
else if @tiene_nombre = 0
    and @tiene_apellido = 0
    and @tiene_fecha = 0
    and @tiene_nombre_cifrado = 1
    and @tiene_apellido_cifrado = 1
    and @tiene_fecha_cifrada = 1
begin
    alter table dbo.Jugador
    add
        nombre nvarchar(60) null,
        apellido nvarchar(60) null,
        fecha_nacimiento date null;

    print 'OK - Se recrearon las columnas originales.';
end
else if @tiene_nombre = 1
    and @tiene_apellido = 1
    and @tiene_fecha = 1
    and @tiene_nombre_cifrado = 1
    and @tiene_apellido_cifrado = 1
    and @tiene_fecha_cifrada = 1
begin
    print 'INFO - Se detecto un estado intermedio. Se continuara el descifrado.';
end
else
begin
    throw 54303, N'dbo.Jugador se encuentra en un estado no reconocido. Revise sus columnas antes de continuar.', 1;
end;
go

/* =========================================================
   FASE 2 - DESCIFRAR Y RESTAURAR LA ESTRUCTURA ORIGINAL
   ========================================================= */
set nocount on;

declare
    @tiene_nombre bit = case when col_length(N'dbo.Jugador', N'nombre') is not null then 1 else 0 end,
    @tiene_apellido bit = case when col_length(N'dbo.Jugador', N'apellido') is not null then 1 else 0 end,
    @tiene_fecha bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento') is not null then 1 else 0 end,
    @tiene_nombre_cifrado bit = case when col_length(N'dbo.Jugador', N'nombre_cifrado') is not null then 1 else 0 end,
    @tiene_apellido_cifrado bit = case when col_length(N'dbo.Jugador', N'apellido_cifrado') is not null then 1 else 0 end,
    @tiene_fecha_cifrada bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is not null then 1 else 0 end;

if @tiene_nombre = 1
   and @tiene_apellido = 1
   and @tiene_fecha = 1
   and @tiene_nombre_cifrado = 0
   and @tiene_apellido_cifrado = 0
   and @tiene_fecha_cifrada = 0
begin
    print 'OK - No hay nada para descifrar: dbo.Jugador ya esta normal.';
    return;
end;

if not (
    @tiene_nombre = 1
    and @tiene_apellido = 1
    and @tiene_fecha = 1
    and @tiene_nombre_cifrado = 1
    and @tiene_apellido_cifrado = 1
    and @tiene_fecha_cifrada = 1
)
    throw 54304, N'No se pudo preparar dbo.Jugador para el descifrado.', 1;

begin try
    open symmetric key Clave_Jugador
    decryption by certificate Certificado_Jugador;

    begin transaction;

    update dbo.Jugador
    set
        nombre = convert(
            nvarchar(60),
            decryptbykey(nombre_cifrado)
        ),
        apellido = convert(
            nvarchar(60),
            decryptbykey(apellido_cifrado)
        ),
        fecha_nacimiento = convert(
            date,
            convert(nvarchar(10), decryptbykey(fecha_nacimiento_cifrada)),
            23
        );

    if exists (
        select 1
        from dbo.Jugador
        where nombre is null
           or apellido is null
           or fecha_nacimiento is null
    )
        throw 54305, N'No se pudieron descifrar correctamente todos los jugadores. Se cancela la restauracion.', 1;

    if exists (
        select 1
        from dbo.Jugador
        where nombre <> convert(nvarchar(60), decryptbykey(nombre_cifrado))
           or apellido <> convert(nvarchar(60), decryptbykey(apellido_cifrado))
           or fecha_nacimiento <> convert(
                date,
                convert(nvarchar(10), decryptbykey(fecha_nacimiento_cifrada)),
                23
           )
    )
        throw 54306, N'La verificacion del descifrado fallo.', 1;

    alter table dbo.Jugador
    drop column nombre_cifrado, apellido_cifrado, fecha_nacimiento_cifrada;

    alter table dbo.Jugador
    alter column nombre nvarchar(60) not null;

    alter table dbo.Jugador
    alter column apellido nvarchar(60) not null;

    alter table dbo.Jugador
    alter column fecha_nacimiento date not null;

    commit transaction;

    close symmetric key Clave_Jugador;

    print 'OK - dbo.Jugador fue descifrada completamente.';
    print 'La tabla vuelve a utilizar nombre, apellido y fecha_nacimiento en sus tipos originales.';
end try
begin catch
    if @@trancount > 0
        rollback transaction;

    if exists (
        select 1
        from sys.openkeys
        where key_name = N'Clave_Jugador'
    )
        close symmetric key Clave_Jugador;

    throw;
end catch;
go
