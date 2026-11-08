# Logica de negocio: convocatoria y reemplazos

Los procedimientos de esta carpeta pertenecen al esquema `negocio` y coordinan
las operaciones ABM de la Entrega 5. No cambian la estructura de las tablas.

La numeracion sigue la entidad de los ABM: 14 para Reemplazo y 15 para
Asignacion_Publicitaria. Las pruebas de operaciones funcionales estan en
`Test_Negocio`. La carga masiva de reemplazos usa el esquema `carga` y esta en
`Stored_Procedures_Importaciones`, junto a las cargas de Region y Pieza_Para_Region;
su prueba esta en `Test_Importaciones`. Ambas usan el prefijo 14 de Reemplazo.

## Instalacion

Sobre una base existente, ejecutar en este orden:

1. `Table/00_Script_DB_Schemas_Creacion.sql`: crea todos los esquemas si faltan (`abm`, `test`, `importacion`, `negocio` y `carga`). Toda creacion de esquemas se concentra en ese archivo.
2. Los ABM de Jugador y Reemplazo (10 y 14), si todavia no estan instalados.
3. `Stored_Procedures/12_Formacion_Jugador_ABM.sql`: agrega el control de bajas.
4. `Stored_Procedures_Negocio/14_Registrar_Reemplazo.sql`.
5. En una base de pruebas, `Test_Negocio/14_Test_Registrar_Reemplazo.sql`.

Para poblar la tabla con cinco casos, instalar despues
`Stored_Procedures_Importaciones/14_Cargar_Reemplazos_Manuales.sql` y ejecutar
`carga.Cargar_Reemplazos_Manuales @reconstruir_convocatoria = 1`. Ver las fuentes,
fechas simuladas y reglas en
[README_Reemplazos_Manuales.md](../Stored_Procedures_Importaciones/README_Reemplazos_Manuales.md).

Los archivos SQL estan incluidos en `Solucion.slnx`.

## Uso

```sql
-- Sustituir 123 por un ID real de jugador convocado.
EXEC negocio.Registrar_Reemplazo
    @id_jugador_baja = 123,
    @fecha_cambio = '20260601',
    @motivo = 'Lesion muscular',
    @nombre = N'Nombre del entrante',
    @apellido = N'Apellido del entrante',
    @fecha_nacimiento = '19950101',
    @club_origen = N'Club de origen',
    @posicion = 'Defensa';

EXEC negocio.Listar_Convocados_Vigentes @id_seleccion = 1;
```

El alta del entrante y el registro del reemplazo se confirman juntos. Se conserva
el saliente en `Jugador`, para mantener las referencias y su informacion personal.
El entrante hereda la seleccion y el dorsal. El procedimiento devuelve los tres
identificadores: reemplazo, jugador de baja y jugador de alta.

Un convocado vigente es un jugador sin registros como baja en `Reemplazo`.
Por ello, consultar directamente todos los jugadores de una seleccion incluye
tambien su historial. Usar `negocio.Listar_Convocados_Vigentes` para la plantilla
actual; las altas y modificaciones de formaciones tambien rechazan las bajas.

No se permite reincorporar bajas ni agregar a alguien que ya esta registrado en
esa seleccion: con este modelo, si nunca fue dado de baja, ya esta convocado.
La identidad se compara por seleccion, nombre, apellido y fecha de nacimiento,
con el mismo criterio que el importador de jugadores. Repetir una operacion se
rechaza, sin duplicar datos. Se permiten cadenas A -> B -> C, siempre que la baja
de B no sea anterior a su incorporacion.

## Orden de carga y limites

Importar las plantillas iniciales, aplicar reemplazos y luego cargar formaciones
e incidencias. El fixture puede existir: se exige que la fecha del cambio sea
anterior al primer partido de esa seleccion y que aun no tenga formaciones.
Esta es una regla operativa del proyecto, no una implementacion del reglamento
completo de reemplazos del torneo. Como la tabla solo guarda DATE, no se admiten
cambios el mismo dia del debut.

Si la fuente de jugadores ya contiene la plantilla definitiva, reconstruir primero
la convocatoria inicial del caso documentado. No aplicar de nuevo un reemplazo
que esa fuente ya refleja. El lote manual complementario realiza esa preparacion
de forma explicita y atomica para los cinco casos documentados.

Los ABM de Reemplazo siguen disponibles como operaciones de mantenimiento. No
usarlos para registrar cambios funcionales: no tienen todas las validaciones del
procedimiento de negocio. Modificar o eliminar un reemplazo afecta la convocatoria
derivada; no hay una operacion de anulacion automatica ni se elimina al entrante.

El procedimiento acepta una transaccion externa usando un punto de guardado.
Si un error deja esa transaccion no confirmable (`XACT_STATE() = -1`), el llamador
debe ejecutar un `ROLLBACK` completo. Las llamadas de negocio se serializan con
un bloqueo de aplicacion y las lecturas de validacion mantienen bloqueos hasta
el fin de la transaccion.

El test incluye reemplazo exitoso, cadena, baja repetida, entrante existente,
datos obligatorios, fecha incoherente y un fallo simulado de escritura mediante
un trigger transitorio. Revierte los datos y el trigger creados; pueden avanzar
los contadores IDENTITY. Requiere permiso para crear ese trigger en la base de
pruebas. Los seis casos pasaron en SQL Server el 03/11/2026, en una base aislada.


## Calendario, cruces y arbitros

Se incorporan 13_Confirmar_Resultado_Eliminatorio.sql y 16_Designacion_Arbitral.sql.
Instalar el archivo 16 antes de los ABM actualizados, porque define la funcion de
normalizacion de pais. Ver ../Stored_Procedures_Importaciones/README_Designaciones_Arbitrales.md
para el orden completo de recreacion, uso, alcances y pruebas. La importacion no
requiere ganadores; la carga arbitral usa los ABM con controles compartidos.
