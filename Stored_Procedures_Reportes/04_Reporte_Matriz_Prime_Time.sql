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
    Generar una matriz de prime time por partido y mercado.
    Para cada partido se convierte horario_UTC a la hora local de
    cada región configurada, se determina si cae dentro de su franja
    de prime time y se presenta el resultado mediante un PIVOT estático.

    Decisión de diseño:
    No se utiliza SQL dinámico. Los mercados del PIVOT se declaran
    explícitamente para respetar la consigna de evitar SQL dinámico
    salvo que sea absolutamente necesario.
*/

use MUNDIALDEFUTBOL;
go

IF SCHEMA_ID(N'reportes') IS NULL
    THROW 51910,N'Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.',1;
go

create or alter procedure reportes.Reporte_Matriz_Prime_Time
    @id_partido int = null,
    @fase varchar(30) = null
as
begin
    set nocount on;

    ------------------------------------------------------------
    -- 1. VALIDACIONES DE PARAMETROS
    ------------------------------------------------------------

    if @id_partido is not null and @id_partido <= 0
        throw 53201, 'El id_partido debe ser mayor que cero.', 1;

    if @id_partido is not null
       and not exists (
            select 1
            from dbo.Partido
            where id_partido = @id_partido
       )
        throw 53202, 'El partido indicado no existe.', 1;

    if @fase is not null
       and ltrim(rtrim(@fase)) = ''
        throw 53203, 'La fase no puede ser una cadena vacia.', 1;

    if @fase is not null
       and not exists (
            select 1
            from dbo.Partido
            where fase = @fase
       )
        throw 53204, 'La fase indicada no existe en los partidos cargados.', 1;

    ------------------------------------------------------------
    -- 2. VALIDAR LOS OCHO MERCADOS DEL PIVOT ESTATICO
    ------------------------------------------------------------

    if exists (
        select nombre_esperado
        from (
            values
                (N'Argentina'),
                (N'Brasil'),
                (N'Francia'),
                (N'Estados Unidos'),
                (N'Alemania'),
                (N'España'),
                (N'Reino Unido'),
                (N'México')
        ) E(nombre_esperado)
        where not exists (
            select 1
            from dbo.Region R
            where R.nombre = E.nombre_esperado
        )
    )
        throw 53205, 'Falta al menos uno de los mercados requeridos por el PIVOT estatico.', 1;

    ------------------------------------------------------------
    -- 3. VALIDAR HUSOS HORARIOS SOPORTADOS
    ------------------------------------------------------------

    if exists (
        select 1
        from dbo.Region
        where nombre in (
            N'Argentina',
            N'Brasil',
            N'Francia',
            N'Estados Unidos',
            N'Alemania',
            N'España',
            N'Reino Unido',
            N'México'
        )
        and huso_horario not in (
            'America/Argentina/Buenos_Aires',
            'America/Sao_Paulo',
            'Europe/Paris',
            'America/New_York',
            'Europe/Berlin',
            'Europe/Madrid',
            'Europe/London',
            'America/Mexico_City'
        )
    )
        throw 53206, 'Existe un huso horario no soportado por el reporte.', 1;

    ------------------------------------------------------------
    -- 4. PARTIDO x REGION
    ------------------------------------------------------------

    ;with PartidoRegion as
    ( --primero tomamos los datos del partido
        select
            P.id_partido,
            P.fecha,
            P.fase,
            P.horario_UTC,
            S1.pais as seleccion_1,
            S2.pais as seleccion_2,
            R.nombre as region,
            R.hora_prime_inicio,
            R.hora_prime_fin,
--Obtenemos el huso horario de esa region
            case R.huso_horario
                when 'America/Argentina/Buenos_Aires'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'Argentina Standard Time'
                        as datetime2(0)
                    )
                when 'America/Sao_Paulo'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'E. South America Standard Time'
                        as datetime2(0)
                    )
                when 'Europe/Paris'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'Romance Standard Time'
                        as datetime2(0)
                    )
                when 'America/New_York'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'Eastern Standard Time'
                        as datetime2(0)
                    )
                when 'Europe/Berlin'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'W. Europe Standard Time'
                        as datetime2(0)
                    )
                when 'Europe/Madrid'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'Romance Standard Time'
                        as datetime2(0)
                    )
                when 'Europe/London'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'GMT Standard Time'
                        as datetime2(0)
                    )
                when 'America/Mexico_City'
                    then cast(
                        (P.horario_UTC at time zone 'UTC')
                        at time zone 'Central Standard Time (Mexico)'
                        as datetime2(0)
                    )
            end as hora_local

        from dbo.Partido P

        inner join dbo.Seleccion S1
            on S1.id_seleccion = P.id_seleccion_1

        inner join dbo.Seleccion S2
            on S2.id_seleccion = P.id_seleccion_2

        cross join dbo.Region R -- Combinamos cada partido con cada region

        where R.nombre in (
            N'Argentina',
            N'Brasil',
            N'Francia',
            N'Estados Unidos',
            N'Alemania',
            N'España',
            N'Reino Unido',
            N'México'
        ) -- con este where limitamos las regiones
        and (@id_partido is null or P.id_partido = @id_partido)
        and (@fase is null or P.fase = @fase)
    ),

    EstadoPrime as --segunda CTE
    (
        select
            id_partido,
            fecha,
            fase,
            horario_UTC,
            seleccion_1,
            seleccion_2,
            region,
            case -- Aca tomamos los datos de la CTE anterior y verfificamos si cae en horario prime
                when cast(hora_local as time) >= hora_prime_inicio
                 and cast(hora_local as time) < hora_prime_fin
                    then 'SI'
                else 'NO'
            end as en_prime
        from PartidoRegion
    ),

    ConteoPrime as
    ( -- Aca contamos cuantos mercados prime caen en el horario de ese partido
        select
            id_partido,
            sum(
                case
                    when en_prime = 'SI' then 1 -- sumamos los SI
                    else 0
                end
            ) as cantidad_mercados_prime
        from EstadoPrime
        group by id_partido
    ),

    MatrizPrime as -- aca aplicamos pivot y transformamos los valores de region en columnas
    (
        select
            id_partido,
            fecha,
            fase,
            horario_UTC,
            seleccion_1,
            seleccion_2,
            [Argentina],
            [Brasil],
            [Francia],
            [Estados Unidos],
            [Alemania],
            [España],
            [Reino Unido],
            [México]
        from
        (
            select
                id_partido,
                fecha,
                fase,
                horario_UTC,
                seleccion_1,
                seleccion_2,
                region, -- IMP
                en_prime -- IMP
            from EstadoPrime
        ) Fuente
        pivot
        (
            max(en_prime) -- Use max simplemente para PIVOT, en realidad existe una fila x partido y region
            for region in
            (
                [Argentina],
                [Brasil],
                [Francia],
                [Estados Unidos],
                [Alemania],
                [España],
                [Reino Unido],
                [México]
            )
        ) P
    )

    select -- mostramos los datos del partido
        M.id_partido,
        M.fecha,
        M.fase,
        M.seleccion_1,
        M.seleccion_2,
        M.horario_UTC,
        C.cantidad_mercados_prime,
        M.[Argentina],
        M.[Brasil],
        M.[Francia],
        M.[Estados Unidos],
        M.[Alemania],
        M.[España],
        M.[Reino Unido],
        M.[México]

    from MatrizPrime M

    inner join ConteoPrime C
        on C.id_partido = M.id_partido

    order by
        M.fecha,
        M.id_partido;
end;
go

-- Ejemplos:
-- exec reportes.Reporte_Matriz_Prime_Time;
--
-- exec reportes.Reporte_Matriz_Prime_Time
--     @fase = 'GRUPOS';
--
-- exec reportes.Reporte_Matriz_Prime_Time
--     @id_partido = 42;
