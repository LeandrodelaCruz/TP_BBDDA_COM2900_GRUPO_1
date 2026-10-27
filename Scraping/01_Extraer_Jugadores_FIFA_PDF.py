#!/usr/bin/env python3
"""
Extrae los jugadores del PDF oficial de convocatorias FIFA 2026 y genera
un CSV preparado para ser importado por SQL Server.

Uso:
  python3 Extraccion_PDF/01_Extraer_Jugadores_FIFA_PDF.py \
      SquadLists-Spanish.pdf \
      Archivos_Importacion/jugadores_fifa_pdf.csv

El script NO inserta datos en SQL Server. Solo extrae del PDF las columnas
que luego consume importacion.SP_Importar_Jugador_PDF_CSV.
"""

from __future__ import annotations

import csv
import re
import sys
from pathlib import Path

import pdfplumber

# El PDF usa "Korea Republic", mientras que dbo.Seleccion fue cargada desde
# teams.csv con "South Korea". Se normaliza solo esa diferencia de nombre.
SELECCION_MAP = {
    "Korea Republic": "South Korea",
}

# Algunos glifos/ligaduras del PDF no se extraen correctamente y aparecen
# como \x00. Estas correcciones son explícitas para no modificar datos de forma
# silenciosa ni aplicar heurísticas generales.
TEXT_FIXES = {
    "Ra\x00k": "Rafik",
    "Al\x00e": "Alfie",
    "Sou\x00ane": "Soufiane",
    "Mfanu\x00kile": "Mfanufikile",
    "SL Ben\x00ca": "SL Benfica",
    "CA Vélez Sars\x00eld": "CA Vélez Sarsfield",
    "AE Ki\x00sia FC": "AE Kifisia FC",
    "She\x00eld United FC": "Sheffield United FC",
}

# Excepción puntual detectada en la extracción tabular del PDF:
# en la página de Sudáfrica, el club de Jayden Adams (dorsal 23)
# queda vacío aunque visualmente figura como Mamelodi Sundowns FC (RSA).
MISSING_FIELD_FIXES = {
    ("RSA", "23", "club_origen"): "Mamelodi Sundowns FC (RSA)",
}


def limpiar(valor: object | None) -> str:
    if valor is None:
        return ""
    texto = str(valor).replace("\n", " ").strip()
    for original, corregido in TEXT_FIXES.items():
        texto = texto.replace(original, corregido)
    texto = re.sub(r"\s+", " ", texto).strip()
    return texto


def obtener_seleccion(page) -> tuple[str, str]:
    texto = page.extract_text() or ""
    for linea in texto.splitlines():
        linea = linea.strip()
        match = re.fullmatch(r"(.+?)\s+\(([A-Z]{3})\)", linea)
        if match:
            seleccion = limpiar(match.group(1))
            codigo = match.group(2)
            return SELECCION_MAP.get(seleccion, seleccion), codigo
    raise ValueError("No se pudo identificar la selección de la página.")


def obtener_tabla_jugadores(page):
    for tabla in page.extract_tables():
        if not tabla or not tabla[0]:
            continue
        encabezado = " | ".join(limpiar(celda) for celda in tabla[0] if celda)
        if "NOMBRE(S)" in encabezado and "APELLIDO(S)" in encabezado and "CLUB" in encabezado:
            return tabla
    raise ValueError("No se encontró la tabla de jugadores de la página.")


