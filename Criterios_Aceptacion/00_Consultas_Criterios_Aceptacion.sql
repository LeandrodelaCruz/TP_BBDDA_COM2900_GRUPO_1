--EXPULSION DOBLE AMONESTACION

USE MUNDIALDEFUTBOL;
GO

CREATE OR ALTER VIEW dbo.vw_Caso_Expulsiones
AS
WITH Amarillas AS
(
    SELECT
        id_partido,
        id_jugador,
        COUNT(*) AS cantidad_amarillas,
        MIN(minuto) AS primera_amarilla,
        MAX(minuto) AS ultima_amarilla
    FROM dbo.Incidencia
    WHERE tipo = 'AMONESTACION'
    GROUP BY id_partido, id_jugador
)
SELECT
    P.id_partido,
    P.fecha,
    S1.pais AS seleccion_1,
    S2.pais AS seleccion_2,

    I.id_incidencia,
    I.id_jugador,
    CONCAT(J.nombre, ' ', J.apellido) AS jugador_expulsado,

    I.minuto AS minuto_expulsion,
    I.periodo,
    I.motivo,

    ISNULL(A.cantidad_amarillas, 0) AS cantidad_amarillas,
    A.primera_amarilla,
    A.ultima_amarilla,

    CASE
        WHEN ISNULL(A.cantidad_amarillas, 0) >= 2
          OR I.motivo COLLATE Latin1_General_CI_AI
                LIKE '%DOBLE AMONESTACION%'
          OR I.motivo COLLATE Latin1_General_CI_AI
                LIKE '%SEGUNDA AMARILLA%'
        THEN 'EXPULSION POR DOBLE AMONESTACION'
        ELSE 'ROJA DIRECTA'
    END AS tipo_expulsion

FROM dbo.Incidencia I
INNER JOIN dbo.Partido P
    ON I.id_partido = P.id_partido
INNER JOIN dbo.Jugador J
    ON I.id_jugador = J.id_jugador
INNER JOIN dbo.Seleccion S1
    ON P.id_seleccion_1 = S1.id_seleccion
INNER JOIN dbo.Seleccion S2
    ON P.id_seleccion_2 = S2.id_seleccion
LEFT JOIN Amarillas A
    ON I.id_partido = A.id_partido
    AND I.id_jugador = A.id_jugador

WHERE I.tipo = 'EXPULSION';
GO

-- SUSPENSION POR ACUMULACION DE AMARILLAS

CREATE OR ALTER VIEW dbo.vw_Caso_Suspension_Acumulacion
AS
WITH AmarillasPorPartido AS
(
    SELECT
        I.id_jugador,
        J.id_seleccion,
        I.id_partido,
        P.fecha,
        P.horario_UTC,
        COUNT(*) AS cantidad_amarillas

    FROM dbo.Incidencia I
    INNER JOIN dbo.Jugador J
        ON I.id_jugador = J.id_jugador
    INNER JOIN dbo.Partido P
        ON I.id_partido = P.id_partido

    WHERE I.tipo = 'AMONESTACION'
      AND NOT EXISTS
      (
          SELECT 1
          FROM dbo.Incidencia E
          WHERE E.id_partido = I.id_partido
            AND E.id_jugador = I.id_jugador
            AND E.tipo = 'EXPULSION'
      )

    GROUP BY
        I.id_jugador,
        J.id_seleccion,
        I.id_partido,
        P.fecha,
        P.horario_UTC
),
Ordenadas AS
(
    SELECT
        *,
        ROW_NUMBER() OVER
        (
            PARTITION BY id_jugador
            ORDER BY horario_UTC, id_partido
        ) AS numero_amonestacion

    FROM AmarillasPorPartido
),
PrimerasDos AS
(
    SELECT
        id_jugador,

        MAX(CASE
            WHEN numero_amonestacion = 1
            THEN id_partido
        END) AS primer_partido_amarilla,

        MAX(CASE
            WHEN numero_amonestacion = 2
            THEN id_partido
        END) AS segundo_partido_amarilla

    FROM Ordenadas
    WHERE numero_amonestacion <= 2
    GROUP BY id_jugador
)
SELECT
    J.id_jugador,
    CONCAT(J.nombre, ' ', J.apellido) AS jugador,
    S.pais AS seleccion,

    D.primer_partido_amarilla,
    D.segundo_partido_amarilla,

    O.cantidad_amarillas AS amarillas_en_segundo_partido,

    O.fecha AS fecha_suspension,
    O.horario_UTC AS horario_suspension,

    SIG.id_partido AS siguiente_partido,
    SIG.fecha AS fecha_siguiente_partido,
    SIG.fase AS fase_siguiente_partido,
    SIG.seleccion_rival,

    FJ.es_titular,

    CASE
        WHEN FJ.es_titular = 1
            THEN 'INCLUIDO COMO TITULAR - REVISAR'
        WHEN FJ.es_titular = 0
            THEN 'FIGURA COMO SUPLENTE'
        ELSE 'NO FIGURA EN LA FORMACION'
    END AS estado_suspension

