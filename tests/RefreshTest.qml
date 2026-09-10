// El widget no puede releerse a sí mismo en bucle.
//
// NetState escucha networkStatusChanged y contesta con refreshAll(), que vuelve
// a correr el probe. Si el probe emite la señal al terminar CADA lectura, eso
// es un bucle cerrado: el widget queda en "checking" permanente y la latencia
// salta sin parar, que es exactamente lo que se veía.
//
// Estuvo latente mientras el script tenía el error de sintaxis (la salida vacía
// se descartaba antes de emitir). Arreglar el probe lo encendió, así que este
// test tiene que quedarse.
import QtQuick
import "../netindicator/contents/ui/lib" as Lib

Item {    id: h


    // NetState ya no es un singleton: es uno por applet. El test crea el suyo,
    // igual que main.qml.
    Lib.NetState { id: estado }

    property int checks: 0
    property int failures: 0
    property int emitted: 0

    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    Connections {
        target: Lib.NetService
        function onNetworkStatusChanged() { h.emitted++; }
    }

    Component.onCompleted: {
        const req = new XMLHttpRequest();
        req.open("GET", "file:///tmp/probe-out.txt", false);
        req.send(null);
        const probe = req.responseText;

        h.expect("el fixture trae los lifetimes volátiles", probe.indexOf("valid_life_time") !== -1, true);

        Lib.NetService.applyProbe(probe);
        h.expect("la primera lectura avisa que hay estado nuevo", h.emitted, 1);

        // La misma red, leída otra vez: no cambió nada.
        Lib.NetService.applyProbe(probe);
        Lib.NetService.applyProbe(probe);
        h.expect("releer lo mismo no vuelve a avisar", h.emitted, 1);

        // Sólo bajan los contadores de la dirección DHCP. La red está quieta.
        const older = probe.replace(/83915/g, "83902");
        h.expect("y el texto sí cambió", older !== probe, true);
        Lib.NetService.applyProbe(older);
        h.expect("los lifetimes no cuentan como cambio de red", h.emitted, 1);

        // Un cambio de verdad: otra IP.
        Lib.NetService.applyProbe(probe.replace("192.168.1.39", "192.168.1.77"));
        h.expect("una IP distinta sí avisa", h.emitted, 2);

        // Y una VPN que se conecta.
        Lib.NetService.applyProbe(probe.replace(
            "u-wired:802-3-ethernet:eno1:activated:Wired connection 1",
            "u-wired:802-3-ethernet:eno1:activated:Wired connection 1\nu-ca:wireguard:wg0:activated:VPN Canada"));
        h.expect("una VPN que se conecta también", h.emitted, 3);
        h.expect("y queda registrada como activa", estado.vpnActiveNames.join(), "VPN Canada");

        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