def extraer(pdf_path: Path) -> list[dict[str, str]]:
    jugadores: list[dict[str, str]] = []

    with pdfplumber.open(pdf_path) as pdf:
        for numero_pagina, page in enumerate(pdf.pages, start=1):
            seleccion, codigo_fifa = obtener_seleccion(page)
            tabla = obtener_tabla_jugadores(page)
            encabezado = [limpiar(celda) for celda in tabla[0]]

            try:
                idx_dorsal = encabezado.index("#")
                idx_posicion = encabezado.index("POS")
                idx_nombre = encabezado.index("NOMBRE(S)")
                idx_apellido = encabezado.index("APELLIDO(S)")
                idx_fecha = encabezado.index("FN")
                idx_club = encabezado.index("CLUB")
            except ValueError as exc:
                raise ValueError(
                    f"Página {numero_pagina}: no se pudieron ubicar todas las columnas requeridas."
                ) from exc

            cantidad_pagina = 0
            for fila in tabla:
                if not fila or not fila[0]:
                    continue

                if len(fila) <= max(idx_dorsal, idx_posicion, idx_nombre, idx_apellido, idx_fecha, idx_club):
                    raise ValueError(
                        f"Página {numero_pagina}: estructura de fila inesperada: {fila!r}"
                    )

                dorsal = limpiar(fila[idx_dorsal])
                if not re.fullmatch(r"\d{1,2}", dorsal):
                    continue

                posicion_codigo = limpiar(fila[idx_posicion])
                nombre = limpiar(fila[idx_nombre])
                apellido = limpiar(fila[idx_apellido])
                fecha_nacimiento = limpiar(fila[idx_fecha])
                club_origen = limpiar(fila[idx_club])

                if not club_origen:
                    club_origen = MISSING_FIELD_FIXES.get(
                        (codigo_fifa, dorsal, "club_origen"), ""
                    )

                campos_obligatorios = {
                    "dorsal": dorsal,
                    "posicion_codigo": posicion_codigo,
                    "nombre": nombre,
                    "apellido": apellido,
                    "fecha_nacimiento": fecha_nacimiento,
                    "club_origen": club_origen,
                }
                vacios = [k for k, v in campos_obligatorios.items() if not v]
                if vacios:
                    raise ValueError(
                        f"Página {numero_pagina}, selección {seleccion}: "
                        f"campos vacíos en dorsal {dorsal}: {', '.join(vacios)}"
                    )

                jugadores.append(
                    {
                        "seleccion": seleccion,
                        "codigo_fifa": codigo_fifa,
                        "dorsal": dorsal,
                        "posicion_codigo": posicion_codigo,
                        "nombre": nombre,
                        "apellido": apellido,
                        "fecha_nacimiento": fecha_nacimiento,
                        "club_origen": club_origen,
                    }
                )
                cantidad_pagina += 1

            if cantidad_pagina != 26:
                raise ValueError(
                    f"Página {numero_pagina} ({seleccion}): se esperaban 26 jugadores "
                    f"y se extrajeron {cantidad_pagina}."
                )

    if len(jugadores) != 48 * 26:
        raise ValueError(
            f"Se esperaban 1248 jugadores en total y se extrajeron {len(jugadores)}."
        )

    return jugadores


def main() -> int:
    if len(sys.argv) not in (2, 3):
        print(
            "Uso: python3 01_Extraer_Jugadores_FIFA_PDF.py "
            "<SquadLists-Spanish.pdf> [salida.csv]",
            file=sys.stderr,
        )
        return 2

    pdf_path = Path(sys.argv[1]).expanduser().resolve()
    salida = (
        Path(sys.argv[2]).expanduser().resolve()
        if len(sys.argv) == 3
        else Path("Archivos_Importacion/jugadores_fifa_pdf.csv").resolve()
    )

    if not pdf_path.exists():
        print(f"No existe el PDF: {pdf_path}", file=sys.stderr)
        return 1

    salida.parent.mkdir(parents=True, exist_ok=True)
    jugadores = extraer(pdf_path)

    with salida.open("w", encoding="utf-8", newline="") as archivo:
        writer = csv.DictWriter(
            archivo,
            fieldnames=[
                "seleccion",
                "codigo_fifa",
                "dorsal",
                "posicion_codigo",
                "nombre",
                "apellido",
                "fecha_nacimiento",
                "club_origen",
            ],
        )
        writer.writeheader()
        writer.writerows(jugadores)

    selecciones = len({j["codigo_fifa"] for j in jugadores})
    print(f"OK - Selecciones: {selecciones}")
    print(f"OK - Jugadores extraídos: {len(jugadores)}")
    print(f"OK - CSV generado: {salida}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
