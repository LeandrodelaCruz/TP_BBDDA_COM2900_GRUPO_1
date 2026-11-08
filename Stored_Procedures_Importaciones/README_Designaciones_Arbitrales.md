# Entrega 6: calendario, cruces y designaciones arbitrales

Universidad Nacional de La Matanza. Bases de Datos Aplicada. Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha de verificación de los escenarios originales: 07/11/2026.
Ampliación explicativa: 08/11/2026. No implica nuevas pruebas ni cambios funcionales.

## Objetivo y alcance

Poblar Designacion_Arbitral con equipos sintéticos a partir de los árbitros ya importados. No se utiliza una fuente externa para las designaciones. Los nombres de los árbitros proceden del CSV existente; las asignaciones son aleatorias y no deben presentarse como oficiales.

El calendario permite registrar sede, fecha, horarios y fase antes de conocer participantes. El mapa conecta ganadores y perdedores de partidos eliminatorios. La importación NO necesita ni deduce la selección ganadora. Su confirmación manual es opcional y se realiza por un procedimiento de negocio.

## Revisión de la situación anterior

El alta de designaciones comparaba el país del árbitro con los dos participantes. La modificación solo cambiaba el rol. El CHECK de la tabla aceptaba cinco nombres de roles, pero no verificaba compatibilidad con el puesto del árbitro ni cantidad por rol. No había advertencia de posibles cruces, mapa de eliminatorias ni posibilidad de crear partidos con selecciones pendientes.

La nueva validación se comparte entre alta y modificación en abm.Designacion_Arbitral_Guardar. El procedimiento negocio.Evaluar_Cruce_Arbitral calcula las advertencias. La carga llama al ABM; no duplica su decisión ni inserta designaciones directamente.

## Modelo de datos

Partido.id_seleccion_1 y Partido.id_seleccion_2 admiten NULL. NULL significa participante pendiente, nunca una selección ficticia. Partido.id_seleccion_ganadora es opcional y referencia Seleccion. Cuando existe una ganadora debe ser uno de los dos participantes, corresponder a eliminación directa y existir un resultado informado.

Cruce_Partido contiene id_partido_destino, posicion_destino (1 o 2), id_partido_origen y tipo_clasificado (GANADOR o PERDEDOR). La clave primaria es destino y posicion. Una salida origen/tipo tiene un solo destino. GANADOR conecta rondas consecutivas; PERDEDOR solo conecta semifinal con tercer puesto. El destino debe jugarse después del origen. Estas reglas impiden ciclos y saltos de ronda desde los procedimientos.

Los dieciseisavos son los puntos de entrada del mapa: sus participantes se importan o confirman manualmente. No se calcula la clasificación de grupos ni la combinacion de mejores terceros.

## Ganadores y participantes confirmados

negocio.Confirmar_Resultado_Eliminatorio recibe partido, selección ganadora y resultado textual. Valida al ganador, lo registra y completa los lugares siguientes del mapa dentro de una transacción. No interpreta el marcador ni calcula una tanda de penales.

Se permite repetir una confirmación identica. Un ganador ya confirmado no se reemplaza automáticamente. Si el destino tiene otro participante, se revierte la confirmación completa. Si ya contiene al participante correcto, se conserva. Un cruce agregado después de una confirmación se propaga al repetir la confirmación correspondiente.

Cambiar participantes con resultados, formaciones, incidencias, sustituciones o publicidad asociada se rechaza. También se rechazan cambios que contradigan un origen confirmado o un destino conocido, o generen conflicto de nacionalidad con los árbitros existentes. Fase y horario de partidos vinculados no se cambian sin retirar antes los cruces no utilizados.

## Ejemplo físico: dónde se guarda cada encuentro

«Cuarto A», «Cuarto B» y «Semifinal C» son etiquetas explicativas. No existe una tabla llamada Cuarto ni un campo que guarde esos nombres. Cada encuentro es una fila de dbo.Partido, identificada por id_partido; dbo.Cruce_Partido guarda las conexiones entre esas filas.

