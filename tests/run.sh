#!/usr/bin/env bash
# Suite de la reescritura nativa. Lo que la distingue de la anterior: RENDERIZA
# los widgets y CUENTA PIXELES. Los tests del port preguntaban "¿construye?" y
# "¿reporta un tamaño?" - las dos daban que sí mientras el widget era invisible.
set -uo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; root="$(dirname "$here")"
[ -x "$here/render" ] || g++ -fPIC -O1 -o "$here/render" "$here/render.cpp" \
    $(pkg-config --cflags --libs Qt6Quick Qt6Qml Qt6Gui Qt6Core) || exit 1
export QT_QPA_PLATFORM=offscreen QT_QUICK_BACKEND=software QML2_IMPORT_PATH="$here" QML_DISABLE_DISK_CACHE=1
failed=0

# Un suelo de checks por suite. Una suite que no asegura nada pasa igual, y eso
# ya paso aqui: dos suites verdes que no afirmaban nada.
floor_for() {
    case "$1" in
        PixelTest) echo 3 ;;
        GhostZoom) echo 4 ;;
        NetPixelTest) echo 4 ;;
        AppletTest) echo 11 ;;
        BadgeTest) echo 9 ;;
        PopupTest) echo 4 ;;
        ClickTest) echo 10 ;;
        *) echo 1 ;;
    esac
}

echo "==> se dibujan de verdad"
for c in PixelTest:/tmp/t-pac.png:--pacman GhostZoom:/tmp/t-ghost.png:--pacman NetPixelTest:/tmp/t-net.png: PopupTest:/tmp/t-popup.png:; do
    f="${c%%:*}"; rest="${c#*:}"; png="${rest%%:*}"; flag="${rest#*:}"
    out="$(cd "$here" && ./render "$f.qml" "$png" 1800 2>&1 | grep -v XDG_RUNTIME_DIR)"
    echo "$out" | sed 's/^qml: //' | grep -E "PASS|FAIL|^   " | sed 's/^/   /'
    echo "$out" | grep -qE "FAIL|QML ERROR|Cannot |unavailable|is not a type|Unexpected|Binding loop" && { echo "   !! $f"; failed=1; }
    n="$(echo "$out" | grep -c "PASS ")"; min="$(floor_for "$f")"
    [ "$n" -lt "$min" ] && { echo "   !! $f solo afirmo $n checks (minimo $min)"; failed=1; }
    python3 "$here/pixels.py" "$png" $flag | sed 's/^/   /' || failed=1
done

echo; echo "==> Plasma elige la representacion compacta, y un clic hace algo"
# El bug que dejo a Pac-Man invisible siete rondas seguidas, y que ningun test
# de pixeles podia ver porque todos instancian la tira a mano.
# appletShouldBeExpanded() empieza con `if (!fullRepresentation) return true;`,
# ANTES de mirar preferredRepresentation: un applet que solo declara
# compactRepresentation se considera expandido, pide una representacion completa
# que no existe, recibe nullptr y no dibuja nada. Sin error y sin aviso.
for f in AppletTest BadgeTest ClickTest; do
    out="$(cd "$here" && ./render "$f.qml" "/tmp/t-${f}.png" 1800 2>&1 | grep -v XDG_RUNTIME_DIR)"
    echo "$out" | sed 's/^qml: //' | grep -E "PASS|FAIL|^   " | sed 's/^/   /'
    echo "$out" | grep -qE "FAIL|QML ERROR|Cannot |unavailable|is not a type|Unexpected|Binding loop" && { echo "   !! $f"; failed=1; }
    n="$(echo "$out" | grep -c "PASS ")"; min="$(floor_for "$f")"
    [ "$n" -lt "$min" ] && { echo "   !! $f solo afirmo $n checks (minimo $min)"; failed=1; }
done

echo; echo "==> los sprites usan el renderer de DMS"
# El fantasma corrio un tiempo con GeometryRenderer, que triangula las curvas:
# la cupula es un arco de 180 grados y los cuatro pies son PathQuad, asi que
# salian facetados. Es el fantasma que se veia mal. Qt 6.4 (el del contenedor)
# no tiene preferredRendererType, asi que esto solo se puede comprobar estatico.
strip="$root/pacman/contents/ui/PacmanStrip.qml"
n_curve="$(grep -c "preferredRendererType.*Shape.CurveRenderer" "$strip")"
n_other="$(grep "preferredRendererType" "$strip" | grep -vc "Shape.CurveRenderer" || true)"
if [ "$n_curve" -ne 2 ] || [ "$n_other" -ne 0 ]; then
    echo "   !! FAIL Pac-Man y fantasma tienen que pedir CurveRenderer los dos (curve=$n_curve otros=$n_other)"; failed=1
