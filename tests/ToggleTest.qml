// El botón del medio, con un túnel arriba.
//
// El usuario dice que le refresca la IP pero no le alterna entre la de la LAN y
// la del túnel. Esto comprueba cuál de las dos cosas pasa y por qué: la
// alternancia está detrás del ajuste "Swap on middle click", que NO es el
// valor de fábrica.
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
        const s = Lib.NetState;

        // Una VPN levantada y llevando tráfico de verdad.
        s.localInterface = "eno1";
        s.routeInterface = "wg0";
        s.routeSourceIp = "10.2.0.2";
        s.localIp = "192.168.1.39";

        h.expect("el túnel lleva el tráfico", s.trafficLeavesViaTunnel, true);

        // Como viene de fábrica: el botón del medio refresca, no alterna.
        s.pluginData = { "localIpSource": "lan" };
        h.expect("de fábrica no es alternable", s.localIpIsToggleable, false);
        h.expect("y el pill muestra la de la LAN", s.displayLocalIp, "192.168.1.39");
        s.pillSecondaryAction();
        h.expect("el botón del medio no la cambia", s.displayLocalIp, "192.168.1.39");

        // Con el ajuste puesto en "Swap on middle click".
        s.pluginData = { "localIpSource": "toggle" };
        h.expect("ahora sí es alternable", s.localIpIsToggleable, true);
        h.expect("arranca en la de la LAN", s.displayLocalIp, "192.168.1.39");
        s.pillSecondaryAction();
        h.expect("un clic del medio pasa a la del túnel", s.displayLocalIp, "10.2.0.2");
        s.pillSecondaryAction();
        h.expect("y otro vuelve a la de la LAN", s.displayLocalIp, "192.168.1.39");

        // Fijo en la del túnel, sin alternar.
        s.pluginData = { "localIpSource": "tunnel" };
        h.expect("fijo en túnel la muestra siempre", s.displayLocalIp, "10.2.0.2");

        // Sin túnel, alternar no puede inventar una dirección: antes el gesto
        // invertía un booleano que displayLocalIp ignora, o sea que no hacía
        // NADA. Ahora cae al refresco.
        s.pluginData = { "localIpSource": "toggle" };
        s.routeInterface = "eno1";
        h.expect("sin túnel se queda en la de la LAN", s.displayLocalIp, "192.168.1.39");
        const before = s.showingTunnelIp;
        // El proceso está mockeado y contesta al instante, así que mirar el
        // statusText final es una carrera. Lo que se comprueba es que la ruta
        // del refresco se haya recorrido: el centinela ya no está.
        s.statusText = "CENTINELA";
        s.pillSecondaryAction();
        h.expect("y el gesto no deja un estado colgado", s.showingTunnelIp, before);
        h.expect("sino que refresca", s.statusText !== "CENTINELA", true);

        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
