// Los mete en un Layout con alto fijo, que es exactamente lo que hace el panel.
//
// Todo test anterior los instanció sueltos, donde implicitWidth alcanza. En un
// Layout no alcanza: Plasma lee Layout.preferredWidth, y sin eso da un ancho
// por defecto - texto cortado en uno, espacio vacío en el otro.
import QtQuick
import QtQuick.Layouts
import "../pacman/contents/ui" as P
import "../netindicator/contents/ui" as N
import "../pacman/contents/ui/lib" as PL
import "../netindicator/contents/ui/lib" as NL

Rectangle {    id: h


    // NetState ya no es un singleton: es uno por applet. El test crea el suyo,
    // igual que main.qml.
    NL.NetState { id: estado }
    width: 600; height: 44; color: "#2a2e36"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    // Un panel horizontal de 36px, como el de abajo de la pantalla.
    RowLayout {
        id: panel
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: 36
        spacing: 8

        P.PacmanStrip { id: pac; Layout.fillHeight: true }
        N.NetPill     { state: estado; id: net; Layout.fillHeight: true }
    }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c","d"]; i.desktopNames = ["","","",""];
        i.numberOfDesktops = 4; i.currentDesktop = "b";
        NL.NetService.applyProbe([
            "#DEV","eno1:ethernet:connected:x","#ACT","#PRO",
            "#ADDR",'[{"ifname":"eno1","addr_info":[{"family":"inet","local":"192.168.1.39","scope":"global"}]}]',
            "#SSID","","#END"].join("\n"));
        settle.start();
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: {
            console.log("=== dentro de un panel de 36px ===");
            console.log("   pacman " + Math.round(pac.width) + "x" + Math.round(pac.height)
                + "   net " + Math.round(net.width) + "x" + Math.round(net.height));

            // Lo que falló en el panel real: ancho por defecto en vez del del
            // contenido.
            h.expect("pacman pide su propio ancho", pac.Layout.preferredWidth > 0, true);
            h.expect("y lo recibe", Math.round(pac.width) === Math.round(pac.Layout.preferredWidth), true);
            h.expect("con alto del panel", pac.height > 20, true);

            h.expect("net pide su propio ancho", net.Layout.preferredWidth > 0, true);
            h.expect("y lo recibe entero", Math.round(net.width) === Math.round(net.Layout.preferredWidth), true);
            h.expect("suficiente para la IP completa", net.width >= 60, true);

            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