Ejemplo ilustrativo, independiente de los números reales del dataset: en Seleccion, 1 representa Argentina, 2 Brasil, 3 Francia y 4 España. Las columnas de Partido guardan únicamente los identificadores numéricos, no el texto del país.

Filas de Partido antes de confirmar ganadores:

| id_partido | fase | id_seleccion_1 | id_seleccion_2 |
|---|---|---|---|
| 97 | CUARTOS | 1 | 2 |
| 98 | CUARTOS | 3 | 4 |
| 101 | SEMIFINAL | NULL | NULL |

En este ejemplo, «Cuarto A» es el partido 97, «Cuarto B» es el 98 y «Semifinal C» es el 101. También se guardan sede, fecha y horarios en Partido; se omiten de la tabla ilustrativa para concentrarse en los participantes.

Filas de Cruce_Partido que conectan esos encuentros:

| id_partido_origen | tipo_clasificado | id_partido_destino | posicion_destino |
|---|---|---|---|
| 97 | GANADOR | 101 | 1 |
| 98 | GANADOR | 101 | 2 |

La primera fila significa: «El ganador del partido 97 ocupa el primer lugar del partido 101». La posición 1 corresponde a id_seleccion_1; la posición 2, a id_seleccion_2. El partido 101 debe existir antes de registrar estas relaciones, aunque todavía no tenga participantes.

Al confirmar Argentina como ganadora del 97 por 2-1, se actualizan dos filas de Partido:

| Fila de Partido | Campo actualizado | Valor |
|---|---|---|
| 97 | resultado_final | 2-1 |
| 97 | id_seleccion_ganadora | 1 (Argentina) |
| 101 | id_seleccion_1 | 1 (Argentina) |

La semifinal queda Argentina contra participante pendiente. Cuando se confirme al ganador del 98, se completará id_seleccion_2 del 101. Las dos filas de Cruce_Partido permanecen iguales: el mapa describe de dónde viene cada participante y no necesita cambiar al conocer su identidad.

```sql
-- Ejemplo ilustrativo: requiere haber preparado exactamente esos IDs y cruces.
EXEC negocio.Confirmar_Resultado_Eliminatorio
    @id_partido = 97,
    @id_seleccion_ganadora = 1,
    @resultado_final = '2-1';
```

Los IDs 97, 98 y 101 no deben copiarse como si fueran obligatorios o coincidieran con el IDENTITY de otra base. Al recrear o cargar datos, se deben resolver los identificadores reales.

## Qué hace exactamente Confirmar_Resultado_Eliminatorio

El procedimiento registra quién ganó y completa los participantes de los destinos directos. Puede usarse si todavía no había marcador o si el dataset ya lo había importado. Confirmar aquí significa informar explícitamente la selección ganadora; no significa que el motor deduzca el ganador a partir del texto.

1. Comprueba que el partido exista, no sea de grupos y tenga ambas selecciones.
2. Comprueba que la ganadora sea una de ellas y que se informe un resultado no vacío.
3. Guarda id_seleccion_ganadora y resultado_final en el partido de origen.
4. Consulta Cruce_Partido y completa el lugar indicado de cada destino, mediante abm.Partidos_Modificacion.
5. Confirma todos los cambios juntos. Si un destino resulta incompatible, revierte también la confirmación del origen.

En una semifinal puede haber dos relaciones: GANADOR hacia la final y PERDEDOR hacia el tercer puesto. Si Argentina vence a Francia, se coloca Argentina en el lugar correspondiente de la final y Francia en el del tercer puesto. Los rivales se completan al confirmar la otra semifinal. No se decide el ganador de ningún partido posterior ni se modifican las relaciones del mapa.

Si el destino ya contiene al clasificado correcto, se conserva. Si tiene otro participante, se rechaza la operación completa. Si no hay relaciones de salida, se registra el ganador y el marcador, pero no se completa ningún otro partido. Esto también permite confirmar una final o el tercer puesto, que normalmente no tienen destinos.

