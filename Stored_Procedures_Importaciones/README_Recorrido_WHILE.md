# Recorrido con WHILE: Reemplazo y Personal_Tecnico

La correccion del docente prohibe los cursores SQL en todo el proyecto.
La primera adaptacion comprendio Reemplazo, Personal_Tecnico y la preparacion
de su prueba. El usuario autorizo despues extender el patron al proyecto.
La comparacion del estado anterior y nuevo, incluidos los dos casos especiales,
esta en [README_Migracion_WHILE.md](README_Migracion_WHILE.md).

## Caso de referencia: Reemplazo

En `14_Cargar_Reemplazos_Manuales.sql`, los cinco casos ya tienen una clave
`orden` unica. Se toma la menor clave, se obtienen sus datos, se ejecuta el
tratamiento del caso y se busca la siguiente clave mayor.

```sql
SELECT @orden = MIN(orden) FROM @casos;
WHILE @orden IS NOT NULL
BEGIN
    -- SELECT de los datos del caso WHERE orden = @orden.
    -- BEGIN TRY: validaciones, ABM y transaccion del caso.
    -- BEGIN CATCH: ROLLBACK del caso e informe del error.

    SELECT @orden = MIN(orden)
    FROM @casos WHERE orden > @orden;
END;
```

El fragmento es el patron de recorrido, no un script de carga independiente.
El procedimiento completo sirve como ejemplo ejecutable con sus ABM.

La busqueda de la siguiente clave funciona aunque existan huecos: 10, 30 y 40
tambien se recorren una sola vez. Cuando no quedan filas, MIN devuelve NULL
y el WHILE termina. Una tabla vacia no entra al ciclo.

El avance esta FUERA del TRY/CATCH: un caso con error no se intenta de nuevo
indefinidamente y el siguiente sigue procesandose. Las filas de la tabla de
trabajo no se eliminan, por lo que un ROLLBACK no vuelve a poner una fila
pendiente ni deshace el avance de una variable escalar.

Cada caso conserva su propia transaccion: si falla la reconstruccion de una
convocatoria o el registro del reemplazo, se revierte el caso completo. El
recorrido nuevo no altera las reglas de negocio, los parametros ni el resumen.

## Adaptacion a Personal_Tecnico

El CSV sigue entrando en `#Personal_Staging` con sus cuatro columnas originales.
Despues se copia a `#Personal_Trabajo`, donde se agrega una clave interna
`registro INT IDENTITY(1,1) PRIMARY KEY` y se convierte a NVARCHAR.

El WHILE usa esa clave y aplica las mismas validaciones y ABM que antes.
La conversion conserva las longitudes de entrada y los caracteres Unicode.
No se agrega IDENTITY directamente a staging, para no alterar la correspondencia
entre las cuatro columnas del CSV y BULK INSERT.

La clave representa un orden interno de procesamiento, no el numero fisico de
linea del CSV. No garantiza su orden original ni resuelve por si sola conflictos
entre filas que traigan distintos valores para una misma persona.

## Como replicar la adaptacion en otro modulo

1. Identificar el conjunto que se recorre y las variables que recibe cada fila.
2. Usar una clave unica existente o preparar una tabla de trabajo con IDENTITY.
3. Reemplazar la apertura y primera lectura por MIN(clave).
4. En cada vuelta, asignar las variables con SELECT por esa clave.
5. Conservar las validaciones, llamadas a ABM y limites de transaccion originales.
6. Buscar MIN(clave) mayor que la actual, fuera del manejo de errores por fila.
7. Retirar las instrucciones de lectura, cierre y liberacion del recorrido anterior.
8. Comprobar carga inicial, repeticion, errores intermedios y entrada vacia.

Si existe CONTINUE o una salida anticipada, revisar que no saltee el avance.
No suponer que un WHILE permite continuar una transaccion no confirmable:
el ROLLBACK y el manejo de errores deben seguir siendo adecuados al modulo.

Si una operacion puede resolverse por conjuntos, evaluar esa alternativa. En
estos dos casos se conserva el recorrido por fila para reutilizar los SP ABM
y reportar errores parciales conforme a la entrega.

## Validacion

Ejecutar las pruebas existentes en una base aislada:

- `Test_Negocio/14_Test_Registrar_Reemplazo.sql`.
- `Test_Importaciones/14_Test_Carga_Reemplazos.sql`.
- `Test_Importaciones/09_Test_Importar_Personal_Tecnico_CSV.sql`, con el CSV real
  y el fixture opcional `Test/Datos_Importacion/personal_tecnico_casos.csv`.

La prueba de carga de Reemplazo exige una base vacia y su propio prefijo de
nombre. La de Personal_Tecnico revierte sus datos al finalizar. Los archivos de
prueba indican sus requisitos y no deben ejecutarse sin revisar esas condiciones.

Verificado en SQL Server el 07/11/2026, en una base aislada:

- Reemplazo: seis pruebas de la operacion individual y cuatro del lote, incluidas
  la reversion de un fallo de escritura y la repeticion sin duplicados.
- Personal_Tecnico: 147 altas en la primera importacion y 147 actualizaciones
  sin nuevas altas al repetir. El fixture de siete filas devuelve una alta,
  una actualizacion y cinco errores; la fila valida posterior se procesa.
- CSV solo con encabezado: cero procesados, altas, actualizaciones y errores.

No se modifico la base del proyecto para estas verificaciones.
