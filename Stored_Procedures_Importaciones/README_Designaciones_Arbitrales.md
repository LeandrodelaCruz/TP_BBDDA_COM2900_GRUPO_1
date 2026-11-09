# Entrega 6: mapa de cruces y designaciones arbitrales

Universidad Nacional de La Matanza. Bases de Datos Aplicada. Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Actualización y pruebas: 08/11/2026.

## Alcance actual

Se importan partidos con ambas selecciones informadas y se cargan equipos arbitrales sintéticos. El mapa de cruces permite advertir si el país de un árbitro aparece como rival posterior de alguno de los participantes, según los encuentros cargados.

Partido recupera su estructura anterior a la ampliación arbitral: id_seleccion_1 e id_seleccion_2 son NOT NULL y no existe una columna de selección ganadora. No se admiten encuentros con participantes pendientes, no se interpreta el marcador ni se propagan ganadores. Se retiró el procedimiento de confirmación y avance eliminatorio.

El JSON local contiene 104 partidos con ambas selecciones. Su contenido se conserva tal como estaba. No se certifica la autenticidad de sus resultados ni se presentan las asignaciones sintéticas como oficiales.

## Qué guarda Cruce_Partido

Cada fila relaciona un partido de origen con un lugar de un partido de destino. Contiene id_partido_origen, tipo_clasificado (GANADOR o PERDEDOR), id_partido_destino y posicion_destino (1 o 2). GANADOR y PERDEDOR describen la conexión del cuadro; no almacenan un resultado confirmado ni ejecutan el avance.

Ejemplo: un cuarto Argentina-Brasil y otro Francia-España alimentan una semifinal Argentina-Francia. Se registran dos conexiones GANADOR, una para cada posición de la semifinal. No se modifica ninguno de esos participantes al cargar las conexiones.

La tabla exige una relación por destino/posición, una salida por origen/tipo, referencias a partidos existentes, posición 1 o 2, tipo válido y origen distinto del destino. El ABM valida fases consecutivas, horario posterior y pertenencia del participante de destino al encuentro de origen. PERDEDOR solo conecta semifinal con tercer puesto. Estas validaciones no interpretan marcadores ni certifican por sí solas todo el torneo.

Repetir un alta idéntica no duplica relaciones. Una relación distinta para el mismo lugar se rechaza: para corregirla se utiliza la modificación. La baja y la modificación solo afectan al mapa. La modificación conserva la conexión anterior si la nueva falla. Retirar conexiones puede dejar una evaluación incompleta, que se informa en futuras consultas. No se conserva un historial de advertencias.

## Alimentación y uso

1. Importar selecciones, sedes y árbitros desde los archivos del proyecto.
2. Importar partidos_mundial_2026.json. Ambas selecciones deben existir; una fila incompleta se rechaza y las filas válidas posteriores continúan.
3. Ejecutar carga.Cargar_Cruces_Dataset. Registra las 32 conexiones preparadas para el fixture local. Resuelve los ID internos por horario UTC y fase; exige una coincidencia única y no supone que el número del archivo sea el IDENTITY.
4. Ejecutar carga.Cargar_Designaciones_Arbitrales. La carga pasa por el ABM y completa seis integrantes por partido.

El mapa sigue siendo una configuración específica del archivo local. No se agregó otro importador ni un identificador externo a Partido. Si cambia el fixture se debe revisar la configuración. El sistema no genera el fixture ni deduce sus conexiones. La carga completa del mapa es atómica y puede repetirse sin duplicados.

## Advertencia arbitral

La nacionalidad coincidente con un participante del propio encuentro impide designar. Se utiliza una normalización compartida de alias como USA y United States.

Desde dieciseisavos, negocio.Evaluar_Cruce_Arbitral sigue las conexiones del mapa. Un participante continúa por una conexión únicamente si ya figura en la posición correspondiente del destino. Se compara el país del árbitro con el rival que figura en ese encuentro posterior. Se incluyen final y tercer puesto. No se necesita ni se deduce una selección ganadora.

