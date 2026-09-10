// El mismo widget en DOS paneles.
//
// El bug que reportó el usuario: agregó los dos plugins a un panel horizontal y
// a uno vertical, y el segundo rompió al primero — los clics del horizontal
// dejaron de hacer nada, sus ajustes aparecieron reemplazados, y el escritorio
// se congeló unos segundos.
//
// Causa: NetState era un `pragma Singleton`. plasmashell corre TODOS los applets
// en un solo motor QML, así que un singleton es uno para todo el escritorio — y
// main.qml le escribía tres cosas que son por instancia: los ajustes
// (`pluginData`), la orientación (`isVertical`) y la función con la que el
// applet guarda su configuración (`savePluginData`). Con dos instancias, el
// segundo pisaba al primero: los clics del horizontal escribían en la
// configuración del vertical.
//
// Los HECHOS de red sí son globales, y siguen compartidos en NetService: una
// sola sonda para los dos, que es lo que se quiere.
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
        const c = Qt.createComponent("../netindicator/contents/ui/main.qml");
        if (c.status === Component.Error) {
            console.log("FAIL main.qml: " + c.errorString()); h.failures++; return;
        }
        const horizontal = c.createObject(h);
        const vertical = c.createObject(h);
        horizontal.visible = false; vertical.visible = false;

        h.expect("los dos applets se construyen", horizontal !== null && vertical !== null, true);
        h.expect("cada uno tiene su propio estado", horizontal.netState !== vertical.netState, true);
        h.expect("y ninguno es nulo", horizontal.netState !== null && vertical.netState !== null, true);

        // Lo que el segundo pisaba: la funcion de guardar.
        h.expect("cada uno guarda por su cuenta",
                 horizontal.netState.savePluginData !== vertical.netState.savePluginData, true);

        // Y los ajustes: tocar los de uno no toca los del otro.
        horizontal.netState.pluginData = { "pillContent": "publicIp", "monospace": false };
        vertical.netState.pluginData = { "pillContent": "gateway", "monospace": true };
        h.expect("los ajustes del primero se quedan quietos",
                 horizontal.netState.pillContent, "publicIp");
        h.expect("y los del segundo tambien", vertical.netState.pillContent, "gateway");
        h.expect("sin contagiarse el monospace", horizontal.netState.monospace, false);

        // La orientacion, que era la tercera cosa contestada.
        horizontal.netState.isVertical = false;
        vertical.netState.isVertical = true;
        h.expect("el horizontal se queda horizontal", horizontal.netState.isVertical, false);
        h.expect("y el vertical, vertical", vertical.netState.isVertical, true);

        // Pero la red SI se comparte: una sola sonda para los dos.
        h.expect("los hechos de red siguen siendo unicos",
                 Lib.NetService === Lib.NetService, true);
        Lib.NetService.parseProfiles("u-x:wireguard:no:VPN Canada:");
        h.expect("y los ven los dos", horizontal.netState.vpnProfiles.length,
                 vertical.netState.vpnProfiles.length);

        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
