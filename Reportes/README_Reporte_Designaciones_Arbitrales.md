# Entrega 7: designaciones arbitrales en XML

Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha: 09/11/2026.

## Resultado

`reportes.Reporte_Designaciones_Arbitrales_XML` devuelve una columna de tipo XML, `reporte_xml`, con la jerarquía ReporteDesignacionesArbitrales → Arbitro → Partidos → Partido → Tarjetas → Tarjeta. Aporta uno de los dos reportes XML exigidos por la entrega 7.

Por árbitro se informa nombre, país, cantidad de partidos asignados, cantidad como principal y totales de amonestaciones/expulsiones atribuidas. Por partido se muestra fecha, fase, selecciones y rol. El detalle de tarjetas contiene identificador de incidencia, tipo, jugador con identificador y nombre, selección, minuto, período y motivo cuando están informados.

## Reglas del reporte

- Incidencia no identifica al árbitro que señaló un evento. Por decisión del grupo, AMONESTACION y EXPULSION se atribuyen al designado como PRINCIPAL de ese partido.
- Se muestran también ASISTENTE, CUARTO ARBITRO, VAR y AVAR. Sus partidos contienen `Tarjetas atribuibles="false"`, sin detalle ni resumen de tarjetas del encuentro. No significa cero tarjetas señaladas por esas personas: significa que el modelo no permite atribuirles esas incidencias.
- El principal sin tarjetas registradas tiene resumen en cero y `Tarjetas atribuibles="true"` vacío. Cero registros no certifica que las incidencias del partido estén completamente cargadas.
- Una segunda amarilla y su posterior expulsión son dos incidencias: se conservan y cuentan ambas. No se interpreta el motivo para clasificar expulsiones en directas o por doble amarilla.
- Goles, penales y revisiones VAR quedan excluidos. Los eventos no se repiten por cada miembro del equipo arbitral.
- Los filtros se aplican antes de calcular los totales: resumen y detalle corresponden al mismo conjunto de partidos. Sin coincidencias se devuelve la raíz XML vacía; no es un error.
- Solo aparecen árbitros con designaciones en el conjunto seleccionado. Si el filtro identifica un árbitro existente pero sin designaciones, también se devuelve la raíz vacía.
- Se utiliza el estado actual de las designaciones. No hay un historial de cambios que permita reconstruir un principal anterior.
- Los partidos se ordenan por horario UTC e identificador; los eventos por período, minuto e identificador de incidencia. Un minuto desconocido se omite y se coloca al final de su período; un motivo NULL se omite.

No se agregan columnas ni se modifican las tablas. No se utilizan Cruce_Partido ni Sancion_Arbitral, ni se ejecutan importaciones o simulaciones desde el reporte. Si hubiera duplicados en Incidencia, se reflejarían en los totales: corregir la importación es independiente y no se ocultan filas con DISTINCT. La validación final de la entrega parte de una base creada desde cero con el importador corregido.

## Instalación y ejecución

1. Ejecutar el script central `Table/00_Script_DB_Schemas_Creacion.sql`, que ahora incluye el esquema compartido reportes.
2. Crear las tablas e instalar los ABM y las cargas habituales. Para datos representativos, cargar selecciones, jugadores, partidos, árbitros, designaciones e incidencias.
3. Instalar `Reportes/18_Reporte_Designaciones_Arbitrales_XML.sql`.
4. Ejecutar en MUNDIALDEFUTBOL:

```sql
EXEC reportes.Reporte_Designaciones_Arbitrales_XML;
```

Los identificadores de los ejemplos siguientes deben reemplazarse por valores existentes:

```sql
EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_arbitro=25;
EXEC reportes.Reporte_Designaciones_Arbitrales_XML @id_partido=101;
EXEC reportes.Reporte_Designaciones_Arbitrales_XML
    @id_arbitro=25, @id_partido=101;
```

También puede obtenerse el mismo XML por OUTPUT, sin emitir un resultado adicional:

```sql
DECLARE @xml XML;
EXEC reportes.Reporte_Designaciones_Arbitrales_XML
    @reporte=@xml OUTPUT, @devolver=0;
SELECT @xml AS reporte_xml;
```

No es necesario escribir un archivo para cumplir la consigna. SQL Server muestra el XML al ejecutar el procedimiento.

## Validaciones

Los filtros inválidos o inexistentes se agrupan en el error 53401. Una combinación de filtros válidos sin coincidencias devuelve una raíz vacía. Si un partido seleccionado tiene más de un PRINCIPAL, el error 53402 evita atribuir sus tarjetas dos veces o elegir una persona arbitrariamente. Se utiliza THROW y no hay cursores ni SQL dinámico.

## Pruebas y ejemplo

`Reportes/19_Test_Reporte_Designaciones_Arbitrales_XML.sql` instala y ejecuta `test.Reporte_Designaciones_Arbitrales_XML_Test` sobre MUNDIALDEFUTBOL. No requiere una base auxiliar ni datos de negocio previamente cargados; sí las tablas y el procedimiento de reporte. Crea un escenario propio con nombres únicos dentro de una transacción y revierte sus filas al terminar o fallar. Rechaza transacciones previas. Los IDENTITY consumidos pueden dejar saltos aunque se reviertan las filas.

La prueba usa un árbitro Principal que actúa como principal en dos partidos y cuarto árbitro en otro, respetando la categoría actual del proyecto. Los asistentes y el VAR son personas distintas. Comprueba filtros individuales y combinados, totales, jugador, caracteres XML, NULL, orden de segunda amarilla/expulsión, inclusión sin tarjetas, exclusión de otros eventos, raíz vacía y rechazo de dos principales. Emite el XML de ejemplo incluso después de revertir sus datos; esas referencias son ficticias y ya no existen en la base al terminar.

Resultado del 09/11/2026 en SQL Server 2022 Developer: aprobado. Resumen del árbitro de prueba: tres asignaciones, dos como principal, dos amonestaciones y una expulsión. Se verificaron también las validaciones y la reversión del escenario. No representa una regresión completa del resto de los módulos.

`Reportes/Ejemplo_Designaciones_Arbitrales.xml` conserva el XML emitido por esa ejecución, formateado para lectura. No contiene designaciones oficiales.

## Integración con los avances del grupo

Se sigue la carpeta Reportes y el esquema reportes ya utilizados por publicidad. Se centralizó la creación de esquemas que estaba repetida en los reportes, sus tests y las nuevas cargas de incidencias/simulaciones: esos archivos ahora verifican la dependencia e indican ejecutar el script central si falta. No se cambió su lógica de negocio ni se corrigió el UPSERT del importador.

La solución de SSMS incluye los reportes y sus tests. Se corrigieron además dos referencias que todavía conservaban los nombres anteriores del importador de árbitros y su test después del merge.
