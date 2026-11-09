# Carga manual de reemplazos de convocatoria

Carga por otros medios admitida en la seccion I. No cuenta como dataset
externo importado, API ni scraping. Los SQL conservan los acentos y nombres
completos del archivo `Archivos_Importacion/jugadores_fifa_pdf.csv`.

Como Region y Pieza_Para_Region, el procedimiento pertenece al esquema `carga`
y se instala desde `Stored_Procedures_Importaciones`. Invoca la operacion
funcional `negocio.Registrar_Reemplazo` para cada caso.

La carga y la preparacion de su prueba recorren las claves con `WHILE`.
El patron reutilizable esta explicado en [README_Recorrido_WHILE.md](README_Recorrido_WHILE.md).

## Casos

| Seleccion | Saliente | Entrante | Dorsal | Fecha simulada |
| --- | --- | --- | --- | --- |
| Argentina | Leonardo Julian Balerdi Rosa | Marcos Senesi | 2 | 2026-06-15 |
| Brazil | Wesley Vinicius Franca Lima | Ederson de Atalanta | 2 | 2026-06-12 |
| Germany | Lennart Karl | Assan Ouedraogo | 25 | 2026-06-13 |
| Austria | Christoph Baumgartner | Dejan Ljubicic | 19 | 2026-06-15 |
| England | Valentino Francisco Livramento | Trevoh Chalobah | 12 | 2026-06-16 |

Las fechas fueron acordadas para el TP: NO son fechas historicas verificadas.
El motivo guardado tambien indica que son simuladas. Son anteriores a los
debuts del fixture: Brasil 13/6, Alemania 14/6, Argentina y Austria 16/6,
Inglaterra 17/6. Los dorsales se toman del entrante del CSV y se asignan al
saliente al reconstruir la convocatoria: es un supuesto explicito del escenario.