else
    echo "   ok las dos formas piden CurveRenderer"
fi

echo; echo "==> el probe de nmcli es shell válido, y los perfiles VPN llegan"
# El script se unía con "; ", lo que produce `do;`, `case ... in vpn|wireguard);`
# y `;;;`. `sh -c` analiza todo antes de ejecutar una línea, así que el probe
# entero moría en silencio y la lista de VPN salía vacía con tres cargadas.
# Se vuelca el script REAL desde el QML, se comprueba su sintaxis, se corre
# contra un nmcli de mentira y se parsea el resultado.
out="$(cd "$here" && ./render ProbeTest.qml /tmp/t-probe.png 700 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | awk '/^### PROBE-BEGIN/{f=1;next} /^### PROBE-END/{f=0} f' > /tmp/probe-gen.sh
if [ ! -s /tmp/probe-gen.sh ]; then
    echo "   !! FAIL no se pudo volcar probeScript"; failed=1
elif ! bash -n /tmp/probe-gen.sh 2>/tmp/probe-err.txt; then
    echo "   !! FAIL el probe no es shell válido: $(head -1 /tmp/probe-err.txt)"; failed=1
else
    echo "   ok el probe pasa bash -n ($(wc -l < /tmp/probe-gen.sh) líneas)"
    PATH="$here/fakebin:$PATH" bash /tmp/probe-gen.sh > /tmp/probe-out.txt 2>/dev/null
    vout="$(cd "$here" && QML_XHR_ALLOW_FILE_READ=1 ./render VpnTest.qml /tmp/t-vpn.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
    echo "$vout" | grep -E "PASS|FAIL" | sed 's/^/   /'
    echo "$vout" | grep -qE "FAIL|QML ERROR|Binding loop" && { echo "   !! VpnTest"; failed=1; }
    n="$(echo "$vout" | grep -c "PASS ")"
    [ "$n" -lt 13 ] && { echo "   !! VpnTest solo afirmo $n checks (minimo 13)"; failed=1; }

    # Y que releer no cuente como cambiar: la señal realimenta un refreshAll(),
    # así que emitirla en cada lectura deja el widget releyéndose en bucle.
    rout="$(cd "$here" && QML_XHR_ALLOW_FILE_READ=1 ./render RefreshTest.qml /tmp/t-refresh.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
    echo "$rout" | grep -E "PASS|FAIL" | sed 's/^/   /'
    echo "$rout" | grep -qE "FAIL|QML ERROR|Binding loop" && { echo "   !! RefreshTest"; failed=1; }
    n="$(echo "$rout" | grep -c "PASS ")"
    [ "$n" -lt 8 ] && { echo "   !! RefreshTest solo afirmo $n checks (minimo 8)"; failed=1; }
fi

echo; echo "==> el logo de la distro y el lookup público"
# El logo se construía como `<ID>-logo`. En Arch el ID es "arch" y el icono se
# llama "archlinux-logo", así que se dibujaba el cuadrado blanco de icono
# ausente. Ahora se prueba LOGO= de os-release y las variantes del ID, y cada
# candidato se busca en disco antes de aceptarlo.
lout="$(cd "$here" && ./render LogoTest.qml /tmp/t-logo.png 700 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$lout" | awk '/^### LOGO-BEGIN/{f=1;next} /^### LOGO-END/{f=0} f' > /tmp/logo-gen.sh
echo "$lout" | awk '/^### PUB-BEGIN/{f=1;next} /^### PUB-END/{f=0} f' > /tmp/pub-gen.sh
lfail=0
for f in /tmp/logo-gen.sh /tmp/pub-gen.sh; do
    bash -n "$f" 2>/dev/null || { echo "   !! FAIL $f no es shell válido"; failed=1; lfail=1; }
done

