use MUNDIALDEFUTBOL;
go

/*============================================================
    Materia: Bases de Datos Aplicada
    Modulo: Test de reportes

    Procedimiento:
        test.Reporte_Ocupacion_Publicitaria_Test

    Objetivo:
        Verificar que el reporte de ocupacion publicitaria:
        - devuelva las asignaciones reales del partido;
        - use solamente espacios 1..4;
        - no repita espacios;
        - muestre costos validos;
        - calcule correctamente el ingreso total;
        - respete los filtros por partido y por sede.
============================================================*/

IF SCHEMA_ID(N'test') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
go

create or alter procedure test.Reporte_Ocupacion_Publicitaria_Test
as
begin
    set nocount on;

 -- 1. VALIDAR DEPENDENCIAS, es decir, que existan los objetos necesarios antes de ejecutar el test.

    if object_id(N'reportes.Reporte_Ocupacion_Publicitaria', N'P') is null
        throw 53100, 'TEST FALLIDO: no existe reportes.Reporte_Ocupacion_Publicitaria.', 1;

    if object_id(N'dbo.Asignacion_Publicitaria', N'U') is null
        throw 53101, 'TEST FALLIDO: no existe dbo.Asignacion_Publicitaria.', 1;

    ------------------------------------------------------------
    -- 2. ELEGIR UN PARTIDO CON ASIGNACIONES
    -- Se toma el que tenga mayor cantidad de espacios ocupados.
    -- El id_partido solo se usa como desempate tecnico.

    declare
        @id_partido int,
        @id_sede int;

    select top (1)
        @id_partido = AP.id_partido,
        @id_sede = P.id_sede
    from dbo.Asignacion_Publicitaria AP
    inner join dbo.Partido P
        on P.id_partido = AP.id_partido
    group by
        AP.id_partido,
        P.id_sede
    order by
        count(*) desc, --Aca ordenamos todos los partidos
        AP.id_partido desc; --Entra el que tiene id_partido mas chico

    if @id_partido is null -- valida que encontro 1
        throw 53102, 'TEST FALLIDO: no existen asignaciones publicitarias para probar el reporte.', 1;

    print 'Partido seleccionado para el test: ' + cast(@id_partido as varchar(20));
    print 'Sede seleccionada para el test: ' + cast(@id_sede as varchar(20));

    ------------------------------------------------------------
    -- 3. CAPTURAR EL REPORTE FILTRADO POR PARTIDO
    ------------------------------------------------------------
--Esta tabla tiene la estructura del reporte
    create table #Resultado (
        id_sede int not null,
        nombre_estadio nvarchar(120) not null,
        ciudad nvarchar(80) not null,
        pais_sede nvarchar(80) not null,

        id_partido int not null,
        fecha date not null,
        fase varchar(30) not null,
        horario_UTC datetime2(0) not null,
        seleccion_1 nvarchar(200) not null,
        seleccion_2 nvarchar(200) not null,
        resultado_final varchar(20) null,

        numero_espacio tinyint not null,

        anunciante nvarchar(120) not null,
        campania nvarchar(500) not null,
        pieza nvarchar(500) not null,
        idioma nvarchar(100) null,

        ingreso_usd decimal(14,2) not null,
        ingreso_total_partido_usd decimal(38,2) null
    );
-- Aca ejecutamos el reporte para el partido seleccionado y guardamos las filas que devuelve en resultado
    insert into #Resultado
    exec reportes.Reporte_Ocupacion_Publicitaria
        @id_partido = @id_partido;

    ------------------------------------------------------------
    -- 4. EL REPORTE DEBE DEVOLVER FILAS
    ------------------------------------------------------------