Los pares saliente/entrante estan documentados en la
[recopilacion de ge del 17/06/2026, actualizada el 18/06](https://ge.globo.com/futebol/copa-do-mundo/noticia/2026/06/17/copa-do-mundo-2026-veja-lista-final-com-todos-os-cortados-e-substitutos.ghtml).
Tambien se consultaron [Bolavip para Inglaterra](https://bolavip.com/ar/mundial/cambio-en-la-lista-de-inglaterra-a-24hs-de-su-debut-en-el-mundial-2026-ingresa-trevorh-chalobah-ante-la-lesion-de-tino-livramento)
y [FIFA para Brasil](https://www.fifa.com/es/articles/brasil-convocado-ederson-wesley-ancelotti).

Datos de los salientes, Wikipedia consultada el 03/11/2026:

| Nombre / apellido | Nacimiento | Club en junio de 2026 | Posicion adaptada |
| --- | --- | --- | --- |
| [Leonardo Julian / Balerdi Rosa](https://en.wikipedia.org/wiki/Leonardo_Balerdi) | 1999-01-26 | Olympique Marseille | Defensa |
| [Wesley Vinicius / Franca Lima](https://en.wikipedia.org/wiki/Wesley_Fran%C3%A7a) | 2003-09-06 | AS Roma | Defensa |
| [Lennart / Karl](https://en.wikipedia.org/wiki/Lennart_Karl) | 2008-02-22 | Bayern Munchen | Mediocentro |
| [Christoph / Baumgartner](https://en.wikipedia.org/wiki/Christoph_Baumgartner) | 1999-08-01 | RB Leipzig | Mediocentro |
| [Valentino Francisco / Livramento](https://en.wikipedia.org/wiki/Tino_Livramento) | 2002-11-12 | Newcastle United | Defensa |

Se usa Marseille para Balerdi en junio; su pase a Roma es posterior. Los
datos del entrante, incluyendo club y nacimiento, se conservan tal como estan
en el CSV, sin actualizarlos con datos posteriores. Ederson de Atalanta es
distinto del arquero Ederson Santana de Moraes.

## Instalacion y ejecucion

1. Ejecutar `Table/00_Script_DB_Schemas_Creacion.sql`: crea la base y todos los esquemas, incluidos `negocio` y `carga`. Los otros scripts solo validan su existencia.
2. Instalar tablas y ABM 10 (Jugador) y 14 (Reemplazo).
3. Ejecutar la version actual de `Stored_Procedures_Negocio/14_Registrar_Reemplazo.sql`.
4. Ejecutar `Stored_Procedures_Importaciones/14_Cargar_Reemplazos_Manuales.sql`.
5. Importar las selecciones y jugadores mediante los procesos existentes.
6. Ejecutar el procedimiento indicado debajo antes de cargar formaciones e incidencias. El fixture puede existir.

Desde una consulta sobre MUNDIALDEFUTBOL:

```sql
EXEC carga.Cargar_Reemplazos_Manuales @reconstruir_convocatoria = 1;
```

Se muestran resumen y detalle de cinco casos: APLICADO, YA APLICADO o ERROR,
con ID del reemplazo o numero y mensaje del error. Los contadores tambien se
devuelven mediante parametros OUTPUT. Un caso fallido no impide procesar los
otros. Ejecutar sin una transaccion externa, para confirmar cada caso por separado.

## Tratamiento de listas finales

Si esta el entrante y falta el saliente, se exige habilitar explicitamente la
reconstruccion. Se comprueban identidad y datos del entrante, ausencia de
referencias en formaciones/incidencias/sustituciones/reemplazos, ausencia de
formaciones de la seleccion y una fecha anterior al debut registrado.

En una transaccion se retira al entrante con Jugador_Baja, se crea al saliente
con Jugador_Alta y se aplica Registrar_Reemplazo. Si falla cualquier paso, se
restauran la plantilla y los IDs originales. Si confirma, el entrante tiene un
ID nuevo: realizar esta preparacion antes de usar esos IDs en otras tablas.
Las claves foraneas permanecen habilitadas y todos los cambios usan SP.

Si solo existe el saliente, se aplica directamente el reemplazo. Si ambos
existen sin el reemplazo exacto, falta la pareja completa o tienen otro historial,
se informa un error para revision. Si el reemplazo exacto ya existe, se omite
conservando los IDs y el historial, incluso si hubo actividad posterior.

Se conserva la cantidad de convocados vigentes. Con una lista de 26 quedan
27 filas historicas por seleccion: 26 vigentes y un saliente. Consultar
`negocio.Listar_Convocados_Vigentes`. La identidad usa seleccion, nombre,
apellido y nacimiento, sin IDs fijos. Evitar volver a importar una fuente
antigua que refleje otra convocatoria: el importador de Jugador no administra
el historial de reemplazos.

## Pruebas

`Test_Importaciones/14_Test_Carga_Reemplazos.sql` apunta a MUNDIALDEFUTBOL.
Requiere Seleccion y Jugador vacias y ninguna transaccion abierta; ejecutarlo
antes de la poblacion de esas tablas. Requiere tambien los ABM 03/04/13 para
crear datos de apoyo. Crea cinco plantillas minimas y un fixture, y conserva
la evidencia en la base principal. No elimina datos previos para preparar el caso.

Verifica reconstruccion explicita, cuatro casos exitosos y un quinto con fallo
de escritura simulado, restauracion completa del quinto, reintento solo del
pendiente y repeticion sin duplicados ni cambios de identidad. El trigger
transitorio que simula el fallo se elimina al terminar.

Las pruebas individuales (seis casos) y las del lote (cuatro casos) pasaron
en SQL Server el 03/11/2026.

Tambien se verifico en otra base aislada con las cinco listas completas del
CSV (130 jugadores): cinco reemplazos aplicados, 135 jugadores historicos,
26 vigentes por seleccion, los otros 125 jugadores sin cambios y cinco casos
omitidos al repetir la carga. Las bases temporales de verificacion se eliminan
al finalizar; la base del proyecto no se modifica durante estas pruebas.
