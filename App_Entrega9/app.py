import os

import pymssql
from dotenv import load_dotenv
from flask import Flask, flash, redirect, render_template, request, url_for

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "tp-bbdd-aplicada-grupo-1")

DB_SERVER = os.getenv("DB_SERVER", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "1433"))
DB_NAME = os.getenv("DB_NAME", "MUNDIALDEFUTBOL")
DB_USER = os.getenv("DB_USER", "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")


def obtener_conexion():
    if not DB_PASSWORD:
        raise RuntimeError(
            "Falta DB_PASSWORD en el archivo .env."
        )

    return pymssql.connect(
        server=DB_SERVER,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        charset="UTF-8",
        autocommit=False,
    )


def limpiar_error(error):
    mensaje = str(error)

    # pymssql puede devolver información técnica adicional.
    # Para la pantalla dejamos el mensaje entendible del SP.
    for prefijo in ["(50001", "(50002", "(50003", "(50004"]:
        if prefijo in mensaje:
            partes = mensaje.split("b'")
            if len(partes) > 1:
                mensaje = partes[-1].rstrip("')")
                mensaje = mensaje.replace("\\n", " ").replace("\\r", " ")

    return mensaje


def listar_anunciantes():
    conexion = obtener_conexion()
    try:
        cursor = conexion.cursor(as_dict=True)
        cursor.execute("exec abm.Anunciante_Listar;")
        return cursor.fetchall()
    finally:
        conexion.close()


def consultar_anunciante(id_anunciante):
    conexion = obtener_conexion()
    try:
        cursor = conexion.cursor(as_dict=True)
        cursor.execute(
            "exec abm.Anunciante_ConsultarPorId @id_anunciante = %s;",
            (id_anunciante,),
        )
        return cursor.fetchone()
    finally:
        conexion.close()


@app.get("/")
def index():
    buscado = None
    id_busqueda = request.args.get("id", "").strip()

    try:
        anunciantes = listar_anunciantes()

        if id_busqueda:
            buscado = consultar_anunciante(int(id_busqueda))

        return render_template(
            "index.html",
            anunciantes=anunciantes,
            buscado=buscado,
            id_busqueda=id_busqueda,
        )

    except Exception as error:
        return render_template(
            "index.html",
            anunciantes=[],
            buscado=None,
            id_busqueda=id_busqueda,
            error_conexion=limpiar_error(error),
        )


@app.post("/alta")
def alta():
    nombre = request.form.get("nombre", "")
    pais = request.form.get("pais", "")
    conexion = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor(as_dict=True)

        # El SP devuelve el registro creado mediante SELECT.
        cursor.execute(
            """
            declare @id_anunciante int;

            exec abm.Anunciante_Alta
                @nombre = %s,
                @pais = %s,
                @id_anunciante = @id_anunciante output;
            """,
            (nombre, pais),
        )

        creado = cursor.fetchone()
        conexion.commit()

        if creado:
            flash(
                f"Anunciante creado: {creado['nombre']} "
                f"(ID {creado['id_anunciante']}).",
                "success",
            )
        else:
            flash("Anunciante creado correctamente.", "success")

    except Exception as error:
        if conexion:
            conexion.rollback()
        flash(
            f"No se pudo crear el anunciante: {limpiar_error(error)}",
            "error",
        )

    finally:
        if conexion:
            conexion.close()

    return redirect(url_for("index"))


@app.post("/modificar/<int:id_anunciante>")
def modificar(id_anunciante):
    nombre = request.form.get("nombre", "")
    pais = request.form.get("pais", "")
    conexion = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor(as_dict=True)

        cursor.execute(
            """
            exec abm.Anunciante_Modificar
                @id_anunciante = %s,
                @nombre = %s,
                @pais = %s;
            """,
            (id_anunciante, nombre, pais),
        )

        modificado = cursor.fetchone()
        conexion.commit()

        if modificado:
            flash(
                f"Anunciante {id_anunciante} modificado: "
                f"{modificado['nombre']} - {modificado['pais']}.",
                "success",
            )
        else:
            flash(
                f"Anunciante {id_anunciante} modificado correctamente.",
                "success",
            )

    except Exception as error:
        if conexion:
            conexion.rollback()
        flash(
            f"No se pudo modificar: {limpiar_error(error)}",
            "error",
        )

    finally:
        if conexion:
            conexion.close()

    return redirect(url_for("index"))


@app.post("/baja/<int:id_anunciante>")
def baja(id_anunciante):
    conexion = None

    try:
        conexion = obtener_conexion()
        cursor = conexion.cursor()

        cursor.execute(
            """
            exec abm.Anunciante_Baja
                @id_anunciante = %s;
            """,
            (id_anunciante,),
        )

        conexion.commit()

        flash(
            f"Anunciante {id_anunciante} eliminado correctamente.",
            "success",
        )

    except Exception as error:
        if conexion:
            conexion.rollback()

        flash(
            "No se pudo eliminar el anunciante. "
            f"SQL Server informó: {limpiar_error(error)}",
            "error",
        )

    finally:
        if conexion:
            conexion.close()

    return redirect(url_for("index"))


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=True,
    )
