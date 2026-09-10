// El flujo de conectar y desconectar VPN, que no tenía ni un test.
//
// Es la zona con más forma de trampa del widget: `vpnIsBusy` deja todos los
// botones grises, y sólo se baja dentro de un refresh. Si ese refresh no llega
// -la VPN tarda, la salida viene vacía, el proceso no contesta- el panel queda
// congelado. En la versión de DMS eso pasó de verdad.
import QtQuick
import org.kde.plasma.plasma5support as P5
import "../netindicator/contents/ui/lib" as Lib

Item {
    id: h

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }
    function comandos() { return P5.DsMock.calls.length }

    Component.onCompleted: {
        const S = Lib.NetService, N = Lib.NetState;

        // Un perfil cargado y nada activo.
        S.parseProfiles("u-ok:wireguard:no:VPN Canada:");
        S.vpnActive = [];
        h.expect("arranca libre", N.vpnBusy, false);

        // --- conectar bien -------------------------------------------------
        P5.DsMock.responses = { "connection up uuid": { "out": "", "code": 0 },
                                "#DEV": { "out": "#DEV\n#ACT\nu-ok:wireguard:wg0:activated:VPN Canada\n#PRO\nu-ok:wireguard:no:VPN Canada:\n#ADDR\n#SSID\n#END", "code": 0 } };
        S.connectVpn("u-ok", true);
        h.expect("tras conectar, la VPN quedo activa", S.isActiveVpnUuid("u-ok"), true);
        h.expect("y el flag de ocupado bajo solo", N.vpnBusy, false);

        // --- conectar y que falle -----------------------------------------
        S.vpnActive = [];
        P5.DsMock.responses = { "connection up uuid": { "out": "Error: Connection activation failed.", "code": 4 },
                                "#DEV": { "out": "#DEV\n#ACT\n#PRO\n#ADDR\n#SSID\n#END", "code": 0 } };
        S.connectVpn("u-bad", true);
        h.expect("un fallo no deja el panel ocupado", N.vpnBusy, false);
        h.expect("y se queda con el motivo", S.vpnError, "Error: Connection activation failed.");
        h.expect("y con cual fallo", S.vpnErrorUuid, "u-bad");

        // --- no se pisan dos operaciones ----------------------------------
        S.vpnIsBusy = true; S.pendingVpnUuid = "u-ok";
        const antes = h.comandos();
        S.connectVpn("u-ok", true);
        h.expect("con una en vuelo, la segunda se ignora", h.comandos(), antes);

        // --- el rescate del flag colgado ----------------------------------
        // Este es el caso que congelaba el panel: la orden se dio, la respuesta
        // que bajaria el flag no llega nunca.
        S.vpnIsBusy = true; S.pendingVpnUuid = "u-ok"; S.vpnActive = [];
        N.vpnBusySince = Date.now();
        h.expect("recien pedido, no parece colgado", N.vpnBusyLooksStuck(), false);
        h.expect("y no se rescata todavia", N.recoverStuckVpnBusy(), false);

        N.vpnBusySince = Date.now() - 31000;
        h.expect("pasada la gracia, si parece colgado", N.vpnBusyLooksStuck(), true);
        h.expect("y se rescata", N.recoverStuckVpnBusy(), true);
        h.expect("dejando el panel usable", N.vpnBusy, false);
        h.expect("y sin operacion pendiente", S.pendingVpnUuid, "");

        // --- la gracia corta para una operacion que no puede contestar -----
        S.vpnIsBusy = true; S.pendingVpnUuid = ""; S.vpnActive = [];
        N.vpnBusySince = Date.now() - 7000;
        h.expect("sin nada que desconectar, la gracia es corta",
                 N.vpnBusyLooksStuck(), true);
        S.vpnIsBusy = true; S.pendingVpnUuid = ""; S.vpnActive = [];
        N.vpnBusySince = Date.now() - 3000;
        h.expect("pero no instantanea", N.vpnBusyLooksStuck(), false);

        // --- el boton del popout: vpnToggle -------------------------------
        // enabled: !vpnBusy || row.isBusy, y onActivated: NetState.vpnToggle().
        // Nadie habia probado esa funcion.
        S.vpnIsBusy = false; S.pendingVpnUuid = "";
        S.parseProfiles("u-ok:wireguard:no:VPN Canada:");
        S.vpnActive = [];
        P5.DsMock.responses = { "connection up uuid": { "out": "", "code": 0 },
                                "#DEV": { "out": "#DEV\n#ACT\nu-ok:wireguard:wg0:activated:VPN Canada\n#PRO\nu-ok:wireguard:no:VPN Canada:\n#ADDR\n#SSID\n#END", "code": 0 } };
        N.vpnToggle(S.vpnProfiles[0]);
        h.expect("el boton conecta cuando esta apagada", S.isActiveVpnUuid("u-ok"), true);

        P5.DsMock.responses = { "connection down uuid": { "out": "", "code": 0 },
                                "#DEV": { "out": "#DEV\n#ACT\n#PRO\nu-ok:wireguard:no:VPN Canada:\n#ADDR\n#SSID\n#END", "code": 0 } };
        N.vpnToggle(S.vpnProfiles[0]);
        h.expect("y desconecta cuando esta encendida", S.isActiveVpnUuid("u-ok"), false);

        S.vpnIsBusy = true;
        const antesToggle = h.comandos();
        N.vpnToggle(S.vpnProfiles[0]);
        h.expect("y no hace nada con otra operacion en vuelo", h.comandos(), antesToggle);

        S.vpnIsBusy = false;
        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
