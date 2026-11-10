/*
    Universidad: Universidad Nacional de La Matanza - UNLaM
    Materia: Bases de Datos Aplicada - 2C-2026
    Comisión: 01-2900
    Grupo 01:
    - Caro, Nicolás Darío
    - Clara, Lucas
    - De La Cruz, Leandro Ariel
    - Rodríguez, Elías Uriel

    Objetivo:
    Probar reportes.Reporte_Matriz_Prime_Time.

    Resultado esperado:
    - Cada fila representa un partido.
    - Cada mercado contiene solamente SI o NO.
    - cantidad_mercados_prime coincide con la cantidad de SI.
    - El partido 42 debe presentar mas de cuatro mercados en prime time.
    - Los filtros por partido y por fase deben funcionar correctamente.
*/

use MUNDIALDEFUTBOL;
go

IF SCHEMA_ID(N'test') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
go

create or alter procedure test.Reporte_Matriz_Prime_Time_Test
as
begin
    set nocount on;

    if object_id(
        N'reportes.Reporte_Matriz_Prime_Time',
        N'P'
    ) is null
        throw 53301, 'TEST FALLIDO: no existe reportes.Reporte_Matriz_Prime_Time.', 1;

    create table #Resultado
    (
        id_partido int not null,
        fecha date not null,
        fase varchar(30) not null,
        seleccion_1 nvarchar(200) not null,
        seleccion_2 nvarchar(200) not null,
        horario_UTC datetime2(0) not null,
        cantidad_mercados_prime int not null,
        [Argentina] varchar(2) null,
        [Brasil] varchar(2) null,
        [Francia] varchar(2) null,
        [Estados Unidos] varchar(2) null,
        [Alemania] varchar(2) null,
        [España] varchar(2) null,
        [Reino Unido] varchar(2) null,
        [México] varchar(2) null
    );

    insert into #Resultado
    exec reportes.Reporte_Matriz_Prime_Time;

    if not exists (
        select 1
        from #Resultado
    )
        throw 53302, 'TEST FALLIDO: el reporte no devolvio partidos.', 1;

    print 'OK - El reporte devolvio partidos.';

    if exists (
        select 1
        from #Resultado
        where [Argentina] not in ('SI', 'NO')
           or [Brasil] not in ('SI', 'NO')
           or [Francia] not in ('SI', 'NO')
           or [Estados Unidos] not in ('SI', 'NO')
           or [Alemania] not in ('SI', 'NO')
           or [España] not in ('SI', 'NO')
           or [Reino Unido] not in ('SI', 'NO')
           or [México] not in ('SI', 'NO')
           or [Argentina] is null
           or [Brasil] is null
           or [Francia] is null
           or [Estados Unidos] is null
           or [Alemania] is null
           or [España] is null
           or [Reino Unido] is null
           or [México] is null
    )
        throw 53303, 'TEST FALLIDO: existe un mercado con valor distinto de SI/NO.', 1;

    print 'OK - Todos los mercados contienen SI o NO.';

    if exists (
        select 1
        from #Resultado
        where cantidad_mercados_prime <>
            case when [Argentina] = 'SI' then 1 else 0 end
          + case when [Brasil] = 'SI' then 1 else 0 end
          + case when [Francia] = 'SI' then 1 else 0 end
          + case when [Estados Unidos] = 'SI' then 1 else 0 end
          + case when [Alemania] = 'SI' then 1 else 0 end
          + case when [España] = 'SI' then 1 else 0 end
          + case when [Reino Unido] = 'SI' then 1 else 0 end
          + case when [México] = 'SI' then 1 else 0 end
    )
        throw 53304, 'TEST FALLIDO: cantidad_mercados_prime no coincide con la matriz.', 1;

    print 'OK - La cantidad de mercados prime coincide con los SI de la matriz.';

    if not exists (
        select 1
        from dbo.Partido
        where id_partido = 42
    )
        throw 53305, 'TEST FALLIDO: no existe el partido 42 requerido para esta prueba.', 1;

    if not exists (
        select 1
        from #Resultado
        where id_partido = 42
          and cantidad_mercados_prime > 4
    )
        throw 53306, 'TEST FALLIDO: el partido 42 no presenta mas de cuatro mercados en prime time.', 1;

    print 'OK - El partido 42 presenta mas de cuatro mercados en prime time.';

    create table #ResultadoPartido
    (
        id_partido int not null,
        fecha date not null,
        fase varchar(30) not null,
        seleccion_1 nvarchar(200) not null,
        seleccion_2 nvarchar(200) not null,
        horario_UTC datetime2(0) not null,
        cantidad_mercados_prime int not null,
        [Argentina] varchar(2) null,
        [Brasil] varchar(2) null,
        [Francia] varchar(2) null,
        [Estados Unidos] varchar(2) null,
        [Alemania] varchar(2) null,
        [España] varchar(2) null,
        [Reino Unido] varchar(2) null,
        [México] varchar(2) null
    );

    insert into #ResultadoPartido
    exec reportes.Reporte_Matriz_Prime_Time
        @id_partido = 42;

    if (
        select count(*)
        from #ResultadoPartido
    ) <> 1
        throw 53307, 'TEST FALLIDO: el filtro por partido no devolvio exactamente una fila.', 1;

    if exists (
        select 1
        from #ResultadoPartido
        where id_partido <> 42
    )
        throw 53308, 'TEST FALLIDO: el filtro por partido devolvio otro partido.', 1;

    print 'OK - El filtro por partido funciona correctamente.';

    create table #ResultadoFase
    (
        id_partido int not null,
        fecha date not null,
        fase varchar(30) not null,
        seleccion_1 nvarchar(200) not null,
        seleccion_2 nvarchar(200) not null,
        horario_UTC datetime2(0) not null,
        cantidad_mercados_prime int not null,
        [Argentina] varchar(2) null,
        [Brasil] varchar(2) null,
        [Francia] varchar(2) null,
        [Estados Unidos] varchar(2) null,
        [Alemania] varchar(2) null,
        [España] varchar(2) null,
        [Reino Unido] varchar(2) null,
        [México] varchar(2) null
    );

    insert into #ResultadoFase
    exec reportes.Reporte_Matriz_Prime_Time
        @fase = 'FINAL';

    if not exists (
        select 1
        from #ResultadoFase
    )
        throw 53309, 'TEST FALLIDO: el filtro FINAL no devolvio partidos.', 1;

    if exists (
        select 1
        from #ResultadoFase
        where fase <> 'FINAL'
    )
        throw 53310, 'TEST FALLIDO: el filtro por fase devolvio otra fase.', 1;

    print 'OK - El filtro por fase funciona correctamente.';

    print '';
    print 'TEST COMPLETADO CORRECTAMENTE.';

    select
        id_partido,
        fecha,
        fase,
        seleccion_1,
        seleccion_2,
        horario_UTC,
        cantidad_mercados_prime,
        [Argentina],
        [Brasil],
        [Francia],
        [Estados Unidos],
        [Alemania],
        [España],
        [Reino Unido],
        [México]
    from #Resultado
    order by fecha, id_partido;
end;
go

-- Ejecutar:
exec test.Reporte_Matriz_Prime_Time_Test;
