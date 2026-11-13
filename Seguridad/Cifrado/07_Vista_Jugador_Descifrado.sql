use MUNDIALDEFUTBOL;
go

create or alter view dbo.vw_Jugador_Descifrado
as
    select
        J.id_jugador,
        J.id_seleccion,

        convert(
            nvarchar(60),
            decryptbykeyautocert(
                cert_id('Certificado_Jugador'),
                null,
                J.nombre_cifrado
            )
        ) as nombre,

        convert(
            nvarchar(60),
            decryptbykeyautocert(
                cert_id('Certificado_Jugador'),
                null,
                J.apellido_cifrado
            )
        ) as apellido,

        convert(
            date,
            convert(
                nvarchar(10),
                decryptbykeyautocert(
                    cert_id('Certificado_Jugador'),
                    null,
                    J.fecha_nacimiento_cifrada
                )
            ),
            23
        ) as fecha_nacimiento,

        J.club_origen,
        J.posicion,
        J.dorsal

    from dbo.Jugador J;
go

--PRUEBAS

-- Datos realmente almacenados
--select * from dbo.Jugador;

-- Datos con al vista
select * from dbo.vw_Jugador_Descifrado;