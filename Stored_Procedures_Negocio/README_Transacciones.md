# Transacciones para la demo secuencial

La base academica se crea y se ejecuta paso a paso, con una operacion por vez.
Los procedimientos no solicitan bloqueos de aplicacion (`sp_getapplock`) ni
bloqueos explicitos de lectura (`UPDLOCK`, `HOLDLOCK`). SQL Server conserva
su manejo normal de bloqueos. No se cambia el nivel de aislamiento.

## Que se conserva

Una transaccion agrupa cambios que deben confirmarse juntos. Por ejemplo,
incorporar un jugador y registrar su reemplazo, o sustituir una conexion
del mapa conservando la anterior cuando la nueva no es valida. Si la operacion falla, se deshace su trabajo
y se informa el error mediante `THROW`.

Las cargas de reemplazos y designaciones confirman cada caso o partido por
separado. Un error revierte ese caso y permite continuar con el siguiente.
La carga de cruces conserva su transaccion para el conjunto completo.

## Por que algunos procedimientos comprueban @@TRANCOUNT

Un procedimiento puede ejecutarse solo o ser llamado por otro procedimiento.
Esto tambien ocurre en una ejecucion totalmente secuencial.

- Si no existe una transaccion, abre una y la confirma con `COMMIT`. Ante un
  error, ejecuta `ROLLBACK`.
- Si el llamador ya abrio una, crea un punto de guardado con `SAVE TRANSACTION`.
  No confirma la transaccion del llamador. Si falla y la transaccion sigue
  siendo valida, vuelve al punto de guardado y conserva el trabajo anterior.

Por ejemplo, modificar un cruce elimina la relacion anterior y agrega la nueva.
Si el alta falla, el punto de guardado permite recuperar la relacion anterior.
En la carga arbitral, un candidato rechazado permite probar el siguiente sin
perder las designaciones validas que ya se hicieron dentro del mismo partido.

`XACT_STATE()` distingue una transaccion valida (`1`), una que solo puede
deshacerse por completo (`-1`) y la ausencia de transaccion (`0`). Si una
transaccion externa queda en `-1`, el error se propaga para que el llamador
ejecute el `ROLLBACK` completo.

## SET XACT_ABORT

El cuadro arbitral usa `OFF` para poder capturar rechazos previstos y continuar
con otro candidato dentro de la misma transaccion. Eso no evita la reversion
ante errores: la resuelve el bloque `CATCH`.

Reemplazos conserva `ON`: un error de escritura que invalida la transaccion
se propaga y provoca la reversion completa del caso en la carga.

## Explicacion para la presentacion

"Agrupamos en una transaccion los cambios que deben hacerse juntos. Si todo
sale bien, confirmamos; si algo falla, deshacemos e informamos el error.
Cuando un procedimiento llama a otro, un punto de guardado permite deshacer
solo la operacion interna si el error es recuperable. Las cargas trabajan
caso por caso. La demo se ejecuta de forma secuencial."
