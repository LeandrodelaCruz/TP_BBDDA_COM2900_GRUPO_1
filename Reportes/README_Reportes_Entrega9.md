# Entrega 9: fixture, historial de titularidad y equipo en cancha

Universidad Nacional de La Matanza · Bases de Datos Aplicada · Comisión 01-2900 · Grupo 01.

Integrantes del Grupo 01 — Nicolás Dario Caro, Lucas Nicolás Clara, Leandro Ariel de la Cruz y Elías Uriel Rodríguez.

15/11/2026

## Resultado

Los tres procedimientos devuelven resultados tabulares y cubren las consultas de las secciones A, C y D del alcance «To BE».

| Procedimiento | Consulta | Una fila por |
| --- | --- | --- |
| `reportes.Reporte_Fixture` | ¿Cuándo, dónde y entre qué selecciones se juega? | Partido |
| `reportes.Reporte_Historial_Titularidad` | ¿En qué partidos figuró un jugador como titular o suplente? | Jugador registrado en la formación de un partido |
| `reportes.Reporte_Equipo_En_Cancha` | ¿Quién estaba en cancha para una selección al cierre de un minuto? | Jugador presente en el corte consultado |

## Reglas de los reportes

### Fixture

- Lee `Partido`, `Sede` y `Seleccion`. Muestra identificador, fase, fecha, horarios local y UTC, estadio, ciudad, país de la sede, las dos selecciones, resultado final y asistencia. Los partidos pendientes también aparecen y pueden tener resultado o asistencia en `NULL`.
- Los filtros `@id_sede`, `@fase`, `@id_seleccion` y `@fecha` son opcionales y combinables. La selección puede figurar en cualquiera de los dos lados. La fecha es el día local de la sede guardado en `Partido.fecha`, incluso cuando el horario UTC cae en otro día.
- La fase admite `GRUPOS`, `DIECISEISAVOS`, `OCTAVOS`, `CUARTOS`, `SEMIFINAL`, `TERCER PUESTO` y `FINAL`. El procedimiento quita espacios de los extremos y convierte la fase a mayúsculas.
- El orden es por horario UTC e identificador de partido. Una búsqueda sin coincidencias, incluso con un ID de sede o selección inexistente, devuelve cero filas.

### Historial de titularidad

- Parte de `Formacion_Jugador` y `Formacion`. Cada fila informa jugador, partido, fecha y horario local, fase, selección, rival, dorsal, posición en la formación y condición inicial. El rival surge del otro lado de `Partido`.
- `es_titular` proviene de la formación. `ingreso_registrado` vale 1 si una sustitución del mismo partido identifica a ese jugador como quien entró. Para leer la participación del suplente se combinan ambos campos.

| `es_titular` | `ingreso_registrado` | Lectura |
| --- | --- | --- |
| 1 | Cualquier valor | Titular según la formación |
| 0 | 1 | Suplente con ingreso registrado |
| 0 | 0 | Suplente sin ingreso registrado |

- Con `@id_jugador` se obtiene el historial individual. Al omitirlo se ven todas las formaciones cargadas, ordenadas por jugador, horario UTC e identificador de partido. Un jugador sin filas en formaciones devuelve cero filas.
- El historial y el equipo en cancha identifican a los jugadores por ID y dorsal, lo que permite usar estas consultas también cuando se aplica el cifrado de datos personales de `Jugador`.

### Equipo en cancha

1. Toma los titulares de la formación de la selección para el partido. Cada sustitución registrada hasta el corte quita al jugador que sale e incorpora al que entra.
2. El período prevalece sobre el número del minuto. Por ejemplo, un cambio en el minuto 47 del primer tiempo ya cuenta al consultar el minuto 46 del segundo tiempo. Si varias sustituciones del mismo minuto afectan a un jugador, el orden se resuelve por identificador de sustitución.
3. La consulta refleja el estado después de los eventos del minuto pedido. Quedan fuera los jugadores con una incidencia `EXPULSION` en ese minuto o antes. Una expulsión sin minuto se aplica si pertenece a un período anterior. Si pertenece al período consultado, se informa que el corte es ambiguo.
4. Los períodos admitidos son `PRIMER TIEMPO`, `SEGUNDO TIEMPO`, `PRIMER SUPLEMENTARIO` y `SEGUNDO SUPLEMENTARIO`. El minuto es acumulado y admite mínimos de 0, 45, 90 y 105 respectivamente, con 255 como máximo de almacenamiento para los eventos. `PENALES` queda fuera de la reconstrucción.

