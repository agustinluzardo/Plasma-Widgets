// Que un clic haga algo.
//
// El pill de red se instalaba, se dibujaba, reportaba su tamaño y no abría
// nada: abrir el popup es tarea de la representación compacta, no del shell.
// Ningún test lo veía porque todos los demás miran píxeles y tamaños.
// Este construye el applet por el camino de Plasma - incluida la asignación de
// `plasmoidItem`, que es el único asidero que la representación recibe - y
// afirma qué hace cada botón.
import QtQuick
import "../pacman/contents/ui" as P
import "../netindicator/contents/ui" as N
import "../netindicator/contents/ui/lib" as NL
import "../pacman/contents/ui/lib" as PL

Rectangle {
    id: h
    width: 300; height: 60; color: "#101216"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    property var plasmoidItem: null
    property var pill: null

    // La tira de Pac-Man: el clic izquierdo cambia de escritorio, no abre nada.
    P.PacmanStrip { id: strip; height: 40; visible: false }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c"]; i.desktopNames = ["","",""];
        i.numberOfDesktops = 3; i.currentDesktop = "a";

        const c = Qt.createComponent("../netindicator/contents/ui/main.qml");
        if (c.status === Component.Error) {
            console.log("FAIL netindicator/main.qml: " + c.errorString()); h.failures++; return;
        }
        h.plasmoidItem = c.createObject(h);
        h.plasmoidItem.visible = false;
        h.pill = h.plasmoidItem.compactRepresentation.createObject(h);
        h.pill.visible = false;
        // Exactamente lo que hace createCompactRepresentationItem().
        h.pill.plasmoidItem = h.plasmoidItem;
        settle.start();
    }

    Timer {
        id: settle; interval: 500
        onTriggered: {
            h.expect("el pill recibe el plasmoidItem", h.pill.plasmoidItem === h.plasmoidItem, true);
            h.expect("arranca cerrado", h.plasmoidItem.expanded, false);

            h.pill.togglePopup(false);
            h.expect("un clic abre el popup", h.plasmoidItem.expanded, true);

            // Con el popup abierto, el clic siguiente llega despues de que el
            // popup se cerro por perdida de foco: el estado se lee en el press.
            h.pill.togglePopup(true);
            h.expect("y el siguiente lo cierra", h.plasmoidItem.expanded, false);

            // El boton del medio es la accion secundaria, no el popup.
            const before = NL.NetState.showingTunnelIp;
            NL.NetState.pillSecondaryAction();
            h.expect("el boton del medio no toca el popup", h.plasmoidItem.expanded, false);

            // Y la tira sigue cambiando de escritorio con el izquierdo.
            h.expect("la tira acepta el clic izquierdo", strip.slotCount >= 3, true);

            // Los controles del panel: los chips llaman a NetState.saveSetting,
            // que solo hablaba con `pluginService` - el objeto de DMS, null en
            // Plasma - asi que todos se dibujaban y ninguno hacia nada.
            h.expect("main.qml inyecto el guardado", typeof NL.NetState.savePluginData, "function");
            NL.NetState.saveSetting("pillContent", "publicIp");
            h.expect("un chip cambia el ajuste de verdad",
                     h.plasmoidItem.Plasmoid.configuration.pillContent, "publicIp");
            NL.NetState.saveSetting("iconOffset", 4);
            h.expect("y el stepper tambien",
                     h.plasmoidItem.Plasmoid.configuration.iconOffset, 4);
            NL.NetState.saveSetting("textOffset", 5);
            h.expect("incluido el tamaño de texto nuevo",
                     h.plasmoidItem.Plasmoid.configuration.textOffset, 5);

            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
