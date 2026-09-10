// Los perfiles VPN de NetworkManager tienen que llegar al panel.
//
// El usuario tenia tres cargados y el widget decia "No profiles yet". La causa
// no estaba en el parseo sino en el script: se unia con "; " y era un error de
// sintaxis, asi que nunca corrio. Este test parte de la salida REAL del script
// arreglado (run.sh la genera con un nmcli de mentira) y comprueba el otro
// extremo: que se parsee y llegue a la lista.
import QtQuick
import "../netindicator/contents/ui/lib" as Lib

Item {
    id: h

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    Component.onCompleted: {
        const req = new XMLHttpRequest();
        req.open("GET", "file:///tmp/probe-out.txt", false);
        req.send(null);
        Lib.NetService.applyProbe(req.responseText);

        const p = Lib.NetService.vpnProfiles;
        h.expect("se ven los tres perfiles VPN", p.length, 3);
        h.expect("wireguard y openvpn los dos", p.filter(x => x.type === "vpn").length, 1);
        h.expect("el primero es VPN Canada", p[0].name, "VPN Canada");
        h.expect("el segundo es VPN United States", p[1].name, "VPN United States");
        h.expect("el tercero es VPN Netherlands", p[2].name, "VPN Netherlands");
        h.expect("y arranca al boot solo el de US", p.filter(x => x.autoconnect).map(x => x.name).join(), "VPN United States");
        h.expect("la conexion cableada no cuenta como VPN", p.filter(x => x.uuid === "u-wired").length, 0);
        h.expect("ninguno conectado", Lib.NetState.vpnActiveNames.length, 0);
        h.expect("pero hay VPN disponible", Lib.NetState.vpnAvailable, true);
        h.expect("y la IP local llego igual", Lib.NetState.localIp, "192.168.1.39");

        // nmcli escapa los dos puntos literales. El nombre tiene que llegar
        // legible, no con la barra invertida a la vista.
        Lib.NetService.parseProfiles("u-x:wireguard:no:VPN\\: Canada:\n"
                                   + "u-y:vpn:yes:Casa \\\\ Oficina:svc");
        const p2 = Lib.NetService.vpnProfiles;
        h.expect("un nombre con dos puntos se desescapa", p2[0].name, "VPN: Canada");
        h.expect("y una barra invertida tambien", p2[1].name, "Casa \\ Oficina");
        h.expect("sin perder el resto de los campos", p2[1].autoconnect, true);
        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