Si el dataset ya trae los participantes de rondas posteriores, no es obligatorio ejecutar este procedimiento para importar esos partidos o cargar sus árbitros. La confirmación explícita sirve para registrar el avance y precisar las rutas posibles de la advertencia arbitral.

Límites de la implementación actual:

- No interpreta el marcador ni verifica que coincida con la ganadora. Argentina-Brasil con marcador 1-1 y Argentina ganadora puede representar penales; el texto se informa manualmente. Un marcador contradictorio tampoco se detecta automáticamente.
- Siempre escribe el resultado recibido: puede reemplazar un marcador previamente importado.
- Si ya existe una ganadora confirmada, no permite cambiarla por la otra selección. Sí permite mantener la misma ganadora y cambiar el texto del resultado.
- Repetir una confirmación idéntica es válido. Si se agregó un cruce después, repetirla permite completar ese nuevo destino.

Estas son características del código actual, no promesas de funcionalidades adicionales.

## Restricciones de las tablas y validaciones de los procedimientos

En Table/01_Script_Tablas_Creacion.sql se hicieron opcionales id_seleccion_1 e id_seleccion_2, se incorporó id_seleccion_ganadora y se creó Cruce_Partido. Las restricciones nuevas de Partido son:

| Restricción | Regla aplicada por la tabla |
|---|---|
| FK_Partido_Ganadora | La ganadora informada debe existir en Seleccion. |
| CK_Partido_Selecciones | Si se conocen ambas selecciones, deben ser distintas. Se admiten participantes pendientes. |
| CK_Partido_Resultado | Un resultado distinto de NULL exige ambos participantes. |
| CK_Partido_Ganadora | Si hay ganadora, exige ambos participantes, resultado no NULL, fase distinta de GRUPOS y que sea uno de los participantes. |

Ejemplos: final sin participantes ni resultado, permitida; final con un participante pendiente y resultado, rechazada; Argentina-Brasil con Uruguay ganadora, rechazada. Dejar la ganadora en NULL sigue siendo válido aunque exista un marcador importado.

CK_Partido_Ganadora comprueba específicamente fase distinta de GRUPOS; no enumera por sí sola todas las fases válidas. Esa enumeración está en los ABM. CK_Partido_Resultado comprueba NULL, no analiza un marcador ni descarta por sí solo un texto vacío; los procedimientos aportan la normalización y validación de ese texto.

Restricciones de Cruce_Partido:

- PK_Cruce_Partido: una única relación por destino y posición.
- UQ_Cruce_Salida: una única salida por origen y tipo de clasificado. Ganador y perdedor pueden ir a destinos diferentes.
- FK_Cruce_Destino y FK_Cruce_Origen: ambos encuentros deben existir en Partido.
- CK_Cruce_Posicion: posición 1 o 2.
- CK_Cruce_Tipo: GANADOR o PERDEDOR.
- CK_Cruce_Distintos: el origen no puede ser el mismo partido que el destino.

Las tablas no validan por sí solas todo el cuadro. El ABM de cruces controla rondas consecutivas, perdedor de semifinal hacia tercer puesto, horario del destino posterior al origen y otras coherencias entre participantes. Las fases consecutivas permitidas impiden ciclos a través del ABM; el CHECK de origen distinto de destino solo impide un ciclo de un único partido.

Probar que un ABM rechaza una operación no demuestra necesariamente que actuó el CHECK: el procedimiento puede rechazarla antes de escribir. La prueba independiente de restricciones requiere casos dirigidos a esas restricciones con datos controlados y reversión de la transacción. No se documenta aquí una cobertura exhaustiva de cada constraint como si ya estuviera realizada.

## Designaciones y equipo de carga

- PRINCIPAL: 1, desde categoría Principal.
- ASISTENTE: 2, desde categoría Asistente.
- CUARTO ARBITRO: 1, desde categoría Principal.
- VAR: 1, desde categoría VAR.
- AVAR: 1, desde categoría VAR.

