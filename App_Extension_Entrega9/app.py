import os
import re
from xml.dom import minidom

import pymssql
from dotenv import load_dotenv
from flask import (
    Flask,
    Response,
    flash,
    redirect,
    render_template,
    request,
    url_for,
)
from werkzeug.utils import secure_filename

load_dotenv()

app = Flask(__name__)
app.secret_key = os.getenv("FLASK_SECRET_KEY", "tp-bbdd-aplicada-grupo-1")

DB_SERVER = os.getenv("DB_SERVER", "localhost")
DB_PORT = int(os.getenv("DB_PORT", "1433"))
DB_NAME = os.getenv("DB_NAME", "MUNDIALDEFUTBOL")
DB_USER = os.getenv("DB_USER", "sa")
DB_PASSWORD = os.getenv("DB_PASSWORD", "")

IMPORT_DIR = os.getenv(
    "IMPORT_DIR",
    r"C:\TP_BBDDA_COM2900_GRUPO_1-main\Archivos_Importacion",
)
REPORTES_XML_DIR = os.getenv(
    "REPORTES_XML_DIR",
    r"C:\TP_BBDDA_COM2900_GRUPO_1-main\Reportes",
)


def obtener_conexion():
    if not DB_PASSWORD:
        raise RuntimeError("Falta DB_PASSWORD en el archivo .env.")

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

    # Captura cualquier error de usuario de SQL Server (50000 - 59999),
    # incluyendo ABM (50001..), Importacion (51400..) y Reportes (53400..).
    coincidencia = re.search(
        r"\((5\d{4}),\s*b(['\"])(.*?)\2\)",
        mensaje,
        re.DOTALL,
    )
    if coincidencia:
        texto = coincidencia.group(3)
        return texto.replace("\\n", " ").replace("\\r", " ").strip()

    return mensaje


def formatear_xml(xml_crudo):
    if not xml_crudo:
        return ""
    try:
        dom = minidom.parseString(xml_crudo.encode("utf-8"))
        return dom.toprettyxml(indent="  ")
    except Exception:
        return xml_crudo


def listar_csv_disponibles():
    if not os.path.isdir(IMPORT_DIR):
        return []
    return sorted(
        nombre
        for nombre in os.listdir(IMPORT_DIR)
        if nombre.lower().endswith(".csv")
    )


def ejecutar_reporte_arbitros_xml(id_arbitro=None, id_partido=None):
    conexion = obtener_conexion()
    try:
        cursor = conexion.cursor()
        cursor.execute(
            """
            exec reportes.Reporte_Designaciones_Arbitrales_XML
                @id_arbitro = %s,
                @id_partido = %s,
                @devolver = 1;
            """,
            (id_arbitro, id_partido),
        )
        # SQL Server fragmenta salidas FOR XML largas en multiples filas.
        filas = cursor.fetchall()
        xml_crudo = "".join(
            fila[0] for fila in filas if fila and fila[0] is not None
        )
        return formatear_xml(xml_crudo)
    finally:
        conexion.close()


def construir_nombre_archivo_xml(id_arbitro=None, id_partido=None):
    partes = ["designaciones_arbitrales"]
    if id_arbitro is not None:
        partes.append(f"arbitro_{id_arbitro}")
    if id_partido is not None:
        partes.append(f"partido_{id_partido}")
    return "_".join(partes) + ".xml"


def guardar_xml_en_disco(contenido_xml, nombre_archivo):
    os.makedirs(REPORTES_XML_DIR, exist_ok=True)
    ruta_destino = os.path.abspath(
        os.path.join(REPORTES_XML_DIR, nombre_archivo)
    )
    with open(ruta_destino, "w", encoding="utf-8", newline="\n") as archivo:
        archivo.write(contenido_xml)
    return ruta_destino


# =========================================================
# MODULO 1: ABM DE ANUNCIANTES (ENTREGA 5 / ENTREGA 9)
# =========================================================


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


# =========================================================
# MODULO 2: IMPORTACION DE PERSONAL TECNICO (ENTREGA 6)
# =========================================================


