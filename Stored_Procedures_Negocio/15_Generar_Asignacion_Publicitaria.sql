use MUNDIALDEFUTBOL;
go

/*============================================================
    Universidad Nacional de La Matanza
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        negocio.Generar_Asignacion_Publicitaria

    Objetivo:
        Generar hasta cuatro asignaciones publicitarias para
        un partido, priorizando los mercados cuya hora local
        esté más cerca del centro de su franja de prime time.

    Flujo:
        Partido.horario_UTC
            -> hora local por Region
            -> regiones en prime time
            -> piezas habilitadas
            -> priorización
            -> máximo 4 espacios
            -> Asignacion_Publicitaria
============================================================*/

-- Validar esquema creado por Table/00_Script_DB_Schemas_Creacion.sql
IF SCHEMA_ID(N'negocio') IS NULL
    THROW 51910, N'Falta el esquema negocio. Ejecute primero Table/00_Script_DB_Schemas_Creacion.sql.', 1;
go

create or alter procedure negocio.Generar_Asignacion_Publicitaria
    @id_partido int,
    @costo_espacio_1 decimal(14,2) = 200000.00,
    @costo_espacio_2 decimal(14,2) = 175000.00,
    @costo_espacio_3 decimal(14,2) = 150000.00,
    @costo_espacio_4 decimal(14,2) = 125000.00,
    @cantidad_candidatos int = null output,
    @cantidad_asignados int = null output
