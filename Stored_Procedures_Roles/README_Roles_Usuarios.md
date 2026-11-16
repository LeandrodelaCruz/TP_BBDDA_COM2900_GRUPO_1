# Entrega 8: administración de usuarios y roles

UNLaM · Bases de Datos Aplicada · Comisión 01-2900 · Grupo 01 · 10/11/2026.

Integrantes: Caro, Nicolás Darío; Clara, Lucas Nicolas; de la Cruz, Leandro Ariel; Rodríguez, Elías Uriel.

## Alcance y decisión de diseño

Se implementan tres roles de base de datos mediante procedimientos almacenados. Cada rol tiene un usuario de prueba WITHOUT LOGIN, sin contraseña y sin posibilidad de iniciar una conexión propia. Las pruebas se ejecutan desde una conexión DBA mediante EXECUTE AS USER y finalizan con REVERT, incluso ante errores capturables. No se crean roles de servidor ni se asigna db_owner a los usuarios.

## Cuadro de permisos por rol

Base de datos: `MUNDIALDEFUTBOL`. El cuadro refleja los permisos definidos en [00_Roles_Usuarios.sql](00_Roles_Usuarios.sql).

| Permiso o ámbito | Administrador funcional (`rol_admin_funcional`) | Gestor de publicidad (`rol_gestor_publicidad`) | Consulta (`rol_consulta`) |
| --- | --- | --- | --- |
| Usuario de prueba | `usr_prueba_admin` | `usr_prueba_publicidad` | `usr_prueba_consulta` |
| `EXECUTE` en `abm` | Todo el esquema | 25 SP publicitarios de la lista siguiente | Sin concesión |
| `EXECUTE` en `negocio` | Todo el esquema | `negocio.Generar_Asignacion_Publicitaria` | Sin concesión |
| `EXECUTE` en `importacion` | Todo el esquema (1) | Sin concesión | Sin concesión |
| `EXECUTE` en `carga` | Todo el esquema (1) | Sin concesión | Sin concesión |
| `EXECUTE` en `reportes` | Todo el esquema | `reportes.Reporte_Ocupacion_Publicitaria` y `reportes.Reporte_Matriz_Prime_Time` | Todo el esquema |
| `SELECT`, `INSERT`, `UPDATE` y `DELETE` directos sobre el esquema `dbo` | DENY | DENY | DENY |
| `ALTER ANY ROLE` y `ALTER ANY USER` en la base | DENY | DENY | DENY |
| `CREATE TABLE` y `CREATE PROCEDURE` en la base | DENY | DENY | DENY |
| `EXECUTE` de `dbo.Configurar_Roles_Entrega8` y `dbo.Crear_Usuarios_Prueba_Entrega8` | DENY | DENY | DENY |

**Sin concesión** indica que el script no otorga ese permiso al rol. **DENY** indica una denegación explícita. El gestor de publicidad recibe 28 permisos `EXECUTE` por objeto, detallados en la sección siguiente.

(1) El permiso `EXECUTE` habilita la invocación. Las importaciones masivas que usan `BULK INSERT` u `OPENROWSET` con SQL dinámico requieren permisos adicionales del motor y acceso a los archivos. En la configuración actual las ejecuta el DBA.

## Procedimientos autorizados al gestor de publicidad

- `abm.Anunciante_Alta`
- `abm.Anunciante_Modificar`
- `abm.Anunciante_Baja`
- `abm.Anunciante_ConsultarPorId`
- `abm.Anunciante_Listar`
- `abm.Region_Alta`
- `abm.Region_Modificar`
- `abm.Region_Baja`
- `abm.Region_ConsultarPorId`
- `abm.Region_Listar`
- `abm.Campania_Alta`
- `abm.Campania_Modificar`
- `abm.Campania_Baja`
- `abm.Pieza_Publicitaria_Alta`
- `abm.Pieza_Publicitaria_Modificar`
- `abm.Pieza_Publicitaria_Baja`
- `abm.Pieza_Para_Region_Alta`
- `abm.Pieza_Para_Region_Baja`
- `abm.Asignacion_Publicitaria_Alta`
- `abm.Asignacion_Publicitaria_GetById`
- `abm.Asignacion_Publicitaria_GetByPartido`
- `abm.Asignacion_Publicitaria_GetByAnunciante`
- `abm.Asignacion_Publicitaria_TotalesPorAnunciante`
- `abm.Asignacion_Publicitaria_Modificacion`
- `abm.Asignacion_Publicitaria_Baja`
- `negocio.Generar_Asignacion_Publicitaria`
- `reportes.Reporte_Ocupacion_Publicitaria`
- `reportes.Reporte_Matriz_Prime_Time`

