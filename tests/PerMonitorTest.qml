// perMonitor tiene que hacer algo.
//
// Estaba en el esquema, en la página de settings y en pluginData, y nadie lo
// leía: la tira siempre miraba el escritorio global. El comentario que lo
// justificaba decía que Plasma no tiene escritorios por monitor, y es falso —
// son globales, pero CUÁL está actual puede diferir por salida, y el Pager de
// KDE se apoya justo en eso.
import QtQuick
import QtQuick.Layouts
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL

Rectangle {
    id: h
    width: 460; height: 44; color: "#101216"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    // Dos tiras, cada una fijada a una pantalla distinta.
    RowLayout {
        anchors.fill: parent
        P.PacmanStrip { id: izq; Layout.fillHeight: true; screenName: "DP-1" }
        P.PacmanStrip { id: der; Layout.fillHeight: true; screenName: "HDMI-A-1" }
        Item { Layout.fillWidth: true }
    }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c","d"]; i.desktopNames = ["","","",""];
        i.numberOfDesktops = 4; i.currentDesktop = "b";   // el global es el 2
        settle.start();
    }

    Timer {
        id: settle; interval: 400
        onTriggered: {
            const i = PL.WorkspaceService._info;

            i._setForScreen("DP-1", "a");
            i._setForScreen("HDMI-A-1", "d");

            h.expect("el global es el 2", PL.WorkspaceService.focusedNum, 2);
            h.expect("y el servicio sabe el de DP-1", PL.WorkspaceService.focusedNumFor("DP-1"), 1);
            h.expect("y el de HDMI-A-1", PL.WorkspaceService.focusedNumFor("HDMI-A-1"), 4);
            h.expect("una pantalla sin entrada cae al global",
                     PL.WorkspaceService.focusedNumFor("DVI-0"), 2);
            h.expect("sin nombre de pantalla, el global",
                     PL.WorkspaceService.focusedNumFor(""), 2);

            // Y la tira lo usa: con perMonitor puesto cada una sigue la suya.
            h.expect("perMonitor viene puesto de fabrica", izq.perMonitor, true);
            h.expect("la tira de DP-1 enfoca el 1", izq.resolvedFocusId, 1);
            h.expect("la de HDMI-A-1 enfoca el 4", der.resolvedFocusId, 4);
            h.expect("y cada una dibuja su Pac-Man en distinto slot",
                     izq.resolvedFocusId !== der.resolvedFocusId, true);

            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
