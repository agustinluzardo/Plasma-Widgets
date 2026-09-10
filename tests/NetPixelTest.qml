// La pastilla y el panel de red, renderizados con datos realistas.
// Las afirmaciones son sobre lo que el render tiene que contener: si el estado
// no llego, el PNG sale bonito y vacio y los pixeles solos no lo notan.
import QtQuick
import "../netindicator/contents/ui" as W
import "../netindicator/contents/ui/lib" as Lib

Rectangle {    id: h


    // NetState ya no es un singleton: es uno por applet. El test crea el suyo,
    // igual que main.qml.
    Lib.NetState { id: estado }
    width: 520; height: 560; color: "#1b1e24"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    W.NetPill  { state: estado; id: pill;  anchors.left: parent.left; anchors.top: parent.top; anchors.margins: 8 }
    W.NetPanel { state: estado; id: panel; anchors.left: parent.left; anchors.top: pill.bottom; anchors.margins: 8
                 width: 480 }

    Component.onCompleted: {
        Lib.NetService.applyProbe([
            "#DEV","eno1:ethernet:connected:Cableada",
            "#ACT","a1b2:wireguard:wg-US:activated:wg-US",
            "#PRO","a1b2:wireguard:yes:wg-US:\ne5f6:wireguard:no:wg-NL:",
            "#ADDR",'[{"ifname":"eno1","addr_info":[{"family":"inet","local":"192.168.1.39","scope":"global"}]}]',
            "#SSID","","#END"].join("\n"));
        estado.publicIp4 = "186.57.211.4";
        estado.publicIp6 = "2802:8010:619b:b901:46bb:6849:ef25:b4c4";
        estado.isp = "AS22927 Telefonica de Argentina";
        estado.location = "AR - Quilmes";
        estado.countryCode = "AR";
        estado.gateway = "192.168.1.1";
        estado.latency = "0.50";
        estado.statusText = "OK";
        settle.start();
    }

    Timer {
        id: settle; interval: 600
        onTriggered: {
            console.log("   pill " + Math.round(pill.implicitWidth) + "x" + Math.round(pill.implicitHeight)
                + "  panel " + Math.round(panel.implicitWidth) + "x" + Math.round(panel.implicitHeight));
            h.expect("la sonda dejo la IP local", estado.localIp, "192.168.1.39");
            h.expect("y la VPN activa", estado.vpnActiveNames.length > 0, true);
            h.expect("la pastilla tiene ancho", pill.implicitWidth > 0, true);
            h.expect("el panel tiene alto de verdad", panel.implicitHeight > 100, true);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
