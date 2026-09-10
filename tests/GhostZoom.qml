// El fantasma a tamaño grande, para comparar contra el de DMS pixel a pixel.
// Ademas afirma lo que el zoom deberia mostrar: con el foco en el 3 de 5 y
// ghostMode "behind", los fantasmas van en los dos slots anteriores.
import QtQuick
import "../pacman/contents/ui" as W
import "../pacman/contents/ui/lib" as Lib

Rectangle {
    id: h
    width: 420; height: 120; color: "#000000"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    W.PacmanStrip { id: s; anchors.centerIn: parent; height: 64 }

    Component.onCompleted: {
        const i = Lib.WorkspaceService._info;
        i.desktopIds = ["a","b","c","d","e"]; i.desktopNames = ["","","","",""];
        i.numberOfDesktops = 5; i.currentDesktop = "c";
        settle.start();
    }

    Timer {
        id: settle; interval: 400
        onTriggered: {
            h.expect("cinco slots", s.slotCount, 5);
            h.expect("el tercero enfocado", s.resolvedFocusId, 3);
            h.expect("dos fantasmas detras", s.visibleGhostCount, 2);
            h.expect("y la celda es grande para el zoom", s.cellSize > 20, true);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
