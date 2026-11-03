import csv
import re
import sys
import unicodedata
from pathlib import Path

import requests
from bs4 import BeautifulSoup


URL = "https://system1group.com/blog/worldcup2026tracker"

PUBLICIDADES = [
    {
        "anunciante": "Adidas",
        "pais": "Argentina",
        "idioma": "Español",
    },
    {
        "anunciante": "Guaraná Antarctica",
        "pais": "Brazil",
        "idioma": "Portugués",
    },
    {
        "anunciante": "KFC",
        "pais": "France",
        "idioma": "Francés",
    },
    {
        "anunciante": "Home Depot",
        "pais": "US",
        "idioma": "Inglés",
    },
    {
        "anunciante": "Magenta TV",
        "pais": "Germany",
        "idioma": "Alemán",
    },
    {
        "anunciante": "McDonald’s",
        "pais": "Spain",
        "idioma": "Español",
    },
    {
        "anunciante": "AB InBev",
        "pais": "UK",
        "idioma": "Inglés",
    },
    {
        "anunciante": "Bimbo",
        "pais": "Mexico",
        "idioma": "Español",
    },
]


HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (X11; Linux x86_64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) "
        "Chrome/156.0 Safari/537.36"
    )
}


# ============================================================
# FUNCIONES AUXILIARES
# ============================================================

def limpiar(texto):
    if texto is None:
        return ""

    return re.sub(r"\s+", " ", str(texto)).strip()


def normalizar(texto):
    """
    Se utiliza solamente para comparar textos.
    """

    texto = limpiar(texto)

    texto = (
        texto
        .replace("’", "'")
        .replace("‘", "'")
        .replace("“", '"')
        .replace("”", '"')
    )

    texto = unicodedata.normalize("NFKD", texto)

    texto = "".join(
        caracter
        for caracter in texto
        if not unicodedata.combining(caracter)
    )

    return texto.casefold()


# ============================================================
# DESCARGAR PAGINA
# ============================================================

def descargar_pagina():

    print("Descargando pagina de System1...")

    respuesta = requests.get(
        URL,
        headers=HEADERS,
        timeout=30
    )

    respuesta.raise_for_status()

    if len(respuesta.text) < 10000:
        raise RuntimeError(
            "La pagina descargada parece incompleta."
        )

    print(
        f"Pagina descargada correctamente "
        f"({len(respuesta.text)} caracteres)."
    )

    return respuesta.text


# ============================================================
# EXTRAER CAMPANIA
# ============================================================

def extraer_campania(
    texto_pagina,
    anunciante,
    pais
):
    """
    Busca estructuras como:

        Adidas | Argentina
        “Seguí soñando”
        Star Rating: 4.3 Stars

    No importa si el HTML internamente separa
    Adidas, | y Argentina en distintos elementos.
    """

    patron = re.compile(
        re.escape(anunciante)
        + r"\s*\|\s*"
        + re.escape(pais)
        + r"\s+(.*?)\s+"
        + r"(?:Star Rating|Spike Rating)\s*:",
        re.IGNORECASE
    )

    coincidencia = patron.search(
        texto_pagina
    )

    if coincidencia is None:
        raise ValueError(
            f"No se encontro: "
            f"{anunciante} | {pais}"
        )

    campania = limpiar(
        coincidencia.group(1)
    )

    # Quitar comillas tipograficas
    campania = campania.strip(
        '“”"‘’'
    )

    if not campania:
        raise ValueError(
            f"La campania de {anunciante} "
            f"esta vacia."
        )

    return campania


# ============================================================
# EXTRAER VIDEO
# ============================================================

def extraer_video(
    soup,
    campania
):
    """
    Recorre los enlaces de YouTube y mira el texto
    inmediatamente anterior.

    Si en ese contexto aparece el nombre de la campania,
    consideramos que ese video corresponde a ella.
    """

    campania_norm = normalizar(
        campania
    )

    enlaces = soup.find_all(
        "a",
        href=True
    )

    for enlace in enlaces:

        href = enlace.get(
            "href",
            ""
        )

        href_norm = href.casefold()

        if (
            "youtube.com" not in href_norm
            and "youtu.be" not in href_norm
        ):
            continue

        anteriores = enlace.find_all_previous(
            string=True,
            limit=20
        )

        contexto = " ".join(
            limpiar(texto)
            for texto in reversed(anteriores)
        )

        contexto_norm = normalizar(
            contexto
        )

        if campania_norm in contexto_norm:
            return href

    raise ValueError(
        f"No se encontro el video "
        f"de la campania '{campania}'."
    )


# ============================================================
# EXTRAER REGISTRO COMPLETO
# ============================================================

def extraer_registro(
    soup,
    texto_pagina,
    configuracion
):

    anunciante = configuracion[
        "anunciante"
    ]

    pais = configuracion[
        "pais"
    ]

    idioma = configuracion[
        "idioma"
    ]

    campania = extraer_campania(
        texto_pagina,
        anunciante,
        pais
    )

    video = extraer_video(
        soup,
        campania
    )

    pieza_nombre = (
        f"{campania} - Video"
    )

    return {
        "anunciante": anunciante,
        "pais": pais,
        "campania": campania,
        "pieza_nombre": pieza_nombre,
        "pieza_contenido": video,
        "pieza_idioma": idioma,
        "fuente": URL,
    }