POSIBLE CRUCE informa un encuentro posterior y no bloquea la designación. EVALUACION INCOMPLETA informa conexiones faltantes en el subcuadro relevante; no equivale a ausencia de riesgo.

La evaluación representa el estado actual de los participantes cargados. En el ejemplo anterior, un árbitro francés para Argentina-Brasil genera advertencia por la semifinal Argentina-Francia. Si el destino se informa como Argentina-España, esa ruta deja de incluir a Francia. No se reconstruyen las posibilidades que existían antes de conocer esos participantes ni se recalcula quién debería haber clasificado según el marcador.

La advertencia se devuelve por OUTPUT y se imprime en llamadas individuales; la carga la incluye en el detalle. Corregir el mapa o los participantes cambia evaluaciones futuras; no reevalúa automáticamente las designaciones ya existentes ni guarda advertencias históricas.

## Protecciones que se mantienen

Se mantienen la validación de nacionalidad, categorías, roles y cupos; los seis integrantes son distintos. PRINCIPAL: uno de categoría Principal; ASISTENTE: dos de categoría Asistente; CUARTO ARBITRO: uno de categoría Principal; VAR y AVAR: uno de cada rol, ambos de categoría VAR.

El ABM de Partido conserva las protecciones contra cambios de participantes con datos dependientes o resultado, y contra conflictos con árbitros existentes. Un partido conectado no puede eliminarse ni cambiar fase u horario sin retirar sus conexiones. Los participantes de origen y destino deben seguir siendo compatibles con el mapa. Se mantienen los controles sobre cambios de país de selecciones y país/categoría de árbitros con relaciones existentes.

## Importación y transacciones

El importador vuelve a identificar partidos por fecha, horario UTC y ambas selecciones, como antes de la ampliación arbitral. Rechaza coincidencias ambiguas. Ese criterio no es una restricción UNIQUE ni un identificador externo estable; corregir participantes o fecha puede requerir reconciliación manual. No se agrega otro mecanismo de identidad.

Se conservan THROW, puntos de guardado y @devolver=0 en las llamadas del importador para permitir errores parciales sin INSERT EXEC. No se utiliza la reimportación para completar participantes pendientes.

La carga arbitral recorre partidos, puestos y candidatos mediante WHILE con claves únicas, sin cursores. Confirma por partido; si se agotan candidatos, revierte las nuevas designaciones de ese encuentro y sigue con el siguiente. Conserva equipos completos y completa equipos parciales. Errores y advertencias describen esa ejecución, sin persistencia histórica propia. La carga exige no tener una transacción externa abierta. Ver README_Transacciones.md en la carpeta de negocio.

## Instalación

Los scripts de creación describen una base recreada. No migran una base anterior ni retiran objetos ya instalados. Esta intervención solo cambia los archivos del proyecto; no altera MUNDIALDEFUTBOL existente.

1. Ejecutar Table/00_Script_DB_Schemas_Creacion.sql y Table/01_Script_Tablas_Creacion.sql.
2. Instalar Stored_Procedures_Negocio/16_Designacion_Arbitral.sql, que define la normalización y el evaluador.
3. Instalar los ABM, incluido 20_Cruce_Partido_ABM.sql.
4. Instalar importadores y cargas 13.1_Cargar_Cruces_Dataset.sql y 16_Cargar_Designaciones_Arbitrales.sql.
5. Importar los archivos y ejecutar las cargas en el orden indicado anteriormente.

Los esquemas se crean exclusivamente en el script central. Instalar un procedimiento no ejecuta su carga.

## Pruebas y límites

La verificación actual está en Test_Negocio/README_Verificacion_Arbitral.md y su PDF. Los scripts sintéticos tienen condiciones de ejecución propias: las pruebas de carga y de errores de importación exigen una base aislada. No ejecutar esos escenarios persistentes sobre una base poblada de trabajo.

No se automatizan clasificación de grupos, mejores terceros, avance de resultados, descansos, traslados, superposición horaria, reparto equitativo ni habilitación FIFA/confederación. La simplificación no agrega reportes ni un calendario de participantes pendientes.
