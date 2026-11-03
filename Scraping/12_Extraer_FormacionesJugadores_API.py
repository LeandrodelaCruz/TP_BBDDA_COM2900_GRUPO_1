import requests
import json
import time

# ==========================================
# CONFIGURACIÓN
# ==========================================

INPUT_FILE = "formaciones_mundial_2026.json"
OUTPUT_FILE = "alineaciones_extraidas.json"

LIVE_URL_TEMPLATE = "https://api.fifa.com/api/v3/live/football/17/285023/{id_stage}/{id_match}"

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

POSITION_MAP = {
    0: "Goalkeeper",
    1: "Defender",
    2: "Midfielder",
    3: "Forward"
}


def obtener_nombre(datos, idioma="en"):
    if not datos:
        return None
    for elemento in datos:
        if elemento.get("Locale", "").lower().startswith(idioma):
            return elemento.get("Description")
    return datos[0].get("Description") if datos else None


def extraer_jugadores_desde_equipo(team_data):
    if not team_data:
        return []

    jugadores = []
    players_list = team_data.get("Players", [])

    for player in players_list:
        player_name = obtener_nombre(player.get("PlayerName")) or player.get("Name")

        # --- Lógica robusta para titularidad ---
        es_titular = player.get("StartingLineup")
        if es_titular is None:
            status = player.get("Status")
            if status is not None:
                es_titular = (status == 1)
            else:
                es_titular = False
        else:
            es_titular = bool(es_titular)
        # ---------------------------------------

        shirt_number = player.get("ShirtNumber")
        position_code = player.get("Position")
        is_captain = player.get("Captain", False)

        if not player_name or shirt_number is None:
            continue

        posicion_texto = POSITION_MAP.get(position_code, None)

        jugador = {
            "nombre_jugador": player_name,
            "dorsal_en_cancha": int(shirt_number),
            "es_titular": es_titular,
            "posicion_en_cancha": posicion_texto,
            "es_capitan": bool(is_captain),
            "id_jugador_fifa": player.get("IdPlayer")
        }
        jugadores.append(jugador)

    return jugadores


# ==========================================
# PROCESO PRINCIPAL
# ==========================================

try:
    with open(INPUT_FILE, "r", encoding="utf-8") as f:
        partidos = json.load(f)

    print(f"Se cargaron {len(partidos)} partidos para procesar alineaciones.")

    session = requests.Session()
    resultados_alineaciones = []

    for idx, partido in enumerate(partidos):
        id_match = partido.get("id_match_fifa")
        id_stage = partido.get("id_stage_fifa")

        if not id_match or not id_stage:
            print(f"  [Advertencia] Partido sin id_match o id_stage. Saltando.")
            continue

        url = LIVE_URL_TEMPLATE.format(id_stage=id_stage, id_match=id_match)

        print(
            f"[{idx + 1}/{len(partidos)}] Consultando partido {id_match} "
            f"({partido.get('seleccion_1', {}).get('nombre')} vs {partido.get('seleccion_2', {}).get('nombre')})..."
        )

        try:
            respuesta = session.get(url, headers=HEADERS, timeout=30)
            respuesta.raise_for_status()
            data = respuesta.json()

            home_team = data.get("HomeTeam") or data.get("Home")
            away_team = data.get("AwayTeam") or data.get("Away")

            jugadores_local = extraer_jugadores_desde_equipo(home_team)
            jugadores_visitante = extraer_jugadores_desde_equipo(away_team)

            if not jugadores_local and not jugadores_visitante:
                print(f"  -> No se encontraron datos de alineación para este partido.")
                continue

            # ==========================================
            # AQUÍ AÑADIMOS LOS CAMPOS QUE FALTABAN
            # ==========================================
            resultado_partido = {
                "id_match_fifa": id_match,
                "id_stage_fifa": id_stage,
                "fecha": partido.get("fecha"),
                "horario_local": partido.get("horario_local"),
                "horario_utc": partido.get("horario_utc"),
                "estadio": partido.get("estadio"),
                "ciudad": partido.get("ciudad"),
                "pais_estadio": partido.get("pais_estadio"),
                "fase": partido.get("fase"),
                "grupo": partido.get("grupo"),
                "seleccion_1_nombre": partido.get("seleccion_1", {}).get("nombre"),
                "seleccion_1_abreviatura": partido.get("seleccion_1", {}).get("abreviatura"),
                "seleccion_1_esquema_tactico": partido.get("seleccion_1", {}).get("esquema_tactico"),
                "seleccion_2_nombre": partido.get("seleccion_2", {}).get("nombre"),
                "seleccion_2_abreviatura": partido.get("seleccion_2", {}).get("abreviatura"),
                "seleccion_2_esquema_tactico": partido.get("seleccion_2", {}).get("esquema_tactico"),
                "jugadores_seleccion_1": jugadores_local,
                "jugadores_seleccion_2": jugadores_visitante
            }
            # ==========================================

            resultados_alineaciones.append(resultado_partido)
            print(
                f"  -> OK: {len(jugadores_local)} jugadores (Local), {len(jugadores_visitante)} jugadores (Visitante)."
            )

            time.sleep(0.5)

        except requests.exceptions.RequestException as e:
            print(f"  -> Error al consultar el partido: {e}")
            continue
        except json.JSONDecodeError:
            print(f"  -> Error al decodificar JSON de la respuesta.")
            continue

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(resultados_alineaciones, f, indent=4, ensure_ascii=False)

    print(f"\n✅ Proceso completado. Se guardaron alineaciones de {len(resultados_alineaciones)} partidos.")
    print(f"Archivo generado: {OUTPUT_FILE}")

    if resultados_alineaciones:
        print("\n--- Ejemplo de estructura de salida ---")
        ejemplo = resultados_alineaciones[0]
        print(json.dumps({
            "id_match_fifa": ejemplo["id_match_fifa"],
            "horario_local": ejemplo["horario_local"],
            "horario_utc": ejemplo["horario_utc"],
            "estadio": ejemplo["estadio"],
            "ciudad": ejemplo["ciudad"],
            "pais_estadio": ejemplo["pais_estadio"],
            "seleccion_1_nombre": ejemplo["seleccion_1_nombre"],
            "jugadores_seleccion_1": ejemplo["jugadores_seleccion_1"][:2]
        }, indent=2, ensure_ascii=False))

except FileNotFoundError:
    print(f"Error: No se encontró el archivo '{INPUT_FILE}'.")
except Exception as e:
    print(f"Error inesperado: {e}")