@app.route("/importacion", methods=["GET", "POST"])
def importacion():
    resumen = None
    errores_importacion = []
    error_ejecucion = None
    archivo_seleccionado = ""

    if request.method == "POST":
        archivo_subido = request.files.get("archivo_csv")
        archivo_existente = request.form.get("archivo_existente", "").strip()
        ruta_csv = None
        conexion = None

        try:
            os.makedirs(IMPORT_DIR, exist_ok=True)

            if archivo_subido and archivo_subido.filename:
                nombre_seguro = secure_filename(archivo_subido.filename)
                if not nombre_seguro.lower().endswith(".csv"):
                    raise ValueError("El archivo seleccionado debe tener extensión .csv.")

                ruta_csv = os.path.abspath(
                    os.path.join(IMPORT_DIR, nombre_seguro)
                )
                # Se guarda sin alterar bytes ni codificacion (regla Entrega 6).
                archivo_subido.save(ruta_csv)
                archivo_seleccionado = nombre_seguro

            elif archivo_existente:
                nombre_seguro = secure_filename(archivo_existente)
                ruta_csv = os.path.abspath(
                    os.path.join(IMPORT_DIR, nombre_seguro)
                )
                archivo_seleccionado = nombre_seguro

            else:
                raise ValueError(
                    "Subí un archivo CSV o elegí uno disponible en la carpeta de importación."
                )

            conexion = obtener_conexion()
            cursor = conexion.cursor(as_dict=True)

            cursor.execute(
                "exec importacion.Importar_Personal_Tecnico_CSV @archivo = %s;",
                (ruta_csv,),
            )

            # 1er result set: resumen de la ejecucion
            resumen = cursor.fetchone()

            # 2do result set: filas rechazadas con su motivo
            if cursor.nextset():
                errores_importacion = cursor.fetchall()

            # Se confirma la transaccion para persistir los registros validos
            # (importacion parcial ante errores de datos).
            conexion.commit()

            if resumen:
                if resumen["registros_con_error"] == 0:
                    flash(
                        f"Importación completada sin errores: "
                        f"{resumen['registros_insertados']} insertados, "
                        f"{resumen['registros_actualizados']} actualizados.",
                        "success",
                    )
                else:
                    flash(
                        f"Importación parcial: {resumen['registros_insertados']} insertados, "
                        f"{resumen['registros_actualizados']} actualizados y "
                        f"{resumen['registros_con_error']} con error.",
                        "error",
                    )

        except Exception as error:
            if conexion:
                conexion.rollback()
            error_ejecucion = limpiar_error(error)

        finally:
            if conexion:
                conexion.close()

    return render_template(
        "importacion.html",
        import_dir=IMPORT_DIR,
        archivos_disponibles=listar_csv_disponibles(),
        archivo_seleccionado=archivo_seleccionado,
        resumen=resumen,
        errores_importacion=errores_importacion,
        error_conexion=error_ejecucion,
    )


# =========================================================
# MODULO 3: REPORTE DESIGNACIONES ARBITRALES XML (ENTREGA 7)
# =========================================================


def parsear_filtro_entero(valor_texto, nombre_campo):
    valor_limpio = valor_texto.strip()
    if not valor_limpio:
        return None
    try:
        return int(valor_limpio)
    except ValueError as exc:
        raise ValueError(f"El filtro {nombre_campo} debe ser un número entero.") from exc


@app.route("/reportes/designaciones-arbitrales", methods=["GET", "POST"])
def reporte_designaciones_arbitrales():
    id_arbitro_raw = (
        request.form.get("id_arbitro")
        if request.method == "POST"
        else request.args.get("id_arbitro", "")
    ) or ""
    id_partido_raw = (
        request.form.get("id_partido")
        if request.method == "POST"
        else request.args.get("id_partido", "")
    ) or ""

    xml_contenido = ""
    ruta_guardada = None
    nombre_archivo = "designaciones_arbitrales.xml"
    error_ejecucion = None

    try:
        id_arbitro = parsear_filtro_entero(id_arbitro_raw, "ID Árbitro")
        id_partido = parsear_filtro_entero(id_partido_raw, "ID Partido")

        xml_contenido = ejecutar_reporte_arbitros_xml(
            id_arbitro=id_arbitro,
            id_partido=id_partido,
        )
        nombre_archivo = construir_nombre_archivo_xml(
            id_arbitro=id_arbitro,
            id_partido=id_partido,
        )

        # Guarda el XML en disco automaticamente (o al presionar Guardar XML)
        if xml_contenido:
            ruta_guardada = guardar_xml_en_disco(xml_contenido, nombre_archivo)
            if request.method == "POST":
                flash(
                    f"Reporte XML guardado en: {ruta_guardada}",
                    "success",
                )

    except Exception as error:
        error_ejecucion = limpiar_error(error)

    return render_template(
        "reporte_xml.html",
        id_arbitro=id_arbitro_raw.strip(),
        id_partido=id_partido_raw.strip(),
        xml_contenido=xml_contenido,
        ruta_guardada=ruta_guardada,
        nombre_archivo=nombre_archivo,
        error_conexion=error_ejecucion,
    )


@app.get("/reportes/designaciones-arbitrales/descargar")
def descargar_reporte_xml():
    id_arbitro_raw = request.args.get("id_arbitro", "")
    id_partido_raw = request.args.get("id_partido", "")

    try:
        id_arbitro = parsear_filtro_entero(id_arbitro_raw, "ID Árbitro")
        id_partido = parsear_filtro_entero(id_partido_raw, "ID Partido")

        xml_contenido = ejecutar_reporte_arbitros_xml(
            id_arbitro=id_arbitro,
            id_partido=id_partido,
        )
        nombre_archivo = construir_nombre_archivo_xml(
            id_arbitro=id_arbitro,
            id_partido=id_partido,
        )
        guardar_xml_en_disco(xml_contenido, nombre_archivo)

        return Response(
            xml_contenido,
            mimetype="application/xml; charset=utf-8",
            headers={
                "Content-Disposition": f'attachment; filename="{nombre_archivo}"'
            },
        )

    except Exception as error:
        flash(
            f"No se pudo descargar el XML: {limpiar_error(error)}",
            "error",
        )
        return redirect(
            url_for(
                "reporte_designaciones_arbitrales",
                id_arbitro=id_arbitro_raw.strip(),
                id_partido=id_partido_raw.strip(),
            )
        )


if __name__ == "__main__":
    app.run(
        host="127.0.0.1",
        port=5000,
        debug=True,
    )