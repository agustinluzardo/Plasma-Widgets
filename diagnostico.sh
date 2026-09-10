#!/usr/bin/env bash
# Si algo sigue mal, corré esto y mandame la salida. Convierte "está todo mal"
# en datos concretos.
echo "=== versiones ==="
plasmashell --version 2>/dev/null; qmake6 -query QT_VERSION 2>/dev/null || qmake -query QT_VERSION 2>/dev/null
echo; echo "=== instalados ==="
ls -la ~/.local/share/plasma/plasmoids/ 2>/dev/null | grep agustinluzardo
echo; echo "=== errores QML desde la instalación actual ==="
# Sólo desde que se instalaron los plugins que están puestos ahora. `-b` muestra
# el arranque entero, así que un log de hace media hora - de una versión que ya
# no está - se lee como si fuera de ahora. La fecha del directorio instalado es
# el corte.
dest="$HOME/.local/share/plasma/plasmoids"
since=""
for d in "$dest"/com.agustinluzardo.*; do
    [ -d "$d" ] || continue
    t=$(date -r "$d" "+%Y-%m-%d %H:%M:%S" 2>/dev/null) || continue
    [ -z "$since" ] && since="$t"
    [ "$t" \< "$since" ] && since="$t"
done
if [ -n "$since" ]; then
    echo "  (instalados el $since)"
    log=$(journalctl --user -b --since "$since" --no-pager 2>/dev/null \
          | grep -iE "agustinluzardo|pacmanworkspaces|netindicator")
else
    log=$(journalctl --user -b --no-pager 2>/dev/null \
          | grep -iE "agustinluzardo|pacmanworkspaces|netindicator")
fi

# Los avisos `cfg_<algo>Default`, `cfg_length` y `cfg_expanding` los produce
# Plasma, no el plugin: AppletConfiguration recorre TODAS las claves del
# property map -incluidas las sintéticas `<nombre>Default`- e intenta ponerlas
# en la página. Los applets propios de KDE tiran exactamente los mismos: en todo
# plasma-workspace hay cero apariciones de `cfg_*Default`. Se cuentan y se
# apartan para que un error de verdad no quede enterrado entre cuarenta.
benign=$(printf '%s\n' "$log" | grep -cE "does not have a property called cfg_([A-Za-z0-9_]+Default|length|expanding)" )
real=$(printf '%s\n' "$log" | grep -vE "does not have a property called cfg_([A-Za-z0-9_]+Default|length|expanding)" | grep -v '^$')

[ "${benign:-0}" -gt 0 ] && echo "  $benign avisos de cfg_*Default (los tira Plasma en todos los widgets, incluidos los suyos)"
if [ -n "$real" ]; then
    echo "  --- lo que sí importa ---"
    printf '%s\n' "$real" | tail -40
else
    echo "  sin errores propios del plugin"
fi

echo; echo "=== widgets que hay en cada panel ==="
# Un applet en HiddenStatus sigue estando en la config aunque no se dibuje:
# el Pager se esconde solo cuando hay un unico escritorio virtual
# (applets/pager/pagermodel.cpp:284 -> Plasmoid.status = HiddenStatus ->
# containments/panel/AppletContainer.qml:24 no lo dibuja). Asi que si aqui NO
# aparece, no es que este escondido: no esta puesto.
cfg="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
if [ -f "$cfg" ]; then
    python3 - "$cfg" <<'PYEOF'
import re, sys
txt = open(sys.argv[1], encoding="utf-8", errors="replace").read()
cont, applets, section = {}, {}, None
for line in txt.splitlines():
    m = re.match(r"^\[Containments\]\[(\d+)\](?:\[Applets\]\[(\d+)\])?(.*)$", line)
    if m:
        section = (m.group(1), m.group(2), m.group(3))
        continue
    if section and line.startswith("plugin="):
        c, a, rest = section
        if rest:
            continue
        if a is None:
            cont[c] = line[7:]
        else:
            applets.setdefault(c, []).append((a, line[7:]))
    if line.startswith("["):
        if not re.match(r"^\[Containments\]", line):
            section = None
for c, plug in sorted(cont.items(), key=lambda kv: int(kv[0])):
    kind = "PANEL" if "panel" in plug else plug
    print(f"  contenedor {c} ({kind})")
    for a, ap in sorted(applets.get(c, []), key=lambda kv: int(kv[0])):
        mark = "  <-- el pager" if "pager" in ap else ""
        print(f"      {ap}{mark}")
    if not applets.get(c):
        print("      (sin widgets)")
PYEOF
else
    echo "  no encuentro $cfg"
fi
echo "  --- el paquete del pager esta instalado? ---"
find /usr/share/plasma/plasmoids /usr/lib*/qt6/plugins/plasma/applets -maxdepth 1 -iname "*pager*" 2>/dev/null | sed 's/^/      /' | head
kpackagetool6 --list --type Plasma/Applet 2>/dev/null | grep -i pager | sed 's/^/      /' | head

echo; echo "=== escritorios virtuales que ve KWin ==="
dbus-send --session --print-reply --dest=org.kde.KWin /VirtualDesktopManager \
  org.freedesktop.DBus.Properties.Get string:org.kde.KWin.VirtualDesktopManager string:desktops 2>&1 | head -20
echo; echo "=== el lookup publico: codigo HTTP de cada proveedor ==="
# Un cuerpo vacio con rc=0 y un 429 se ven igual hasta que se mira el codigo.
for u in https://ipinfo.io/json https://ifconfig.co/json https://ipwho.is/; do
    for f in 4 ""; do
        body=$(curl ${f:+-4} -sL --max-time 4 -w "\n#http=%{http_code}" "$u" 2>/dev/null); rc=$?
        code=$(printf %s "$body" | sed -n 's/^#http=//p' | tail -1)
        body=$(printf %s "$body" | sed '/^#http=/d')
        echo "$u  ${f:+-4}${f:+ }${f:-sin forzar}: rc=$rc http=${code:-?}  ${body:0:100}"
    done
done
echo; echo "=== el logo de la distro ==="
. /etc/os-release 2>/dev/null || true
echo "ID=$ID  LOGO=${LOGO:-<sin definir>}"
for n in "${LOGO:-}" "${ID:-}-logo" "${ID:-}linux-logo" "distributor-logo-${ID:-}" "${ID:-}"; do
    [ -n "$n" ] && [ "$n" != "-logo" ] && [ "$n" != "linux-logo" ] || continue
    hit=$(find /usr/share/icons /usr/share/pixmaps "$HOME/.local/share/icons" \
          \( -name "$n.png" -o -name "$n.svg" -o -name "$n.svgz" -o -name "$n.xpm" \) \
          -print -quit 2>/dev/null)
    echo "  $n -> ${hit:-no existe}"
done
echo; echo "=== nmcli responde? ==="
nmcli -t -f DEVICE,TYPE,STATE device status 2>&1 | head -5
