# Verificación de calendario y designaciones arbitrales

Universidad Nacional de La Matanza. Bases de Datos Aplicada. Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha: 07/11/2026. Motor: SQL Server 2022 Developer, 16.0.4265.3, contenedor Linux.

## Aclaración de cobertura y cambios en los tests (08/11/2026)

Los resultados del 07/11/2026 corresponden a los escenarios enumerados en este informe. No certifican una regresión completa de todos los objetos preexistentes ni de todas las dependencias modificadas. La regresión posterior se dejó de continuar por indicación del usuario; la recuperación puntual del test ABM no la declara completada ni modifica los resultados históricos.

El test original Test/16_Designacion_Arbitral_Test.sql fue reducido a una auditoría de nacionalidad y un listado de cantidades. No es equivalente a su anterior cobertura de operaciones ABM. Test_Negocio/16_Test_Designacion_Arbitral.sql tampoco reemplaza todos sus casos:

| Operación o escenario | Cobertura del nuevo test de negocio |
|---|---|
| Altas y rechazos de nacionalidad/categoría/cupo | Incluidos. |
| Advertencias de cruces e interacción entre tablas | Incluidas. |
| Consulta por partido | Ejecutada como evidencia; no valida exhaustivamente su resultado. |
| Modificación rechazada | Incluida. |
| Modificación exitosa | No incluida en ese archivo. |
| Baja exitosa | No incluida en ese archivo; hay llamadas a baja en el test de carga. |
| Consulta por árbitro | No incluida en ese archivo. |

Actualización del 08/11/2026: se recuperó el código del test ABM con alta, rechazo de nacionalidad, modificación Principal -> Cuarto árbitro, validación de los resultados de ambas consultas y baja. Tras eliminar comprueba también que ambas consultas no devuelven filas. La tabla anterior describe exclusivamente el archivo de negocio, no la cobertura conjunta.

Los dos tests de designación ahora usan MUNDIALDEFUTBOL con datos propios y ROLLBACK al finalizar o fallar. Rechazan transacciones previas abiertas. El test de negocio admite USA ya cargada sin modificar esa selección. Pueden consumir números IDENTITY aunque las filas se reviertan. Los demás scripts sintéticos no se adaptaron en esta intervención.

Validación de esta actualización: revisión estática del código; ejecución pendiente porque el motor Docker de SQL Server no estaba disponible y no se encontró un servicio SQL Server local. No se atribuyen resultados aprobados a estas nuevas versiones.

Las restricciones de Partido y Cruce_Partido también deben distinguirse de las validaciones de los SP. Los escenarios que fallan antes del INSERT/UPDATE no verifican directamente cada CHECK o FK. Este informe no afirma una prueba independiente exhaustiva de todas las restricciones nuevas.

El test de importación de Partido cambió sus JOIN a LEFT JOIN para conservar filas pendientes en la consulta y su agrupación de duplicados a sede/UTC/fase para acompañar al importador. Mantiene dos ejecuciones del mismo archivo. Ese criterio no reemplaza la PK id_partido ni resuelve automáticamente reprogramaciones de sede u horario.

Para el ejemplo físico de los partidos 97, 98 y 101, las restricciones exactas y los límites de Confirmar_Resultado_Eliminatorio, consultar la guía README_Designaciones_Arbitrales.md y su PDF. La explicación distingue comportamientos implementados de mejoras pendientes.

## Resultado general

Los scripts se compilaron y ejecutaron en bases aisladas. Se probaron escenarios simulados y los archivos originales del proyecto. La asignacion es sintética; no se verificaron designaciones arbitrales oficiales.

## Pruebas del cuadro

Archivo: Test_Negocio/13_Test_Cuadro_Eliminatorio.sql.

- Crear partidos con cero, uno y dos participantes confirmados.
- Rechazar fases invertidas y relaciones ciclicas.
- Rechazar un ganador ajeno al partido.
- Rechazar resultado y formacion con participantes pendientes.
- Revertir el ganador cuando un destino contiene otra selección.
- Propagar ganadores a semifinal y final; perdedor de semifinal a tercer puesto.
- Confirmar explicitamente una definición por penales, sin interpretar su texto.
- Repetir confirmación y alta de cruce sin duplicados; modificar un cruce no utilizado.
- Rechazar rectificación automatica del ganador y baja de un cruce utilizado.

Resultado: aprobado; el test revierte su escenario al finalizar.

## Pruebas de designación

Archivo: Test_Negocio/16_Test_Designacion_Arbitral.sql.

