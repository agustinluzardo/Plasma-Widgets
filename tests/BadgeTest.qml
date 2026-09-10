// The diagnostic overlay: it has to be silent on a working panel and loud when
// the strip has collapsed.
//
// The first version of this asserted on `wouldBeEmpty` with no desktops, which
// never fires: the strip pads to minSlots and draws five pellets whatever the
// compositor reports. Missing desktop data is not what invisibility looks like.
// Collapsed GEOMETRY is, so that is what the badge watches, and the explicit
// switch is what the user turns on when nothing at all shows up.
import QtQuick
import QtQuick.Layouts
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL

Rectangle {
    id: h
    width: 460; height: 90; color: "#101216"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    RowLayout {
        anchors.fill: parent
        P.PacmanStrip { id: ok; Layout.fillHeight: true }
        Item { Layout.fillWidth: true }
    }

    // A strip given no room at all - the failure the badge exists to name.
    P.PacmanStrip {
        id: squashed
        width: 0; height: 0
        visible: false
    }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c","d"]; i.desktopNames = ["","","",""];
        i.numberOfDesktops = 4; i.currentDesktop = "b";
        good.start();
    }

    Timer {
        id: good; interval: 350
        onTriggered: {
            console.log("=== el badge de diagnostico ===");
            console.log("   " + ok.diagnostic);
            h.expect("en un panel de verdad la tira no esta vacia", ok.wouldBeEmpty, false);
            h.expect("y el badge no se ve", ok.wouldBeEmpty || ok.debugOverlay, false);
            h.expect("una tira sin sitio si se declara vacia", squashed.wouldBeEmpty, true);

            // El diagnostico tiene que decir lo que hace falta para decidir.
            const d = ok.diagnostic;
            h.expect("el diagnostico trae los slots", d.indexOf("slots=") !== -1, true);
            h.expect("el tamaño de celda", d.indexOf("cell=") !== -1, true);
            h.expect("la geometria real", d.indexOf("w=") !== -1 && d.indexOf("h=") !== -1, true);
            h.expect("y los escritorios", d.indexOf("desktops=4") !== -1, true);

            const i = PL.WorkspaceService._info;
            i.desktopIds = []; i.desktopNames = []; i.numberOfDesktops = 0; i.currentDesktop = "";
            bad.start();
        }
    }

    Timer {
        id: bad; interval: 350
        onTriggered: {
            console.log("   sin escritorios -> " + ok.diagnostic);
            h.expect("sin escritorios sigue dibujando", ok.slotCount >= 1, true);
            h.expect("y el diagnostico lo dice", ok.diagnostic.indexOf("desktops=0") !== -1, true);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
