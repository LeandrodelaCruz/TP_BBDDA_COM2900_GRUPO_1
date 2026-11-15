/*
    ABM PARA dbo.Jugador EN ESTADO CIFRADO

    Estos procedimientos se utilizan solamente mientras dbo.Jugador posee:
      - nombre_cifrado
      - apellido_cifrado
      - fecha_nacimiento_cifrada

    El usuario envia nombre, apellido y fecha normalmente.
    Los SP los cifran antes de INSERT/UPDATE.

    Crear este archivo DESPUES de ejecutar 02_Cifrar_Jugadores_Existentes.sql.
*/

use MUNDIALDEFUTBOL;
go

set nocount on;
go


--   JUGADOR CIFRADO - ALTA

create or alter procedure abm.Jugador_Cifrado_Alta
    @fecha_nacimiento date,
    @club_origen nvarchar(100),
    @apellido nvarchar(60),
    @nombre nvarchar(60),
    @posicion varchar(40),
    @dorsal tinyint,
    @id_seleccion int
as
begin
    set nocount on;

    declare @errores nvarchar(2048) = N'';

    if col_length(N'dbo.Jugador', N'nombre_cifrado') is null
       or col_length(N'dbo.Jugador', N'apellido_cifrado') is null
       or col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is null
        throw 54100, N'dbo.Jugador no se encuentra en estado cifrado.', 1;

    if nullif(ltrim(rtrim(@club_origen)), N'') is null
        set @errores += N'club_origen es obligatorio. ';

    if nullif(ltrim(rtrim(@apellido)), N'') is null
        set @errores += N'apellido es obligatorio. ';

    if nullif(ltrim(rtrim(@nombre)), N'') is null
        set @errores += N'nombre es obligatorio. ';

    if @fecha_nacimiento is null
        set @errores += N'fecha_nacimiento es obligatoria. ';

    if nullif(ltrim(rtrim(@posicion)), '') is null
        set @errores += N'posicion es obligatoria. ';

    if not exists (
        select 1
        from dbo.Seleccion
        where id_seleccion = @id_seleccion
    )
        set @errores += N'No existe la seleccion indicada. ';

    if @dorsal not between 1 and 26
        set @errores += N'El dorsal debe estar entre 1 y 26. ';

    if @errores <> N''
        throw 54101, @errores, 1;

    begin try
        open symmetric key Clave_Jugador
        decryption by certificate Certificado_Jugador;

        insert into dbo.Jugador
        (
            id_seleccion,
            nombre_cifrado,
            apellido_cifrado,
            fecha_nacimiento_cifrada,
            club_origen,
            posicion,
            dorsal
        )
        values
        (
            @id_seleccion,
            encryptbykey(
                key_guid(N'Clave_Jugador'),
                ltrim(rtrim(@nombre))
            ),
            encryptbykey(
                key_guid(N'Clave_Jugador'),
                ltrim(rtrim(@apellido))
            ),
            encryptbykey(
                key_guid(N'Clave_Jugador'),
                convert(nvarchar(10), @fecha_nacimiento, 23)
            ),
            ltrim(rtrim(@club_origen)),
            ltrim(rtrim(@posicion)),
            @dorsal
        );

        declare @id_jugador_generado int = scope_identity();

        close symmetric key Clave_Jugador;

        select @id_jugador_generado as id_jugador_generado;
    end try
    begin catch
        if exists (
            select 1
            from sys.openkeys
            where key_name = N'Clave_Jugador'
        )
            close symmetric key Clave_Jugador;

        throw;
    end catch;
end;
go


--   JUGADOR CIFRADO - MODIFICACION

create or alter procedure abm.Jugador_Cifrado_Modificar
    @id_jugador int,
    @fecha_nacimiento date,
    @club_origen nvarchar(100),
    @apellido nvarchar(60),
    @nombre nvarchar(60),
    @posicion varchar(40),
    @dorsal tinyint,
    @id_seleccion int
as
begin
    set nocount on;

    declare @errores nvarchar(2048) = N'';

    if col_length(N'dbo.Jugador', N'nombre_cifrado') is null
       or col_length(N'dbo.Jugador', N'apellido_cifrado') is null
       or col_length(N'dbo.Jugador', N'fecha_nacimiento_cifrada') is null
        throw 54110, N'dbo.Jugador no se encuentra en estado cifrado.', 1;

    if not exists (
        select 1
        from dbo.Jugador
        where id_jugador = @id_jugador
    )
        set @errores += N'El jugador a modificar no existe. ';

    if nullif(ltrim(rtrim(@club_origen)), N'') is null
        set @errores += N'club_origen es obligatorio. ';

    if nullif(ltrim(rtrim(@apellido)), N'') is null
        set @errores += N'apellido es obligatorio. ';

    if nullif(ltrim(rtrim(@nombre)), N'') is null
        set @errores += N'nombre es obligatorio. ';

    if @fecha_nacimiento is null
        set @errores += N'fecha_nacimiento es obligatoria. ';

    if nullif(ltrim(rtrim(@posicion)), '') is null
        set @errores += N'posicion es obligatoria. ';

    if not exists (
        select 1
        from dbo.Seleccion
        where id_seleccion = @id_seleccion
    )
        set @errores += N'No existe la seleccion indicada. ';

    if @dorsal not between 1 and 26
        set @errores += N'El dorsal debe estar entre 1 y 26. ';

    if @errores <> N''
        throw 54111, @errores, 1;

    begin try
        open symmetric key Clave_Jugador
        decryption by certificate Certificado_Jugador;

        update dbo.Jugador
        set
            fecha_nacimiento_cifrada = encryptbykey(
                key_guid(N'Clave_Jugador'),
                convert(nvarchar(10), @fecha_nacimiento, 23)
            ),
            club_origen = ltrim(rtrim(@club_origen)),
            apellido_cifrado = encryptbykey(
                key_guid(N'Clave_Jugador'),
                ltrim(rtrim(@apellido))
            ),
            nombre_cifrado = encryptbykey(
                key_guid(N'Clave_Jugador'),
                ltrim(rtrim(@nombre))
            ),
            posicion = ltrim(rtrim(@posicion)),
            dorsal = @dorsal,
            id_seleccion = @id_seleccion
        where id_jugador = @id_jugador;

        close symmetric key Clave_Jugador;

        select @id_jugador as id_jugador_modificado;
    end try
    begin catch
        if exists (
            select 1
            from sys.openkeys
            where key_name = N'Clave_Jugador'
        )
            close symmetric key Clave_Jugador;

        throw;
    end catch;
end;
go


--   JUGADOR CIFRADO - BAJA

create or alter procedure abm.Jugador_Cifrado_Baja
    @id_jugador int
as
begin
    set nocount on;

    if not exists (
        select 1
        from dbo.Jugador
        where id_jugador = @id_jugador
    )
        throw 54120, N'El jugador a eliminar no existe.', 1;

    begin try
        delete from dbo.Jugador
        where id_jugador = @id_jugador;

        select @id_jugador as id_jugador_eliminado;
    end try
    begin catch
        throw 54121, N'No se pudo eliminar el jugador. Verifique relaciones con otras tablas.', 1;
    end catch;
end;
go

/*
    EJEMPLO DE ALTA DIRECTA EN ESTADO CIFRADO
    (usar un id_seleccion existente):

    exec abm.Jugador_Cifrado_Alta
        @fecha_nacimiento = '2000-01-15',
        @club_origen = N'Club de prueba',
        @apellido = N'Apellido Prueba',
        @nombre = N'Jugador Prueba',
        @posicion = 'Delantero',
        @dorsal = 20,
        @id_seleccion = 1;
*/
