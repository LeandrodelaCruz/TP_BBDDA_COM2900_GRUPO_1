use MUNDIALDEFUTBOL;
go


/*============================================================
    Universidad Nacional de La Matanza
    Materia: Bases de Datos Aplicada
    Grupo: 1

    Procedimiento:
        negocio.Generar_Asignacion_Publicitaria

    Objetivo:
        Generar las asignaciones publicitarias correspondientes
        a un partido.

    Funcionamiento general:

        Partido.horario_UTC
                ↓
        convertir a hora local de cada Region
                ↓
        verificar prime time
                ↓
        buscar piezas habilitadas mediante Pieza_Para_Region
                ↓
        determinar mercados candidatos
                ↓
        si existen más de 4, priorizar
                ↓
        seleccionar máximo 4
                ↓
        Asignacion_Publicitaria

    Criterio de priorización:
        Se priorizan las regiones cuya hora local se encuentre
        más cerca del centro de su franja de prime time.

    La operación completa se realiza dentro de una transacción.
============================================================*/


------------------------------------------------------------
-- crear esquema negocio si no existe
------------------------------------------------------------

if schema_id(N'negocio') is null
begin
    exec(N'create schema negocio');
end;
go


------------------------------------------------------------
-- procedimiento
------------------------------------------------------------

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
    -- 1. validar partido
    --------------------------------------------------------

    if @id_partido is null
       or @id_partido <= 0
    begin

        throw 51501,
              'El id_partido debe ser mayor que cero.',
              1;

    end;


    if not exists
    (
        select 1
        from dbo.Partido
        where id_partido = @id_partido
    )
    begin

        throw 51502,
              'El partido indicado no existe.',
              1;

    end;


    --------------------------------------------------------
    -- 2. validar costos
    --------------------------------------------------------

    if @costo_espacio_1 < 0
       or @costo_espacio_2 < 0
       or @costo_espacio_3 < 0
       or @costo_espacio_4 < 0
    begin

        throw 51503,
              'Los costos de los espacios no pueden ser negativos.',
              1;

    end;


    --------------------------------------------------------
    -- 3. validar ABM necesarios
    --------------------------------------------------------

    if object_id(
        N'abm.Asignacion_Publicitaria_Alta',
        N'P'
    ) is null
    begin

        throw 51504,
              'No existe abm.Asignacion_Publicitaria_Alta.',
              1;

    end;


    if object_id(
        N'abm.Asignacion_Publicitaria_Modificacion',
        N'P'
    ) is null
    begin

        throw 51505,
              'No existe abm.Asignacion_Publicitaria_Modificacion.',
              1;

    end;


    if object_id(
        N'abm.Asignacion_Publicitaria_Baja',
        N'P'
    ) is null
    begin

        throw 51506,
              'No existe abm.Asignacion_Publicitaria_Baja.',
              1;

    end;


    --------------------------------------------------------
    -- 4. obtener horario UTC del partido
    --------------------------------------------------------

    declare @horario_utc datetime2(0);


    select
        @horario_utc = horario_UTC
    from dbo.Partido
    where id_partido = @id_partido;


    --------------------------------------------------------
    -- 5. validar husos horarios configurados
    --
    -- dbo.Region almacena identificadores IANA.
    --
    -- Para utilizar AT TIME ZONE hacemos posteriormente
    -- el mapeo correspondiente.
    --------------------------------------------------------

    if exists
    (
        select 1

        from dbo.Region R

        inner join dbo.Pieza_Para_Region PR
            on PR.id_region = R.id_region

        where R.huso_horario not in
        (
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
    begin

        throw 51507,
              'Existe una region con un huso horario sin mapeo.',
              1;

    end;


    --------------------------------------------------------
    -- 6. tabla temporal de candidatos
    --------------------------------------------------------

    create table #Candidatos
    (
        id_region int not null,

        region nvarchar(80) not null,

        id_pieza int not null,

        pieza nvarchar(500) not null,

        hora_local datetime2(0) not null,

        hora_prime_inicio time(0) not null,

        hora_prime_fin time(0) not null,

        distancia_centro_prime int not null
    );


    --------------------------------------------------------
    -- 7. obtener una pieza por región
    --
    -- Actualmente nuestro juego de datos posee una pieza
    -- publicitaria para cada región.
    --
    -- row_number permite mantener una sola candidata por
    -- región incluso si en el futuro existen varias.
    --------------------------------------------------------

    ;with PiezaPorRegion as
    (
        select
            PR.id_region,
            PR.id_pieza,

            row_number() over
            (
                partition by PR.id_region
                order by PR.id_pieza
            ) as numero_pieza

        from dbo.Pieza_Para_Region PR
    ),


    --------------------------------------------------------
    -- calcular hora local de cada región
    --------------------------------------------------------

    RegionConHora as
    (
        select
            R.id_region,

            R.nombre as region,

            P.id_pieza,

            P.nombre as pieza,

            R.hora_prime_inicio,

            R.hora_prime_fin,


            ------------------------------------------------
            -- Argentina
            ------------------------------------------------

            case R.huso_horario

                when 'America/Argentina/Buenos_Aires'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'Argentina Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- Brasil
                ------------------------------------------------

                when 'America/Sao_Paulo'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'E. South America Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- Francia
                ------------------------------------------------

                when 'Europe/Paris'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'Romance Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- Estados Unidos
                ------------------------------------------------

                when 'America/New_York'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'Eastern Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- Alemania
                ------------------------------------------------

                when 'Europe/Berlin'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'W. Europe Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- España
                ------------------------------------------------

                when 'Europe/Madrid'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'Romance Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- Reino Unido
                ------------------------------------------------

                when 'Europe/London'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'GMT Standard Time'

                        as datetime2(0)
                    )


                ------------------------------------------------
                -- México
                ------------------------------------------------

                when 'America/Mexico_City'
                then
                    cast
                    (
                        (
                            @horario_utc
                            at time zone 'UTC'
                        )
                        at time zone
                        'Central Standard Time (Mexico)'

                        as datetime2(0)
                    )

            end as hora_local


        from dbo.Region R


        inner join PiezaPorRegion PR
            on PR.id_region = R.id_region
           and PR.numero_pieza = 1


        inner join dbo.Pieza_Publicitaria P
            on P.id_pieza = PR.id_pieza
    )


    --------------------------------------------------------
    -- 8. guardar solamente regiones en prime time
    --------------------------------------------------------

    insert into #Candidatos
    (
        id_region,
        region,
        id_pieza,
        pieza,
        hora_local,
        hora_prime_inicio,
        hora_prime_fin,
        distancia_centro_prime
    )

    select
        RH.id_region,

        RH.region,

        RH.id_pieza,

        RH.pieza,

        RH.hora_local,

        RH.hora_prime_inicio,

        RH.hora_prime_fin,


        ----------------------------------------------------
        -- calcular distancia respecto del centro
        -- del prime time
        ----------------------------------------------------

        abs
        (
            datediff
            (
                minute,

                cast('00:00:00' as time),

                cast(RH.hora_local as time)
            )

            -

            (
                datediff
                (
                    minute,

                    cast('00:00:00' as time),

                    RH.hora_prime_inicio
                )

                +

                datediff
                (
                    minute,

                    cast('00:00:00' as time),

                    RH.hora_prime_fin
                )

            ) / 2
        )


    from RegionConHora RH


    where
        cast(RH.hora_local as time)
            >= RH.hora_prime_inicio

        and

        cast(RH.hora_local as time)
            < RH.hora_prime_fin;


    --------------------------------------------------------
    -- 9. contar mercados candidatos
    --------------------------------------------------------

    select
        @cantidad_candidatos = count(*)
    from #Candidatos;


    --------------------------------------------------------
    -- 10. tabla con candidatos elegidos
    --------------------------------------------------------

    create table #Seleccionados
    (
        numero_espacio tinyint not null,

        id_region int not null,

        region nvarchar(80) not null,

        id_pieza int not null,

        pieza nvarchar(500) not null,

        hora_local datetime2(0) not null,

        distancia_centro_prime int not null,

        costo_aplicado decimal(14,2) not null
    );


    --------------------------------------------------------
    -- 11. priorizar y seleccionar máximo cuatro
    --------------------------------------------------------

    ;with Rankeados as
    (
        select
            C.*,

            row_number() over
            (
                order by
                    C.distancia_centro_prime asc,
                    C.id_region asc
            ) as prioridad

        from #Candidatos C
    )


    insert into #Seleccionados
    (
        numero_espacio,

        id_region,

        region,

        id_pieza,

        pieza,

        hora_local,

        distancia_centro_prime,

        costo_aplicado
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

            when 1
                then @costo_espacio_1

            when 2
                then @costo_espacio_2

            when 3
                then @costo_espacio_3

            when 4
                then @costo_espacio_4

        end


    from Rankeados


    where prioridad <= 4;


    --------------------------------------------------------
    -- cantidad finalmente asignada
    --------------------------------------------------------

    select
        @cantidad_asignados = count(*)
    from #Seleccionados;


    --------------------------------------------------------
    -- 12. comenzar asignación
    --
    -- Todo el partido se procesa dentro de la misma
    -- transacción.
    --------------------------------------------------------

    begin try

        begin transaction;


        ----------------------------------------------------
        -- variables de procesamiento
        ----------------------------------------------------

        declare
            @numero_espacio tinyint,

            @id_pieza int,

            @id_pieza_actual int,

            @costo_aplicado decimal(14,2),

            @id_asignacion int,

            @id_asignacion_nueva int;


        ----------------------------------------------------
        -- cursor sobre los cuatro espacios seleccionados
        ----------------------------------------------------

        declare cursor_asignaciones
        cursor local fast_forward
        for

            select
                numero_espacio,

                id_pieza,

                costo_aplicado

            from #Seleccionados

            order by numero_espacio;


        open cursor_asignaciones;


        fetch next from cursor_asignaciones
        into
            @numero_espacio,

            @id_pieza,

            @costo_aplicado;


        while @@fetch_status = 0
        begin


            set @id_asignacion = null;

            set @id_pieza_actual = null;

            set @id_asignacion_nueva = null;


            ------------------------------------------------
            -- buscar si ese espacio ya existe
            ------------------------------------------------

            select
                @id_asignacion = id_asignacion,

                @id_pieza_actual = id_pieza

            from dbo.Asignacion_Publicitaria

            where id_partido = @id_partido

              and numero_espacio = @numero_espacio;


            ------------------------------------------------
            -- CASO 1
            --
            -- El espacio todavía no existe.
            --
            -- Se realiza un alta.
            ------------------------------------------------

            if @id_asignacion is null
            begin

                exec abm.Asignacion_Publicitaria_Alta

                    @id_partido = @id_partido,

                    @id_pieza = @id_pieza,

                    @numero_espacio = @numero_espacio,

                    @costo_aplicado = @costo_aplicado,

                    @id_asignacion =
                        @id_asignacion_nueva output;

            end


            ------------------------------------------------
            -- CASO 2
            --
            -- El espacio existe y mantiene la misma pieza.
            --
            -- El ABM de modificación únicamente permite
            -- actualizar el costo.
            ------------------------------------------------

            else if @id_pieza_actual = @id_pieza
            begin

                exec abm.Asignacion_Publicitaria_Modificacion

                    @id_asignacion = @id_asignacion,

                    @costo_aplicado = @costo_aplicado;

            end


            ------------------------------------------------
            -- CASO 3
            --
            -- El espacio existe pero cambió la pieza.
            --
            -- Como Modificacion no permite cambiar
            -- id_pieza, hacemos:
            --
            -- Baja
            -- +
            -- Alta
            ------------------------------------------------

            else
            begin

                exec abm.Asignacion_Publicitaria_Baja

                    @id_asignacion =
                        @id_asignacion;


                set @id_asignacion_nueva = null;


                exec abm.Asignacion_Publicitaria_Alta

                    @id_partido = @id_partido,

                    @id_pieza = @id_pieza,

                    @numero_espacio = @numero_espacio,

                    @costo_aplicado = @costo_aplicado,

                    @id_asignacion =
                        @id_asignacion_nueva output;

            end;


            ------------------------------------------------
            -- siguiente espacio
            ------------------------------------------------

            fetch next from cursor_asignaciones
            into
                @numero_espacio,

                @id_pieza,

                @costo_aplicado;

        end;


        ----------------------------------------------------
        -- cerrar cursor
        ----------------------------------------------------

        close cursor_asignaciones;

        deallocate cursor_asignaciones;


        ----------------------------------------------------
        -- 13. eliminar asignaciones viejas
        --
        -- Si anteriormente había más espacios asignados
        -- y ahora ya no corresponden, se eliminan.
        ----------------------------------------------------

        declare @id_asignacion_baja int;


        declare cursor_bajas
        cursor local fast_forward
        for

            select
                AP.id_asignacion

            from dbo.Asignacion_Publicitaria AP

            where AP.id_partido = @id_partido

              and not exists
              (
                  select 1

                  from #Seleccionados S

                  where
                      S.numero_espacio =
                      AP.numero_espacio
              );


        open cursor_bajas;


        fetch next from cursor_bajas
        into @id_asignacion_baja;


        while @@fetch_status = 0
        begin

            exec abm.Asignacion_Publicitaria_Baja

                @id_asignacion =
                    @id_asignacion_baja;


            fetch next from cursor_bajas
            into @id_asignacion_baja;

        end;


        close cursor_bajas;

        deallocate cursor_bajas;


        ----------------------------------------------------
        -- confirmar operación
        ----------------------------------------------------

        commit transaction;

    end try


    --------------------------------------------------------
    -- si algo falla, se revierte toda la asignación
    --------------------------------------------------------

    begin catch

        if xact_state() <> 0
        begin

            rollback transaction;

        end;


        ----------------------------------------------------
        -- limpieza de cursores si quedaron abiertos
        ----------------------------------------------------

        if cursor_status
        (
            'local',
            'cursor_asignaciones'
        ) >= 0
        begin

            close cursor_asignaciones;

        end;


        if cursor_status
        (
            'local',
            'cursor_asignaciones'
        ) > -3
        begin

            deallocate cursor_asignaciones;

        end;


        if cursor_status
        (
            'local',
            'cursor_bajas'
        ) >= 0
        begin

            close cursor_bajas;

        end;


        if cursor_status
        (
            'local',
            'cursor_bajas'
        ) > -3
        begin

            deallocate cursor_bajas;

        end;


        throw;

    end catch;


    --------------------------------------------------------
    -- 14. resumen
    --------------------------------------------------------

    select
        @id_partido as id_partido,

        @horario_utc as horario_UTC,

        @cantidad_candidatos
            as mercados_candidatos,

        @cantidad_asignados
            as espacios_asignados;


    --------------------------------------------------------
    -- 15. todos los mercados que estaban en prime time
    --------------------------------------------------------

    select
        id_region,

        region,

        id_pieza,

        pieza,

        hora_local,

        hora_prime_inicio,

        hora_prime_fin,

        distancia_centro_prime

    from #Candidatos

    order by
        distancia_centro_prime,

        id_region;


    --------------------------------------------------------
    -- 16. cuatro asignaciones finalmente elegidas
    --------------------------------------------------------

    select
        S.numero_espacio,

        S.id_region,

        S.region,

        S.hora_local,

        S.id_pieza,

        S.pieza,

        S.costo_aplicado,

        S.distancia_centro_prime

    from #Seleccionados S

    order by S.numero_espacio;

end;
go