FROM Ordenadas O

INNER JOIN PrimerasDos D
    ON O.id_jugador = D.id_jugador

INNER JOIN dbo.Jugador J
    ON O.id_jugador = J.id_jugador

INNER JOIN dbo.Seleccion S
    ON J.id_seleccion = S.id_seleccion

CROSS APPLY
(
    SELECT TOP (1)
        P.id_partido,
        P.fecha,
        P.horario_UTC,
        P.fase,

        CASE
            WHEN P.id_seleccion_1 = O.id_seleccion
                THEN S2.pais
            ELSE S1.pais
        END AS seleccion_rival

    FROM dbo.Partido P

    INNER JOIN dbo.Seleccion S1
        ON P.id_seleccion_1 = S1.id_seleccion

    INNER JOIN dbo.Seleccion S2
        ON P.id_seleccion_2 = S2.id_seleccion

    WHERE
        (
            P.id_seleccion_1 = O.id_seleccion
            OR P.id_seleccion_2 = O.id_seleccion
        )
        AND
        (
            P.horario_UTC > O.horario_UTC
            OR
            (
                P.horario_UTC = O.horario_UTC
                AND P.id_partido > O.id_partido
            )
        )

    ORDER BY P.horario_UTC, P.id_partido

) SIG

LEFT JOIN dbo.Formacion F
    ON SIG.id_partido = F.id_partido
    AND F.id_seleccion = J.id_seleccion

LEFT JOIN dbo.Formacion_Jugador FJ
    ON F.id_formacion = FJ.id_formacion
    AND J.id_jugador = FJ.id_jugador

WHERE O.numero_amonestacion = 2;
GO

--SUSTITUCION POR LESION DENTRO DE LOS PRIMEROS VEINTE

CREATE OR ALTER VIEW dbo.vw_Caso_Sustitucion_Lesion
AS
SELECT
    P.id_partido,
    P.fecha,

    S1.pais AS seleccion_1,
    S2.pais AS seleccion_2,

    SU.id_sustitucion,

    SU.id_jugador_sale,
    CONCAT(JS.nombre, ' ', JS.apellido) AS jugador_que_sale,

    SU.id_jugador_entra,
    CONCAT(JE.nombre, ' ', JE.apellido) AS jugador_que_entra,

    SU.minuto,
    SU.periodo,
    SU.motivo,
    SU.numero_ventana

FROM dbo.Sustitucion SU

INNER JOIN dbo.Partido P
    ON SU.id_partido = P.id_partido

INNER JOIN dbo.Jugador JS
    ON SU.id_jugador_sale = JS.id_jugador

INNER JOIN dbo.Jugador JE
    ON SU.id_jugador_entra = JE.id_jugador

INNER JOIN dbo.Seleccion S1
    ON P.id_seleccion_1 = S1.id_seleccion

INNER JOIN dbo.Seleccion S2
    ON P.id_seleccion_2 = S2.id_seleccion

WHERE
    SU.minuto <= 20
    AND SU.motivo COLLATE Latin1_General_CI_AI LIKE '%LESION%';
GO

--PRIME TIME CUATRO MERCADOS

