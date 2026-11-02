# Extraccion de Personal Tecnico

El script `03_scrapear_personal_tecnico_transfermarkt.py` recorre, en el orden
del archivo, `indice_selecciones_transfermarkt.csv`. El indice utiliza los nombres
de `teams.csv` y requiere las columnas `seleccion` y `url`; `orden` es informativa.

Se extraen los roles `Entrenador`, `Entrenador Interino` y `Entrenador Asistente`.
`Entrenador Interino` se exporta como `Entrenador`.
Los datos representan el cuerpo tecnico vigente al consultar Transfermarkt,
no necesariamente el que participo en el Mundial 2026. El nombre completo se
conserva como aparece en la fuente y corresponde a la columna `nombre_completo`
del modelo actualizado. El scraper no realiza escrituras en SQL Server.

Desde la raiz del repositorio, con las dependencias de `Scraping/requirements.txt`:

```powershell
.\.venv\Scripts\python.exe Scraping\03_scrapear_personal_tecnico_transfermarkt.py
```

Genera `Archivos_Importacion/personal_tecnico.csv` con:

```text
seleccion,nombre_completo,rol,fecha_extraccion_utc
```

Las rutas predeterminadas se calculan desde la ubicacion del script, por lo que
tambien funciona al ejecutarlo desde otra carpeta. `--indice` y `--salida`
permiten indicar archivos alternativos; las rutas relativas explicitas se
interpretan desde la carpeta de ejecucion.

Prueba de Estados Unidos sin escribir archivos:

```powershell
.\.venv\Scripts\python.exe Scraping\03_scrapear_personal_tecnico_transfermarkt.py --seleccion USA --solo-conexion
```

Se espera medio segundo entre paginas; puede ajustarse con `--pausa`.
Si una pagina falla, se continua con las siguientes. El archivo separado
`personal_tecnico_errores.csv` informa seleccion, URL y mensaje de cada fallo.
Si no hay errores, contiene solo el encabezado. Ante errores, el proceso retorna
codigo 1 aunque haya guardado los registros validos; con exito completo retorna 0.
Si todas las paginas fallan, no reemplaza un CSV de datos anterior.
La ausencia de asistentes detectables se informa como aviso y no se inventan filas.
Si no se detecta entrenador ni interino, se conservan los asistentes encontrados
y se informa un aviso.

Fuente: https://www.transfermarkt.com.ar/

## Importacion en SQL Server

El SP `importacion.SP_Importar_Personal_Tecnico_CSV` esta en
`Stored_Procedures_Importaciones/04_SP_Importar_Personal_Tecnico_CSV.sql`.

Antes de crearlo, deben estar cargadas las selecciones, la tabla Personal_Tecnico
debe tener `nombre_completo NVARCHAR(120)` y los ABM del archivo
`Stored_Procedures/09_Personal_Tecnico_ABM.sql` deben recibir `@nombre_completo`.
Modificar el script de creacion de tablas no migra una tabla ya existente.

El UPSERT identifica a la persona por seleccion y nombre completo; actualizar el
rol conserva su ID. Renombrar a una persona o cambiar su seleccion no permite
reconocerla automaticamente con esa clave. No se eliminan personas ausentes del
archivo. La fecha de extraccion se valida como metadato y no se persiste en la
tabla de negocio. El resumen cuenta como actualizados los registros existentes,
incluso si sus valores no cambiaron.

Copiar el CSV a una ruta visible para el servicio SQL Server y ejecutar:

```sql
EXEC importacion.SP_Importar_Personal_Tecnico_CSV
    @archivo = N'/var/opt/mssql/import/personal_tecnico.csv';
```

El SP procesa las cuatro columnas en su orden original. Usa staging UTF-8 y
`CODEPAGE = 'RAW'`, y convierte a NVARCHAR para validar y llamar a los ABM.
Esto se verifico en SQL Server 2022 sobre Linux sin cambiar la intercalacion
de la base. Los errores de datos se informan por registro; un archivo ilegible
o con estructura CSV invalida puede impedir la carga inicial a staging.

La prueba esta en `Test/24_Test_Importar_Personal_Tecnico_CSV.sql`; recibe el
CSV real y, opcionalmente, `Test/Datos_Importacion/personal_tecnico_casos.csv`.
Sus escrituras se revierten al terminar. No ejecutar pruebas con un CSV cuya
informacion haya sido marcada como incompleta por el scraper sin revisar primero
el reporte de errores de extraccion.
