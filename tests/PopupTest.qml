// The full representation has to be a real popup, not a placeholder.
//
// Plasma will not render a compact-only applet at all, so this widget must
// carry a full representation; a full representation that draws nothing is
// just a different way to fail. Rendered and counted like everything else.
import QtQuick
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL

Rectangle {
    id: h
    width: 300; height: 200
    color: "#000000"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    P.DesktopList {
        id: popup
        anchors.fill: parent
    }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c"];
        i.desktopNames = ["Main", "Code", "Media"];
        i.numberOfDesktops = 3;
        i.currentDesktop = "b";
        settle.start();
    }

    Timer {
        id: settle; interval: 600
        onTriggered: {
            h.expect("lista los escritorios", popup.desktops.length, 3);
            h.expect("y sabe cual es el actual", popup.focusedNum, 2);
            h.expect("declara ancho para el popup", popup.Layout.preferredWidth > 0, true);
            h.expect("y alto", popup.Layout.preferredHeight > 0, true);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