as
begin
    set nocount on;
    set xact_abort on;

    --------------------------------------------------------
    -- 1. validaciones
    --------------------------------------------------------
    if @id_partido is null or @id_partido <= 0
        throw 51501, 'El id_partido debe ser mayor que cero.', 1;

    if not exists (
        select 1
        from dbo.Partido
        where id_partido = @id_partido
    )
        throw 51502, 'El partido indicado no existe.', 1;

    if @costo_espacio_1 < 0 or @costo_espacio_2 < 0
       or @costo_espacio_3 < 0 or @costo_espacio_4 < 0
        throw 51503, 'Los costos de los espacios no pueden ser negativos.', 1;

    if object_id(N'abm.Asignacion_Publicitaria_Alta', N'P') is null
        throw 51504, 'No existe abm.Asignacion_Publicitaria_Alta.', 1;

    if object_id(N'abm.Asignacion_Publicitaria_Modificacion', N'P') is null
        throw 51505, 'No existe abm.Asignacion_Publicitaria_Modificacion.', 1;

    if object_id(N'abm.Asignacion_Publicitaria_Baja', N'P') is null
        throw 51506, 'No existe abm.Asignacion_Publicitaria_Baja.', 1;

    --------------------------------------------------------
    -- 2. obtener horario UTC del partido
    --------------------------------------------------------
    declare @horario_utc datetime2(0);

    select @horario_utc = horario_UTC
    from dbo.Partido
    where id_partido = @id_partido;

    --------------------------------------------------------
    -- 3. validar husos horarios soportados
    --------------------------------------------------------
    if exists (
        select 1
        from dbo.Region R
        inner join dbo.Pieza_Para_Region PR on PR.id_region = R.id_region
        where R.huso_horario not in (
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
        throw 51507, 'Existe una region con un huso horario sin mapeo.', 1;

    --------------------------------------------------------
    -- 4. candidatos
    --------------------------------------------------------
    create table #Candidatos ( --Tabla temporal para almacenar los resultados candidatos
        id_region int not null,
        region nvarchar(80) not null,
        id_pieza int not null,
        pieza nvarchar(500) not null,
        hora_local datetime2(0) not null,
        hora_prime_inicio time(0) not null,
        hora_prime_fin time(0) not null,
        distancia_centro_prime int not null
    );

    ;with PiezaPorRegion as ( --PRIMER CTE: Enumera secuencialmente las piezas publicitarias disponibles para cda region
        select
            PR.id_region,
            PR.id_pieza,
            row_number() over (
                partition by PR.id_region
                order by PR.id_pieza
            ) as numero_pieza
        from dbo.Pieza_Para_Region PR
    ),
    RegionConHora as ( --SEGUNDA CTE: COnvierte una hora UTC Base a la hora local exacta de cada region
        select                  -- usa at time zone, convierte el estandar IANA al formato que utiliza windows sql server de manera interna
            R.id_region,
            R.nombre as region,
            P.id_pieza,
            P.nombre as pieza,
            R.hora_prime_inicio,
            R.hora_prime_fin,
            case R.huso_horario
                when 'America/Argentina/Buenos_Aires' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'Argentina Standard Time' as datetime2(0))
                when 'America/Sao_Paulo' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'E. South America Standard Time' as datetime2(0))
                when 'Europe/Paris' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'Romance Standard Time' as datetime2(0))
                when 'America/New_York' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'Eastern Standard Time' as datetime2(0))
                when 'Europe/Berlin' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'W. Europe Standard Time' as datetime2(0))
                when 'Europe/Madrid' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'Romance Standard Time' as datetime2(0))
                when 'Europe/London' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'GMT Standard Time' as datetime2(0))
                when 'America/Mexico_City' then
                    cast((@horario_utc at time zone 'UTC') at time zone 'Central Standard Time (Mexico)' as datetime2(0))
            end as hora_local
        from dbo.Region R
        inner join PiezaPorRegion PR
            on PR.id_region = R.id_region
           and PR.numero_pieza = 1
        inner join dbo.Pieza_Publicitaria P
            on P.id_pieza = PR.id_pieza
    )
    insert into #Candidatos (
        id_region, region, id_pieza, pieza, hora_local,
        hora_prime_inicio, hora_prime_fin, distancia_centro_prime
    )
    select
        RH.id_region,
        RH.region,
        RH.id_pieza,
        RH.pieza,
        RH.hora_local,
        RH.hora_prime_inicio,
        RH.hora_prime_fin,
        abs(
            datediff(minute, cast('00:00:00' as time), cast(RH.hora_local as time)) -- Transforma las horas a minutos
            - (
                datediff(minute, cast('00:00:00' as time), RH.hora_prime_inicio)
                + datediff(minute, cast('00:00:00' as time), RH.hora_prime_fin)
              ) / 2
        )
    from RegionConHora RH
    where cast(RH.hora_local as time) >= RH.hora_prime_inicio
      and cast(RH.hora_local as time) < RH.hora_prime_fin; --Claramente la hora local debe estar estrictamente entre prime inicio y prime fin

    select @cantidad_candidatos = count(*)
    from #Candidatos;

    --------------------------------------------------------
    -- 5. priorizar y elegir máximo 4
    --------------------------------------------------------
    create table #Seleccionados ( -- Tabla temporal para guardar los ganadores
        numero_espacio tinyint not null,
        id_region int not null,
        region nvarchar(80) not null,
        id_pieza int not null,
        pieza nvarchar(500) not null,
        hora_local datetime2(0) not null,
        distancia_centro_prime int not null, -- Incorporo
        costo_aplicado decimal(14,2) not null -- Incorporo
    );

    ;with Rankeados as ( -- Arma un ranking por prioridad
        select
            C.*,
            row_number() over (
                order by C.distancia_centro_prime asc, C.id_region asc
            ) as prioridad
        from #Candidatos C
    )
    insert into #Seleccionados (
        numero_espacio, id_region, region, id_pieza, pieza,
        hora_local, distancia_centro_prime, costo_aplicado
    )
    select
        cast(prioridad as tinyint),
        id_region,
        region,
        id_pieza,
        pieza,
        hora_local,
        distancia_centro_prime,
        case prioridad
            when 1 then @costo_espacio_1
            when 2 then @costo_espacio_2
            when 3 then @costo_espacio_3
            when 4 then @costo_espacio_4
        end
    from Rankeados
    where prioridad <= 4; --FIltra el top 4

    select @cantidad_asignados = count(*)
    from #Seleccionados;

    --------------------------------------------------------
    -- 6. persistir asignaciones de forma atómica
    --------------------------------------------------------
    begin try
        begin transaction;

        declare
            @numero_espacio tinyint,
            @id_pieza int,
            @id_pieza_actual int,
            @costo_aplicado decimal(14,2),
            @id_asignacion int,
            @id_asignacion_nueva int;

        declare cursor_asignaciones cursor local fast_forward for
            select numero_espacio, id_pieza, costo_aplicado
            from #Seleccionados
            order by numero_espacio;

        open cursor_asignaciones;
        fetch next from cursor_asignaciones
            into @numero_espacio, @id_pieza, @costo_aplicado;

        while @@fetch_status = 0
        begin
            set @id_asignacion = null;
            set @id_pieza_actual = null;
            set @id_asignacion_nueva = null;

            select
                @id_asignacion = id_asignacion,
                @id_pieza_actual = id_pieza
            from dbo.Asignacion_Publicitaria
            where id_partido = @id_partido
              and numero_espacio = @numero_espacio;

            -- caso 1: el espacio no existe -> alta
            if @id_asignacion is null
            begin
                exec abm.Asignacion_Publicitaria_Alta
                    @id_partido = @id_partido,
                    @id_pieza = @id_pieza,
                    @numero_espacio = @numero_espacio,
                    @costo_aplicado = @costo_aplicado,
                    @id_asignacion = @id_asignacion_nueva output;
            end
            -- caso 2: misma pieza -> actualizar costo
            else if @id_pieza_actual = @id_pieza
            begin
                exec abm.Asignacion_Publicitaria_Modificacion
                    @id_asignacion = @id_asignacion,
                    @costo_aplicado = @costo_aplicado;
            end
            -- caso 3: cambió la pieza -> baja + alta
            else
            begin
                exec abm.Asignacion_Publicitaria_Baja
                    @id_asignacion = @id_asignacion;

                exec abm.Asignacion_Publicitaria_Alta
                    @id_partido = @id_partido,
                    @id_pieza = @id_pieza,
                    @numero_espacio = @numero_espacio,
                    @costo_aplicado = @costo_aplicado,
                    @id_asignacion = @id_asignacion_nueva output;
            end;

            fetch next from cursor_asignaciones
                into @numero_espacio, @id_pieza, @costo_aplicado;
        end;

        close cursor_asignaciones;
        deallocate cursor_asignaciones;

        ----------------------------------------------------
        -- eliminar asignaciones viejas que ya no aplican
        ----------------------------------------------------
        declare @id_asignacion_baja int;

        declare cursor_bajas cursor local fast_forward for
            select AP.id_asignacion
            from dbo.Asignacion_Publicitaria AP
            where AP.id_partido = @id_partido
              and not exists (
                  select 1
                  from #Seleccionados S
                  where S.numero_espacio = AP.numero_espacio
              );

        open cursor_bajas;
        fetch next from cursor_bajas into @id_asignacion_baja;

        while @@fetch_status = 0
        begin
            exec abm.Asignacion_Publicitaria_Baja
                @id_asignacion = @id_asignacion_baja;

            fetch next from cursor_bajas into @id_asignacion_baja;
        end;

        close cursor_bajas;
        deallocate cursor_bajas;

        commit transaction;
    end try
    begin catch
        if xact_state() <> 0
            rollback transaction;

        if cursor_status('local', 'cursor_asignaciones') >= 0
            close cursor_asignaciones;
        if cursor_status('local', 'cursor_asignaciones') > -3
            deallocate cursor_asignaciones;

        if cursor_status('local', 'cursor_bajas') >= 0
            close cursor_bajas;
        if cursor_status('local', 'cursor_bajas') > -3
            deallocate cursor_bajas;

        throw;
    end catch;

    --------------------------------------------------------
    -- 7. resultados
    --------------------------------------------------------
    select
        @id_partido as id_partido,
        @horario_utc as horario_UTC,
        @cantidad_candidatos as mercados_candidatos,
        @cantidad_asignados as espacios_asignados;

    select
        id_region, region, id_pieza, pieza, hora_local,
        hora_prime_inicio, hora_prime_fin, distancia_centro_prime
    from #Candidatos
    order by distancia_centro_prime, id_region;

    select
        numero_espacio, id_region, region, hora_local,
        id_pieza, pieza, costo_aplicado, distancia_centro_prime
    from #Seleccionados
    order by numero_espacio;
end;
go
