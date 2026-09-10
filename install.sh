#!/usr/bin/env bash
# Instala los dos widgets para el usuario actual. Sin root, sin compilar.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
dest="$HOME/.local/share/plasma/plasmoids"

for p in netindicator pacman; do
    id="$(sed -n 's/.*"Id": "\([^"]*\)".*/\1/p' "$here/$p/metadata.json")"
    echo "==> $id"
    rm -rf "${dest:?}/$id"
    mkdir -p "$dest/$id"
    cp "$here/$p/metadata.json" "$dest/$id/"
    cp -r "$here/$p/contents" "$dest/$id/"
done

echo
echo "==> reiniciando plasmashell"
# En una sesión Plasma 6 arrancada por systemd, plasmashell es una unit. Pedirle
# a systemd que la reinicie es un reinicio limpio y supervisado; matarla con
# kquitapp6 y relanzarla a mano la saca de debajo de systemd, que además puede
# volver a levantarla y dejar dos. Eso queda sólo como respaldo para sesiones
# sin systemd.
if systemctl --user --quiet is-active plasma-plasmashell.service 2>/dev/null; then
    systemctl --user restart plasma-plasmashell.service
elif command -v kquitapp6 >/dev/null 2>&1; then
    kquitapp6 plasmashell 2>/dev/null || true
    sleep 2
    (setsid plasmashell >/dev/null 2>&1 &) || true
else
    echo "    ni la unit ni kquitapp6; cerrá sesión y volvé a entrar"
fi
echo
echo 'Click derecho en el panel -> Añadir widgets -> "Network Indicator" / "Pac-Man Workspaces"'
