// Nada puede quedarse en memoria para siempre.
//
// Sh mantiene una cola de callbacks POR COMANDO, con este supuesto escrito en
// el propio archivo: "dos comandos idénticos en vuelo serían indistinguibles,
// así que los callbacks se encolan y se contestan en orden".
//
// El supuesto es falso. El motor ejecutable de Plasma deduplica por nombre de
// source: dos comandos idénticos en vuelo son UN source y llega UNA respuesta,
// no dos. Se contestaba a uno y el resto quedaba huérfano, con su clave viva en
// el mapa para toda la sesión. Dos clics rápidos sobre el mismo escritorio
// alcanzaban.
//
// El mock corre en modo diferido para poder tener dos en vuelo de verdad, en
// vez de tocar el mapa interno desde afuera.
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
    function pendientes() { return Object.keys(Lib.Sh._pending).length }
    // Lo que no puede crecer sin limite son los CALLBACKS retenidos. Las claves
    // se quedan, una por comando distinto, que es un conjunto finito.
    function retenidos() {
        let n = 0;
        const k = Object.keys(Lib.Sh._pending);
        for (let i = 0; i < k.length; i++) n += Lib.Sh._pending[k[i]].length;
        return n;
    }

    property int contestados: 0

    Component.onCompleted: {
        const base = h.pendientes();
        P5.DsMock.defer = true;

        // Dos peticiones idénticas antes de que conteste ninguna.
        Lib.Sh.exec(["sh", "-c", "echo hola"], function () { h.contestados++ });
        Lib.Sh.exec(["sh", "-c", "echo hola"], function () { h.contestados++ });
        h.expect("dos en vuelo, una sola clave", h.pendientes(), base + 1);
        h.expect("y dos callbacks retenidos", h.retenidos(), 2);
        h.expect("el motor las colapsó en un solo comando", P5.DsMock.deferred.length, 1);

        // El proceso termina: UNA respuesta.
        Lib.Sh._engine.flush();
        h.expect("contesta a los dos que preguntaron", h.contestados, 2);
        h.expect("y no deja ningun callback retenido", h.retenidos(), 0);

        // Muchas rondas normales no dejan residuo.
        P5.DsMock.defer = false;
        for (let i = 0; i < 2000; i++)
            Lib.Sh.exec(["sh", "-c", "echo n" + (i % 7)], function () { h.contestados++ });
        h.expect("2000 comandos no retienen nada", h.retenidos(), 0);
        h.expect("y las claves quedan acotadas a los comandos distintos", h.pendientes() <= 8, true);
        h.expect("y todos fueron contestados", h.contestados, 2002);

        console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
    }
}