Son seis personas distintas por partido. No se carga quinto árbitro. Un AVAR es una decisión del escenario académico, no una cantidad impuesta por el enunciado. El alta individual permite equipos parciales; la carga exige completar los seis puestos para confirmar sus nuevas filas.

Se rechazan partidos sin ambos participantes, árbitros inexistentes, roles inválidos, categorías incompatibles, cupos completos, duplicación del árbitro y coincidencia de país con cualquiera de las dos selecciones. Se agrupan las condiciones incumplidas en el mensaje. El error 51601 identifica el conflicto de nacionalidad; 51602 identifica otras validaciones de designación.

La comparacion usa negocio.Pais_Arbitral_Normalizado: contempla USA/United States/United States of America, IR Iran/Iran, Korea Republic/South Korea e Ivory Coast/Cote d'Ivoire. Se conservan los nombres originales. Las categorías toleran retornos de carro del CSV; el importador elimina CR/LF del campo puesto al cargarlo en SQL Server sobre Linux.

Un árbitro con designaciones no puede cambiar país o categoría hasta retirar y volver a validar sus asignaciones. Una selección vinculada a partidos no puede renombrar su país. Los demas datos siguen siendo modificables.

## Advertencias de cruces

Desde dieciseisavos se considera cualquier ronda posterior del cuadro, incluida final y tercer puesto. Se propagan las selecciones conocidas por rutas compatibles con los ganadores confirmados y con los participantes que ya figuran en los destinos. Una selección eliminada de una ruta deja de circular por ella.

POSIBLE CRUCE informa el país del árbitro y el identificador de un futuro partido donde podría enfrentar a un participante. No bloquea la designación. EVALUACION INCOMPLETA informa que faltan relaciones o participantes de entrada. Cuando faltan ganadores confirmados, se explicita que la evaluación es potencial. No se trata la falta de informacion como ausencia de riesgo.

La evaluación refleja el estado ACTUAL del cuadro: no reconstruye lo que se sabia en una fecha histórica. Un dataset con participantes de rondas posteriores ya definidos restringe las posibilidades aunque no incluya una columna de ganadora. La advertencia se devuelve por parametro OUTPUT y se imprime en llamadas individuales; la carga la incorpora a su detalle. No se persiste un historial temporal de advertencias.

## Carga del mapa local

carga.Cargar_Cruces_Dataset registra 32 relaciones explícitas del archivo local partidos_mundial_2026.json. Se prepararon verificando la continuidad de sus participantes entre rondas. No se certifica que el archivo represente resultados oficiales y no se consultaron fuentes externas.

Los números de partido del archivo solo documentan las referencias. Se resuelven los ID reales por horario UTC y fase, exigiendo una coincidencia única. No se supone que numero_partido sea el IDENTITY. Si cambia el fixture, hay que revisar esta configuracion; no se adivinan relaciones nuevas. El procedimiento es atómico y puede repetirse sin duplicar cruces. No confirma ganadores.

## Algoritmo de carga arbitral

carga.Cargar_Designaciones_Arbitrales acepta @id_partido opcional y @demostrar_rechazo (por defecto 1). Devuelve por OUTPUT @completados, @omitidos, @errores y @rechazados, además de dos resultados: resumen y detalle de intentos.

1. Materializa los partidos y los recorre por MIN(id) y siguiente clave mayor.
2. Omite partidos sin participantes confirmados. Valida las designaciones existentes antes de considerarlas utilizables.
3. Recorre los seis lugares. Para cada puesto faltante sortea los candidatos de la categoría una sola vez, excluyendo los ya designados en ese partido.
4. Si se solicita demostracion, prioriza un candidato de nacionalidad conflictiva hasta demostrar el primer rechazo. No inventa un candidato si los datos no lo permiten.
5. Llama al alta por cada candidato. Solo los errores previstos 51601 y 51602 permiten probar al siguiente. Cada candidato se intenta una sola vez por puesto.
6. Confirma el partido al completar los seis puestos. Si se agotan candidatos o aparece un error inesperado, revierte las nuevas asignaciones de ese partido y continua con el siguiente.

