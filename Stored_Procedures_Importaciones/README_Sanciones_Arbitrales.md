# Carga manual de sanciones arbitrales simuladas

Universidad Nacional de La Matanza - Bases de Datos Aplicada, Comisión 01-2900, Grupo 01.
Integrantes: Nicolás Dario Caro; Lucas Nicolás Clara; Leandro Ariel de la Cruz; Elías Uriel Rodríguez.
Fecha: 08/11/2026.

## Alcance

Cinco casos inventados para poblar Sancion_Arbitral. Representan sanciones o advertencias hacia los propios árbitros, no tarjetas a jugadores. No corresponden a hechos reales ni a sanciones oficiales. Cada motivo comienza con una marca `[SIMULADO SA-01]` a `[SIMULADO SA-05]` para que esto sea visible también al consultar la tabla.

| Caso | Encuentro del dataset local | Rol | Motivo simulado | Tipo |
|---|---|---|---|---|
| SA-01 | Mexico - South Africa | Principal | Amarillas incorrectas y criterio inconsistente | ADVERTENCIA |
| SA-02 | South Korea - Czechia | Asistente | Fuera de juego incorrecto que interrumpe un ataque | ADVERTENCIA |
| SA-03 | Canada - Bosnia and Herzegovina | VAR | Omisión de recomendar la revisión de un posible penal | SUSPENSION |
| SA-04 | USA - Paraguay | Cuarto árbitro | Demora en una sustitución y errores de control del área técnica | ADVERTENCIA |
| SA-05 | Qatar - Switzerland | Principal | Segunda amonestación omitida e informe incompleto | MULTA |

Los árbitros se resuelven desde Designacion_Arbitral al ejecutar la carga, porque la población de designaciones es aleatoria. Para el caso del asistente se utiliza el de menor id_arbitro entre los asistentes de ese encuentro. No se asume un ID ni un nombre fijo. El fixture se identifica por UTC, fase y selecciones; las referencias corresponden al archivo local actual y deben revisarse si cambia ese dataset.

La fecha se toma del partido para respetar el ABM existente, que exige esa coincidencia. No se generan sanciones para partidos futuros. SUSPENSION y MULTA son valores del registro: esta carga no calcula fechas de inhabilitación, modifica designaciones ni genera facturación. No se cambia la tabla ni su ABM.

## Instalación y ejecución

1. Instalar los esquemas y tablas del proyecto, la normalización de países de negocio/16 y los ABM, incluido `18_Sancion_Arbitral_ABM.sql`.
2. Importar selecciones, sedes, árbitros y partidos; ejecutar la carga de designaciones arbitrales.
3. Instalar `Stored_Procedures_Importaciones/18_Cargar_Sanciones_Arbitrales_Manuales.sql`.
4. Ejecutar:

```sql
EXEC carga.Cargar_Sanciones_Arbitrales_Manuales;
```

Instalar el script no ejecuta la carga. El procedimiento devuelve resumen y detalle con caso, estado, árbitro, rol, partido, sanción y error. También admite contadores OUTPUT:

```sql
DECLARE @insertadas INT, @omitidas INT, @errores INT;
EXEC carga.Cargar_Sanciones_Arbitrales_Manuales
    @insertadas OUTPUT, @omitidas OUTPUT, @errores OUTPUT;
SELECT @insertadas AS insertadas, @omitidas AS omitidas, @errores AS errores;
```

## Repetición y errores

El recorrido usa WHILE, clave única y avance por siguiente orden mayor, igual que las cargas manuales del proyecto. Cada caso se confirma por separado mediante `abm.Sancion_Arbitral_Alta`. Si falla, se revierte ese caso y se continúa con los demás. La carga exige ejecutarse sin una transacción previa, porque el ABM heredado puede revertirla por completo ante un error.

La marca identifica cada caso de esta carga. Repetir con los mismos datos devuelve cinco casos YA EXISTE. Si faltan partidos o designaciones, se informan errores sin inventar referencias ni crear árbitros. Los casos válidos continúan y los fallidos pueden reintentarse después.

Si un caso ya existe con otro motivo, tipo, fecha, partido o árbitro, se informa el desacuerdo y no se duplica ni se sobrescribe. Esto también evita trasladar una sanción anterior a otra persona si cambian las designaciones. Se requiere revisar ese caso explícitamente mediante los ABM. Los registros ajenos a estas cinco marcas se conservan.

## Verificación

`Test_Importaciones/18_Test_Carga_Sanciones_Arbitrales.sql` se ejecuta en MUNDIALDEFUTBOL con el fixture y las designaciones del proyecto, sin estas marcas previas. Conserva los cinco casos para inspección. Comprueba primera carga, repetición idéntica, relación con designaciones, fechas, conservación de datos previos y respeto de una corrección manual; esa corrección temporal se restaura al terminar.

Validado el 08/11/2026 en SQL Server 2022 Developer, en la base aislada con 104 partidos y 624 designaciones: cinco altas, segunda ejecución sin altas y cinco omitidas, y corrección manual detectada sin sobrescribirla. Se verificó además una ejecución sin los encuentros requeridos: cinco errores informados, ninguna sanción nueva y ninguna transacción abierta.

La base principal estaba vacía al comprobarla. No se cargaron partidos, designaciones ni sanciones allí; la población y sus pruebas se ejecutaron en bases aisladas.

Actualización de ejecución: los tests apuntan a MUNDIALDEFUTBOL y no exigen nombres de bases auxiliares. Las ejecuciones aisladas citadas arriba son evidencia histórica; esta adaptación de destino se verificó estáticamente, sin ejecutar cargas sobre la base principal.
