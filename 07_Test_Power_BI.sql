
USE MUNDIALDEFUTBOL
go

-- Check si ya se ejecuto simulaciones

select * from dbo.Incidencia
go
select * from dbo.Sustitucion
go

-- Borrado para mostrar db vacia
delete from dbo.Incidencia
go

delete from dbo.Sustitucion
go


-- Se completan de nuevo
EXEC test.Completar_Partidos_Test;
GO
