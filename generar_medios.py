#!/usr/bin/env python3
"""
Genera medios.json: la lista de todo lo que hay en la carpeta medios/.

La página web lee este archivo para saber qué fotos, audios y videos cargar,
así los archivos pueden tener cualquier nombre. Se ejecuta solo en Render
(Build Command) y en GitHub (Action), pero también puedes correrlo a mano:

    python3 generar_medios.py

Estructura que reconoce:

    medios/imagenes/            fotos (.jpg .jpeg .png .webp .gif)
    medios/audios/              voces y paisajes sonoros (.mp3 .wav .ogg .m4a)
    medios/videos/movimiento/   videos que aparecen al INCLINAR la maleta
    medios/videos/cercania/     videos que aparecen al ACERCAR la mano
    medios/videos/voz/          videos que aparecen con SONIDO
    medios/creditos.csv         (opcional) archivo,credito
"""
import csv
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

RAIZ = Path(__file__).resolve().parent
MEDIOS = RAIZ / "medios"
SALIDA = RAIZ / "medios.json"

EXT_IMG = {".jpg", ".jpeg", ".png", ".webp", ".gif"}
EXT_AUD = {".mp3", ".wav", ".ogg", ".m4a"}
EXT_VID = {".mp4", ".webm"}
CATEGORIAS = ["movimiento", "cercania", "voz"]
LIMITE_GITHUB_WEB_MB = 25    # subir por el navegador de GitHub
LIMITE_GITHUB_MB = 100       # límite absoluto de GitHub por archivo

avisos = []


def orden_natural(p: Path):
    return [int(t) if t.isdigit() else t.lower() for t in re.split(r"(\d+)", p.name)]


def credito_por_nombre(p: Path) -> str:
    """Si no hay crédito en el CSV, se arma uno legible a partir del nombre."""
    texto = re.sub(r"[-_]+", " ", p.stem).strip()
    return texto[:1].upper() + texto[1:] if texto else p.name


def leer_creditos() -> dict:
    ruta = MEDIOS / "creditos.csv"
    creditos = {}
    if not ruta.exists():
        return creditos
    with ruta.open(encoding="utf-8-sig", newline="") as f:
        for fila in csv.reader(f):
            if len(fila) < 2 or fila[0].strip().lower() == "archivo":
                continue
            clave = fila[0].strip().replace("\\", "/")
            creditos[clave] = fila[1].strip()
            creditos.setdefault(Path(clave).name, fila[1].strip())  # también por nombre solo
    return creditos


def listar(carpeta: Path, extensiones: set, tipo: str):
    if not carpeta.exists():
        return []
    archivos = []
    for p in sorted(carpeta.iterdir(), key=orden_natural):
        if p.is_dir() or p.name.startswith("."):
            continue
        ext = p.suffix.lower()
        rel = p.relative_to(MEDIOS).as_posix()
        if ext not in extensiones:
            if p.name.lower() not in {"creditos.csv", "leeme.txt", "readme.md"}:
                avisos.append(f"IGNORADO  {rel}: formato {ext or '(sin extensión)'} no válido para {tipo}. "
                              f"Usa {' '.join(sorted(extensiones))}")
            continue
        mb = p.stat().st_size / 1_048_576
        if mb > LIMITE_GITHUB_MB:
            avisos.append(f"MUY GRANDE {rel}: {mb:.0f} MB. GitHub no acepta archivos de más de {LIMITE_GITHUB_MB} MB.")
        elif mb > LIMITE_GITHUB_WEB_MB:
            avisos.append(f"PESADO    {rel}: {mb:.0f} MB. Por el navegador de GitHub solo se suben archivos de hasta "
                          f"{LIMITE_GITHUB_WEB_MB} MB; conviene comprimirlo.")
        if ext == ".webp" and tipo == "imagen":
            avisos.append(f"NOTA      {rel}: .webp funciona en la web pero no en Processing.")
        if ext in {".ogg", ".m4a"}:
            avisos.append(f"NOTA      {rel}: {ext} funciona en la web pero no en Processing (usa .mp3 o .wav).")
        archivos.append(p)
    return archivos


def main():
    if not MEDIOS.exists():
        print("No existe la carpeta medios/.")
        sys.exit(1)
    creditos = leer_creditos()

    def entrada(p: Path, extra=None):
        rel = p.relative_to(MEDIOS).as_posix()
        d = {"src": "medios/" + rel, "credito": creditos.get(rel) or creditos.get(p.name) or credito_por_nombre(p)}
        if extra:
            d.update(extra)
        return d

    imagenes = [entrada(p) for p in listar(MEDIOS / "imagenes", EXT_IMG, "imagen")]
    audios = [entrada(p) for p in listar(MEDIOS / "audios", EXT_AUD, "audio")]
    videos = []
    for cat in CATEGORIAS:
        videos += [entrada(p, {"categoria": cat}) for p in listar(MEDIOS / "videos" / cat, EXT_VID, "video")]
    # Videos sueltos en medios/videos/ (sin categoría): se reparten en orden.
    sueltos = listar(MEDIOS / "videos", EXT_VID, "video")
    for i, p in enumerate(sueltos):
        avisos.append(f"NOTA      {p.relative_to(MEDIOS).as_posix()}: está fuera de movimiento/, cercania/ o voz/; "
                      f"se usará como '{CATEGORIAS[i % 3]}'.")
        videos.append(entrada(p, {"categoria": CATEGORIAS[i % 3]}))

    datos = {
        "generado": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "imagenes": imagenes,
        "audios": audios,
        "videos": videos,
    }
    SALIDA.write_text(json.dumps(datos, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    print(f"medios.json actualizado: {len(imagenes)} imágenes · {len(audios)} audios · {len(videos)} videos")
    for cat in CATEGORIAS:
        n = sum(1 for v in videos if v["categoria"] == cat)
        print(f"  videos de {cat}: {n}" + ("   <- falta al menos uno" if n == 0 else ""))
    if not imagenes:
        avisos.append("FALTA     no hay imágenes en medios/imagenes/")
    if not audios:
        avisos.append("FALTA     no hay audios en medios/audios/")
    for a in avisos:
        print("  " + a)


if __name__ == "__main__":
    main()