## Orden de ejecución

Previamente instalar la base, las tablas y los SP de ABM, negocio, importación, carga y reportes. Ejecutar los archivos completos en SSMS desde una conexión DBA:

1. `00_Roles_Usuarios.sql`: define los dos SP de administración en dbo; no crea esquemas.
2. `01_Configurar_Roles_Usuarios.sql`: ejecuta los SP; crea tres roles y tres usuarios, y asigna permisos y membresías.
3. `02_Consultar_Usuarios_Roles.sql`: muestra membresías y permisos declarados en el catálogo.
4. `03_Test_Admin_Funcional.sql`: verifica el administrador funcional.
5. `04_Test_Gestor_Publicidad.sql`: verifica el gestor publicitario.
6. `05_Test_Consulta.sql`: verifica consulta.

Los archivos incluyen USE MUNDIALDEFUTBOL; pueden abrirse desde una consulta inicialmente conectada a master. No hay un “plano superior” necesario para los roles de base de datos: se consultan en los catálogos de MUNDIALDEFUTBOL.

La configuración puede repetirse. Se crean los usuarios que faltan y se agrega cada membresía si aún no existe. Si un nombre de prueba ya está ocupado, debe corresponder a un usuario WITHOUT LOGIN. Las membresías adicionales se conservan. La configuración de roles y la de usuarios tienen transacciones independientes. No ejecutar con una transacción previa abierta. Los permisos futuros de abm/negocio/importacion/carga/reportes se heredan donde se otorga EXECUTE por esquema; el gestor usa una lista explícita y no recibe automáticamente nuevos SP.

## Qué comprueba cada script por usuario

- Identidad efectiva, rol asignado y restauración del usuario original.
- Permiso EXECUTE esperado sobre todos los SP de usuario instalados, capturando primero el inventario como DBA para evitar que la visibilidad de metadatos oculte objetos prohibidos. Los objetos se validan antes de suplantar; si el usuario no puede resolver sus metadatos y HAS_PERMS_BY_NAME retorna NULL, se interpreta como ausencia de permiso.
- Ausencia de SELECT/INSERT/UPDATE/DELETE directos sobre todas las tablas de dbo, y ausencia de permisos de administración y creación de objetos.
- Una ejecución autorizada real: Anunciante_Listar para administrador y gestor; Reporte_Resultados para consulta.
- Una ejecución rechazada real: Configurar_Roles_Entrega8 para administrador; Seleccion_Listar para gestor y consulta.
- SELECT directo y UPDATE directo rechazados con el error SQL Server 229. Otra excepción no cuenta como una prueba exitosa.

No se modifican datos de negocio: el UPDATE de prueba tiene WHERE 1=0 incluso si la configuración fuera incorrecta. Cada script muestra filas OK/ERROR y lanza THROW ante diferencias. Los scripts requieren un ejecutor con acceso al catálogo y permiso para suplantar los usuarios; no deben envolverse en un SP WITH EXECUTE AS OWNER.

## Coordinación con cifrado

Los SP y tablas deben compartir propietario para aprovechar la cadena de propiedad con SQL estático. No se conceden accesos a claves o certificados ni permisos de descifrado genéricos. El equipo de cifrado debe controlar qué datos exponen los reportes, mantener los contratos de los SP y definir cómo abrir las claves con los permisos mínimos necesarios. Reejecutar las tres pruebas después de integrar esos cambios. El cifrado y la política de respaldo pertenecen a otros apartados de la entrega.

## Referencias técnicas

- Consigna oficial: Trabajo-Practico-2026-2C---Mundial-de-Futbol.pdf, páginas 7 y 8.
- Microsoft Learn: https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-transact-sql
- Microsoft Learn: https://learn.microsoft.com/en-us/sql/t-sql/statements/execute-as-clause-transact-sql