CREATE OR ALTER VIEW dbo.vw_Caso_PrimeTime_Priorizacion
AS
WITH PiezaPorRegion AS
(
    SELECT
        PR.id_region,
        PR.id_pieza,

        ROW_NUMBER() OVER
        (
            PARTITION BY PR.id_region
            ORDER BY PR.id_pieza
        ) AS numero_pieza

    FROM dbo.Pieza_Para_Region PR
),
RegionConHora AS
(
    SELECT
        P.id_partido,
        P.fecha,
        P.horario_UTC,

        S1.pais AS seleccion_1,
        S2.pais AS seleccion_2,

        R.id_region,
        R.nombre AS region,

        PP.id_pieza,
        PP.nombre AS pieza,

        R.hora_prime_inicio,
        R.hora_prime_fin,

        CASE R.huso_horario

            WHEN 'America/Argentina/Buenos_Aires'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'Argentina Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'America/Sao_Paulo'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'E. South America Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'Europe/Paris'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'Romance Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'America/New_York'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'Eastern Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'Europe/Berlin'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'W. Europe Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'Europe/Madrid'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'Romance Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'Europe/London'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'GMT Standard Time'
                AS DATETIME2(0)
            )

            WHEN 'America/Mexico_City'
            THEN CAST(
                (P.horario_UTC AT TIME ZONE 'UTC')
                AT TIME ZONE 'Central Standard Time (Mexico)'
                AS DATETIME2(0)
            )

        END AS hora_local

    FROM dbo.Partido P

    CROSS JOIN dbo.Region R

    INNER JOIN PiezaPorRegion PR
        ON R.id_region = PR.id_region
        AND PR.numero_pieza = 1

    INNER JOIN dbo.Pieza_Publicitaria PP
        ON PR.id_pieza = PP.id_pieza

    INNER JOIN dbo.Seleccion S1
        ON P.id_seleccion_1 = S1.id_seleccion

    INNER JOIN dbo.Seleccion S2
        ON P.id_seleccion_2 = S2.id_seleccion
),
Candidatos AS
(
    SELECT
        RH.*,

        ABS(
            DATEDIFF(
                MINUTE,
                CAST('00:00:00' AS TIME),
                CAST(RH.hora_local AS TIME)
            )
            -
            (
                DATEDIFF(
                    MINUTE,
                    CAST('00:00:00' AS TIME),
                    RH.hora_prime_inicio
                )
                +
                DATEDIFF(
                    MINUTE,
                    CAST('00:00:00' AS TIME),
                    RH.hora_prime_fin
                )
            ) / 2
        ) AS distancia_centro_prime

    FROM RegionConHora RH

    WHERE RH.hora_local IS NOT NULL
      AND CAST(RH.hora_local AS TIME) >= RH.hora_prime_inicio
      AND CAST(RH.hora_local AS TIME) < RH.hora_prime_fin
),
Rankeados AS
(
    SELECT
        C.*,

        COUNT(*) OVER (
            PARTITION BY C.id_partido
        ) AS mercados_candidatos,

        ROW_NUMBER() OVER
        (
            PARTITION BY C.id_partido
            ORDER BY
                C.distancia_centro_prime ASC,
                C.id_region ASC
        ) AS prioridad

    FROM Candidatos C
)
SELECT
    R.id_partido,
    R.fecha,
    R.seleccion_1,
    R.seleccion_2,

    R.horario_UTC,

    R.id_region,
    R.region,

    R.id_pieza,
    R.pieza,

    R.hora_local,
    R.hora_prime_inicio,
    R.hora_prime_fin,

    R.distancia_centro_prime,

    R.mercados_candidatos,
    R.prioridad,

    CASE
        WHEN R.prioridad <= 4 THEN 1
        ELSE 0
    END AS seleccionado_por_prioridad,

    CASE
        WHEN R.prioridad <= 4
            THEN CAST(R.prioridad AS TINYINT)
        ELSE NULL
    END AS numero_espacio,

    AP.id_asignacion,
    AP.id_pieza AS id_pieza_persistida,

    CASE
        WHEN R.prioridad > 4
            THEN 'DESCARTADO POR PRIORIDAD'

        WHEN AP.id_asignacion IS NULL
            THEN 'SELECCIONADO - PENDIENTE DE PERSISTIR'

        WHEN AP.id_pieza = R.id_pieza
            THEN 'SELECCIONADO Y PERSISTIDO'

        ELSE 'ASIGNACION PERSISTIDA CON OTRA PIEZA'
    END AS estado_asignacion

