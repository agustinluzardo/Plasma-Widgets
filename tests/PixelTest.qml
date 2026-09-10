// Does the strip actually put pixels on the screen?
//
// Every test in the previous attempt asked "does it construct" and "does it
// report a size". Both passed while the widget was invisible in the panel. This
// one renders it and counts what came out - the only question that matches the
// symptom.
import QtQuick
import "../pacman/contents/ui" as Widget
import "../pacman/contents/ui/lib" as Lib

Rectangle {
    id: harness
    width: 260; height: 40
    color: "#000000"

    property int checks: 0
    property int failures: 0
    function expect(label, actual, wanted) {
        checks++;
        const ok = actual === wanted;
        if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + JSON.stringify(actual) + (ok ? "" : " (expected " + JSON.stringify(wanted) + ")"));
    }

    Widget.PacmanStrip {
        id: strip
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 24
    }

    Component.onCompleted: {
        const info = Lib.WorkspaceService._info;
        info.desktopIds = ["a", "b", "c", "d"];
        info.desktopNames = ["", "", "", ""];
        info.numberOfDesktops = 4;
        info.currentDesktop = "b";
        settle.start();
    }

    Timer {
        id: settle
        interval: 250
        onTriggered: {
            console.log("=== la tira, de verdad ===");
            expect("hay cuatro slots", strip.slotCount >= 4, true);
            expect("el segundo está enfocado", strip.focusedWorkspaceId, 2);
            expect("tiene ancho", strip.implicitWidth > 0, true);
            console.log("   " + Math.round(strip.implicitWidth) + " x " + Math.round(strip.implicitHeight)
                + "  celda=" + strip.cellSize + " sep=" + strip.cellSpacing);

            // Render it and count non-black pixels. A widget that constructs,
            // reports a size and draws nothing is exactly what shipped last time.
            harness.grabToImage(function (result) {
                const img = result.image;
                let painted = 0, yellow = 0;
                for (let x = 0; x < harness.width; x += 2) {
                    for (let y = 0; y < harness.height; y += 2) {
                        const c = img.pixel(x, y);
                        const r = (c >> 16) & 0xff, g = (c >> 8) & 0xff, b = c & 0xff;
                        if (r + g + b > 30) painted++;
                        if (r > 180 && g > 140 && b < 120) yellow++;
                    }
                }
                console.log("   pixeles pintados=" + painted + "  amarillos(pac-man)=" + yellow);
                harness.expect("dibuja algo", painted > 0, true);
                harness.expect("y Pac-Man es visible", yellow > 0, true);
                console.log("=== " + harness.checks + " checks, " + (harness.failures === 0 ? "ALL PASS" : harness.failures + " FAILURES") + " ===");
            });
        }
    }
}
