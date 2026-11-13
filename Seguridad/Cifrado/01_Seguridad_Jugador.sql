/*
    Universidad Nacional de La Matanza - UNLaM
    Bases de Datos Aplicada - 2C-2026
    Grupo 01

    SEGURIDAD - INFRAESTRUCTURA DE CIFRADO DE JUGADOR

    Crea:
      1) Database Master Key (si no existe).
      2) Certificado que protege la clave simetrica.
      3) Clave simetrica AES-256 usada para cifrar/descifrar.

    Ejecutar antes de los demas scripts de cifrado.
*/

use MUNDIALDEFUTBOL;
go

set nocount on;
go


--   1. DATABASE MASTER KEY

if not exists (
    select 1
    from sys.symmetric_keys
    where name = N'##MS_DatabaseMasterKey##'
)
begin
    create master key
    encryption by password = 'Mundial2026_Grupo01_Cifrado!';

    print 'OK - Database Master Key creada.';
end
else
begin
    print 'OK - La Database Master Key ya existia.';
end;
go


 --  2. CERTIFICADO

if not exists (
    select 1
    from sys.certificates
    where name = N'Certificado_Jugador'
)
begin
    create certificate Certificado_Jugador
    with subject = 'Proteccion de datos personales de dbo.Jugador';

    print 'OK - Certificado_Jugador creado.';
end
else
begin
    print 'OK - Certificado_Jugador ya existia.';
end;
go


--   3. CLAVE SIMETRICA AES-256

if not exists (
    select 1
    from sys.symmetric_keys
    where name = N'Clave_Jugador'
)
begin
    create symmetric key Clave_Jugador
    with algorithm = AES_256
    encryption by certificate Certificado_Jugador;

    print 'OK - Clave_Jugador AES-256 creada.';
end
else
begin
    print 'OK - Clave_Jugador ya existia.';
end;
go

print '';
print 'INFRAESTRUCTURA DE CIFRADO PREPARADA CORRECTAMENTE.';
go