FROM Rankeados R

LEFT JOIN dbo.Asignacion_Publicitaria AP
    ON AP.id_partido = R.id_partido
    AND AP.numero_espacio = R.prioridad;
GO

--DESIGNACION ARBITRAL

CREATE OR ALTER VIEW dbo.vw_Caso_Conflicto_Arbitral
AS
SELECT
    P.id_partido,
    P.fecha,

    S1.pais AS seleccion_1,
    S2.pais AS seleccion_2,

    A.id_arbitro,
    CONCAT(A.nombre, ' ', A.apellido) AS arbitro,
    A.pais AS nacionalidad_arbitro,
    A.puesto,

    CASE
        WHEN UPPER(LTRIM(RTRIM(A.pais)))
                COLLATE Latin1_General_CI_AI =
             UPPER(LTRIM(RTRIM(S1.pais)))
                COLLATE Latin1_General_CI_AI
            THEN S1.pais

        ELSE S2.pais
    END AS pais_en_conflicto,

    DA.rol_arbitro,

    CASE
        WHEN DA.id_arbitro IS NULL
            THEN 'CANDIDATO QUE DEBE SER RECHAZADO'
        ELSE 'CONFLICTO PERSISTIDO - REVISAR'
    END AS estado_designacion,

    'Conflicto de nacionalidad con una seleccion participante'
        AS motivo_rechazo

FROM dbo.Partido P

INNER JOIN dbo.Seleccion S1
    ON P.id_seleccion_1 = S1.id_seleccion

INNER JOIN dbo.Seleccion S2
    ON P.id_seleccion_2 = S2.id_seleccion

CROSS JOIN dbo.Arbitro A

LEFT JOIN dbo.Designacion_Arbitral DA
    ON DA.id_partido = P.id_partido
    AND DA.id_arbitro = A.id_arbitro

WHERE
    UPPER(LTRIM(RTRIM(A.pais)))
        COLLATE Latin1_General_CI_AI =
    UPPER(LTRIM(RTRIM(S1.pais)))
        COLLATE Latin1_General_CI_AI

    OR

    UPPER(LTRIM(RTRIM(A.pais)))
        COLLATE Latin1_General_CI_AI =
    UPPER(LTRIM(RTRIM(S2.pais)))
        COLLATE Latin1_General_CI_AI;
GO

--MOSTRAR LOS 5 CASOS

USE MUNDIALDEFUTBOL;
GO

-- 0. Import con errores y jugadores rechazados por acumulación de amarillas
EXEC importacion.Importar_Formacion_Jugador_JSON '/home/proyecto/alineaciones_extraidas_error.json';

-- 1. Expulsiones
SELECT *
FROM dbo.vw_Caso_Expulsiones
ORDER BY id_partido, minuto_expulsion;


-- 2. Acumulacion de amarillas
SELECT *
FROM dbo.vw_Caso_Suspension_Acumulacion
ORDER BY jugador;


-- 3. Sustitucion por lesion
SELECT *
FROM dbo.vw_Caso_Sustitucion_Lesion
ORDER BY fecha, minuto;


-- 4. Priorizacion de mercados
SELECT *
FROM dbo.vw_Caso_PrimeTime_Priorizacion
WHERE id_partido = 42
ORDER BY prioridad;


-- 5. Conflicto de nacionalidad
/*SELECT *
FROM dbo.vw_Caso_Conflicto_Arbitral
ORDER BY id_partido, arbitro;*/

-- Árbitra propuesta: Katia García, de México
SELECT id_arbitro, nombre, apellido, pais AS nacionalidad
FROM dbo.Arbitro
WHERE id_arbitro = 17;

-- Selecciones del partido 1: México y Sudáfrica
SELECT p.id_partido, s1.pais AS seleccion_1, s2.pais AS seleccion_2
FROM dbo.Partido AS p
JOIN dbo.Seleccion AS s1 ON s1.id_seleccion = p.id_seleccion_1
JOIN dbo.Seleccion AS s2 ON s2.id_seleccion = p.id_seleccion_2
WHERE p.id_partido = 1;

EXEC abm.Designacion_Arbitral_Alta @id_partido = 1, @id_arbitro = 17, @rol_arbitro = 'CUARTO ARBITRO';

