# Verificación de la simplificación arbitral

Universidad Nacional de La Matanza. Bases de Datos Aplicada. Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha: 08/11/2026. Motor probado: SQL Server 2022 Developer, 16.0.4265.3, contenedor Linux.

## Cambio verificado

Se comparó el proyecto con TP_BBDDA_COM2900_rollback. Partido recuperó la definición de tabla de ese respaldo: ambas selecciones obligatorias y sin columna de ganadora. Se retiraron la confirmación/propagación de resultados y el soporte de participantes pendientes. Se conservaron los controles de designación y el mapa de cruces para advertencias sobre los participantes cargados.

Se mantuvieron mejoras independientes del avance: THROW, errores parciales de importación, puntos de guardado, normalización de países, cupos y compatibilidad de roles. No se restauraron archivos completos de módulos ajenos ni se revirtieron sus cambios posteriores al respaldo.

## Entorno y aislamiento

Se instalaron tablas, evaluador, todos los ABM y los importadores/cargas necesarios en dos bases nuevas: Codex_Arbitral_Simple_20261108 y Codex_Arbitral_Simple_Dataset_20261108. La compilación concluyó sin errores. La base principal MUNDIALDEFUTBOL no fue modificada. El respaldo proporcionado por el usuario se utilizó solo para lectura.

Se conservó una copia previa de cada archivo modificado o retirado fuera del repositorio, en la carpeta de trabajo de esta conversación. Los resultados anteriores de noviembre corresponden a la implementación anterior y no se trasladan como pruebas de la versión simplificada.

## Mapa de cruces

Test_Negocio/13_Test_Mapa_Cruces.sql: aprobado en SQL Server; revierte sus datos al terminar.

- Rechazo de alta y modificación sin ambas selecciones, conservando la transacción externa.
- Alta repetida sin duplicados y rechazo de fases invertidas.
- Modificación incompatible revertida sin perder la relación anterior.
- Modificación válida y baja de conexiones con participantes informados.
- Protección del horario de un partido conectado.
- Cargar, modificar o quitar conexiones no cambia participantes ni resultados.
- Detección de cruce hacia la final a dos saltos y por la rama de tercer puesto.
- Ausencia de advertencia para una selección situada en otra ruta del cuadro.

## Designación y mantenimiento

Test_Negocio/16_Test_Designacion_Arbitral.sql y Test/16_Designacion_Arbitral_Test.sql: aprobados en SQL Server; revierten sus datos.

- Rechazo de nacionalidad y equivalencia USA/United States.
- Categoría incompatible, cupo de principal y validaciones en modificación.
- Advertencia no bloqueante sobre una ruta cargada y aviso de mapa parcial.
- Desaparición del conflicto al informar otro participante en el destino, sin confirmar ni propagar resultados.
- Rechazo de cambio de participante que genera conflicto con un árbitro y cambio de país del árbitro con designaciones.
- Equipo completo, alta, modificación exitosa de rol, consultas por partido/árbitro y baja.
- Conservación de la transacción externa después de los rechazos previstos.

## Carga y errores parciales

Test_Importaciones/16_Test_Carga_Designaciones_Arbitrales.sql: aprobado en base aislada. Conserva sus datos de prueba y requiere partidos/árbitros vacíos.

- Lote vacío, rechazo de candidato y sustitución por uno válido.
- Repetición con conservación de integrantes y roles.
- Falta de candidato VAR: reversión de las filas nuevas del partido.
- Conservación de otro equipo, reposición de candidato y completado de equipo parcial.
- Continuación del recorrido sobre los demás partidos.

Test_Importaciones/13.2_Test_Partidos_Incompletos.sql: aprobado en base aislada. Usa los dos JSON sintéticos existentes, cuyos nombres conservan su denominación histórica; ahora comprueba el rechazo de participantes faltantes.

- Archivo sin selecciones: ninguna fila aceptada.
- Archivo mixto: dos filas válidas y dos rechazadas, sin detener las filas posteriores.
- Repetición sin duplicados y sin transacciones abiertas.

## Dataset completo

Test_Importaciones/16.1_Test_Designaciones_Dataset.sql: aprobado en una segunda base aislada con los archivos locales sin modificarlos.

- 104 partidos con ambas selecciones.
- 32 conexiones; repetir su carga mantiene esa cantidad.
- 624 designaciones para 104 equipos completos de seis personas.
- Cero conflictos de nacionalidad en las designaciones aceptadas.
- Segunda carga sin equipos nuevos ni cambios de integrantes.
- Reimportación del JSON sin duplicar los 104 partidos.

Las asignaciones son sintéticas. Los candidatos, rechazos y tiempos dependen de cada ejecución; no se certifican designaciones oficiales ni concurrencia.

## Comprobaciones finales y límites

Se comprueba la identidad de la definición de Partido con el respaldo, ausencia de referencias SQL a la funcionalidad retirada, archivos de la solución existentes, esquemas centralizados y ausencia de cursores. Estas comprobaciones estáticas complementan las ejecuciones anteriores.

No se declara una regresión completa de todos los módulos del TP ni pruebas independientes exhaustivas de cada CHECK/FK. Formaciones, incidencias y sustituciones se compilaron, pero sus suites completas no se ejecutaron en esta intervención. No se creó una migración de bases existentes.

La advertencia utiliza participantes actuales de los destinos; no reconstruye posibilidades históricas ni infiere ganadores del marcador. Cruce_Partido continúa alimentándose con la configuración específica del dataset local. La guía de ejecución actualizada detalla estos límites.
