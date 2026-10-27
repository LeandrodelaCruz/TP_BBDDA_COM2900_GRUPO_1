#!/usr/bin/env python3
"""
Universidad Nacional de La Matanza - Bases de Datos Aplicada - 2C 2026
Grupo 01

Scraping de los planteles definitivos de la Copa Mundial FIFA 2026.
Fuente: https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_squads

El script NO escribe en SQL Server. Su única responsabilidad es obtener el
HTML público, extraer las tablas de jugadores y generar un CSV que luego será
importado mediante T-SQL y los SP ABM de la Entrega 5.
"""

from __future__ import annotations

import argparse
import csv
import re
from pathlib import Path

import requests
from bs4 import BeautifulSoup

URL = "https://en.wikipedia.org/wiki/2026_FIFA_World_Cup_squads"

# Nombres exactamente iguales a los cargados en dbo.Seleccion desde teams.csv.
EXPECTED_TEAMS = {
    "Mexico", "South Africa", "South Korea", "Czechia", "Canada",
    "Bosnia and Herzegovina", "Qatar", "Switzerland", "Brazil", "Morocco",
    "Haiti", "Scotland", "USA", "Paraguay", "Australia", "Türkiye",
    "Germany", "Curaçao", "Côte d'Ivoire", "Ecuador", "Netherlands", "Japan",
    "Sweden", "Tunisia", "Belgium", "Egypt", "IR Iran", "New Zealand",
    "Spain", "Cabo Verde", "Saudi Arabia", "Uruguay", "France", "Senegal",
    "Iraq", "Norway", "Argentina", "Algeria", "Austria", "Jordan",
    "Portugal", "Congo DR", "Uzbekistan", "Colombia", "England", "Croatia",
    "Ghana", "Panama"
}

# Wikipedia y el dataset de Seleccion no siempre usan el mismo nombre del país.
TEAM_ALIASES = {
    "United States": "USA",
    "United States of America": "USA",
    "Czech Republic": "Czechia",
    "Turkey": "Türkiye",
    "Ivory Coast": "Côte d'Ivoire",
    "Iran": "IR Iran",
    "Cape Verde": "Cabo Verde",
    "DR Congo": "Congo DR",
    "Democratic Republic of the Congo": "Congo DR",
    "Korea Republic": "South Korea",
}


def clean_text(value: str) -> str:
    value = re.sub(r"\[[^\]]+\]", "", value)
    return " ".join(value.split()).strip()


def canonical_team(raw: str) -> str:
    raw = clean_text(raw)
    raw = re.sub(r"\s+edit$", "", raw, flags=re.IGNORECASE).strip()
    return TEAM_ALIASES.get(raw, raw)


def extract_date(cell) -> str | None:
    # Wikipedia suele incluir una fecha ISO oculta (class=bday).
    bday = cell.find(class_="bday")
    if bday:
        value = clean_text(bday.get_text(" ", strip=True))
        if re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
            return value

    text = cell.get_text(" ", strip=True)
    match = re.search(r"(\d{4}-\d{2}-\d{2})", text)
    return match.group(1) if match else None


def extract_club(cell) -> str:
    links = cell.find_all("a")
    if links:
        # El último enlace suele ser el club; los íconos/banderas aparecen antes.
        value = clean_text(links[-1].get_text(" ", strip=True))
        if value:
            return value
    return clean_text(cell.get_text(" ", strip=True))


def scrape() -> list[dict[str, str]]:
    headers = {
        "User-Agent": "UNLaM-BasesDatosAplicada-TP/1.0 (academic project)"
    }
    response = requests.get(URL, headers=headers, timeout=30)
    response.raise_for_status()

    soup = BeautifulSoup(response.text, "html.parser")
    rows: list[dict[str, str]] = []
    teams_found: set[str] = set()

    for heading in soup.find_all("h3"):
        raw_team = heading.get_text(" ", strip=True)
        team = canonical_team(raw_team)
        if team not in EXPECTED_TEAMS:
            continue

        table = heading.find_next("table")
        if table is None:
            continue

        # Evita tomar por accidente una tabla perteneciente a la selección siguiente.
        previous_h3 = table.find_previous("h3")
        if previous_h3 is not heading:
            continue

        header_row = table.find("tr")
        if header_row is None:
            continue
        table_headers = [clean_text(x.get_text(" ", strip=True)) for x in header_row.find_all(["th", "td"])]
        headers_joined = " | ".join(table_headers).lower()
        if "player" not in headers_joined or "date of birth" not in headers_joined:
            continue

        parsed_for_team = 0
        for tr in table.find_all("tr")[1:]:
            cells = tr.find_all(["th", "td"])
            if len(cells) < 7:
                continue

            number_text = clean_text(cells[0].get_text(" ", strip=True))
            number_match = re.search(r"\d+", number_text)
            if not number_match:
                continue
            dorsal = int(number_match.group(0))
            if not 1 <= dorsal <= 26:
                continue

            pos_text = clean_text(cells[1].get_text(" ", strip=True)).upper()
            pos_match = re.search(r"(GK|DF|MF|FW)", pos_text)
            if not pos_match:
                continue
            position = pos_match.group(1)

            player = clean_text(cells[2].get_text(" ", strip=True))
            player = re.sub(r"\s*\((?:captain|vice-captain)\)\s*", "", player, flags=re.IGNORECASE).strip()

            dob = extract_date(cells[3])
            club = extract_club(cells[6])
            if not player or not dob or not club:
                continue

            rows.append({
                "seleccion": team,
                "dorsal": str(dorsal),
                "posicion": position,
                "jugador": player,
                "fecha_nacimiento": dob,
                "club_origen": club,
            })
            parsed_for_team += 1

        if parsed_for_team:
            teams_found.add(team)

    missing = sorted(EXPECTED_TEAMS - teams_found)
    if missing:
        raise RuntimeError(
            "No se pudieron detectar planteles para estas selecciones: " + ", ".join(missing)
        )

    if not rows:
        raise RuntimeError("No se extrajo ningún jugador. La estructura de la página pudo haber cambiado.")

    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Scraping de planteles FIFA World Cup 2026")
    parser.add_argument(
        "--salida",
        default="Archivos_Importacion/jugadores_scraping.csv",
        help="Ruta del CSV a generar",
    )
    args = parser.parse_args()

    rows = scrape()
    output = Path(args.salida)
    output.parent.mkdir(parents=True, exist_ok=True)

    with output.open("w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["seleccion", "dorsal", "posicion", "jugador", "fecha_nacimiento", "club_origen"],
        )
        writer.writeheader()
        writer.writerows(rows)

    teams = {r["seleccion"] for r in rows}
    print(f"OK - Archivo generado: {output}")
    print(f"Selecciones detectadas: {len(teams)}")
    print(f"Jugadores extraídos: {len(rows)}")
    print(f"Fuente: {URL}")


if __name__ == "__main__":
    main()