if [ "$lfail" -eq 0 ]; then
    sim=/tmp/archsim; rm -rf "$sim"; mkdir -p "$sim/.local/share/icons"
    printf 'ID=arch\nPRETTY_NAME="Arch Linux"\n' > "$sim/os-release"
    got="$(HOME=$sim NETINDICATOR_OSRELEASE=$sim/os-release sh /tmp/logo-gen.sh)"
    [ -z "$got" ] && echo "   ok arch sin el icono instalado: vacío, no un cuadrado" \
                  || { echo "   !! FAIL arch sin icono devolvió '$got'"; failed=1; }
    touch "$sim/.local/share/icons/archlinux-logo.svg"
    got="$(HOME=$sim NETINDICATOR_OSRELEASE=$sim/os-release sh /tmp/logo-gen.sh)"
    [ "$got" = "archlinux-logo" ] && echo "   ok arch con el icono: archlinux-logo" \
                                  || { echo "   !! FAIL arch con icono devolvió '$got'"; failed=1; }
    printf 'ID=arch\nLOGO=archlinux\n' > "$sim/os-release"
    touch "$sim/.local/share/icons/archlinux.png"
    got="$(HOME=$sim NETINDICATOR_OSRELEASE=$sim/os-release sh /tmp/logo-gen.sh)"
    [ "$got" = "archlinux" ] && echo "   ok LOGO= de os-release manda: archlinux" \
                             || { echo "   !! FAIL con LOGO= devolvió '$got'"; failed=1; }

    for c in ok v6only ratelimited anidado timeout html alldown; do
        FAKE_CURL_CASE=$c PATH="$here/fakebin:$PATH" sh /tmp/pub-gen.sh > "/tmp/pub-$c.txt" 2>/dev/null
    done
    pout="$(cd "$here" && QML_XHR_ALLOW_FILE_READ=1 ./render PublicTest.qml /tmp/t-pub.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
    echo "$pout" | grep -E "PASS|FAIL" | sed 's/^/   /'
    echo "$pout" | grep -qE "FAIL|QML ERROR|Binding loop" && { echo "   !! PublicTest"; failed=1; }
    n="$(echo "$pout" | grep -c "PASS ")"
    [ "$n" -lt 25 ] && { echo "   !! PublicTest solo afirmo $n checks (minimo 25)"; failed=1; }
fi

echo; echo "==> la cola de comandos no retiene callbacks ni churnea claves"
# Dos cosas en un solo sitio. El motor ejecutable deduplica por nombre de
# source: dos comandos idénticos en vuelo son UNA respuesta, no dos, así que
# contestar a uno solo dejaba al resto huérfano para toda la sesión. Y borrar
# claves de un objeto JS guardado en una propiedad `var` a repetición revienta
# el motor - Qt 6.4 se va a SIGSEGV en QV4::Object::insertMember tras unos
# cientos de ciclos. Se vacía la cola en sitio y la clave se queda.
out="$(cd "$here" && ./render LeakTest.qml /tmp/t-leak.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
rc=$?
echo "$out" | grep -E "PASS|FAIL" | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Binding loop" && { echo "   !! LeakTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 8 ] && { echo "   !! LeakTest solo afirmo $n checks (minimo 8) - revisa si el proceso murio"; failed=1; }

echo; echo "==> ningún comando de shell se arma con JSON.stringify"
# JSON.stringify produce comillas DOBLES, y dentro de comillas dobles el shell
# sigue interpolando $, ` y \. El destino del ping es un campo de texto libre en
# la página de settings, así que un valor como x$(...) se ejecutaba. Sh.quote usa
# comillas simples, donde no se interpola nada.
bad="$(grep -rn 'JSON.stringify' --include=*.qml "$root/pacman" "$root/netindicator" \
       | grep -E '"sh", "-c"|ping |curl |nmcli |printf |dbus-send|Script:' || true)"
if [ -n "$bad" ]; then echo "   !! FAIL comando de shell citado con JSON.stringify: $bad"; failed=1
else echo "   ok todos usan Sh.quote o un argv sin shell"; fi

# Y comprobado de verdad: se vuelca el comando del ping con una carga util
# dentro y se ejecuta.
lout="$(cd "$here" && ./render LogoTest.qml /tmp/t-logo.png 700 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$lout" | awk '/^### PING-BEGIN/{f=1;next} /^### PING-END/{f=0} f' > /tmp/ping-gen.sh
rm -f /tmp/PWNED-subst /tmp/PWNED-tick
if [ -s /tmp/ping-gen.sh ]; then
    sh /tmp/ping-gen.sh >/dev/null 2>&1
    if [ -e /tmp/PWNED-subst ] || [ -e /tmp/PWNED-tick ]; then
        echo "   !! FAIL el destino del ping se ejecutó como comando"; failed=1
        rm -f /tmp/PWNED-subst /tmp/PWNED-tick
    else
        echo "   ok un destino de ping con \$(...) y \`...\` no se ejecuta"
    fi
else
    echo "   !! FAIL no se pudo volcar pingScript"; failed=1
fi

echo; echo "==> los dos applets declaran ambas representaciones"
for p in netindicator pacman; do
    m="$root/$p/contents/ui/main.qml"
    if grep -q "compactRepresentation:" "$m" && ! grep -q "fullRepresentation:" "$m"; then
        echo "   !! FAIL $p: solo compactRepresentation - Plasma no dibujara nada"; failed=1
    else
        echo "   ok $p"
    fi
