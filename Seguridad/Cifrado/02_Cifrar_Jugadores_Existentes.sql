/*
    CIFRADO DE dbo.Jugador

    A) Si ya existen jugadores:
       - agrega columnas cifradas;
       - cifra nombre, apellido y fecha_nacimiento;
       - verifica el resultado;
       - elimina las columnas en texto plano.

    B) Si dbo.Jugador esta vacia:
       - transforma igualmente la estructura al estado cifrado;
       - luego se pueden cargar jugadores con abm.Jugador_Cifrado_Alta.

    Nota tecnica:
    La creacion de columnas y su uso se separan con GO porque SQL Server
    compila un batch completo antes de ejecutarlo.
*/

use MUNDIALDEFUTBOL;
go

set nocount on;
go


--   FASE 1 - VALIDAR ESTADO Y AGREGAR COLUMNAS CIFRADAS

if object_id(N'dbo.Jugador', N'U') is null
    throw 54001, N'No existe dbo.Jugador.', 1;

if not exists (
    select 1
    from sys.certificates
    where name = N'Certificado_Jugador'
)
    throw 54002, N'No existe Certificado_Jugador. Ejecute primero 01_Seguridad_Jugador.sql.', 1;

if not exists (
    select 1
    from sys.symmetric_keys
    where name = N'Clave_Jugador'
)
    throw 54003, N'No existe Clave_Jugador. Ejecute primero 01_Seguridad_Jugador.sql.', 1;

declare
    @tiene_nombre bit = case when col_length(N'dbo.Jugador', N'nombre') is not null then 1 else 0 end,
    @tiene_apellido bit = case when col_length(N'dbo.Jugador', N'apellido') is not null then 1 else 0 end,
    @tiene_fecha bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento') is not null then 1 else 0 end,
    @tiene_nombre_cifrado bit = case when col_length(N'dbo.Jugador', N'nombre_cifrado') is not null then 1 else 0 end,
    @tiene_apellido_cifrado bit = case when col_length(N'dbo.Jugador', N'apellido_cifrado') is not null then 1 else 0 end,
    @tiene_fecha_cifrada bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is not null then 1 else 0 end;

if @tiene_nombre = 0
   and @tiene_apellido = 0
   and @tiene_fecha = 0
   and @tiene_nombre_cifrado = 1
   and @tiene_apellido_cifrado = 1
   and @tiene_fecha_cifrada = 1
begin
    print 'OK - dbo.Jugador ya se encuentra en estado cifrado.';
end
else if @tiene_nombre = 1
    and @tiene_apellido = 1
    and @tiene_fecha = 1
    and @tiene_nombre_cifrado = 0
    and @tiene_apellido_cifrado = 0
    and @tiene_fecha_cifrada = 0
begin
    alter table dbo.Jugador
    add
        nombre_cifrado varbinary(256) null,
        apellido_cifrado varbinary(256) null,
        fecha_nacimiento_cifrada varbinary(256) null;

    print 'OK - Se agregaron las columnas cifradas.';
end
else if @tiene_nombre = 1
    and @tiene_apellido = 1
    and @tiene_fecha = 1
    and @tiene_nombre_cifrado = 1
    and @tiene_apellido_cifrado = 1
    and @tiene_fecha_cifrada = 1
begin
    print 'INFO - Se detecto un estado intermedio. Se continuara el cifrado.';
end
else
begin
    throw 54004, N'dbo.Jugador se encuentra en un estado no reconocido. Revise sus columnas antes de continuar.', 1;
end;
go


--  FASE 2 - CIFRAR Y REEMPLAZAR COLUMNAS ORIGINALES

set nocount on;

declare
    @tiene_nombre bit = case when col_length(N'dbo.Jugador', N'nombre') is not null then 1 else 0 end,
    @tiene_apellido bit = case when col_length(N'dbo.Jugador', N'apellido') is not null then 1 else 0 end,
    @tiene_fecha bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento') is not null then 1 else 0 end,
    @tiene_nombre_cifrado bit = case when col_length(N'dbo.Jugador', N'nombre_cifrado') is not null then 1 else 0 end,
    @tiene_apellido_cifrado bit = case when col_length(N'dbo.Jugador', N'apellido_cifrado') is not null then 1 else 0 end,
    @tiene_fecha_cifrada bit = case when col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is not null then 1 else 0 end,
    @cantidad_jugadores int;

if @tiene_nombre = 0
   and @tiene_apellido = 0
   and @tiene_fecha = 0
   and @tiene_nombre_cifrado = 1
   and @tiene_apellido_cifrado = 1
   and @tiene_fecha_cifrada = 1
begin
    print 'OK - No hay nada para cifrar: dbo.Jugador ya esta cifrada.';
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
    throw 54005, N'No se pudo preparar dbo.Jugador para el cifrado.', 1;

select @cantidad_jugadores = count(*)
from dbo.Jugador;

print 'Jugadores encontrados antes del cifrado: ' + cast(@cantidad_jugadores as varchar(20));

begin try
    open symmetric key Clave_Jugador
    decryption by certificate Certificado_Jugador;

    begin transaction;

    update dbo.Jugador
    set
        nombre_cifrado = encryptbykey(
            key_guid(N'Clave_Jugador'),
            convert(nvarchar(60), nombre)
        ),
        apellido_cifrado = encryptbykey(
            key_guid(N'Clave_Jugador'),
            convert(nvarchar(60), apellido)
        ),
        fecha_nacimiento_cifrada = encryptbykey(
            key_guid(N'Clave_Jugador'),
            convert(nvarchar(10), fecha_nacimiento, 23)
        );

    if exists (
        select 1
        from dbo.Jugador
        where nombre_cifrado is null
           or apellido_cifrado is null
           or fecha_nacimiento_cifrada is null
    )
        throw 54006, N'No se pudieron cifrar todos los jugadores. No se eliminaron los datos originales.', 1;

    if exists (
        select 1
        from dbo.Jugador
        where convert(nvarchar(60), decryptbykey(nombre_cifrado)) <> nombre
           or convert(nvarchar(60), decryptbykey(apellido_cifrado)) <> apellido
           or convert(
                date,
                convert(nvarchar(10), decryptbykey(fecha_nacimiento_cifrada)),
                23
              ) <> fecha_nacimiento
    )
        throw 54007, N'La verificacion del cifrado fallo. No se eliminaron los datos originales.', 1;

    alter table dbo.Jugador
    drop column nombre, apellido, fecha_nacimiento;

    alter table dbo.Jugador
    alter column nombre_cifrado varbinary(256) not null;

    alter table dbo.Jugador
    alter column apellido_cifrado varbinary(256) not null;

    alter table dbo.Jugador
    alter column fecha_nacimiento_cifrada varbinary(256) not null;

    commit transaction;

    close symmetric key Clave_Jugador;

    print 'OK - dbo.Jugador fue cifrada correctamente.';
    print 'Los campos nombre, apellido y fecha_nacimiento fueron reemplazados por sus versiones cifradas.';
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

select * from dbo.jugador;