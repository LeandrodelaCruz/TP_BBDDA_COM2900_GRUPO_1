# Organizacion de esquemas

- Toda creacion de esquemas debe estar exclusivamente en `Table/00_Script_DB_Schemas_Creacion.sql`, junto con la creacion de la base de datos.
- Al agregar un esquema, incorporarlo a ese script con una comprobacion de existencia para permitir su ejecucion reiterada.
- Los scripts de procedimientos, importaciones, cargas y pruebas no deben crear esquemas. Si necesitan comprobar un esquema, deben informar con `THROW` que primero se ejecute el script central.
- Verificar esta regla buscando `CREATE SCHEMA` en todos los archivos SQL antes de finalizar cambios relacionados.
