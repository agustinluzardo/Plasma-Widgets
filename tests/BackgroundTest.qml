// El fondo del slot y los rieles, que el port no tenía.
//
// Se cambian los ajustes en el mock de Plasmoid.configuration, que es de donde
// el widget los lee de verdad, y al final se deja la tira con los rieles en un
// naranja inconfundible: run.sh cuenta los píxeles DE ESE COLOR. Que haya
// píxeles pintados no diría nada, la tira ya dibuja sprites.
import QtQuick
import org.kde.plasma.plasmoid
import "../pacman/contents/ui" as P
import "../pacman/contents/ui/lib" as PL

Rectangle {
    id: h
    width: 300; height: 60; color: "#000000"

    property int checks: 0
    property int failures: 0
    function expect(l, a, w) {
        checks++; const ok = a === w; if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + l + " = " + JSON.stringify(a) + (ok ? "" : " (esperado " + JSON.stringify(w) + ")"));
    }

    P.PacmanStrip { id: strip; anchors.centerIn: parent; height: 40 }

    Component.onCompleted: {
        const i = PL.WorkspaceService._info;
        i.desktopIds = ["a","b","c"]; i.desktopNames = ["","",""];
        i.numberOfDesktops = 3; i.currentDesktop = "b";
        settle.start();
    }

    Timer {
        id: settle; interval: 450
        onTriggered: {
            const cfg = PlasmoidConfigMock;

            h.expect("por defecto no hay fondo", strip.slotBackground, "none");
            h.expect("ni corredor ni rieles", strip.hasSlotBackground, false);
            const bareW = strip.stripBoxWidth;
            const bareH = strip.stripBoxHeight;

            cfg.slotBackground = "corridor";
            h.expect("el corredor ensancha la tira", strip.stripBoxWidth > bareW, true);
            h.expect("y la hace más alta", strip.stripBoxHeight > bareH, true);
            h.expect("cuenta como corredor", strip.hasCorridor, true);
            h.expect("pero no como rieles", strip.hasRails, false);

            cfg.slotBackground = "corridorTint";
            h.expect("el relleno también es corredor", strip.hasCorridor, true);

            cfg.slotBackground = "rails";
            h.expect("los rieles son fondo", strip.hasSlotBackground, true);
            h.expect("y no corredor", strip.hasCorridor, false);
            h.expect("el riel tiene grosor", strip.railThickness >= 1, true);
            h.expect("los rieles no ensanchan", strip.stripBoxWidth, bareW);
            h.expect("pero sí dejan sitio arriba y abajo", strip.stripBoxHeight > bareH, true);

            h.expect("automático da el azul de cabina", String(strip.corridorColor).toUpperCase(), "#2121DE");
            cfg.slotBackgroundColorMode = "custom";
            cfg.slotBackgroundColor = "#ff8800";
            h.expect("custom lo pisa", String(strip.corridorColor).toUpperCase(), "#FF8800");
            cfg.slotBackgroundColorMode = "auto";
            h.expect("y volver a automático lo descarta", String(strip.corridorColor).toUpperCase(), "#2121DE");

            cfg.animations = true;
            h.expect("con animaciones la boca se mueve", strip.animationsOn, true);
            cfg.animations = false;
            h.expect("sin animaciones se congela", strip.animationsOn, false);
            h.expect("y lleva pellet por defecto", strip.mouthPellet, true);
            cfg.mouthPellet = false;
            h.expect("se puede dejar la boca vacía", strip.mouthPellet, false);

            // Estado final para el conteo de píxeles: rieles naranjas.
            cfg.mouthPellet = true;
            cfg.animations = true;
            cfg.slotBackgroundColorMode = "custom";
            cfg.slotBackgroundColor = "#ff8800";
            console.log("   " + strip.diagnostic);
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