--Aca se verifica que el reporte devolvio datos
    if not exists (select 1 from #Resultado)
        throw 53103, 'TEST FALLIDO: el reporte no devolvio filas para el partido seleccionado.', 1;

    print 'OK - El reporte devolvio datos.';
    ------------------------------------------------------------
    -- 5. LA CANTIDAD DE FILAS DEBE COINCIDIR CON LAS
    --    ASIGNACIONES REALES DEL PARTIDO
    ------------------------------------------------------------
--Aca verificamos que si hay 4 asignaciones, debe devolver 4 filas
    declare
        @cantidad_esperada int,
        @cantidad_reporte int;

    select
        @cantidad_esperada = count(*)
    from dbo.Asignacion_Publicitaria
    where id_partido = @id_partido;

    select
        @cantidad_reporte = count(*)
    from #Resultado;

    if @cantidad_esperada <> @cantidad_reporte
        throw 53104, 'TEST FALLIDO: la cantidad de filas del reporte no coincide con las asignaciones del partido.', 1;

    print 'OK - La cantidad de filas coincide con las asignaciones reales.';

    ------------------------------------------------------------
    -- 6. ESPACIOS VALIDOS 1..4
    ------------------------------------------------------------

    if exists (
        select 1
        from #Resultado
        where numero_espacio not between 1 and 4
    )
        throw 53105, 'TEST FALLIDO: existe un numero de espacio fuera del rango 1..4.', 1;

    print 'OK - Todos los espacios estan entre 1 y 4.';

    ------------------------------------------------------------
    -- 7. SIN ESPACIOS DUPLICADOS PARA EL PARTIDO
    ------------------------------------------------------------

    if exists (
        select numero_espacio
        from #Resultado
        group by numero_espacio
        having count(*) > 1
    )
        throw 53106, 'TEST FALLIDO: el reporte contiene espacios duplicados.', 1;
-- En un mismo partido no puede haber dos publicidades ocupando el mismo numero de espacio
    print 'OK - No existen espacios duplicados.';

    ------------------------------------------------------------
    -- 8. COSTOS VALIDOS Y DATOS COMERCIALES COMPLETOS
    ------------------------------------------------------------

    if exists (
        select 1
        from #Resultado
        where ingreso_usd < 0
           or anunciante is null
           or ltrim(rtrim(anunciante)) = N''
           or campania is null
           or ltrim(rtrim(campania)) = N''
           or pieza is null
           or ltrim(rtrim(pieza)) = N''
    )
        throw 53107, 'TEST FALLIDO: existe un costo invalido o faltan datos comerciales.', 1;

    print 'OK - Costos y datos comerciales validos.';

    ------------------------------------------------------------
    -- 9. VERIFICAR INGRESO TOTAL DEL PARTIDO
    ------------------------------------------------------------
--Aca verificamos que el total corresponda con la cantidad de espacios ocupados
    declare @total_esperado decimal(38,2);

    select
        @total_esperado = sum(cast(costo_aplicado as decimal(38,2)))
    from dbo.Asignacion_Publicitaria
    where id_partido = @id_partido;

    if exists (
        select 1
        from #Resultado
        where ingreso_total_partido_usd <> @total_esperado
           or ingreso_total_partido_usd is null
    )
        throw 53108, 'TEST FALLIDO: el ingreso total del partido no coincide con la suma de sus espacios.', 1;

    print 'OK - El ingreso total del partido es correcto.';

    ------------------------------------------------------------
    -- 10. VERIFICAR FILTRO POR PARTIDO
    ------------------------------------------------------------

    if exists (
        select 1
        from #Resultado
        where id_partido <> @id_partido
    )
        throw 53109, 'TEST FALLIDO: el filtro por partido devolvio datos de otro partido.', 1;

    print 'OK - El filtro por partido funciona correctamente.';

    ------------------------------------------------------------
    -- 11. VERIFICAR FILTRO POR SEDE
    ------------------------------------------------------------

    select top (0) *
    into #ResultadoSede
    from #Resultado;

    insert into #ResultadoSede
    exec reportes.Reporte_Ocupacion_Publicitaria
        @id_sede = @id_sede;

    if exists (
        select 1
        from #ResultadoSede
        where id_sede <> @id_sede
    )
        throw 53110, 'TEST FALLIDO: el filtro por sede devolvio datos de otra sede.', 1;

    print 'OK - El filtro por sede funciona correctamente.';

    ------------------------------------------------------------
    -- 12. RESULTADO FINAL
    ------------------------------------------------------------

    print '';
    print 'TEST COMPLETADO CORRECTAMENTE.';

    select
        @id_partido as id_partido_probado,
        @id_sede as id_sede_probada,
        @cantidad_reporte as espacios_reportados,
        @total_esperado as ingreso_total_usd;

    select *
    from #Resultado
    order by numero_espacio;
end;
go

--Ejecutar test:
exec test.Reporte_Ocupacion_Publicitaria_Test;

--Ejecutar SP:
/*
exec reportes.Reporte_Ocupacion_Publicitaria;
*/