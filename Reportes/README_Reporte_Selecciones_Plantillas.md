# Entrega 7: selecciones y plantillas en XML

Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha: 09/11/2026.

## Contenido y regla de convocatoria

`reportes.Reporte_Selecciones_Plantillas_XML` devuelve un listado de selecciones con un vector anidado de jugadores, incluyendo convocados vigentes y dados de baja. La raíz es ReporteSeleccionesPlantillas; cada Seleccion tiene identificador, país, confederación, grupo y una Plantilla con los contadores separados `convocadosVigentes` y `jugadoresDadosDeBaja`. Cada Jugador incluye identificador, estado, nombre completo, posición, club y dorsal, según lo solicitado por el punto 6 de la entrega 7 y su ampliación con bajas.

Se utiliza la misma regla de `negocio.Listar_Convocados_Vigentes`: un jugador está convocado si no aparece como `id_jugador_baja` en Reemplazo. El reporte ahora conserva a todos los jugadores y les asigna `estado="CONVOCADO"` o `estado="BAJA"`. Para cada saliente, el nodo Baja informa la fecha, el identificador del reemplazante y el motivo registrado. En una cadena A → B → C, A y B aparecen como bajas y C como convocado. Los jugadores sin reemplazos aparecen como convocados, sin nodo Baja.

El reporte utiliza el estado actual registrado; no recibe fecha de corte ni reconstruye convocatorias históricas. No deduce convocatorias desde formaciones ni incluye cuerpo técnico. No agrega columnas ni modifica cargas o datos.

Las selecciones se ordenan por país e identificador. Sus jugadores se ordenan por dorsal numérico, apellido, nombre e identificador. El entrante hereda el dorsal del saliente, por lo que pueden aparecer varios jugadores con ese dorsal y distinto estado. Los contadores separan la convocatoria vigente del historial de bajas: su suma coincide con los jugadores de la lista. Las selecciones sin jugadores se muestran con ambos contadores en cero. Se pueden consultar plantillas parcialmente cargadas; el reporte no valida ni certifica el mínimo/máximo reglamentario.

El estado se determina por existencia de una baja, sin unir directamente Jugador con todas las filas de Reemplazo. Así cada jugador aparece una sola vez y se cuenta una sola vez; sus registros de baja se anidan dentro de ese jugador.

## Instalación y uso

1. Ejecutar el script central de base y esquemas y crear las tablas del proyecto.
2. Instalar `Reportes/20_Reporte_Selecciones_Plantillas_XML.sql`.
3. Cargar selecciones, jugadores y los reemplazos correspondientes mediante los procesos existentes. El reporte no ejecuta esas cargas.
4. Consultar sobre MUNDIALDEFUTBOL:

```sql
EXEC reportes.Reporte_Selecciones_Plantillas_XML;
```

Se devuelve una columna `reporte_xml` de tipo XML. No es necesario crear un archivo para cumplir la consigna. Puede filtrarse una selección; reemplazar el identificador de ejemplo por uno existente:

```sql
EXEC reportes.Reporte_Selecciones_Plantillas_XML @id_seleccion=1;
```

Si se necesita capturar el XML sin emitir otro resultado:

```sql
DECLARE @xml XML;
EXEC reportes.Reporte_Selecciones_Plantillas_XML
    @reporte=@xml OUTPUT, @devolver=0;
SELECT @xml AS reporte_xml;
```

Los parámetros inválidos se agrupan en THROW 53501. Una selección inexistente es un error; una selección existente sin jugadores es una respuesta válida con lista vacía. Una selección que solo tuviera jugadores dados de baja conserva esos registros y muestra cero convocados vigentes. Sin selecciones cargadas, la consulta general devuelve la raíz XML vacía.

## Prueba y evidencia

`Reportes/21_Test_Reporte_Selecciones_Plantillas_XML.sql` instala y ejecuta `test.Reporte_Selecciones_Plantillas_XML_Test` en MUNDIALDEFUTBOL. Crea datos propios con nombres únicos y los revierte tanto al terminar como ante un fallo. Rechaza transacciones previas. Requiere las tablas y el reporte; no necesita que se hayan importado plantillas reales. Puede consumir números IDENTITY aunque se reviertan las filas.

Se verifican el XML, todos los campos solicitados, la clasificación de salientes y sustitutos intermedios como bajas, sus fechas, motivos y reemplazantes, la ausencia de bajas en jugadores convocados, los contadores separados, los jugadores sin reemplazos, el orden numérico de dorsales, los caracteres especiales, los filtros, la repetición estable, las selecciones vacías y el listado general. La prueba no modifica la lógica de Reemplazo ni intenta probar de nuevo sus validaciones de negocio.

Resultado del 09/11/2026 en SQL Server 2022 Developer: aprobado. La selección de prueba mostró cuatro jugadores: dos convocados y dos bajas, con sus datos de reemplazo y ordenados por dorsales 1 y 9. Las filas ficticias se revirtieron. El XML emitido por esa ejecución se conserva, formateado, en `Reportes/Ejemplo_Selecciones_Plantillas.xml`; sus identificadores de prueba ya no existen al finalizar.

El reporte arbitral y este reporte constituyen dos salidas XML para la entrega 7. La prueba no representa una regresión completa de los demás módulos ni certifica la integridad de una población real todavía no cargada.
