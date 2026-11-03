
import requests
import json

# ==========================================
# CONFIGURACION FIFA
# ==========================================

URL = "https://api.fifa.com/api/v3/calendar/matches"

PARAMETROS = {
    "idCompetition": 17,
    "idSeason": 285023,
    "count": 500,
    "language": "en"
}

# ==========================================
# ENCABEZADOS HTTP
# ==========================================

HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/130.0.0.0 Safari/537.36"
    ),
    "Accept": "application/json, text/plain, */*",
    "Accept-Language": "en-US,en;q=0.9",
    "Referer": "https://www.fifa.com/",
    "Origin": "https://www.fifa.com"
}


# ==========================================
# FUNCIONES AUXILIARES
# ==========================================

def obtener_nombre(datos, idioma="en"):

    if not datos:
        return None

    for elemento in datos:

        if elemento.get("Locale", "").lower().startswith(idioma):
            return elemento.get("Description")

    return datos[0].get("Description")


def obtener_datos_seleccion(seleccion):

    if not seleccion:
        return None

    return {
        "nombre": obtener_nombre(seleccion.get("TeamName")),
        "abreviatura": seleccion.get("Abbreviation"),
        "codigo_pais": seleccion.get("IdCountry"),
        "esquema_tactico": seleccion.get("Tactics")
    }


# ==========================================
# CONSULTA A FIFA
# ==========================================

try:

    session = requests.Session()

    respuesta = session.get(
        URL,
        params=PARAMETROS,
        headers=HEADERS,
        timeout=30
    )

    print("Codigo HTTP:", respuesta.status_code)
    print("URL:", respuesta.url)

    # Verificar respuesta HTTP

    if respuesta.status_code != 200:

        print("\nFIFA rechazo la solicitud.")

        print("Respuesta del servidor:")
        print(respuesta.text[:2000])

        respuesta.raise_for_status()

    # ======================================
    # PROCESAR JSON DE FIFA
    # ======================================

    datos = respuesta.json()

    partidos_api = datos.get("Results", [])

    print("\nPartidos encontrados:", len(partidos_api))

    partidos = []

    for partido in partidos_api:

        estadio = partido.get("Stadium") or {}

        seleccion_local = obtener_datos_seleccion(
            partido.get("Home")
        )

        seleccion_visitante = obtener_datos_seleccion(
            partido.get("Away")
        )

        partido_procesado = {

            # Identificadores externos
            "id_match_fifa": partido.get("IdMatch"),
            "id_stage_fifa": partido.get("IdStage"),

            # Fecha y horarios
            "fecha": (
                partido.get("LocalDate")[:10]
                if partido.get("LocalDate")
                else None
            ),

            "horario_local": partido.get("LocalDate"),
            "horario_utc": partido.get("Date"),

            # Estadio
            "estadio": obtener_nombre(
                estadio.get("Name")
            ),

            "ciudad": obtener_nombre(
                estadio.get("CityName")
            ),

            "pais_estadio": estadio.get("IdCountry"),

            # Selecciones
            "seleccion_1": seleccion_local,
            "seleccion_2": seleccion_visitante,

            # Fase y grupo
            "fase": obtener_nombre(
                partido.get("StageName")
            ),

            "grupo": obtener_nombre(
                partido.get("GroupName")
            )
        }

        partidos.append(partido_procesado)

    # ======================================
    # GENERAR ARCHIVO JSON
    # ======================================

    with open(
        "formaciones_mundial_2026.json",
        "w",
        encoding="utf-8"
    ) as archivo:

        json.dump(
            partidos,
            archivo,
            indent=4,
            ensure_ascii=False
        )

    print("\nJSON generado correctamente.")

    print("Archivo: partidos_mundial_2026.json")

    # ======================================
    # MOSTRAR PRIMER PARTIDO
    # ======================================

    if partidos:

        print("\nPrimer partido procesado:")

        print(
            json.dumps(
                partidos[0],
                indent=4,
                ensure_ascii=False
            )
        )

except requests.exceptions.HTTPError as error:

    print("\nError HTTP:", error)

except requests.exceptions.RequestException as error:

    print("\nError de conexion:", error)

except ValueError as error:

    print("\nError al interpretar el JSON:", error)
