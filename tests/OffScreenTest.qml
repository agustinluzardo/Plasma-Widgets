// Los relojes tienen que parar cuando no se ve.
//
// Item.visible NO alcanza: medido, se queda en `true` cuando la ventana se
// esconde — que es exactamente lo que hace PanelView::setVisible(false) al
// auto-ocultar el panel o al esquivar ventanas. Así que la tira animaba a 130 ms
// detrás de un panel que no estaba.
//
// El caso de una ventana a pantalla completa tapando un panel siempre visible
// no se puede ver desde QML: la ventana del panel sigue mapeada. Eso no se
// intenta adivinar aquí.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL
import "../netindicator/contents/ui" as N
import "../netindicator/contents/ui/lib" as NL

Rectangle {
    id: h
    width: 300; height: 44; color: "#101216"

    property int checks: 0
    property double sondaAntes: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    // NetIndicator pesa mas: cada ciclo lanza nmcli, ip y curl. La pastilla es
    // la que vive en el panel, asi que es la que le dice al estado si se ve.
    NL.NetState { id: estado }

    // El caso que NO tiene que parar: el widget en el escritorio (formato
    // Planar), donde Plasma no crea representacion compacta y por lo tanto no
    // hay NetPill que cablee nada. El valor de fabrica tiene que dejar la sonda
    // corriendo; un default al reves apagaria la sonda del widget de escritorio
    // para siempre y sin un solo error.
    NL.NetState { id: suelto }

    RowLayout {
        anchors.fill: parent
        P.PacmanStrip { id: tira; Layout.fillHeight: true }
        N.NetPill { id: pastilla; state: estado; Layout.fillHeight: true }
        Item { Layout.fillWidth: true }
    }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c"]; i.desktopNames = ["","",""];
        i.numberOfDesktops = 3; i.currentDesktop = "b";
        paso1.start();
    }

    Timer {
        id: paso1; interval: 350
        onTriggered: {
            h.expect("con la ventana a la vista, se considera en pantalla", tira.onScreen, true);
            h.expect("y el reloj de sprites corre", tira.spriteClockRunning, true);
            h.expect("Item.visible tambien es true", tira.visible, true);
            h.expect("y la sonda de red corre", estado.refreshTimerRunning, true);
            h.expect("un estado sin pastilla se considera a la vista", suelto.onScreen, true);
            h.expect("y su sonda corre igual", suelto.refreshTimerRunning, true);

            // Para poder distinguir "no refresco porque no se ve" de "no
            // refresco porque no toca": se marca como recien sondeado.
            estado.lastRefreshMs = Date.now();
            h.sondaAntes = estado.lastRefreshMs;

            // Lo que hace PanelView al esconder el panel.
            h.Window.window.visible = false;
            paso2.start();
        }
    }

    Timer {
        id: paso2; interval: 350
        onTriggered: {
            h.expect("Item.visible NO se entera de nada", tira.visible, true);
            h.expect("pero onScreen si", tira.onScreen, false);
            h.expect("y el reloj de sprites para", tira.spriteClockRunning, false);
            h.expect("y la sonda de red tambien", estado.refreshTimerRunning, false);
            h.expect("pero el del escritorio sigue sondeando", suelto.refreshTimerRunning, true);

            h.Window.window.visible = true;
            paso3.start();
        }
    }

    Timer {
        id: paso3; interval: 350
        onTriggered: {
            h.expect("al volver, vuelve a estar en pantalla", tira.onScreen, true);
            h.expect("y el reloj arranca de nuevo", tira.spriteClockRunning, true);
            h.expect("y la sonda de red vuelve a correr", estado.refreshTimerRunning, true);

            // Y reaparecer no es una sonda: un panel con auto-ocultar se muestra
            // cada vez que el puntero roza el borde. Solo se recupera el tick
            // que se perdio, y hace un segundo no se perdio ninguno.
            h.expect("volver no dispara un ciclo si no tocaba",
                     estado.lastRefreshMs, h.sondaAntes);

            // Con el tick vencido si tiene que recuperarlo.
            estado.lastRefreshMs = Date.now() - 10 * 60 * 1000;
            h.Window.window.visible = false;
            paso4.start();
        }
    }

    Timer {
        id: paso4; interval: 350
        onTriggered: {
            h.Window.window.visible = true;
            paso5.start();
        }
    }

    Timer {
        id: paso5; interval: 350
        onTriggered: {
            h.expect("pero con el tick vencido si lo recupera",
                     Date.now() - estado.lastRefreshMs < 5000, true);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
