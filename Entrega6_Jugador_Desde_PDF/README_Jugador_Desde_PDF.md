# Jugador desde SquadLists-Spanish.pdf

## Fuente
PDF de convocatorias de la Copa Mundial de la FIFA 2026.
Cada página corresponde a una selección y contiene 26 jugadores.

Campos utilizados del PDF:
- selección
- dorsal
- POS
- NOMBRE(S)
- APELLIDO(S)
- FN (fecha de nacimiento)
- CLUB

El PDF también trae entrenador, altura, internacionalidades y goles, pero esos
campos no pertenecen a `dbo.Jugador` y no se cargan en esta etapa.

## Importante respecto de la Entrega 6
Este flujo usa un PDF como fuente y un script Python para extraerlo a CSV.
Eso es técnicamente un preprocesamiento externo. La consigna menciona como
formatos de entrada CSV/XML/Excel y exceptúa de la prohibición de preprocesado
lo obtenido por scraping. Por lo tanto, conviene confirmar con el docente si
acepta el PDF como fuente formal de la Entrega 6. Si no, este PDF puede usarse
como fuente auxiliar/oficial y cubrir el requisito formal con otro dataset.

## 1. Preparar Python
Desde la raíz del proyecto:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r Extraccion_PDF/requirements.txt
```

## 2. Extraer el PDF
Colocar `SquadLists-Spanish.pdf` en la raíz del proyecto y ejecutar:

```bash
python3 Extraccion_PDF/01_Extraer_Jugadores_FIFA_PDF.py \
  SquadLists-Spanish.pdf \
  Archivos_Importacion/jugadores_fifa_pdf.csv
```

Resultado esperado:
- 48 selecciones
- 1248 jugadores

## 3. Copiar el CSV al contenedor SQL Server

```bash
docker cp Archivos_Importacion/jugadores_fifa_pdf.csv \
  sqlserver:/var/opt/mssql/import/jugadores_fifa_pdf.csv
```

Verificar:

```bash
docker exec -it sqlserver ls -l /var/opt/mssql/import/jugadores_fifa_pdf.csv
```

## 4. Requisitos de base de datos
Antes de importar deben existir:
- `dbo.Seleccion` con las 48 selecciones cargadas.
- `dbo.Jugador`.
- `abm.Jugador_Alta`.
- `abm.Jugador_Modificar`.
- esquema `importacion`.
- esquema `test`.

El SP de importación verifica estos requisitos y muestra un error claro si falta alguno.

## 5. Crear el importador
Ejecutar:

`Stored_Procedures_Importaciones/03_SP_Importar_Jugador_PDF_CSV.sql`

## 6. Ejecutar el test
Ejecutar:

`Test/23_Test_Importar_Jugador_PDF_CSV.sql`

Si `dbo.Jugador` comienza vacío, se espera:

- primera importación: 1248 insertados;
- segunda importación: 1248 actualizados;
- duplicados: 0 filas.

## UPSERT
La clave natural utilizada para reconocer al mismo jugador es:

`id_seleccion + nombre + apellido + fecha_nacimiento`

No se utiliza el dorsal porque podría cambiar.

## Transformaciones realizadas en T-SQL
- `PO` -> `Portero`
- `DF` -> `Defensa`
- `MC` -> `Mediocentro`
- `DC` -> `Delantero`
- fecha `d/m/yyyy` -> `DATE`
- resolución de `seleccion` -> `id_seleccion`

## Particularidad de Corea del Sur
El PDF usa `Korea Republic`, mientras el dataset `teams.csv` utilizado para
`dbo.Seleccion` usa `South Korea`. El extractor normaliza únicamente ese nombre
para que la FK pueda resolverse.