La repetición conserva equipos completos y completa equipos parciales. No vuelve a sortear lo que ya existe. Un equipo previo inválido se informa como error, no se corrige silenciosamente. El detalle diferencia CARGADO, RECHAZADO, REVERTIDO, ADVERTENCIA, PENDIENTE, YA COMPLETO y ERROR PARTIDO. Los rechazos y reversiones son evidencia de esa ejecución y no se guardan en una tabla permanente: exportar el resultado si se necesita conservarlo.

Se usa WHILE con claves únicas y avance explícito, sin cursores. El recorrido partido/puesto/candidato y la transacción por partido fueron aprobados. Los procedimientos nuevos usan puntos de guardado cuando reciben una transacción externa; la carga exige ejecutarse sin una. Un bloqueo de aplicacion coordina las operaciones del cuadro y las designaciones. No habilitar escrituras directas a tablas para saltear los SP.

## Importación de partidos

Los nombres vacios o NULL son participantes pendientes. Un nombre no vacio que no existe sigue siendo un error. El UPSERT se identifica por sede, horario UTC y fase, para poder completar el mismo registro sin cambiar su ID. Una coincidencia ambigua se rechaza. Un campo vacio no borra participantes o resultados ya conocidos. No se importa ni deduce ganador.

La importación llama a los ABM con @devolver=0, evitando INSERT EXEC innecesario y permitiendo aislar rechazos sin dejar transacciones abiertas. Un cambio de sede u horario de la fuente requiere reconciliación manual: esta clave no reemplaza un identificador externo estable.

## Instalación desde una base recreada

Estos cambios actualizan los scripts de creacion. No se incluye migracion de tablas existentes. Recrear la base siguiendo el flujo habitual del proyecto; ejecutar CREATE TABLE sobre una base antigua no cambia sus columnas.

1. Table/00_Script_DB_Schemas_Creacion.sql y Table/01_Script_Tablas_Creacion.sql.
2. Stored_Procedures_Negocio/16_Designacion_Arbitral.sql (incluye la funcion de normalización y el evaluador).
3. Los ABM del proyecto. Se modificaron 04, 05, 11, 13, 16, 17 y 19; se agrego 20_Cruce_Partido_ABM.sql.
4. Stored_Procedures_Negocio/13_Confirmar_Resultado_Eliminatorio.sql.
5. Importadores de Seleccion, Sede, Arbitro y Partido; cargas 13.1_Cargar_Cruces_Dataset.sql y 16_Cargar_Designaciones_Arbitrales.sql.
6. Importar los archivos locales de selecciones, sedes, árbitros y partidos. Las rutas son las visibles desde SQL Server.
7. Ejecutar carga.Cargar_Cruces_Dataset y luego carga.Cargar_Designaciones_Arbitrales.

Los esquemas se crean exclusivamente en Table/00_Script_DB_Schemas_Creacion.sql. Los scripts que definen procedimientos no ejecutan automáticamente la carga.

## Ejemplos de uso

```sql
-- Luego de importar el fixture local y los arbitros:
EXEC carga.Cargar_Cruces_Dataset;
EXEC carga.Cargar_Designaciones_Arbitrales @demostrar_rechazo=1;

-- Un solo partido: sustituir por un ID existente.
EXEC carga.Cargar_Designaciones_Arbitrales @id_partido=123;

-- Ganador confirmado manualmente: IDs ilustrativos, no ejecutar sin reemplazar.
EXEC negocio.Confirmar_Resultado_Eliminatorio
    @id_partido=123, @id_seleccion_ganadora=7, @resultado_final='1-1 (4-3 pen)';

EXEC abm.Partidos_Listar;
EXEC abm.Cruce_Partido_Listar;
EXEC abm.Designacion_Arbitral_GetByPartido @id_partido=123;
```

## Aclaración sobre los tests modificados

