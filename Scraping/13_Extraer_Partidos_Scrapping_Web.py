import requests
import json
from datetime import datetime

URL = "https://api.fifa.com/api/v3/calendar/matches"

PARAMS = {
    "idCompetition": 17,
    "idSeason": 285023,
    "count": 500,
    "language": "en"
}


def obtener_texto(lista):
    """Extrae la descripción de un campo localizado."""
    if not lista:
        return None

    # Priorizar español si está disponible
    for idioma in ("es-AR", "es", "es-ES", "en-GB", "en"):
        for elemento in lista:
            if elemento.get("Locale") == idioma:
                return elemento.get("Description")

    return lista[0].get("Description")


def convertir_fecha(valor):
    """Convierte una fecha ISO de FIFA a datetime sin zona horaria."""
    if not valor:
        return None

    fecha = datetime.fromisoformat(
        valor.replace("Z", "+00:00")
    )

    # Conserva la hora representada por FIFA
    return fecha.replace(tzinfo=None)


def procesar_partido(partido):
    fecha_local = convertir_fecha(partido.get("LocalDate"))
    fecha_utc = convertir_fecha(partido.get("Date"))

    if fecha_local is None or fecha_utc is None:
        raise ValueError("El partido no tiene fecha u horario completo")

    local = partido.get("Home") or {}
    visitante = partido.get("Away") or {}

    sede = partido.get("Stadium") or {}

    nombre_sede = obtener_texto(sede.get("Name"))
    seleccion_local = obtener_texto(local.get("TeamName"))
    seleccion_visitante = obtener_texto(visitante.get("TeamName"))

    fase = obtener_texto(partido.get("StageName"))

    goles_local = partido.get("HomeTeamScore")
    goles_visitante = partido.get("AwayTeamScore")

    resultado = None

    if goles_local is not None and goles_visitante is not None:

        resultado = f"{goles_local}-{goles_visitante}"

        # Agregar definición por penales cuando corresponda
        penales_local = partido.get("HomeTeamPenaltyScore")
        penales_visitante = partido.get("AwayTeamPenaltyScore")

        if penales_local is not None and penales_visitante is not None:
            resultado += f" ({penales_local}-{penales_visitante})"

    return {
        "numero_partido": partido.get("MatchNumber"),
        "id_partido_fifa": partido.get("IdMatch"),

        "id_sede_fifa": sede.get("IdStadium"),
        "sede": nombre_sede,

        "fecha": fecha_local.date().isoformat(),

        "horario_local": fecha_local.isoformat(timespec="seconds"),
        "horario_UTC": fecha_utc.isoformat(timespec="seconds"),

        "fase": fase,

        "resultado_final": resultado,

        "asistencia_publico": partido.get("Attendance"),

        "id_seleccion_local_fifa": local.get("IdTeam"),
        "seleccion_local": seleccion_local,

        "id_seleccion_visitante_fifa": visitante.get("IdTeam"),
        "seleccion_visitante": seleccion_visitante
    }


def main():
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36",
        "Accept": "application/json, text/plain, */*",
        "Accept-Language": "es-AR,es;q=0.9,en;q=0.8",
        "Origin": "https://www.fifa.com",
        "Referer": "https://www.fifa.com/"
    }

    session = requests.Session()

    response = session.get(
        URL,
        params=PARAMS,
        headers=headers,
        timeout=30
    )

    print("Código HTTP:", response.status_code)
    print("URL:", response.url)
    print("Respuesta:", response.text[:1000])

    response.raise_for_status()

    datos = response.json()

    partidos = datos.get("Results", [])

    procesados = []
    errores = []

    for partido in partidos:

        try:
            registro = procesar_partido(partido)

            procesados.append(registro)

        except Exception as error:

            errores.append({
                "id_partido": partido.get("IdMatch"),
                "error": str(error)
            })

    # Generar JSON
    with open(
            "partidos_mundial_2026.json",
            "w",
            encoding="utf-8"
    ) as archivo:

        json.dump(
            procesados,
            archivo,
            ensure_ascii=False,
            indent=4
        )

    print("Partidos obtenidos:", len(partidos))
    print("Partidos procesados:", len(procesados))
    print("Partidos con errores:", len(errores))

    if errores:
        print("\nErrores:")
        for error in errores:
            print(error)

    print("\nJSON generado correctamente.")


if __name__ == "__main__":
    main()
