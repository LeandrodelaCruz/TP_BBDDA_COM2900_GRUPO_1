# Migracion del proyecto a WHILE

Fecha: 07/11/2026. Motivo: correccion docente que prohibe cursores SQL.
El usuario autorizo extender el patron de Reemplazo y Personal_Tecnico y,
tras revisar su funcionamiento, aprobo las adaptaciones especiales de
Formacion_Jugador y asignacion publicitaria, solicitando esta comparacion.

## Recorridos de importacion: estado anterior y nuevo

| Aspecto | Estado anterior | Estado nuevo |
| --- | --- | --- |
| Fuente | Filas de staging o de una tabla de casos | Copia fija de las mismas columnas, sin modificar la entrada |
| Posicion | Estado interno del cursor y FETCH NEXT | Clave numerica unica y MIN de la clave siguiente |
| Inicio y fin | OPEN y estado de lectura | MIN inicial; NULL termina el WHILE |
| Variables | FETCH asignaba las columnas a variables | SELECT por clave asigna las mismas columnas a las mismas variables |
| Orden explicito | ORDER BY del recorrido anterior | ROW_NUMBER con ese mismo ORDER BY |
| Sin orden explicito | Orden no garantizado | ROW_NUMBER sobre la copia, sin prometer orden fisico del archivo |
| Validaciones y ABM | Validaciones y SP existentes por fila | Se conservan |
| Errores parciales | CATCH informaba el error y seguia la lectura | CATCH informa el error y avanza a la siguiente clave |
| Recursos | Cierre y liberacion del cursor | Tablas temporales locales al procedimiento |

Las copias de trabajo tienen un indice unico por orden_recorrido. No se agrega
ninguna columna a las tablas que reciben BULK INSERT: se respeta su formato,
sus codificaciones y sus conversiones originales. No se cambian parametros,
claves de UPSERT, resumenes ni limites de transaccion.

Archivos adaptados con esta variante del patron:

- `01_Importar_Anunciante_CSV.sql`.
- `01_Importar_Seleccion_CSV.sql`.
- `02_Cargar_Regiones.sql`.
- `03_Importar_Sede_CSV.sql`.
- `05_SP_Importar_Arbitro_PDF_CSV.sql`.
- `06_Importar_Campania_CSV.sql`.
- `07_Importar_Pieza_Publicitaria_CSV.sql`.
- `08_Cargar_Pieza_Region.sql`.
- `10_Importar_Jugador_PDF_CSV.sql` y su copia en
  `Entrega6_Jugador_Desde_PDF/Stored_Procedures_Importaciones/03_SP_Importar_Jugador_PDF_CSV.sql`.
- `11_Importar_Formacion_JSON.sql`.
- `13_Importar_Partido_JSON.sql`.

Reemplazo y Personal_Tecnico ya estaban adaptados antes de esta extension.

## Formacion: avance antes de CONTINUE

En `11_Importar_Formacion_JSON.sql`, una validacion fallida a nivel partido
registra un error y salta las dos selecciones con CONTINUE. Antes se hacia
una lectura adicional justo antes del salto. Ahora se busca la siguiente clave
en ese mismo punto. El avance normal sigue al final de la vuelta.

Por lo tanto, cada camino avanza exactamente una vez. Se conserva el orden
por numero de partido y fecha, y el WHILE interno de dos selecciones.

## Caso especial 1: Formacion_Jugador

Archivo: `12_Importar_Formacion_Jugador_JSON.sql`.

### Estado anterior

Un cursor recorria `#JugadoresJSON` por `id_registro`, generado con IDENTITY.
Cada jugador consultaba lo que ya habia en `dbo.Formacion_Jugador` y hacia su
UPSERT. Esto afecta los controles de maximo 11 titulares y 26 convocados:
el estado observado por una fila incluye lo procesado antes de ella.

Los errores de validacion se acumulaban en `#Errores` y los de escritura se
capturaban por operacion. No habia una transaccion global para todo el lote.
El CATCH exterior tambien intentaba cerrar y liberar el cursor.

### Estado nuevo