Test/16_Designacion_Arbitral_Test.sql originalmente preparaba datos y probaba alta, rechazo de nacionalidad, consulta por partido, consulta por árbitro, modificación exitosa y baja exitosa. Su modificación exitosa cambiaba un Principal al rol VAR, incompatible con las nuevas categorías. Ese caso debía adaptarse, por ejemplo a Principal -> Cuarto árbitro cuando hubiera cupo.

La reducción anterior del archivo a una auditoría dejaba operaciones sin probar. El 08/11/2026 se recuperó test.Designacion_Arbitral_Test con datos propios y aserciones de alta, rechazo de nacionalidad sin inserción residual, modificación Principal -> Cuarto árbitro, contenido de ambas consultas y baja. También comprueba que ambas consultas quedan vacías tras la baja.

Test_Negocio/16_Test_Designacion_Arbitral.sql agrega escenarios de altas, categorías, cupos, participantes pendientes, advertencias y efectos entre tablas. No trasladó toda la cobertura anterior: no incluye la modificación exitosa, la baja exitosa ni la consulta por árbitro. El traslado no debe presentarse como equivalente.

La organización implementada conserva el ABM en Test/16... y los escenarios de cruces e interacción entre tablas en Test_Negocio/16.... Que el ABM invoque negocio internamente no elimina la necesidad de probar sus operaciones propias.

En Test_Importaciones/13_Test_Importar_Partido_JSON.sql se mantuvieron las dos importaciones y la consulta de duplicados. Sus cambios fueron:

- INNER JOIN -> LEFT JOIN con Seleccion para mostrar también partidos cuyos participantes están pendientes. Con INNER JOIN esas filas desaparecerían del listado.
- La búsqueda de duplicados pasó de fecha/UTC/participantes a sede/UTC/fase, acompañando al criterio de identificación del importador. Así un encuentro puede completar sus participantes sin ser considerado un partido nuevo.

La clave primaria de Partido sigue siendo id_partido. Sede/UTC/fase es un criterio operativo de búsqueda, no una nueva clave primaria ni una restricción UNIQUE agregada a la tabla. Si cambia sede u horario, requiere reconciliación manual. Conservar un identificador externo estable, como id_partido_fifa, sería una mejora futura; no está implementado en este cambio.

## Pruebas y límites

Ver Test_Negocio/README_Verificacion_Arbitral.md y el informe PDF. Los dos tests de designación modificados se ejecutan en MUNDIALDEFUTBOL, sin exigir un nombre de base de pruebas. Instalar Test/16_Designacion_Arbitral_Test.sql y ejecutar EXEC test.Designacion_Arbitral_Test; el archivo Test_Negocio/16_Test_Designacion_Arbitral.sql ejecuta directamente sus escenarios.

Ambos rechazan una transacción previa abierta para no revertir trabajo del llamador; crean sus datos dentro de una transacción y hacen ROLLBACK tanto al terminar como ante errores. El test ABM usa nombres únicos; el de negocio reserva el prefijo TA_ y aborta si ya está ocupado. La prueba de alias USA reutiliza la referencia a una selección existente, si la hay, sin modificarla. El ROLLBACK elimina las filas de prueba, pero no recupera los valores IDENTITY consumidos.

Esta adaptación abarca los dos tests de designación; los demás scripts sintéticos anteriores no fueron migrados en este cambio. En particular, el de carga todavía exige tablas vacías y conserva datos, por lo que no debe ejecutarse sobre una base poblada. La nueva versión de los dos tests tiene pendiente la ejecución: el motor Docker de SQL Server no estaba disponible el 08/11/2026. No se retomó la regresión completa.

No se automatizan grupos, mejores terceros, rectificación en cascada de resultados, descansos, traslados, superposición de horarios ni reparto equitativo de partidos entre árbitros. Tampoco se modela la habilitacion FIFA/confederacion: puesto conserva las categorías operativas Principal, Asistente y VAR del CSV. Estas limitaciones no deben confundirse con validaciones implementadas.
