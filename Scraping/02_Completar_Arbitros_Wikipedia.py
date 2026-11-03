#!/usr/bin/env python3
"""
Completa el CSV de árbitros extraído del PDF oficial de FIFA con datos
adicionales obtenidos de Wikipedia.

Uso:
  python3 02_Completar_Arbitros_Wikipedia.py \
      Archivos_Importacion/arbitros_fifa_pdf.csv \
      Archivos_Importacion/arbitros_fifa_completo.csv

Qué hace:
  - Lee el CSV generado por 01_Extraer_Arbitros_FIFA_PDF.py.
  - Para cada árbitro, busca su página en Wikipedia y extrae:
      * fecha de nacimiento;
      * idiomas (si aparecen en el infobox como "Lengua materna" o similar).
  - Corrige la separación nombre/apellido de los árbitros que en el PDF
    aparecen solo con apellido en mayúsculas.
  - Escribe un CSV mejorado listo para importar.

Requisitos:
  pip install requests beautifulsoup4 lxml

Notas:
  - Wikipedia tiene límites de tasa. El script hace requests con un User-Agent
    descriptivo y espera entre consultas. Si se bloquea, aumentar RETRASO_SEG.
  - No todas las páginas de árbitros tienen infobox completo. Si no se encuentra
    un dato, se deja el campo vacío.
  - Los idiomas se infieren de campos como "Lengua materna", "Languages",
    "Nationality" o el título de la página en otros idiomas.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Optional

import requests
from bs4 import BeautifulSoup

WIKIPEDIA_API = "https://en.wikipedia.org/w/api.php"
WIKIPEDIA_REST = "https://en.wikipedia.org/api/rest_v1/page/summary"
RETRASO_SEG = 0.6

PAIS_A_LENGUA = {
    "Qatar": "Arabic",
    "Saudi Arabia": "Arabic",
    "Japan": "Japanese",
    "Somalia": "Somali",
    "Gabon": "French",
    "El Salvador": "Spanish",
    "Mauritania": "Arabic",
    "Paraguay": "Spanish",
    "Costa Rica": "Spanish",
    "Brazil": "Portuguese",
    "United States": "English",
    "Norway": "Norwegian",
    "Australia": "English",
    "Argentina": "Spanish",
    "Canada": "English",
    "Chile": "Spanish",
    "Mexico": "Spanish",
    "Algeria": "Arabic",
    "Spain": "Spanish",
    "Morocco": "Arabic",
    "New Zealand": "English",
    "Romania": "Romanian",
    "France": "French",
    "China": "Chinese",
    "Jordan": "Arabic",
    "Netherlands": "Dutch",
    "Poland": "Polish",
    "Italy": "Italian",
    "Honduras": "Spanish",
    "Egypt": "Arabic",
    "Jamaica": "English",
    "Sweden": "Swedish",
    "England": "English",
    "United Arab Emirates": "Arabic",
    "Peru": "Spanish",
    "Portugal": "Portuguese",
    "Colombia": "Spanish",
    "Switzerland": "German",
    "Uzbekistan": "Uzbek",
    "Venezuela": "Spanish",
    "Slovenia": "Slovene",
    "Germany": "German",
    "Croatia": "Croatian",
    "Cameroon": "French",
    "Nicaragua": "Spanish",
    "Belgium": "Dutch",
    "Trinidad and Tobago": "English",
    "Angola": "Portuguese",
    "South Africa": "English",
    "Uruguay": "Spanish",
}


def normalizar(texto: str) -> str:
    """Normaliza espacios y quita espacios de los extremos."""
    return re.sub(r"\s+", " ", str(texto).strip())


def capitalizar(texto: str) -> str:
    """Título simple."""
    if not texto:
        return texto
    return " ".join("-".join(p.capitalize() for p in palabra.split("-")) for palabra in texto.split())


def parsear_fecha(valor: str) -> str:
    """Devuelve YYYY-MM-DD si puede parsear el valor, sino cadena vacía."""
    valor = normalizar(valor).replace("\u00a0", " ")
    if not valor:
        return ""

    # Remueve referencias tipo [1]
    valor = re.sub(r"\[\d+\]", "", valor).strip()

    for fmt in ("%d %B %Y", "%B %d, %Y", "%Y-%m-%d", "%d/%m/%Y", "%m/%d/%Y"):
        try:
            return datetime.strptime(valor, fmt).strftime("%Y-%m-%d")
        except ValueError:
            continue

    # Caso: "12 January 1985 (age 40)"
    m = re.search(r"(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})", valor)
    if m:
        try:
            return datetime.strptime(
                f"{m.group(1)} {m.group(2)} {m.group(3)}", "%d %B %Y"
            ).strftime("%Y-%m-%d")
        except ValueError:
            pass
    return ""


def buscar_pagina_wikipedia(nombre: str, apellido: str, pais: str) -> Optional[str]:
    """
    Busca la página de Wikipedia en inglés más probable para el árbitro.
    Devuelve el título de la página o None si no encuentra nada.
    """
    consultas = [
        f"{nombre} {apellido} football referee",
        f"{nombre} {apellido} referee",
        f"{apellido} {nombre} referee",
        f"{nombre} {apellido}",
    ]

    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "BBDDA-UNLaM-Grupo01/1.0 "
                "(eliasrodriguez@unlam.edu.ar; academic project)"
            )
        }
    )

    for consulta in consultas:
        try:
            resp = session.get(
                WIKIPEDIA_API,
                params={
                    "action": "query",
                    "list": "search",
                    "srsearch": consulta,
                    "format": "json",
                    "srlimit": 5,
                },
                timeout=20,
            )
            resp.raise_for_status()
            data = resp.json()
            resultados = data.get("query", {}).get("search", [])
            for r in resultados:
                titulo = r.get("title", "")
                # Aceptamos si el apellido está en el título y parece futbolístico
                if apellido.split()[-1].lower() in titulo.lower():
                    if any(
                        p in titulo.lower() or p in r.get("snippet", "").lower()
                        for p in ["referee", "football", "soccer"]
                    ):
                        return titulo
            time.sleep(RETRASO_SEG)
        except Exception:
            continue
    return None


def obtener_resumen(titulo: str) -> dict:
    """Obtiene el summary de la API REST de Wikipedia."""
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "BBDDA-UNLaM-Grupo01/1.0 "
                "(eliasrodriguez@unlam.edu.ar; academic project)"
            )
        }
    )
    try:
        resp = session.get(
            f"{WIKIPEDIA_REST}/{requests.utils.quote(titulo.replace(' ', '_'))}",
            timeout=20,
        )
        resp.raise_for_status()
        return resp.json()
    except Exception:
        return {}


def obtener_html(titulo: str) -> Optional[BeautifulSoup]:
    """Obtiene el HTML de la página para parsear infobox."""
    session = requests.Session()
    session.headers.update(
        {
            "User-Agent": (
                "BBDDA-UNLaM-Grupo01/1.0 "
                "(eliasrodriguez@unlam.edu.ar; academic project)"
            )
        }
    )
    try:
        resp = session.get(
            "https://en.wikipedia.org/wiki/" + requests.utils.quote(titulo.replace(" ", "_")),
            timeout=20,
        )
        resp.raise_for_status()
        return BeautifulSoup(resp.text, "lxml")
    except Exception:
        return None


def extraer_fecha_del_infobox(soup: BeautifulSoup) -> str:
    """Busca fecha de nacimiento en infobox."""
    if soup is None:
        return ""

    # API REST summary a veces trae birth_date
    # Lo intentamos con el HTML por si falla.
    infobox = soup.find("table", {"class": re.compile(r"infobox")})
    if not infobox:
        return ""

    for th in infobox.find_all("th"):
        texto_th = normalizar(th.get_text())
        if any(k in texto_th.lower() for k in ["born", "date of birth", "birth date", "fecha de nacimiento"]):
            td = th.find_next_sibling("td")
            if td:
                return parsear_fecha(td.get_text())
    return ""


def extraer_idiomas(soup: BeautifulSoup, pais: str) -> str:
    """
    Intenta inferir idiomas. Primero busca en el infobox; si no, usa el país.
    """
    if soup is None:
        return PAIS_A_LENGUA.get(pais, "")

    infobox = soup.find("table", {"class": re.compile(r"infobox")})
    if infobox:
        for th in infobox.find_all("th"):
            texto_th = normalizar(th.get_text())
            if any(k in texto_th.lower() for k in ["language", "lengua", "native language", "idioma"]):
                td = th.find_next_sibling("td")
                if td:
                    return normalizar(td.get_text()).replace(",", ";")

    # Fallback por nacionalidad
    return PAIS_A_LENGUA.get(pais, "")


def separar_nombre_apellido(nombre_completo: str) -> tuple[str, str]:
    """
    Separa "APELLIDO(S) NOMBRE(S)" del PDF. Si todo es mayúsculas,
    asume que todo es apellido.
    """
    partes = normalizar(nombre_completo).split()
    if not partes:
        return "", ""

    apellidos = []
    nombres = []
    for p in partes:
        letras = p.replace("-", "").replace(".", "")
        if letras.isalpha() and letras.isupper():
            apellidos.append(p)
        else:
            nombres.append(p)

    if not nombres and apellidos:
        # Todo mayúsculas: probablemente sea apellido completo
        return " ".join(apellidos), ""

    return " ".join(apellidos), " ".join(nombres)


def procesar_arbitro(row: dict, cache: dict) -> dict:
    """Procesa una fila del CSV y devuelve una fila mejorada."""
    nombre = normalizar(row.get("nombre", ""))
    apellido = normalizar(row.get("apellido", ""))
    pais = normalizar(row.get("pais", ""))
    puesto = normalizar(row.get("puesto", ""))
    fecha_nacimiento = normalizar(row.get("fecha_nacimiento", ""))

    # Si el nombre está vacío, intentamos buscar en Wikipedia para separar
    clave_busqueda = f"{nombre} {apellido}".strip() if nombre else apellido
    if clave_busqueda not in cache:
        cache[clave_busqueda] = buscar_pagina_wikipedia(nombre, apellido, pais)
        time.sleep(RETRASO_SEG)

    titulo = cache.get(clave_busqueda)
    if titulo:
        if clave_busqueda not in cache or cache[clave_busqueda] is None:
            cache[clave_busqueda] = titulo

        soup = obtener_html(titulo)
        time.sleep(RETRASO_SEG)

        if not fecha_nacimiento:
            fecha_nacimiento = extraer_fecha_del_infobox(soup)

        idiomas = extraer_idiomas(soup, pais)

        # Si no hay nombre y la página existe, intentamos recuperar nombre/apellido
        if not nombre:
            resumen = obtener_resumen(titulo)
            time.sleep(RETRASO_SEG)
            titulo_pagina = resumen.get("title", "")
            if titulo_pagina:
                # El título suele ser "Nombre Apellido"
                posible_apellido, posible_nombre = separar_nombre_apellido(titulo_pagina)
                if posible_nombre:
                    nombre = posible_nombre
                    if not apellido or posible_apellido:
                        apellido = posible_apellido
    else:
        idiomas = PAIS_A_LENGUA.get(pais, "")

    return {
        "nombre": capitalizar(nombre) if nombre else "",
        "apellido": capitalizar(apellido) if apellido else "",
        "fecha_nacimiento": fecha_nacimiento,
        "pais": pais,
        "puesto": puesto,
        "idiomas": idiomas,
    }


def main() -> int:
    global RETRASO_SEG

    parser = argparse.ArgumentParser(
        description="Completa árbitros FIFA con datos de Wikipedia."
    )
    parser.add_argument(
        "entrada",
        nargs="?",
        default="Archivos_Importacion/arbitros_fifa_pdf.csv",
        help="CSV base generado por el extractor del PDF.",
    )
    parser.add_argument(
        "salida",
        nargs="?",
        default="Archivos_Importacion/arbitros_fifa_completo.csv",
        help="CSV mejorado de salida.",
    )
    parser.add_argument(
        "--retraso",
        type=float,
        default=RETRASO_SEG,
        help="Segundos de espera entre requests a Wikipedia.",
    )
    args = parser.parse_args()

    RETRASO_SEG = args.retraso

    entrada = Path(args.entrada).expanduser().resolve()
    salida = Path(args.salida).expanduser().resolve()

    if not entrada.exists():
        print(f"No existe el archivo de entrada: {entrada}", file=sys.stderr)
        return 1

    filas: list[dict] = []
    with entrada.open("r", encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        filas = list(reader)

    cache_busqueda: dict[str, Optional[str]] = {}
    resultados: list[dict] = []
    con_fecha = 0
    con_idiomas = 0
    con_nombre_corregido = 0

    for i, fila in enumerate(filas, start=1):
        print(f"[{i}/{len(filas)}] Procesando {fila.get('apellido', '')}...", flush=True)
        mejorada = procesar_arbitro(fila, cache_busqueda)
        resultados.append(mejorada)
        if mejorada["fecha_nacimiento"]:
            con_fecha += 1
        if mejorada["idiomas"]:
            con_idiomas += 1
        if mejorada["nombre"] and not fila.get("nombre", "").strip():
            con_nombre_corregido += 1

    salida.parent.mkdir(parents=True, exist_ok=True)
    with salida.open("w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(
            f,
            fieldnames=["nombre", "apellido", "fecha_nacimiento", "pais", "puesto", "idiomas"],
        )
        writer.writeheader()
        writer.writerows(resultados)

    print(f"\nOK - CSV generado: {salida}")
    print(f"Total filas: {len(resultados)}")
    print(f"Con fecha de nacimiento: {con_fecha}")
    print(f"Con idiomas: {con_idiomas}")
    print(f"Nombre corregido (sin nombre original): {con_nombre_corregido}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
