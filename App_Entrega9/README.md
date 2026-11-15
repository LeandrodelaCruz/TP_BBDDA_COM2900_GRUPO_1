# Aplicación ABM de Anunciantes - Entrega 9

Aplicación web sencilla desarrollada en Python + Flask para gestionar
`dbo.Anunciante` en la base `MUNDIALDEFUTBOL`.

## Arquitectura

La aplicación no realiza INSERT, UPDATE ni DELETE directos.

Utiliza los Stored Procedures existentes:

- Listar: `abm.Anunciante_Listar`
- Consultar: `abm.Anunciante_ConsultarPorId`
- Alta: `abm.Anunciante_Alta`
- Modificar: `abm.Anunciante_Modificar`
- Baja: `abm.Anunciante_Baja`

Flujo:

```text
Usuario
  ↓
Flask / HTML
  ↓
Stored Procedures abm.*
  ↓
dbo.Anunciante
```

Las validaciones y reglas de negocio permanecen centralizadas en SQL Server.

## 1. Crear el entorno

```bash
python3 -m venv .venv
source .venv/bin/activate
```

## 2. Instalar dependencias

```bash
pip install -r requirements.txt
```

## 3. Configurar la conexión

Copiar:

```bash
cp .env.example .env
```

Editar `.env` y colocar la contraseña real de SQL Server:

```text
DB_SERVER=localhost
DB_PORT=1433
DB_NAME=MUNDIALDEFUTBOL
DB_USER=sa
DB_PASSWORD=TU_PASSWORD
```

Cada integrante puede tener su propia contraseña local.

## 4. Ejecutar

```bash
python app.py
```

Abrir:

```text
http://127.0.0.1:5000
```

## Demostración recomendada

Para no alterar los ocho anunciantes originales del módulo publicitario:

1. Crear:
   - Nombre: `TEST Entrega 9`
   - País: `Argentina`
2. Modificarlo a:
   - Nombre: `TEST Entrega 9 Modificado`
3. Consultarlo por ID.
4. Eliminarlo.
5. Opcional: intentar crear un nombre duplicado para demostrar que el error
   proviene de `abm.Anunciante_Alta`.

## Decisión de diseño

La aplicación se limita a presentación y comunicación con SQL Server.
No duplica validaciones de negocio en Python.

Los atributos `required` y `maxlength` del HTML solamente mejoran la
experiencia del usuario; SQL Server sigue siendo la fuente definitiva de
validación.