done

echo; echo "==> un panel vertical"
# Los dos originales de DMS declaran un verticalBarPill y el port no se llevó
# ninguno: la tira salía horizontal, recortada al grosor de la barra. La
# auditoría de paridad no lo vio porque contaba claves de settings, no
# capacidades.
out="$(cd "$here" && ./render VerticalTest.qml /tmp/t-vertical.png 1200 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | grep -E "PASS|FAIL|^   " | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Cannot |Binding loop" && { echo "   !! VerticalTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 12 ] && { echo "   !! VerticalTest solo afirmo $n checks (minimo 12)"; failed=1; }
python3 "$here/pixels.py" /tmp/t-vertical.png --pacman | sed 's/^/   /' || failed=1

echo; echo "==> perMonitor hace algo"
# Era un ajuste muerto: estaba en el esquema, en la página y en pluginData, y
# nadie lo leía. El comentario que lo justificaba decía que Plasma no tiene
# escritorios por monitor - es falso: son globales, pero cuál está actual puede
# diferir por salida, y el Pager de KDE se apoya justo en eso
# (plasma-desktop/applets/pager/pagermodel.cpp:363).
out="$(cd "$here" && ./render PerMonitorTest.qml /tmp/t-permonitor.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | grep -E "PASS|FAIL" | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Cannot |Binding loop" && { echo "   !! PerMonitorTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 9 ] && { echo "   !! PerMonitorTest solo afirmo $n checks (minimo 9)"; failed=1; }

echo; echo "==> el fondo del slot y los rieles"
# El port no los tenía: se agregaron en la versión de DMS después de portearlo.
# El conteo de píxeles es DEL COLOR del corredor, no de píxeles pintados: con
# los rieles ocultos las 19 afirmaciones de propiedades pasaban igual.
out="$(cd "$here" && ./render BackgroundTest.qml /tmp/t-bg.png 1200 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | grep -E "PASS|FAIL|^   " | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Cannot |unavailable|is not a type|Binding loop" && { echo "   !! BackgroundTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 19 ] && { echo "   !! BackgroundTest solo afirmo $n checks (minimo 19)"; failed=1; }
python3 "$here/pixels.py" /tmp/t-bg.png --pacman --color FF8800 20 | sed 's/^/   /' || failed=1

echo; echo "==> el flujo de VPN no deja el panel congelado"
# La zona con más forma de trampa y sin un solo test hasta ahora: vpnIsBusy deja
# todos los botones grises y sólo se baja dentro de un refresh. Si ese refresh no
# llega -la VPN tarda, la salida viene vacía, el proceso no contesta- el panel
# queda congelado, que es lo que pasó en la versión de DMS. Cubre conectar,
# fallar, el rescate del flag colgado, las dos gracias, y el botón del popout.
out="$(cd "$here" && ./render VpnFlowTest.qml /tmp/t-vpnflow.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | grep -E "PASS|FAIL" | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Cannot |Binding loop" && { echo "   !! VpnFlowTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 18 ] && { echo "   !! VpnFlowTest solo afirmo $n checks (minimo 18)"; failed=1; }

echo; echo "==> el botón del medio hace algo, siempre"
# La alternancia LAN/túnel está detrás del ajuste "Swap on middle click", que no
# es el de fábrica. Y con ese ajuste puesto pero sin ningún túnel llevando
# tráfico, el gesto invertía un booleano que displayLocalIp ignora: no alternaba
# ni refrescaba, no hacía nada.
out="$(cd "$here" && ./render ToggleTest.qml /tmp/t-toggle.png 900 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | grep -E "PASS|FAIL" | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Binding loop" && { echo "   !! ToggleTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 12 ] && { echo "   !! ToggleTest solo afirmo $n checks (minimo 12)"; failed=1; }

echo; echo "==> cambiar de escritorios no colapsa el ancho"
# Guarda, no arreglo: el panel hace findPositive(applet.Layout.minimumWidth,
# availHeight), así que un hint que llegue en 0 se dibuja como un CUADRADO del
# alto de la barra. Cambiar el número de escritorios regenera el Repeater
# entero, que es cuando un Row podría reportar 0 por un frame. Hoy no pasa;
# esto es para que siga sin pasar.
out="$(cd "$here" && ./render ResizeTest.qml /tmp/t-resize.png 1500 2>&1 | grep -v XDG_RUNTIME_DIR | sed 's/^qml: //')"
echo "$out" | grep -E "PASS|FAIL|^   " | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Binding loop" && { echo "   !! ResizeTest"; failed=1; }
n="$(echo "$out" | grep -c "PASS ")"
[ "$n" -lt 6 ] && { echo "   !! ResizeTest solo afirmo $n checks (minimo 6)"; failed=1; }

echo; echo "==> dentro de un panel de verdad"
# El test que faltaba: sueltos, implicitWidth alcanza; en un Layout no, y el
# panel usa un Layout. Sin Layout.preferredWidth el panel da un ancho por
# defecto - la IP salía cortada y Pac-Man ocupaba espacio sin dibujar.
out="$(cd "$here" && ./render PanelTest.qml /tmp/t-panel.png 1500 2>&1 | grep -v XDG_RUNTIME_DIR)"
echo "$out" | sed 's/^qml: //' | grep -E "PASS|FAIL|^   " | sed 's/^/   /'
echo "$out" | grep -qE "FAIL|QML ERROR|Binding loop" && failed=1

echo; echo "==> las representaciones declaran su tamaño"
for f in "$root"/*/contents/ui/*Pill.qml "$root"/*/contents/ui/*Strip.qml; do
    grep -q "Layout.preferredWidth" "$f" || { echo "   !! FAIL $(basename "$f"): sin Layout.preferredWidth"; failed=1; }
done
grep -q "Layout.preferredWidth" "$root/netindicator/contents/ui/NetPanel.qml" || { echo "   !! FAIL NetPanel sin Layout.preferredWidth"; failed=1; }
echo "   ok las tres declaran Layout.preferredWidth"

echo; echo "==> ningún Component cruza de archivo"
# Este es el bug que dejó a Pac-Man invisible sin un solo error: un Component
# definido en el scope de un archivo, instanciado por el loader de
# representaciones de Plasma, que corre en otro contexto.
for p in netindicator pacman; do
    bad="$(grep -rn "sourceComponent:.*\b[a-z][A-Za-z]*\.\(horizontal\|vertical\|popout\)" "$root/$p/contents/ui" || true)"
    if [ -n "$bad" ]; then echo "   !! FAIL $p: $bad"; failed=1; else echo "   ok $p"; fi
done

echo; echo "==> metadatos: icono propio y un solo idioma"
python3 "$here/check_metadata.py" "$root"/*/metadata.json || failed=1

echo; echo "==> la página de settings se dibuja entera"
python3 "$here/check_settings_page.py" "$root"/*/contents/ui/configGeneral.qml || failed=1

echo; echo "==> el mock de configuración cubre los dos esquemas"
# Un mock que se queda atras hace que los tests mientan: un ajuste nuevo se
# escribe en una propiedad que no existe y el test dice "undefined" o, peor,
# pasa. Paso con textOffset.
mock="$here/org/kde/plasma/plasmoid/PlasmoidConfigMock.qml"
missing=""
for p in netindicator pacman; do
    for k in $(grep -o 'entry name="[A-Za-z0-9_]*"' "$root/$p/contents/config/main.xml" | sed 's/.*"\(.*\)"/\1/'); do
        grep -q "property [a-z]* $k:" "$mock" || missing="$missing $p/$k"
    done
done
if [ -n "$missing" ]; then echo "   !! FAIL faltan en el mock:$missing"; failed=1
else echo "   ok las $(grep -c 'property .*:' "$mock") claves del mock cubren los dos esquemas"; fi

echo; echo "==> settings: esquema <-> estado <-> página"
for p in netindicator pacman; do
    schema="$(grep -o 'entry name="[A-Za-z0-9_]*"' "$root/$p/contents/config/main.xml" | sed 's/.*"\(.*\)"/\1/' | sort -u)"
    ui="$(grep -o 'cfg_[A-Za-z0-9_]*' "$root/$p/contents/ui/configGeneral.qml" | sed 's/cfg_//' | sort -u)"
    read_="$(grep -rho 'pluginData?\.[A-Za-z0-9_]*' "$root/$p/contents/ui" | sed 's/.*\.//' | sort -u)"
    m="$(comm -23 <(echo "$read_") <(echo "$schema"))"; u="$(comm -23 <(echo "$schema") <(echo "$ui"))"
    [ -n "$m" ] && { echo "   !! $p: leído pero no en el esquema: $m"; failed=1; }
    [ -n "$u" ] && { echo "   !! $p: en el esquema sin control: $u"; failed=1; }
    [ -z "$m$u" ] && echo "   ok $p: $(echo "$schema" | wc -l) opciones cableadas"
done

echo; [ "$failed" -eq 0 ] && echo "=== TODO PASA ===" || echo "=== FALLAS ==="
exit "$failed"
