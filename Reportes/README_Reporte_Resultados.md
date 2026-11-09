# Entrega 7: resultados de los encuentros

Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha: 09/11/2026.

## Presentación

`reportes.Reporte_Resultados` devuelve una tabla, con una fila por encuentro y estas columnas:

- id_partido: referencia para consultas y filtros.
- fase y fecha: contexto del encuentro.
- seleccion_1, resultado y seleccion_2: equipos a ambos lados del marcador.
- definicion: quién ganó, si fue por penales, empate o resultado pendiente.
- sede: estadio del encuentro.
- observacion: explicación cuando falta información o hay una discrepancia; normalmente NULL.

El orden es grupos, dieciseisavos, octavos, cuartos, semifinales, tercer puesto y final. Dentro de cada fase, los encuentros se ordenan por horario UTC e identificador. Los nombres y fechas provienen de la base. No se agrega detalle de jugadores, árbitros o publicidad, que ya tienen reportes propios. No se devuelve XML: para este listado se prioriza la lectura por columnas y ya hay otros reportes XML en la entrega.

Ejemplos derivados del dataset local, no certificados como resultados oficiales:

| Fase | Selección 1 | Resultado | Selección 2 | Definición |
|---|---|---|---|---|
| GRUPOS | Mexico | 2-0 | South Africa | Ganó Mexico |
| GRUPOS | Canada | 1-1 | Bosnia and Herzegovina | Empate |
| DIECISEISAVOS | Germany | 1-1 (penales 3-4) | Paraguay | Ganó Paraguay por penales |
| OCTAVOS | Switzerland | 0-0 (penales 4-3) | Colombia | Ganó Switzerland por penales |

## Fuentes y relación con Completar_Partidos

Se revisaron el extractor `Scraping/13_Extraer_Partidos_API.py`, el JSON local, su importador y los procedimientos Completar_Partidos, Simular_Partido y Simular_Penales.

El extractor forma `resultado_final` con HomeTeamScore y AwayTeamScore como N-N. Si encuentra HomeTeamPenaltyScore y AwayTeamPenaltyScore, agrega (P-P). El archivo partidos_mundial_2026.json actual contiene 104 partidos: 100 marcadores simples y cuatro con tanda. El importador conserva ese texto en Partido.resultado_final.

Completar_Partidos selecciona partidos con resultado y sin incidencias/sustituciones. Simular_Partido interpreta el marcador y llama a Simular_Penales cuando el resultado trae una tanda. Esta última registra cada tiro como GOL DE PENAL o PENAL ERRADO, con periodo PENALES y minuto NULL, y comprueba que los goles de cada selección coincidan con el marcador de la tanda.

Por lo tanto, la información existe antes de los reportes en dos lugares: el resultado importado y las incidencias generadas por la simulación. El reporte no modifica ni ejecuta ese proceso.

## Criterio de lectura de resultados

1. El marcador del partido se toma de Partido.resultado_final. Nunca se le suman los goles de la tanda.
2. Si existen tiros de periodo PENALES, se cuentan únicamente los GOL DE PENAL de cada selección. Un GOL DE PENAL en PRIMER TIEMPO, SEGUNDO TIEMPO o suplementario no pertenece a la tanda.
3. Si el texto también informa una tanda, ambas fuentes deben coincidir. En ese caso, se muestra N-N (penales P-P) y el ganador por penales.
4. Si el texto trae tanda pero no hay tiros cargados, se conserva la definición de la fuente y se informa esa ausencia en observacion. Esto permite consultar resultados antes de simular incidencias.
5. Si hay tanda en incidencias pero no en el texto, se utiliza ese conteo y se indica su procedencia en observacion.
6. Sin tanda, una diferencia en el marcador permite mostrar el ganador. Un empate de grupos se muestra como Empate. Un empate eliminatorio sin definición se muestra como Definición no informada.
7. Un resultado NULL o vacío se muestra como Pendiente. Un formato desconocido, una tanda contradictoria o una tanda no válida para la fase se presenta como A revisar, conservando el texto original y explicando el problema. No se elige un ganador en esos casos.

El reporte admite los formatos N-N y N-N (P-P), con espacios opcionales. No interpreta otros textos de resultados. Tampoco afirma que una victoria haya ocurrido en tiempo reglamentario o suplementario: el marcador importado no lo distingue de manera general. El ganador se calcula para presentar el reporte; no se guarda una columna nueva ni se propagan clasificados.

La lectura supone que las incidencias de la tanda se cargaron correctamente. No hay un indicador persistido de cierre de tanda que permita certificar su integridad; si hubo duplicados o una carga parcial coherente en sus conteos, deben resolverse en el proceso de población. El reporte detecta contradicciones con el resultado importado, no reemplaza las validaciones del proceso de carga.

## Instalación y ejecución

1. Crear la base, esquemas y tablas con los scripts centrales.
2. Cargar selecciones, sedes, jugadores, partidos y formaciones mediante los procesos existentes.
3. Instalar la lógica de incidencias/simulaciones y ejecutar negocio.Completar_Partidos para poblar los eventos antes de validar la entrega.
4. Instalar `Reportes/24_Reporte_Resultados.sql`.
5. Ejecutar sobre MUNDIALDEFUTBOL:

```sql
EXEC reportes.Reporte_Resultados;
EXEC reportes.Reporte_Resultados @fase='OCTAVOS';
```

Los filtros son opcionales y combinables. Para estos ejemplos, reemplazar los identificadores por valores existentes:

```sql
EXEC reportes.Reporte_Resultados @id_seleccion=1;
EXEC reportes.Reporte_Resultados @id_partido=74;
EXEC reportes.Reporte_Resultados @fase='CUARTOS', @id_seleccion=1;
```

El filtro de selección considera ambos lados del partido. Una fase válida sin encuentros devuelve cero filas. Los filtros inválidos o referencias inexistentes se agrupan mediante THROW 53601. No se requiere un nombre de base auxiliar ni se agrega un esquema nuevo. No se usan cursores ni SQL dinámico.

## Prueba

`Reportes/25_Test_Reporte_Resultados.sql` instala y ejecuta `test.Reporte_Resultados_Test` sobre MUNDIALDEFUTBOL. Requiere las tablas, el reporte, el ABM de incidencias y negocio.Simular_Penales. Crea datos propios con nombres únicos y los revierte al terminar o fallar. Rechaza una transacción previa. Puede consumir IDENTITY aunque las filas se reviertan.

Se prueban diez encuentros: victoria, empate de grupos, tanda simulada 3-4, tanda importada 4-3 sin incidencias, partido pendiente, empate eliminatorio sin definición, formato desconocido, tanda contradictoria, penal durante el partido y tanda solo en incidencias. También se verifican filtros individuales y combinados, selección visitante, ausencia de coincidencias y mensajes de validación.

Para la prueba de integración con penales se crean 11 titulares de cada selección y se ejecuta el procedimiento real Simular_Penales, el mismo que utiliza Simular_Partido. No se ejecuta Completar_Partidos sobre todos los encuentros de la base durante el test. El reporte no necesita nuevas tablas ni modifica la lógica de esos procedimientos.

Resultado del 09/11/2026 en SQL Server 2022 Developer: aprobado. El escenario mostró 1-1 (penales 3-4), ganó la segunda selección, sin sumar la tanda al marcador. Se validaron también las observaciones y filtros. Los datos ficticios se revirtieron. No se declara una regresión completa de todos los módulos del proyecto.