Se devuelven el partido, la selección, el período, el minuto y los jugadores presentes, ordenados por dorsal e ID. El dorsal y la posición corresponden a la formación. Si un ingreso se registró para un jugador de la selección que no figura en ella, se muestra su dorsal de `Jugador` y quedan en `NULL` la posición en la formación y `es_titular`.

El resultado depende de las formaciones, sustituciones y expulsiones cargadas. El período y el minuto funcionan como corte solicitado. La consulta no verifica si el encuentro llegó a ese minuto o si efectivamente se jugó el suplementario.

## Instalación y ejecución

1. Para una base nueva, ejecutar en orden `Table/00_Script_DB_Schemas_Creacion.sql` y `Table/01_Script_Tablas_Creacion.sql`. Si la base ya existe con sus tablas y el esquema `reportes`, pasar al siguiente paso.
2. Ejecutar en `MUNDIALDEFUTBOL` los siguientes scripts de `Stored_Procedures_Reportes`.

   - `07_Reporte_Fixture.sql`
   - `08_Reporte_Historial_Titularidad.sql`
   - `09_Reporte_Equipo_En_Cancha.sql`

   Los scripts usan `CREATE PROCEDURE`. Si ya existe un procedimiento con el mismo nombre, SQL Server informa la colisión.

3. Para consultas representativas, usar partidos y sedes cargados para el fixture, formaciones para la titularidad y sustituciones e incidencias para reconstruir el equipo en cancha.

Reemplazar los ID y la fecha de los ejemplos por valores del conjunto de datos que se quiera consultar.

```sql
EXEC reportes.Reporte_Fixture;
EXEC reportes.Reporte_Fixture
    @id_sede = 1, @fase = 'GRUPOS', @id_seleccion = 2, @fecha = '20260611';

EXEC reportes.Reporte_Historial_Titularidad @id_jugador = 1;
EXEC reportes.Reporte_Historial_Titularidad;

EXEC reportes.Reporte_Equipo_En_Cancha
    @id_partido = 1, @id_seleccion = 1, @periodo = 'SEGUNDO TIEMPO', @minuto = 60;
```

## Validaciones

| Error | Cuándo se informa |
| --- | --- |
| 53610, 53620, 53630 | Falta el esquema `reportes` al instalar el procedimiento correspondiente. |
| 53611 | El filtro de fase del fixture contiene un valor inválido. |
| 53631 | El período de la consulta de cancha no es uno de los cuatro períodos de juego. |
| 53632 | El minuto es nulo o está fuera del rango admitido para el período. |
| 53633 | El partido no existe o la selección no lo disputa. |
| 53634 | La selección carece de titulares registrados para ese partido. |
| 53635 | Hay una expulsión de la selección sin minuto en el período consultado. |

## Pruebas y ejemplo

El 15/11/2026 los tres procedimientos pasaron las pruebas en SQL Server 2022, sobre una base temporal creada con los scripts de tablas y esquemas del proyecto. Se usaron datos ficticios y la base temporal se retiró al finalizar.

- **Fixture.** Se comprobó una consulta completa con un partido pendiente, los cuatro filtros individuales, un filtro combinado y una selección que figura en ambos lados en distintos partidos. Un partido del 11 de junio en horario local, que ya era 12 de junio en UTC, apareció al filtrar por el día 11.
- **Historial.** Se comprobó la consulta individual y general. Un mismo jugador figuró como suplente con ingreso en un partido y como titular en el siguiente. Se verificó también un suplente sin ingreso y la identificación del rival.
- **Equipo en cancha.** Se comprobaron los titulares al inicio, un cambio en la adición del primer tiempo, cambios y expulsión en el minuto 60, la separación de ambas selecciones, los cortes en suplementario y la exclusión de la tanda. Se verificaron los errores por período de penales, minuto inválido, falta de titulares y expulsión sin minuto en el período consultado.
- **Permisos y estructura.** Se ejecutaron el historial y el equipo en cancha con un usuario con permiso de ejecución sobre `reportes` y usando una estructura de `Jugador` sin las columnas de datos personales en texto plano.

## Integración con los avances del grupo

Los tres procedimientos usan el esquema `reportes` y las tablas del proyecto. Son consultas de solo lectura. Los ejemplos se ejecutan directamente en SQL Server. La instalación en la base `MUNDIALDEFUTBOL` del proyecto queda pendiente.
