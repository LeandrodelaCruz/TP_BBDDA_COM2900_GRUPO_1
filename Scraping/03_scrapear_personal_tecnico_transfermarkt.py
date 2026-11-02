#!/usr/bin/env python3
"""
Universidad Nacional de La Matanza - Bases de Datos Aplicada - 2C 2026
Grupo 01: Caro, Nicolas; Clara, Lucas; De La Cruz, Leandro; Rodriguez, Elias.
Fecha: 2026-11-01

Recorre el indice de selecciones para obtener sus cuerpos tecnicos actuales.
Extrae exclusivamente Entrenador y Entrenador Asistente. No escribe en SQL.
El cargo Entrenador Interino se normaliza como Entrenador.
Conserva el nombre completo del origen para dbo.Personal_Tecnico.nombre_completo.
"""

from __future__ import annotations

import argparse
import csv
import re
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

import requests
from bs4 import BeautifulSoup

RAIZ = Path(__file__).resolve().parent.parent
ROLES = {
    "Entrenador": "Entrenador",
    "Entrenador Interino": "Entrenador",
    "Entrenador Asistente": "Entrenador Asistente",
}
CAMPOS = [
    "seleccion", "nombre_completo", "rol", "fecha_extraccion_utc",
]


def limpiar(texto: str) -> str:
    return " ".join(texto.split())


def descargar_pagina(url: str) -> str:
    print(f"Conectando: {url}", flush=True)
    respuesta = requests.get(
        url,
        headers={
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 (KHTML, like Gecko) "
                "Chrome/156.0.0.0 Safari/537.36"
            ),
            "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            "Accept-Language": "es-AR,es;q=0.9,en;q=0.8",
        },
        timeout=30,
    )
    print(f"HTTP: {respuesta.status_code}; bytes recibidos: {len(respuesta.content)}")
    print(f"URL final: {respuesta.url}")
    for nombre in ("Content-Type", "Content-Length", "Server", "Via", "X-Cache", "X-Amzn-Waf-Action"):
        if nombre in respuesta.headers:
            print(f"{nombre}: {respuesta.headers[nombre]}")
    respuesta.raise_for_status()
    if respuesta.status_code != 200 or not respuesta.content.strip():
        raise RuntimeError(
            "El sitio no entrego una pagina utilizable "
            f"(HTTP {respuesta.status_code}). Se omite esta seleccion."
        )
    tipo = respuesta.headers.get("Content-Type", "").lower()
    if "html" not in tipo:
        raise RuntimeError(f"Se esperaba HTML; Content-Type recibido: {tipo!r}.")
    return respuesta.text


def extraer(html: str, seleccion: str) -> list[dict[str, str]]:
    soup = BeautifulSoup(html, "html.parser")
    titulo = limpiar(soup.title.get_text()) if soup.title else "Sin titulo"
    print(f"Titulo: {titulo}")
    if not re.search(r"(?:cuerpo|equipo)\s+t[eé]cnico", soup.get_text(" ", strip=True), re.I):
        raise RuntimeError("No se encontro Cuerpo Tecnico: pagina inesperada o acceso restringido.")

    resultado = []
    vistos = set()
    fecha = datetime.now(timezone.utc).isoformat(timespec="seconds")
    for fila in soup.select("tr"):
        # Las tablas de nombre/foto pueden estar anidadas dentro de una fila.
        # La deduplicacion evita registrar dos veces el mismo perfil y rol.
        textos = {limpiar(t) for t in fila.stripped_strings}
        roles = {ROLES[texto] for texto in textos if texto in ROLES}
        if len(roles) != 1:
            continue
        enlaces = []
        for enlace in fila.select("a[href]"):
            match = re.search(r"/profil/trainer/(\d+)(?:[/?#]|$)", enlace["href"])
            nombre = limpiar(enlace.get_text(" ", strip=True))
            if match and nombre:
                enlaces.append((match.group(1), nombre))
        if not enlaces or len({e[0] for e in enlaces}) != 1:
            continue
        identidad, nombre = enlaces[0]
        rol = next(iter(roles))
        if (identidad, rol) in vistos:
            continue
        vistos.add((identidad, rol))
        resultado.append(dict(zip(CAMPOS, [
            seleccion, nombre, rol, fecha,
        ])))

    if not resultado:
        raise RuntimeError("No se detectaron entrenadores ni asistentes con los roles solicitados.")
    return resultado


