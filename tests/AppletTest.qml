// The path Plasma actually takes, which no other test here covered.
//
// Every render test instantiates PacmanStrip DIRECTLY. Plasma never does that:
// it takes main.qml's `compactRepresentation` Component, creates it, reparents
// it into the shell's CompactApplet, and assigns anchors.fill from JavaScript.
// A widget that draws when built by hand and draws nothing when built that way
// is exactly the symptom, so this test builds it that way and counts pixels.
//
// Mirrors plasma-desktop desktoppackage/contents/applet/CompactApplet.qml:
//     compactRepresentation.anchors.fill = null
//     compactRepresentation.parent = compactRepresentationParent
//     compactRepresentation.anchors.fill = compactRepresentationParent
// and containments/panel/main.qml, which drives the applet's width from the
// representation's Layout hints and pins its height to the panel thickness.
import QtQuick
import QtQuick.Layouts
import "../pacman/contents/ui/lib" as Lib

Rectangle {
    id: h
    width: 420; height: 60
    color: "#000000"

    property int checks: 0
    property int failures: 0
    function expect(label, actual, wanted) {
        checks++;
        const ok = actual === wanted;
        if (!ok) failures++;
        console.log((ok ? "PASS " : "FAIL ") + label + " = " + JSON.stringify(actual) + (ok ? "" : " (expected " + JSON.stringify(wanted) + ")"));
    }

    property var plasmoidItem: null
    property var strip: null

    // AppletQuickItemPrivate::appletShouldBeExpanded(), transcribed from
    // libplasma/src/plasmaquick/appletquickitem.cpp. The order of these checks
    // is the whole point: the null-fullRepresentation case wins BEFORE
    // preferredRepresentation is consulted, so a compact-only applet is treated
    // as expanded and Plasma then renders nothing at all.
    function appletShouldBeExpanded(item, formFactor) {
        if (!item.fullRepresentation)
            return true;
        if (item.switchWidth > 0 && item.switchHeight > 0)
            return item.width > item.switchWidth && item.height > item.switchHeight;
        if (item.preferredRepresentation)
            return item.preferredRepresentation === item.fullRepresentation;
        // 2 = Horizontal, 3 = Vertical
        return formFactor !== 2 && formFactor !== 3;
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // AppletQuickItem. The panel gives it the full thickness and takes its
        // width from the representation's propagated hints.
        Item {
            id: appletQuickItem
            Layout.fillHeight: true
            Layout.minimumWidth: 0
            Layout.preferredWidth: -1

            // CompactApplet's FocusScope, which is what the representation is
            // actually reparented into - not the applet item itself.
            FocusScope {
                id: compactRepresentationParent
                anchors.fill: parent
            }
        }
        Item { Layout.fillWidth: true }
    }

    Component.onCompleted: {
        const info = Lib.WorkspaceService._info;
        info.desktopIds = ["a", "b", "c", "d"];
        info.desktopNames = ["", "", "", ""];
        info.numberOfDesktops = 4;
        info.currentDesktop = "b";

        const c = Qt.createComponent("../pacman/contents/ui/main.qml");
        if (c.status === Component.Error) {
            console.log("FAIL main.qml no compila: " + c.errorString());
            h.failures++;
            return;
        }
        h.plasmoidItem = c.createObject(h);
        if (!h.plasmoidItem) {
            console.log("FAIL main.qml no instancia");
            h.failures++;
            return;
        }
        h.plasmoidItem.visible = false;

        const rep = h.plasmoidItem.compactRepresentation;
        if (!rep) {
            console.log("FAIL compactRepresentation es null");
            h.failures++;
            return;
        }
        // Plasma calls beginCreate/completeCreate; createObject is the QML-side
        // equivalent and uses the same creation context.
        h.strip = rep.createObject(compactRepresentationParent);
        if (!h.strip) {
            console.log("FAIL la representacion no instancia: " + rep.errorString());
            h.failures++;
            return;
        }
        h.strip.anchors.fill = null;
        h.strip.parent = compactRepresentationParent;
        h.strip.anchors.fill = compactRepresentationParent;
        h.strip.visible = true;

        // What AppletQuickItemPrivate::propagateSizeHint does, in QML.
        appletQuickItem.Layout.minimumWidth = Qt.binding(() => h.strip.Layout.minimumWidth);
        appletQuickItem.Layout.preferredWidth = Qt.binding(() => h.strip.Layout.preferredWidth);
        appletQuickItem.Layout.maximumWidth = Qt.binding(() => h.strip.Layout.maximumWidth);

        // The check that matters, made before anything is drawn: a bottom
        // panel must resolve to the COMPACT representation. It did not, and
        // that is why seven rounds of changes inside PacmanStrip.qml had no
        // effect - the strip was never instantiated.
        h.expect("en un panel horizontal se usa la representacion compacta",
                 h.appletShouldBeExpanded(h.plasmoidItem, 2), false);
        h.expect("y hay una representacion completa declarada",
                 h.plasmoidItem.fullRepresentation !== null, true);

        settle.start();
    }

    Timer {
        id: settle
        interval: 700
        onTriggered: {
            console.log("   " + (h.strip ? h.strip.diagnostic : "sin tira"));
            h.expect("el applet recibe la altura del panel", appletQuickItem.height, 60);
            h.expect("la tira llena el applet", Math.round(h.strip.height), 60);
            h.expect("y no queda con ancho cero", h.strip.width > 8, true);
            h.expect("el applet hereda el ancho de la tira",
                     Math.round(appletQuickItem.width) === Math.round(h.strip.Layout.preferredWidth), true);
            h.expect("la tira sigue visible", h.strip.visible, true);
            h.expect("y con opacidad completa", h.strip.opacity, 1);
            // The popup Plasma demands has to be a real one: CompactApplet
            // falls back to a 35x25 gridUnit empty box when it reports no size.
            const full = h.plasmoidItem.fullRepresentation.createObject(h);
            h.expect("la representacion completa instancia", full !== null, true);
            if (full) {
                h.expect("y declara un ancho propio", full.Layout.preferredWidth > 0, true);
                h.expect("y un alto propio", full.Layout.preferredHeight > 0, true);
                full.destroy();
            }
            console.log("=== " + h.checks + " checks, " + (h.failures === 0 ? "TODO PASA" : h.failures + " FALLAS") + " ===");
        }
    }
}