Se usa directamente la misma clave `id_registro` de la tabla temporal:
MIN inicial, SELECT por esa clave y MIN mayor al terminar cada vuelta.
No se reordena por nombre, dorsal, seleccion ni condicion de titular.

Se conservan todas las consultas a los titulares/convocados ya persistidos,
las ramas de alta y actualizacion y los contadores. No se introduce un
tratamiento masivo que evalua todos los limites sobre el estado inicial.
Se retiran solamente las instrucciones de recorrido y su limpieza exterior.

No se agrega una transaccion global. Se conserva el manejo de errores previo,
incluido el RAISERROR exterior. La rama que ya actualizaba directamente la
relacion sigue haciendolo: esta migracion no rediseña sus ABM ni sus reglas.

### Comprobaciones

- Una entrada con 12 titulares debe conservar solo 11 y continuar con el banco.
- Corregir ese jugador a suplente permite completar los 26.
- Repetir la entrada no duplica relaciones.
- Un jugador adicional debe rechazarse al llegar a 26.
- Una fila valida posterior a un error debe seguir procesandose.

## Caso especial 2: asignacion publicitaria

Archivo: `Stored_Procedures_Negocio/15_Generar_Asignacion_Publicitaria.sql`.

### Estado anterior

La seleccion de mercados/piezas se calculaba antes de persistir. Dentro de una
transaccion habia dos recorridos:

1. Cursor ordenado por numero_espacio sobre `#Seleccionados`. Para cada espacio:
   alta si falta; modificacion de costo si la pieza coincide; baja y alta si cambia.
2. Cursor sobre las asignaciones persistidas del partido cuyo espacio ya no
   aparece entre los seleccionados. Cada ID se eliminaba mediante su ABM.

Al finalizar ambas fases se confirmaba la transaccion. Ante un error se
revertia y se intentaban cerrar/liberar los dos cursores.

### Estado nuevo

La primera fase recorre `#Seleccionados` por MIN(numero_espacio). Conserva el
orden, las tres ramas de ABM y los costos calculados.

La segunda fase crea `#Bajas_Pendientes` con los IDs obsoletos DESPUES de la
primera fase, igual que el momento de apertura del recorrido anterior. Esa
lista queda fija y se recorre por ID ascendente, ejecutando el ABM de baja.
El orden de bajas antes no estaba especificado; ahora es explicito.

Se elimina de `dbo.Asignacion_Publicitaria`, pero se avanza sobre la copia de
IDs. No se vuelve a buscar una fila pendiente en la tabla que se esta borrando.
Una seleccion vacia recorre cero altas y retira todas las asignaciones previas
del partido. Una lista de bajas vacia salta directamente al COMMIT.

Ambas fases siguen en una sola transaccion: no se confirman espacios ni bajas
individualmente. El CATCH conserva ROLLBACK y THROW; solo se retira la limpieza
de los cursores. Se mantienen el ranking, los limites de cuatro espacios y los
criterios de prime time; no se revisan en esta correccion.

### Comprobaciones

- Seleccion con mas de cuatro candidatos y persistencia de solo cuatro.
- Repeticion y actualizacion de costos sin duplicar espacios.
- Cambio de piezas mediante baja y alta.
- Seleccion vacia y eliminacion de todas las asignaciones obsoletas.
- Fallo durante las bajas y restauracion de las asignaciones previas.

## Alcance de la evidencia

Las verificaciones se ejecutaron en SQL Server el 07/11/2026, en una base
aislada, con los CSV/JSON del repo y entradas controladas. No se modifico la
base del proyecto. Los 14 archivos adaptados en esta extension contienen 15
recorridos anteriores; los dos recorridos publicitarios pertenecen al mismo SP.

| Importacion o carga | Registros persistidos | Segunda ejecucion |
| --- | ---: | --- |
| Seleccion | 48 | Mismos IDs y datos |
| Sede | 16 | Mismos IDs y datos |
| Arbitro | 170 | Mismos IDs y datos |
| Jugador | 1248 | Mismos IDs y datos |
| Anunciante | 8 | Mismos IDs y datos |
| Campania | 8 | Mismos IDs y datos |
| Pieza_Publicitaria | 8 | Mismos IDs y datos |
| Region | 8 | Mismos IDs y datos |
| Pieza_Para_Region | 8 | Mismas relaciones |
| Partido | 104 | Mismos IDs y datos |
| Formacion | 208 | Mismos IDs y datos |