# ============================================================
# VALIDACIONES
# ============================================================

def validar(registros):

    print()
    print("Validando registros...")

    if len(registros) != 8:
        raise RuntimeError(
            f"Se esperaban 8 registros "
            f"y se obtuvieron {len(registros)}."
        )

    campos = [
        "anunciante",
        "pais",
        "campania",
        "pieza_nombre",
        "pieza_contenido",
        "pieza_idioma",
        "fuente",
    ]

    for numero, registro in enumerate(
        registros,
        start=1
    ):

        for campo in campos:

            if not limpiar(
                registro.get(campo, "")
            ):
                raise RuntimeError(
                    f"Fila {numero}: "
                    f"campo '{campo}' vacio."
                )

    anunciantes = {
        normalizar(
            registro["anunciante"]
        )
        for registro in registros
    }

    campanias = {
        normalizar(
            registro["campania"]
        )
        for registro in registros
    }

    paises = {
        normalizar(
            registro["pais"]
        )
        for registro in registros
    }

    if len(anunciantes) != 8:
        raise RuntimeError(
            "Los anunciantes no son unicos."
        )

    if len(campanias) != 8:
        raise RuntimeError(
            "Las campanias no son unicas."
        )

    if len(paises) != 8:
        raise RuntimeError(
            "Los paises no son unicos."
        )

    if len(paises) < 6:
        raise RuntimeError(
            "No se cumple el requisito "
            "de al menos 6 paises."
        )

    print("Validacion correcta.")
    print(f"Anunciantes: {len(anunciantes)}")
    print(f"Campanias:   {len(campanias)}")
    print(f"Paises:      {len(paises)}")


# ============================================================
# GUARDAR CSV ATOMICAMENTE
# ============================================================

def guardar_csv(
    registros,
    salida
):

    salida.parent.mkdir(
        parents=True,
        exist_ok=True
    )

    temporal = Path(
        str(salida) + ".tmp"
    )

    columnas = [
        "anunciante",
        "pais",
        "campania",
        "pieza_nombre",
        "pieza_contenido",
        "pieza_idioma",
        "fuente",
    ]

    try:

        with temporal.open(
            "w",
            encoding="utf-16",
            newline=""
        ) as archivo:

            writer = csv.DictWriter(
                archivo,
                fieldnames=columnas
            )

            writer.writeheader()

            writer.writerows(
                registros
            )

        # Solo reemplaza el CSV definitivo
        # si todo termino correctamente.
        temporal.replace(
            salida
        )

    except Exception:

        if temporal.exists():
            temporal.unlink()

        raise


# ============================================================
# MAIN
# ============================================================

def main():

    print()
    print(
        "=============================================="
    )
    print(
        " SCRAPING PUBLICIDAD - MUNDIAL FIFA 2026"
    )
    print(
        " FUENTE: SYSTEM1"
    )
    print(
        "=============================================="
    )
    print()

    proyecto = (
        Path(__file__)
        .resolve()
        .parent
        .parent
    )

    if len(sys.argv) > 1:

        salida = Path(
            sys.argv[1]
        )

    else:

        salida = (
            proyecto
            / "Archivos_Importacion"
            / "publicidad_mundial_scraping.csv"
        )

    # --------------------------------------------------------
    # Descargar pagina
    # --------------------------------------------------------

    html = descargar_pagina()

    soup = BeautifulSoup(
        html,
        "html.parser"
    )

    # --------------------------------------------------------
    # Convertimos TODA la pagina a texto plano.
    #
    # Esto evita depender de la estructura interna del HTML.
    # --------------------------------------------------------

    texto_pagina = limpiar(
        soup.get_text(
            " ",
            strip=True
        )
    )

    registros = []

    # --------------------------------------------------------
    # Procesar las 8 publicidades
    # --------------------------------------------------------

    for numero, configuracion in enumerate(
        PUBLICIDADES,
        start=1
    ):

        anunciante = configuracion[
            "anunciante"
        ]

        pais = configuracion[
            "pais"
        ]

        print()
        print(
            f"[{numero}/8] "
            f"{anunciante} | {pais}"
        )

        registro = extraer_registro(
            soup,
            texto_pagina,
            configuracion
        )

        registros.append(
            registro
        )

        print(
            f"    Campania: "
            f"{registro['campania']}"
        )

        print(
            f"    Pieza:    "
            f"{registro['pieza_nombre']}"
        )

        print(
            f"    Video:    "
            f"{registro['pieza_contenido']}"
        )

        print("    OK")

    # --------------------------------------------------------
    # Validar TODOS antes de escribir
    # --------------------------------------------------------

    validar(
        registros
    )

    # --------------------------------------------------------
    # Guardar CSV
    # --------------------------------------------------------

    guardar_csv(
        registros,
        salida
    )

    print()
    print(
        "=============================================="
    )
    print(
        " SCRAPING FINALIZADO CORRECTAMENTE"
    )
    print(
        "=============================================="
    )
    print(
        "Registros:             8"
    )
    print(
        "Anunciantes:           8"
    )
    print(
        "Campanias:             8"
    )
    print(
        "Piezas publicitarias:  8"
    )
    print(
        "Paises diferentes:     8"
    )
    print()
    print(
        f"Archivo: {salida}"
    )
    print(
        "=============================================="
    )


if __name__ == "__main__":
    main()
