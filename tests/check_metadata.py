#!/usr/bin/env python3
"""Los metadatos son lo primero que ve alguien en "Anadir widgets".

Tres cosas que no dan error en ninguna parte y se ven feas ahi:

1. Un Icon que apunta a un archivo que no esta. Plasma cae al icono generico
   (application-x-plasma) sin decir nada. Como resuelve la ruta esta verificado
   en plasmaappletitemmodel.cpp:63 -> si empieza con "/", pkg.filePath("", icon),
   que con fileType vacio arma <paquete>/contents + "/" + <icon>.
2. Un SVG que no parsea: mismo final silencioso.
3. Textos que no estan en ingles. Paso: la descripcion de netindicator quedo
   en espanol mientras la de pacman estaba en ingles, y se veian una al lado de
   la otra en el dialogo.

   La primera version de esta comprobacion buscaba TILDES, y no habria servido:
   la descripcion culpable era "Tu IP local y los perfiles VPN de NetworkManager,
   desde el panel", sin un solo acento. Ahora busca palabras funcionales del
   castellano, que son las que no se pueden evitar al escribir una frase.
"""
import json
import pathlib
import sys
import xml.etree.ElementTree as ET

# Palabras que aparecen en cualquier frase en castellano y en ninguna en ingles.
# Deliberadamente cortas y comunes; nada que pueda ser tambien una palabra
# inglesa ni un termino tecnico ("panel", "IP", "local" valen en los dos).
CASTELLANO = {
    "el", "la", "los", "las", "del", "desde", "tu", "tus", "su", "sus",
    "y", "con", "para", "por", "como", "esta", "este", "estos", "sin",
    "sobre", "entre", "cada", "muy", "ya", "porque", "cuando", "donde",
    "que", "una", "unos", "unas", "al", "lo", "mas", "pero", "si", "no",
}
TILDES = set("áéíóúÁÉÍÓÚñÑ¿¡")
fail = 0

for meta in sys.argv[1:]:
    p = pathlib.Path(meta)
    pkg = p.parent
    name = pkg.name
    kp = json.loads(p.read_text())["KPlugin"]

    icon = kp.get("Icon", "")
    if not icon:
        print(f"   !! FAIL {name}: sin Icon")
        fail = 1
    elif icon.startswith("/"):
        target = pkg / "contents" / icon.lstrip("/")
        if not target.exists():
            print(f"   !! FAIL {name}: Icon {icon} no existe en el paquete")
            fail = 1
        elif target.suffix == ".svg":
            try:
                ET.parse(target)
            except ET.ParseError as e:
                print(f"   !! FAIL {name}: {icon} no es SVG valido: {e}")
                fail = 1

    for key in ("Name", "Description"):
        val = kp.get(key, "")
        palabras = {w.strip(",.;:()").lower() for w in val.split()}
        intruso = sorted(CASTELLANO.intersection(palabras) | TILDES.intersection(val))
        if intruso:
            print(f"   !! FAIL {name}: {key} no esta en ingles ({', '.join(intruso)}): {val}")
            fail = 1

    if not fail:
        print(f"   ok {name}: icono propio en {icon}, textos en ingles")

sys.exit(fail)