- Rechazo de nacionalidad, incluyendo equivalencia USA/United States.
- Rechazo de categoría incompatible y de partido pendiente.
- Advertencia de posible cruce y evaluación incompleta en un cuadro parcial.
- Cupo de principal y validaciones compartidas con modificación.
- Rechazo de cambio de participante que entra en conflicto con un árbitro designado.
- Rechazo de cambio de país del árbitro con designaciones.
- Desaparicion del conflicto potencial al confirmar la eliminación de ese país de la ruta.
- Conservación de la transacción externa después de rechazos previstos.
- Equipo válido de seis personas y consulta de evidencia.

Resultado: aprobado; el test revierte su escenario al finalizar.

## Pruebas de carga y errores parciales

Archivo: Test_Importaciones/16_Test_Carga_Designaciones_Arbitrales.sql.

- Lote vacio: contadores en cero.
- Primer intento conflictivo rechazado y sustitución por candidato válido.
- Repetición sin cambios de integrantes ni duplicados.
- Partido pendiente omitido sin designaciones.
- Falta de un segundo candidato VAR: reversión completa de las nuevas filas del partido.
- Conservación de datos de otros partidos.
- Reposición de candidato y completado de un equipo parcial.
- Recorrido posterior de todos los partidos, incluidos completos y pendientes.

Resultado: aprobado. Este escenario persiste solo en la base aislada y exige tablas Partido y Arbitro vacias al comenzar.

## Importación de participantes pendientes

Archivo: Test_Importaciones/13.2_Test_Partidos_Pendientes.sql, procedimiento test.Partidos_Pendientes_JSON.
Entradas: Test_Importaciones/Datos_Recorridos/13_Partido_Pendiente.json y 13_Partidos_Confirmados_Parciales.json.

El primer archivo crea un partido sin participantes. El segundo completa ese mismo ID, rechaza una selección inexistente (52107), rechaza un resultado sin participantes (51301) y carga la fila válida posterior. Reimportar el primer archivo no borra los participantes ya confirmados. Se comprobó que no queda una transacción abierta.

Resultado: aprobado.

## Prueba con los archivos del proyecto

Entradas originales: teams.csv, venues.csv, arbitros_fifa_pdf.csv y partidos_mundial_2026.json. Las pruebas copiaron los archivos sin modificarlos al servidor de SQL. No se uso una fuente externa de designaciones.

- Árbitros importados: 170 (52 principales, 88 asistentes y 30 VAR).
- Partidos importados: 104.
- Relaciones del mapa: 32; repetir la carga del mapa mantuvo esa cantidad.
- Ganadores inventados por la importación: 0.
- Primera carga arbitral: 104 partidos completos, 624 designaciones, 0 partidos con error.
- Candidatos rechazados en esa ejecución aleatoria: 28.
- Conflictos de nacionalidad en las filas aceptadas: 0, comprobados mediante consulta con alias normalizados.
- Duración medida de la carga inicial: 8178 milisegundos, aproximadamente 8,2 segundos en ese entorno.
- Segunda carga: 0 partidos nuevos y 104 omitidos por equipo completo; mismos integrantes y roles.
- Reimportacion del JSON: se mantuvieron los 104 partidos.

Los candidatos, la cantidad de rechazos y los tiempos varian entre ejecuciones. No es una prueba de concurrencia ni un compromiso de rendimiento para otros equipos.

## Ajustes detectados por las pruebas

Se corrigio el retorno de carro que quedaba en el puesto del árbitro al leer CSV CRLF sobre Linux. Se centralizaron alias de país para que USA y United States no evadan la validación. El importador de partidos dejo de capturar resultados innecesarios mediante INSERT EXEC, lo que permite manejar un rechazo de negocio y seguir con las filas válidas.

Al preparar la primera base aislada se detecto una referencia heredada en minúsculas al nombre de la base principal. Creo únicamente la nueva tabla Cruce_Partido vacia en esa base; se retiró esa tabla, se eliminó la referencia redundante del script y se corrigio la preparación de pruebas. No se insertaron ni modificaron datos de negocio en la base principal. La verificación final confirmo que esa tabla no quedó alli.

## Reproducción y límites

Seguir primero el orden de instalación de Stored_Procedures_Importaciones/README_Designaciones_Arbitrales.md. Ejecutar las pruebas de negocio antes que la prueba de carga que conserva sus datos. El test 13.1_Test_Carga_Cruces_Dataset.sql se ejecuta sobre el fixture local importado y comprueba 32 relaciones tras dos llamadas.

No se certifica aqui el reglamento arbitral completo, la autenticidad de resultados del dataset ni el resto de los módulos del TP. Las advertencias reflejan el cuadro actual, no su reconstrucción histórica. La documentación del alcance indica las reglas operativas excluidas.
