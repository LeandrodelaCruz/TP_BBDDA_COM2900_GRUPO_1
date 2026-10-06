# Entrega 5 — ABM, validaciones y tests de las 5 tablas recibidas

## Alcance
No se agregaron tablas nuevas. El paquete está preparado únicamente para:
- dbo.Anunciante
- dbo.Region
- dbo.Sede
- dbo.Seleccion
- dbo.Arbitro

Debe ejecutarse DESPUÉS de haber creado esas tablas con `tablas.sql`.

## Orden de ejecución

### 1. Crear validadores
Ejecutar, en orden, todos los archivos de `01_Validaciones/`.

### 2. Crear los 5 procedimientos de manejo por tabla
Ejecutar todos los archivos de `02_ABM/`.

Cada tabla queda con:
- `sp_<Tabla>_Alta`
- `sp_<Tabla>_Modificar`
- `sp_<Tabla>_Baja`
- `sp_<Tabla>_ConsultarPorId`
- `sp_<Tabla>_Listar`

### 3. Ejecutar los tests
Ejecutar los archivos `01` a `05` de `03_Tests/`.

Cada test:
- prueba Alta exitosa;
- prueba Consulta;
- prueba Modificación;
- prueba Listado;
- prueba Baja;
- ejecuta casos que DEBEN fallar por validación;
- deja un único registro principal con prefijo `TEST_` para que pueda inspeccionarse.

Los errores esperados están dentro de TRY/CATCH para que el script continúe y muestre el mensaje generado.

### 4. Dejar la base limpia
Cuando ya se haya tomado evidencia de las pruebas, ejecutar:

`03_Tests/99_Limpiar_Datos_Test.sql`

Ese script usa exclusivamente los Stored Procedures de Baja. No realiza DELETE directo.

## Importante
Los procedimientos reciben strings con un tamaño mayor al de la columna para poder validar explícitamente longitudes y devolver un mensaje claro antes de que SQL Server rechace/trunque el dato.

## Observación sobre Region
El `tablas.sql` original incluye checks `hora_prime_inicio > 0` y `hora_prime_fin > 0`. En las validaciones se replicó la intención usando comparación explícita contra `00:00:00`.
