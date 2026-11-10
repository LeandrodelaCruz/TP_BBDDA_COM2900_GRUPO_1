use MUNDIALDEFUTBOL;
go

/*============================================================
    Materia: Bases de Datos Aplicada
    Modulo: Reportes

    Procedimiento:
        reportes.Reporte_Ocupacion_Publicitaria

    Objetivo:
        Mostrar la ocupacion publicitaria por sede y partido,
        detallando los anunciantes exhibidos en cada espacio
        y los ingresos generados.

    Filtros opcionales:
        @id_sede
        @id_partido

    Moneda:
        costo_aplicado e ingresos se interpretan en USD.
============================================================*/

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
go

create or alter procedure reportes.Reporte_Ocupacion_Publicitaria
    @id_sede int = null,
    @id_partido int = null
as
begin
    set nocount on;

    ------------------------------------------------------------
    -- 1. VALIDACIONES
    ------------------------------------------------------------

    if @id_sede is not null and @id_sede <= 0
        throw 53001, 'El id_sede debe ser mayor que cero.', 1;

    if @id_partido is not null and @id_partido <= 0
        throw 53002, 'El id_partido debe ser mayor que cero.', 1;

    if @id_sede is not null
       and not exists (
            select 1
            from dbo.Sede
            where id_sede = @id_sede
       )
        throw 53003, 'La sede indicada no existe.', 1;

    if @id_partido is not null
       and not exists (
            select 1
            from dbo.Partido
            where id_partido = @id_partido
       )
        throw 53004, 'El partido indicado no existe.', 1;

    if @id_sede is not null
       and @id_partido is not null
       and not exists (
            select 1
            from dbo.Partido
            where id_partido = @id_partido
              and id_sede = @id_sede
       )
        throw 53005, 'El partido indicado no pertenece a la sede indicada.', 1;

    ------------------------------------------------------------
    -- 2. REPORTE
    --
    -- Una fila representa un espacio publicitario ocupado.
    -- costo_aplicado es el ingreso historico de esa exhibicion.
    -- La window function mantiene el detalle por espacio y,
    -- al mismo tiempo, calcula el ingreso total del partido.
    ------------------------------------------------------------

    select
        S.id_sede, --S: Sede
        S.nombre_estadio,
        S.ciudad,
        S.pais as pais_sede,

        P.id_partido, --P: Partido
        P.fecha,
        P.fase,
        P.horario_UTC,
        SEL1.pais as seleccion_1, --SEL1: Selec1 y SEL2: Selec2
        SEL2.pais as seleccion_2,
        P.resultado_final,

        AP.numero_espacio, --AP: Asignacion publicitaria

        A.nombre as anunciante, --A: Anunciante
        C.descripcion as campania, --C: Campania
        PP.nombre as pieza, --PP: Pieza para region
        PP.idioma,

        AP.costo_aplicado as ingreso_usd, -- costo aplicado es el costo individual

        sum(AP.costo_aplicado) over (
            partition by P.id_partido
        ) as ingreso_total_partido_usd

    from dbo.Partido P

--A partir de aca, reconstruimos toda la informacion comercial para el partido.

    inner join dbo.Sede S
        on S.id_sede = P.id_sede

    inner join dbo.Seleccion SEL1
        on SEL1.id_seleccion = P.id_seleccion_1

    inner join dbo.Seleccion SEL2
        on SEL2.id_seleccion = P.id_seleccion_2

    inner join dbo.Asignacion_Publicitaria AP
        on AP.id_partido = P.id_partido

    inner join dbo.Pieza_Publicitaria PP
        on PP.id_pieza = AP.id_pieza

    inner join dbo.Campania C
        on C.id_campania = PP.id_campania

    inner join dbo.Anunciante A
        on A.id_anunciante = C.id_anunciante

--Ese where es opcional, si vienen los parametros en null, no hace nada, sino filtra.

    where
        (@id_sede is null or P.id_sede = @id_sede)
        and
        (@id_partido is null or P.id_partido = @id_partido)

    order by
        S.nombre_estadio,
        P.fecha,
        P.id_partido,
        AP.numero_espacio;
end;
go
