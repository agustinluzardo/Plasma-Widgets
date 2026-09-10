// ¿Puede la tira pedir un ancho de cero mientras cambia el número de
// escritorios?
//
// El panel hace `findPositive(applet.Layout.minimumWidth, availHeight)`: si el
// hint llega en 0, usa la ALTURA del panel como ancho, o sea un cuadrado del
// alto de la barra. Cambiar el número de escritorios regenera el Repeater
// entero, que es justo cuando un Row puede reportar 0 por un frame.
import QtQuick
import QtQuick.Layouts
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL

Rectangle {
    id: h
    width: 400; height: 44; color: "#101216"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    property real minBox: 1e9
    property real minPreferred: 1e9
    property real minMinimum: 1e9
    property int samples: 0

    RowLayout {
        anchors.fill: parent
        P.PacmanStrip { id: strip; Layout.fillHeight: true }
        Item { Layout.fillWidth: true }
    }

    // Un binding se reevalúa en cada cambio de sus dependencias, así que esto
    // ve los valores intermedios, que es donde estaría el problema.
    Item {
        property real box: strip.stripBoxWidth
        property real pref: strip.Layout.preferredWidth
        property real mini: strip.Layout.minimumWidth
        onBoxChanged:  { h.samples++; if (box  < h.minBox)       h.minBox = box }
        onPrefChanged: { if (pref < h.minPreferred) h.minPreferred = pref }
        onMiniChanged: { if (mini < h.minMinimum)   h.minMinimum = mini }
    }

    property var counts: [1, 8, 2, 10, 3, 6, 1, 12, 4]
    property int at: 0

    Component.onCompleted: cycle.start()

    Timer {
        id: cycle
        interval: 60
        repeat: true
        onTriggered: {
            if (h.at >= h.counts.length) {
                cycle.stop();
                console.log("   muestras=" + h.samples
                    + "  minBox=" + h.minBox.toFixed(1)
                    + "  minPreferred=" + h.minPreferred.toFixed(1)
                    + "  minMinimum=" + h.minMinimum.toFixed(1)
                    + "  celda=" + strip.cellSize);
                h.expect("se midió algo de verdad", h.samples > 3, true);
                // Un cuadrado del alto de la barra es lo que el panel dibuja
                // cuando el hint llega en 0. El suelo es una celda.
                h.expect("el ancho pedido nunca cae a cero", h.minPreferred >= strip.cellSize, true);
                h.expect("ni el mínimo", h.minMinimum >= strip.cellSize, true);
                h.expect("ni la caja interna", h.minBox >= strip.cellSize, true);
                console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
                return;
            }
            const n = h.counts[h.at++];
            const i = PL.WorkspaceService._info;
            const ids = [], names = [];
            for (let k = 0; k < n; k++) { ids.push("d" + k); names.push(""); }
            i.desktopIds = ids; i.desktopNames = names;
            i.numberOfDesktops = n; i.currentDesktop = "d" + Math.floor(n / 2);
        }
    }
}