Tambien se ejecuto la copia de Jugador de la entrega anterior, sobre los 1248
existentes: no genero duplicados. La estabilidad de las tablas se comprobo
comparando todas sus columnas antes y despues, en ambos sentidos con EXCEPT.

Verificaciones adicionales aprobadas:

- Seleccion: archivo solo con encabezado y una fila valida posterior a otra
  invalida. El lote parcial proceso una actualizacion, un error y una alta.
- Formacion: un partido invalido seguido de uno valido. Se registro el error
  y se actualizo el esquema tactico del siguiente, comprobando el CONTINUE.
- Formacion_Jugador: 12 titulares de entrada dejan 11 y permiten continuar con
  el banco; corregir el jugador permite completar los 26. La repeticion conserva
  las relaciones. Se rechazan un convocado 27 y un nombre vacio, y se aplica
  la fila valida que sigue a esos errores.
- Publicidad: mas de cuatro candidatos producen cuatro espacios; cambiar un
  costo conserva los IDs; retirar una relacion cambia la pieza; un fallo
  simulado en la ultima baja revierte las tres anteriores. Reintentar con
  seleccion vacia retira los cuatro espacios y puede repetirse sin nuevas filas.

## Pruebas reproducibles de los casos especiales

Partir de una base aislada cuyo nombre comience por
`MUNDIALDEFUTBOL_Test_While_`, creada con el script central adaptando solo el
nombre de la base. Instalar tablas, ABM, importadores y negocio. Cargar
selecciones, sedes, jugadores, publicidad, regiones, relaciones, partidos y
formaciones con los datasets del repo. Cada archivo de prueba detalla sus
dependencias y rechaza ejecutarse sobre la base del proyecto.

Para Formacion_Jugador:

1. Copiar los tres JSON de `Test_Importaciones/Datos_Recorridos` a una ruta
   visible por SQL Server. Contienen jugadores de Mexico del primer partido
   del dataset y un jugador de apoyo que el test crea mediante ABM.
2. Instalar `Test_Importaciones/12_Test_Recorrido_Formacion_Jugador_JSON.sql`
   sobre la base aislada seleccionada en SSMS.
3. Ejecutar `test.Recorrido_Formacion_Jugador_Test` con las tres rutas, como
   indica el ejemplo al final de ese archivo. El test revierte todos sus datos
   y comprueba que restaure las relaciones que habia antes de ejecutarlo.

Para Publicidad, ejecutar
`Test_Negocio/15.1_Test_Recorridos_Asignacion_Publicitaria.sql` sobre la base
aislada. Esta prueba cambia los horarios de las regiones para controlar los
candidatos y deja la evidencia en la base de pruebas. Inyecta un fallo con un
trigger transitorio y lo elimina al finalizar. Tambien paso la prueba existente
`Test_Negocio/15_Test_Generar_Asignacion_Publicitaria.sql`.

La busqueda final sobre todos los archivos SQL del repo, incluida la copia de
Jugador, no encontro declaraciones, operaciones de lectura ni limpieza de
cursores. No se cambiaron los formatos de entrada ni se agregaron esquemas.


## Designaciones arbitrales y cuadro (07/11/2026)

Antes no habia carga de designaciones ni mapa. Ahora Cargar_Designaciones_Arbitrales
recorre partido, puesto y candidato mediante claves unicas y MIN(clave) mayor que la
anterior. Esta adaptacion fue aprobada por el usuario: las filas del equipo dependen
entre si y se confirman por partido completo. Los candidatos se ordenan una sola vez
por puesto y no se eliminan para controlar el avance. Los rechazos previstos usan un
punto de guardado; al fallar el equipo se revierte el partido y se avanza al siguiente.
La carga de cruces y la propagacion de resultados tambien usan claves unicas y avance
explicito. No se introdujeron cursores. Ver README_Designaciones_Arbitrales.md.
