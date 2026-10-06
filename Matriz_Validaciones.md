# Matriz de validaciones

Este paquete trabaja EXCLUSIVAMENTE con las cinco tablas recibidas:
`Anunciante`, `Region`, `Sede`, `Seleccion` y `Arbitro`.

## Qué significa “5 ABM” en este paquete
Se prepararon cinco procedimientos de manejo por tabla:
1. Alta
2. Modificar
3. Baja
4. ConsultarPorId
5. Listar

Los tres primeros son el ABM estricto; se agregaron las dos consultas para completar cinco procedimientos por tabla.

## Anunciante
- ID positivo y existente en Modificar/Baja/Consultar.
- Nombre obligatorio.
- Nombre <= 120 caracteres.
- Nombre no duplicado.

## Region
- ID positivo y existente.
- Nombre obligatorio y <= 80.
- Idioma opcional, pero si se informa no puede quedar vacío y debe ser <= 50.
- Huso horario obligatorio y <= 100.
- Inicio y fin de prime time obligatorios.
- Inicio < fin.
- Horas mayores a 00:00, acorde con las restricciones originales del grupo.
- Nombre de región no duplicado.

## Sede
- ID positivo y existente.
- Nombre de estadio obligatorio y <= 120.
- Ciudad obligatoria y <= 80.
- País obligatorio y <= 80.
- Capacidad > 0.
- Huso horario obligatorio y <= 100.
- No repetir exactamente estadio + ciudad + país.

## Seleccion
- ID positivo y existente.
- País obligatorio y <= 80.
- Confederación obligatoria y <= 50.
- Confederación dentro de AFC, CAF, CONCACAF, CONMEBOL, OFC o UEFA.
- Grupo obligatorio y <= 5.
- País no duplicado.

## Arbitro
- ID positivo y existente.
- Nombre obligatorio y <= 60.
- Apellido obligatorio y <= 60.
- Fecha de nacimiento obligatoria y no futura.
- País obligatorio y <= 80.
- Puesto/categoría obligatorio y <= 50.
- Idiomas opcionales, pero no vacíos si se informan y <= 200.
- Evita duplicar la misma persona por nombre + apellido + fecha de nacimiento + país.

Todas las validaciones de una operación se acumulan en `@errores` y se informan juntas con un único `THROW`, tal como solicita la consigna.