def leer_indice(ruta: Path) -> list[dict[str, str]]:
    with ruta.open(encoding="utf-8-sig", newline="") as archivo:
        lector = csv.DictReader(archivo)
        if not {"seleccion", "url"}.issubset(lector.fieldnames or []):
            raise RuntimeError("El indice debe contener las columnas seleccion y url.")
        entradas = []
        selecciones = set()
        urls = set()
        for numero, fila in enumerate(lector, 2):
            seleccion = limpiar(fila.get("seleccion") or "")
            url = limpiar(fila.get("url") or "")
            if not seleccion or not re.fullmatch(
                r"https://www\.transfermarkt\.com\.ar/[^/?#]+/mitarbeiter/verein/\d+/?", url
            ):
                raise RuntimeError(f"Fila {numero} del indice: seleccion o URL invalida.")
            if seleccion.casefold() in selecciones or url.rstrip("/") in urls:
                raise RuntimeError(f"Fila {numero} del indice: seleccion o URL duplicada.")
            selecciones.add(seleccion.casefold())
            urls.add(url.rstrip("/"))
            entradas.append({"seleccion": seleccion, "url": url})
    if not entradas:
        raise RuntimeError("El indice esta vacio.")
    return entradas


def recorrer(entradas: list[dict[str, str]], pausa: float) -> tuple[list[dict[str, str]], list[dict[str, str]]]:
    filas = []
    errores = []
    for numero, entrada in enumerate(entradas, 1):
        if numero > 1:
            time.sleep(pausa)
        seleccion, url = entrada["seleccion"], entrada["url"]
        print(f"\n[{numero}/{len(entradas)}] {seleccion}", flush=True)
        try:
            registros = extraer(descargar_pagina(url), seleccion)
            filas.extend(registros)
            for fila in registros:
                print(f"  {fila['rol']}: {fila['nombre_completo']}")
            if not any(r["rol"] == "Entrenador" for r in registros):
                print("AVISO - No se detecto entrenador ni interino; se conservan los asistentes.")
            if not any(r["rol"] == "Entrenador Asistente" for r in registros):
                print("AVISO - La pagina no contiene asistentes detectables para esta seleccion.")
        except (requests.RequestException, RuntimeError) as error:
            errores.append({"seleccion": seleccion, "url": url, "mensaje": str(error)})
            print(f"ERROR - {seleccion}: {error}", file=sys.stderr)
    return filas, errores


def guardar_csv(salida: Path, campos: list[str], filas: list[dict[str, str]]) -> None:
    salida.parent.mkdir(parents=True, exist_ok=True)
    # Reemplazar el destino solo despues de escribir el archivo completo.
    temporal = salida.with_name(salida.name + ".tmp")
    try:
        with temporal.open("w", encoding="utf-8", newline="") as archivo:
            writer = csv.DictWriter(archivo, fieldnames=campos)
            writer.writeheader()
            writer.writerows(filas)
        temporal.replace(salida)
    finally:
        if temporal.exists():
            temporal.unlink()


def main() -> int:
    # La consola de Windows puede usar una pagina de codigos que no represente
    # nombres turcos, coreanos, etc. El CSV se mantiene siempre en UTF-8.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")
    parser = argparse.ArgumentParser(description="Scraping de entrenadores y asistentes desde un indice de selecciones")
    parser.add_argument("--indice", type=Path, default=RAIZ / "Scraping/indice_selecciones_transfermarkt.csv")
    parser.add_argument("--seleccion", help="Procesar solo esta seleccion del indice, por ejemplo USA")
    parser.add_argument("--salida", type=Path, default=RAIZ / "Archivos_Importacion/personal_tecnico.csv")
    parser.add_argument("--pausa", type=float, default=0.5, help="Segundos entre solicitudes (predeterminado: 0.5)")
    parser.add_argument("--solo-conexion", action="store_true", help="Valida descarga y extraccion sin escribir archivos")
    args = parser.parse_args()
    try:
        if not 0 <= args.pausa <= 60:
            raise RuntimeError("La pausa debe estar entre 0 y 60 segundos.")
        entradas = leer_indice(args.indice)
        if args.seleccion:
            entradas = [e for e in entradas if e["seleccion"].casefold() == args.seleccion.casefold()]
            if not entradas:
                raise RuntimeError(f"La seleccion {args.seleccion!r} no esta en el indice.")
        filas, errores = recorrer(entradas, args.pausa)
        print(f"\nSelecciones procesadas: {len(entradas)}")
        print(f"Selecciones exitosas: {len(entradas) - len(errores)}; con error: {len(errores)}")
        print(f"Registros detectados: {len(filas)}")
        if args.solo_conexion:
            print("No se escribieron archivos.")
            return 1 if errores else 0
        reporte = args.salida.with_name(args.salida.stem + "_errores.csv")
        if args.salida.resolve() == args.indice.resolve() or reporte.resolve() == args.indice.resolve():
            raise RuntimeError("La salida no puede reemplazar el indice.")
        guardar_csv(reporte, ["seleccion", "url", "mensaje"], errores)
        if not filas:
            raise RuntimeError("No se obtuvo ningun registro. Se conserva el CSV de datos anterior si existe.")
        guardar_csv(args.salida, CAMPOS, filas)
        print(f"Archivo generado: {args.salida}")
        print(f"Reporte de errores: {reporte}")
        if errores:
            print("Carga parcial: revisar el reporte de errores antes de importar.")
        return 1 if errores else 0
    except (requests.RequestException, RuntimeError, OSError) as error:
        print(f"ERROR - {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
