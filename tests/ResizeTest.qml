// ¿Puede la tira pedir un ancho de cero mientras cambia el número de
// escritorios?
//
// La primera versión de este test decía que no, con un mínimo observado de 62.
// Estaba SUBMUESTREADA: el binding no se reevaluaba en el instante del bajón.
// Al agregarle al código un suelo -que mete una dependencia más y por lo tanto
// más reevaluaciones- se destapó que sí caía, y a través de una realimentación
// de eje cruzado: el alto declarado salía del contenido, el layout se lo daba,
// el grosor salía de ese alto y el tamaño de celda del grosor. La altura llegaba
// a caer a 12, el literal que estaba en Layout.minimumHeight.
//
// Ahora el eje corto no declara tamaño propio y hay un suelo derivado del grosor
// de la barra. Lo que se afirma abajo es lo que el código GARANTIZA, no lo que
// una medición con suerte llegó a ver.
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
    property real minPiso: 1e9
    property real minBar: 1e9

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
        property real piso: strip._floor
        property real bar: strip.barThickness
        onPisoChanged: if (piso < h.minPiso) h.minPiso = piso
        onBarChanged: if (bar < h.minBar) h.minBar = bar
        onBoxChanged:  { h.samples++; if (box  < h.minBox)       h.minBox = box }
        onPrefChanged: { if (pref < h.minPreferred) h.minPreferred = pref }
        onMiniChanged: { if (mini < h.minMinimum)   h.minMinimum = mini }
    }

    property var counts: [1, 8, 2, 10, 3, 6, 1, 12, 4]
    property int at: 0

    Component.onCompleted: cycle.start()

    Timer {
        id: cycle
        interval: 25
        repeat: true
        onTriggered: {
            if (h.at >= h.counts.length) {
                cycle.stop();
                console.log("   muestras=" + h.samples
                    + "  minBox=" + h.minBox.toFixed(1)
                    + "  minPreferred=" + h.minPreferred.toFixed(1)
                    + "  minMinimum=" + h.minMinimum.toFixed(1)
                    + "  celda=" + strip.cellSize + "  minPiso=" + h.minPiso + "  minBar=" + h.minBar);
                h.expect("se midió algo de verdad", h.samples > 3, true);
                // Un cuadrado del alto de la barra es lo que el panel dibuja
                // cuando el hint llega en 0. El suelo es una celda.
                h.expect("el ancho pedido nunca baja del suelo", h.minPreferred >= 10, true);
                h.expect("ni el mínimo", h.minMinimum >= 10, true);
                h.expect("el suelo mismo nunca se desploma", h.minPiso >= 10, true);
                h.expect("el grosor de barra tampoco", h.minBar >= 40, true);
                h.expect("y la caja interna aguanta una celda", h.minBox >= strip.cellSize, true);
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
