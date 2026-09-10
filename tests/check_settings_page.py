#!/usr/bin/env python3
"""Dos errores estructurales de una pagina de settings de Plasma que no dan error.

1. Kirigami.FormData es una propiedad ADJUNTA que FormLayout lee solo de sus
   hijos DIRECTOS. Envolver los controles en un ColumnLayout no rompe nada
   visible: simplemente desaparece la columna de etiquetas entera.

2. KCM.SimpleKCM toma UN item de contenido. Un control declarado fuera del
   FormLayout no se dibuja nunca, y su `property alias cfg_x` sigue resolviendo,
   asi que tampoco hay aviso. El toggle de debug estuvo asi desde que se agrego.
"""
import re
import sys

fail = 0
for path in sys.argv[1:]:
    src = open(path).read()
    lines = src.splitlines()
    name = path.split("/contents/")[0].split("/")[-1]

    form = next((i for i, l in enumerate(lines) if "FormLayout {" in l), None)
    if form is None:
        print(f"   !! FAIL {name}: sin Kirigami.FormLayout")
        fail = 1
        continue

    # Donde TERMINA el formulario, contando llaves. Comparar solo contra donde
    # empieza deja pasar lo que este despues de su cierre, que es exactamente
    # donde estaba el toggle de debug: la comprobacion daba verde con el bug.
    depth, end = 0, len(lines) - 1
    for i in range(form, len(lines)):
        depth += lines[i].count("{") - lines[i].count("}")
        if depth == 0 and i > form:
            end = i
            break

    # 1. Nada que envuelva a los hijos del formulario.
    wrappers = [i + 1 for i, l in enumerate(lines[form:end], form)
                if re.search(r"\bColumnLayout\s*\{", l)]
    if wrappers:
        print(f"   !! FAIL {name}: ColumnLayout dentro del FormLayout "
              f"(linea {wrappers[0]}) - los hijos dejan de ser directos y "
              f"FormData.label se pierde")
        fail = 1

    # 2. Todo control aliaseado tiene que estar dentro del formulario.
    ids = {}
    for i, l in enumerate(lines):
        # `id:` puede venir al principio de la linea o inline tras un `{`/`;`,
        # que es como se declaran los controles de una fila. Buscarlo solo al
        # principio daba dos falsos positivos.
        for m in re.finditer(r"(?:^|[{;])\s*id:\s*([A-Za-z_][A-Za-z0-9_]*)", l):
            ids.setdefault(m.group(1), i)

    orphans = []
    for m in re.finditer(r"property alias cfg_[A-Za-z0-9_]+:\s*([A-Za-z_][A-Za-z0-9_]*)\.", src):
        target = m.group(1)
        at = ids.get(target)
        if at is None or not (form < at < end):
            orphans.append(target)
    if orphans:
        print(f"   !! FAIL {name}: controles fuera del FormLayout, nunca se "
              f"dibujan: {', '.join(sorted(set(orphans)))}")
        fail = 1

    if not wrappers and not orphans:
        n = len(re.findall(r"property (?:alias|string|int|bool) cfg_", src))
        print(f"   ok {name}: {n} controles, todos hijos directos del formulario")

sys.exit(fail)
