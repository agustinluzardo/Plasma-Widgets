import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "lib" as Lib

// What shows in the panel. This is the DMS pill, unchanged, with its root moved
// out of the Component it used to sit inside - Plasma builds a representation
// in its own context and cannot create a Component from another file's scope.
Item {
    id: pill

    // Plasma sets this on the compact representation right after creating it
    // (AppletQuickItemPrivate::createCompactRepresentationItem). It is the only
    // handle a representation gets on the applet item, and therefore the only
    // way to open or close the popup.
    property PlasmoidItem plasmoidItem

    // Opening the popup is the COMPACT REPRESENTATION'S job, not the shell's.
    //
    // This widget shipped with a comment claiming the left button "stays with
    // the panel, which is what opens the popout". It does not: CompactApplet
    // wraps the representation in a ToolTipArea and a FocusScope that handle
    // hover and keys only. Nothing in Plasma turns a click into an expansion -
    // DefaultCompactRepresentation.qml does it itself, and so must every custom
    // one. Without this, clicking the pill did nothing at all.
    //
    // `wasExpanded` is read on PRESS on purpose: an open popup closes on focus
    // loss before the click lands, so toggling against the live value would
    // reopen it immediately and the popup would look stuck.
    function togglePopup(wasExpanded) {
        if (pill.plasmoidItem)
            pill.plasmoidItem.expanded = !wasExpanded;
    }

    activeFocusOnTab: true
    Accessible.name: Plasmoid.title
    Accessible.description: pill.plasmoidItem ? pill.plasmoidItem.toolTipSubText : ""
    Accessible.role: Accessible.Button

    Keys.onPressed: event => {
        switch (event.key) {
        case Qt.Key_Space:
        case Qt.Key_Enter:
        case Qt.Key_Return:
        case Qt.Key_Select:
            pill.togglePopup(pill.plasmoidItem ? pill.plasmoidItem.expanded : false);
            event.accepted = true;
            break;
        }
    }

    // The pill is a Row, and a MouseArea anchored to fill cannot be a child of
    // one - it breaks the layout outright. So the Row lives inside an Item that
    // sizes to it, and the mouse area is the Item's, not the Row's.
    implicitWidth: pillRow.implicitWidth
    implicitHeight: pillRow.implicitHeight

    // CÓMO SE DIMENSIONA UNA REPRESENTACIÓN COMPACTA EN PLASMA.
    // El panel la coloca en un Layout y lee Layout.preferredWidth/Height.
    // implicitWidth es apenas el último recurso, y confiar en él es lo que
    // dejó a este widget con un ancho por defecto - texto cortado en uno,
    // espacio vacío sin alto en el otro.
    Layout.minimumWidth: pillRow.implicitWidth
    Layout.preferredWidth: pillRow.implicitWidth
    Layout.maximumWidth: pillRow.implicitWidth
    Layout.minimumHeight: pillRow.implicitHeight
    Layout.preferredHeight: pillRow.implicitHeight

    Row {
        id: pillRow
        anchors.centerIn: parent

        spacing: (Lib.NetState.showIcon || Lib.NetState.vpnShownInPill) && Lib.NetState.pillText !== "" ? Lib.Theme.spacingXS : 0

        Lib.DankIcon {
            visible: Lib.NetState.showIcon && !Lib.NetState.pillShowsFlag
            name: Lib.NetState.privacyMode ? "visibility_off" : Lib.NetState.iconName
            size: Lib.NetState.pillIconSize
            color: Lib.NetState.effectiveIconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Lib.StyledText {
            visible: Lib.NetState.showIcon && Lib.NetState.pillShowsFlag
            text: Lib.NetState.countryFlag
            font.family: Lib.NetState.flagFontFamily
            // Sized to sit on the same optical line as the icon it replaces.
            font.pixelSize: Lib.NetState.pillIconSize
            anchors.verticalCenter: parent.verticalCenter
        }

        Lib.DankIcon {
            visible: Lib.NetState.vpnShownInPill
            name: Lib.NetState.vpnIconName
            size: Lib.NetState.pillIconSize
            color: Lib.NetState.tintPillWhenVpn ? Lib.Theme.success : Lib.NetState.pillIconColor
            anchors.verticalCenter: parent.verticalCenter
        }

        Lib.StyledText {
            visible: Lib.NetState.vpnShownInPill && Lib.NetState.showVpnName
            text: Lib.NetState.vpnLabel
            color: Lib.NetState.tintPillWhenVpn ? Lib.Theme.success : Lib.NetState.pillTextColor
            font.pixelSize: Lib.NetState.pillTextSize
            anchors.verticalCenter: parent.verticalCenter
        }

        Lib.StyledText {
            visible: Lib.NetState.pillText !== ""
            text: Lib.NetState.pillText
            color: Lib.NetState.pillTextColor
            font.pixelSize: Lib.NetState.pillTextSize
            isMonospace: Lib.NetState.monospace
            anchors.verticalCenter: parent.verticalCenter
        }
    }


    // On DMS the host gave the plugin the right button. On Plasma the right
    // button belongs to the shell - it is how you reach "Configure..." and
    // "Remove" on a panel widget - so eating it would leave the widget with no
    // way to be configured outside panel edit mode. The secondary action moved
    // to the middle button instead, which is Plasma's own secondary-activation
    // gesture, and right-clicks are left to fall through to the containment.
    MouseArea {
        id: pillMouse

        property bool wasExpanded: false

        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onPressed: pillMouse.wasExpanded = pill.plasmoidItem ? pill.plasmoidItem.expanded : false
        onClicked: mouse => {
            if (mouse.button === Qt.MiddleButton)
                Lib.NetState.pillSecondaryAction();
            else
                pill.togglePopup(pillMouse.wasExpanded);
        }
    }
}
