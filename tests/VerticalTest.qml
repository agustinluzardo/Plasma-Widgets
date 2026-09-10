// Un panel vertical.
//
// Los dos originales de DMS declaran un verticalBarPill además del horizontal
// (PacmanWorkspaces.qml:1262, NetIndicator.qml:849) y el port no se llevó
// ninguno: la tira salía horizontal, recortada al grosor de la barra. La
// auditoría de paridad no lo vio porque contaba claves de settings, no
// capacidades.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL
import "../netindicator/contents/ui" as N
import "../netindicator/contents/ui/lib" as NL

Rectangle {    id: h


    // NetState ya no es un singleton: es uno por applet. El test crea el suyo,
    // igual que main.qml.
    NL.NetState { id: estado }
    width: 60; height: 420; color: "#101216"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    // Como hace el contenedor del panel cuando es vertical: fuerza el ancho al
    // grosor de la barra y toma el alto de los hints.
    ColumnLayout {
        anchors.fill: parent
        P.PacmanStrip { id: tira; Layout.fillWidth: true }
        N.NetPill { state: estado; id: pastilla; Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
    }

    Component.onCompleted: {
        Plasmoid.formFactor = PlasmaCore.Types.Vertical;
        PlasmoidConfigMock.slotBackground = "rails";
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c","d","e"]; i.desktopNames = ["","","","",""];
        i.numberOfDesktops = 5; i.currentDesktop = "c";
        settle.start();
    }

    Timer {
        id: settle; interval: 500
        onTriggered: {
            h.expect("la tira sabe que el panel es vertical", tira.isVertical, true);
            h.expect("y mide el grosor a lo ancho", Math.round(tira.barThickness), Math.round(tira.width));
            h.expect("los slots se apilan", tira.stripBoxHeight > tira.stripBoxWidth, true);
            h.expect("y son cinco", tira.slotCount, 5);
            h.expect("el alto pedido alcanza para los cinco",
                     tira.Layout.preferredHeight >= tira.cellSize * 5, true);
            h.expect("y el ancho no se clava a una celda",
                     tira.Layout.maximumWidth === Number.POSITIVE_INFINITY, true);
            h.expect("en horizontal si se clava",
                     tira.Layout.maximumHeight === Number.POSITIVE_INFINITY, false);
            h.expect("la pastilla tambien sabe que es vertical", pastilla.isVertical, true);
            h.expect("y no se clava a un ancho propio",
                     pastilla.Layout.maximumWidth === Number.POSITIVE_INFINITY, true);
            h.expect("ni declara ancho implicito", pastilla.implicitWidth, 0);

            // El Binding que le pasa la orientacion al estado vive en main.qml,
            // asi que hay que construir el applet, no solo la pastilla.
            const c = Qt.createComponent("../netindicator/contents/ui/main.qml");
            const applet = c.createObject(h);
            h.expect("el applet se construye", applet !== null, true);
            h.expect("y le pasa la orientacion a SU estado", applet.netState.isVertical, true);
            console.log("   " + tira.diagnostic);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
