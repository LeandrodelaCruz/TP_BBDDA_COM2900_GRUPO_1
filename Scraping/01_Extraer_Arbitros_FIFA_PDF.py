#!/usr/bin/env python3
"""
Extrae los árbitros del PDF oficial de FIFA "MEDIA-FWC26-Arbitros.pdf" y genera
un CSV preparado para ser importado por SQL Server.

Uso:
  python3 01_Extraer_Arbitros_FIFA_PDF.py \
      Archivos_Importacion/MEDIA-FWC26-Arbitros.pdf \
      Archivos_Importacion/arbitros_fifa_pdf.csv

El script NO inserta datos en SQL Server. Solo extrae del PDF las columnas
que luego consume importacion.SP_Importar_Arbitro_PDF_CSV.

Fuente del PDF:
    FIFA World Cup 2026™ - List of appointed FIFA Match Officials.

Estructura del PDF:
    - Tabla 0: encabezado "Referees (52)"
    - Tabla 1: encabezado "Assistant Referees (88)"
    - Tabla 2: encabezado "Video Match Officials (30)"
    - Tabla 3: lista de referees (nombre, país)
    - Tabla 4: lista de assistant referees (nombre1, país1, nombre2, país2)
    - Tabla 5: lista de video match officials (nombre, país)

Columnas del CSV generado:
    nombre, apellido, fecha_nacimiento, pais, puesto

La fecha de nacimiento no figura en el PDF oficial. El campo se genera vacío
y el modelo dbo.Arbitro permite NULL en esa columna. Opcionalmente, el usuario
puede completar fechas manualmente o mediante una segunda fuente externa antes
de importar.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
from pathlib import Path
from typing import Optional

import pdfplumber

# Mapeo de códigos FIFA de país a nombre completo, según el dominio esperado
# por dbo.Arbitro.pais.
PAIS_MAP = {
    "QAT": "Qatar",
    "KSA": "Saudi Arabia",
    "JPN": "Japan",
    "SOM": "Somalia",
    "GAB": "Gabon",
    "SLV": "El Salvador",
    "MTN": "Mauritania",
    "PAR": "Paraguay",
    "CRC": "Costa Rica",
    "BRA": "Brazil",
    "USA": "United States",
    "NOR": "Norway",
    "AUS": "Australia",
    "ARG": "Argentina",
    "CAN": "Canada",
    "CHI": "Chile",
    "MEX": "Mexico",
    "ALG": "Algeria",
    "ESP": "Spain",
    "MAR": "Morocco",
    "NZL": "New Zealand",
    "ROU": "Romania",
    "FRA": "France",
    "CHN": "China",
    "JOR": "Jordan",
    "NED": "Netherlands",
    "POL": "Poland",
    "ITA": "Italy",
    "HON": "Honduras",
    "EGY": "Egypt",
    "JAM": "Jamaica",
    "SWE": "Sweden",
    "ENG": "England",
    "UAE": "United Arab Emirates",
    "PER": "Peru",
    "POR": "Portugal",
    "COL": "Colombia",
    "SUI": "Switzerland",
    "UZB": "Uzbekistan",
    "VEN": "Venezuela",
    "SVN": "Slovenia",
    "GER": "Germany",
    "CRO": "Croatia",
    "CMR": "Cameroon",
    "NCA": "Nicaragua",
    "BEL": "Belgium",
    "TRI": "Trinidad and Tobago",
    "ANG": "Angola",
    "RSA": "South Africa",
    "URU": "Uruguay",
}

# Partículas que se escriben en minúscula cuando no son la primera palabra.
PARTICULAS = {
    "AL", "EL", "DE", "DA", "DOS", "DEL", "VAN", "VON", "DER", "DI", "BIN",
    "BEN", "MAC", "MC", "O", "OU", "Y", "E", "LAS", "LOS",
}

# Árbitros cuyo nombre completo aparece todo en mayúsculas en el PDF o cuya
# separación automática no es correcta.
NOMBRE_CORRECCIONES = {
    "OMAR AL ALI": {"apellido": "Omar Al Ali", "nombre": ""},
    "RAMON ABATTI": {"apellido": "Ramon Abatti", "nombre": ""},
    "WILTON SAMPAIO": {"apellido": "Wilton Sampaio", "nombre": ""},
    "JERSON SANTOS": {"apellido": "Jerson Santos", "nombre": ""},
    "BRUNO BOSCHILIA": {"apellido": "Bruno Boschilia", "nombre": ""},
    "BRUNO PIRES": {"apellido": "Bruno Pires", "nombre": ""},
    "DANILO MANIS": {"apellido": "Danilo Manis", "nombre": ""},
    "RAFAEL ALVES": {"apellido": "Rafael Alves", "nombre": ""},
    "MOHAMMED OBAID KHADIM": {"apellido": "Mohammed Obaid Khadim", "nombre": ""},
}

PUESTO_ES = {
    "Referee": "Principal",
    "Assistant Referee": "Asistente",
    "Video Match Official": "VAR",
}


def limpiar(valor: Optional[str]) -> str:
    if valor is None:
        return ""
    return re.sub(r"\s+", " ", str(valor).replace("\n", " ").strip())


def normalizar_nombre(texto: str) -> str:
    return re.sub(r"\s+", " ", texto.strip())


def capitalizar_apellido(apellido: str) -> str:
    """
    Convierte un apellido a formato título respetando partículas.

    Reglas:
      - La primera palabra siempre inicia con mayúscula.
      - Las partículas (Al, De, Van, etc.) se escriben en minúscula cuando no
        son la primera palabra.
      - Se conservan los guiones de apellidos compuestos.
    """
    if not apellido:
        return apellido

    palabras = apellido.split()
    resultado: list[str] = []
    for i, palabra in enumerate(palabras):
        if "-" in palabra:
            partes = palabra.split("-")
            palabra = "-".join(
                p.capitalize() if idx == 0 or p.upper() not in PARTICULAS else p.lower()
                for idx, p in enumerate(partes)
            )
        elif i == 0 or palabra.upper() not in PARTICULAS:
            palabra = palabra.capitalize()
        else:
            palabra = palabra.lower()
        resultado.append(palabra)
    return " ".join(resultado)


def capitalizar_nombre(nombre: str) -> str:
    """Convierte un nombre a formato título respetando guiones."""
    if not nombre:
        return nombre
    return " ".join(
        "-".join(p.capitalize() for p in palabra.split("-"))
        for palabra in nombre.split()
    )


def separar_apellido_nombre(nombre_completo: str) -> tuple[str, str]:
    """
    Separa el nombre completo del PDF en apellido(s) y nombre(s).

    El PDF presenta los nombres como 'APELLIDO(S) NOMBRE(S)'. Las palabras en
    mayúsculas se consideran apellidos y el resto nombres. Casos especiales se
    resuelven mediante el diccionario NOMBRE_CORRECCIONES.
    """
    nombre_completo = normalizar_nombre(nombre_completo)

    if nombre_completo in NOMBRE_CORRECCIONES:
        correccion = NOMBRE_CORRECCIONES[nombre_completo]
        return correccion["apellido"], correccion["nombre"]

    palabras = nombre_completo.split()
    apellidos: list[str] = []
    nombres: list[str] = []

    for palabra in palabras:
        letras = palabra.replace("-", "").replace(".", "")
        if letras.isalpha() and letras.isupper():
            apellidos.append(palabra)
        else:
            nombres.append(palabra)

    return " ".join(apellidos), " ".join(nombres)


def extraer_arbitros_del_pdf(pdf_path: Path) -> list[dict[str, str]]:
    with pdfplumber.open(pdf_path) as pdf:
        page = pdf.pages[0]
        tables = page.extract_tables()

    if len(tables) < 6:
        raise ValueError(
            f"Se esperaban al menos 6 tablas en el PDF (encabezados + 3 listados) "
            f"y se encontraron {len(tables)}."
        )

    arbitros: list[dict[str, str]] = []

    # Tabla 3: Referees (52) - columnas: nombre, país
    for row in tables[3]:
        if row and len(row) >= 2 and row[0] and row[1]:
            arbitros.append(
                {
                    "nombre_completo": limpiar(row[0]),
                    "pais_codigo": limpiar(row[1]),
                    "puesto": "Referee",
                }
            )

    # Tabla 4: Assistant Referees (88) - columnas: nombre1, país1, nombre2, país2
    for row in tables[4]:
        if row and len(row) >= 4:
            for i in (0, 2):
                if row[i] and row[i + 1]:
                    arbitros.append(
                        {
                            "nombre_completo": limpiar(row[i]),
                            "pais_codigo": limpiar(row[i + 1]),
                            "puesto": "Assistant Referee",
                        }
                    )

    # Tabla 5: Video Match Officials (30) - columnas: nombre, país
    for row in tables[5]:
        if row and len(row) >= 2 and row[0] and row[1]:
            arbitros.append(
                {
                    "nombre_completo": limpiar(row[0]),
                    "pais_codigo": limpiar(row[1]),
                    "puesto": "Video Match Official",
                }
            )

    return arbitros


def construir_registros(arbitros: list[dict[str, str]]) -> list[dict[str, str]]:
    registros: list[dict[str, str]] = []

    for arb in arbitros:
        nombre_completo = arb["nombre_completo"]
        apellido_raw, nombre_raw = separar_apellido_nombre(nombre_completo)
        apellido = capitalizar_apellido(apellido_raw)
        nombre = capitalizar_nombre(nombre_raw)
        pais = PAIS_MAP.get(arb["pais_codigo"], arb["pais_codigo"])
        puesto = PUESTO_ES.get(arb["puesto"], arb["puesto"])

        registros.append(
            {
                "nombre": nombre,
                "apellido": apellido,
                "fecha_nacimiento": "",
                "pais": pais,
                "puesto": puesto,
            }
        )

    return registros


def escribir_csv(registros: list[dict[str, str]], salida: Path) -> None:
    salida.parent.mkdir(parents=True, exist_ok=True)
    with salida.open("w", encoding="utf-8", newline="") as archivo:
        writer = csv.DictWriter(
            archivo,
            fieldnames=["nombre", "apellido", "fecha_nacimiento", "pais", "puesto"],
        )
        writer.writeheader()
        writer.writerows(registros)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Extrae árbitros del PDF oficial FIFA 2026 a CSV."
    )
    parser.add_argument(
        "pdf",
        nargs="?",
        default="Archivos_Importacion/MEDIA-FWC26-Arbitros.pdf",
        help="Ruta del PDF de árbitros.",
    )
    parser.add_argument(
        "--salida",
        default="Archivos_Importacion/arbitros_fifa_pdf.csv",
        help="Ruta del CSV a generar.",
    )
    args = parser.parse_args()

    pdf_path = Path(args.pdf).expanduser().resolve()
    salida = Path(args.salida).expanduser().resolve()

    if not pdf_path.exists():
        print(f"No existe el PDF: {pdf_path}", file=sys.stderr)
        return 1

    arbitros = extraer_arbitros_del_pdf(pdf_path)

    esperados = {"Referee": 52, "Assistant Referee": 88, "Video Match Official": 30}
    conteo = {p: sum(1 for a in arbitros if a["puesto"] == p) for p in esperados}
    if conteo != esperados:
        print(
            f"ADVERTENCIA: se esperaban {esperados} y se extrajeron {conteo}.",
            file=sys.stderr,
        )

    registros = construir_registros(arbitros)
    escribir_csv(registros, salida)

    print(f"OK - Árbitros extraídos: {len(registros)}")
    print(f"OK - CSV generado: {salida}")
    print(
        f"OK - Referees: {conteo['Referee']}, "
        f"Assistant Referees: {conteo['Assistant Referee']}, "
        f"Video Match Officials: {conteo['Video Match Official']}"
    )
    print(
        "NOTA: la fecha de nacimiento no figura en el PDF. "
        "El campo se dejó vacío; dbo.Arbitro permite NULL."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
