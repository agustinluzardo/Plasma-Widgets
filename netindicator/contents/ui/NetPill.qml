import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import "lib" as Lib

// Lo que se ve en el panel: la pastilla de DMS, con su raiz sacada del
// Component en el que vivia.
//
// El motivo que estaba escrito aqui era falso ("Plasma no puede crear un
// Component del scope de otro archivo"). No existe esa limitacion. Lo que hacia
// invisible al otro widget esta verificado en pacman/contents/ui/main.qml.
// Sacar la raiz del Component sigue valiendo por acoplamiento, no por eso.
Item {
    id: pill


    // El estado del applet, uno por instancia. Lo entrega main.qml: un singleton
    // aqui seria uno para todo el escritorio, y con el widget en dos paneles el
    // segundo pisaba al primero.
    required property QtObject state
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
    implicitWidth: pill.isVertical ? 0 : pillRow.implicitWidth
    implicitHeight: pillRow.implicitHeight

    // CÓMO SE DIMENSIONA UNA REPRESENTACIÓN COMPACTA EN PLASMA.
    // El panel la coloca en un Layout y lee Layout.preferredWidth/Height.
    // implicitWidth es apenas el último recurso, y confiar en él es lo que
    // dejó a este widget con un ancho por defecto - texto cortado en uno,
    // espacio vacío sin alto en el otro.
    Layout.minimumWidth: pill.isVertical ? 0 : pillRow.implicitWidth
    Layout.preferredWidth: pill.isVertical ? -1 : pillRow.implicitWidth
    Layout.maximumWidth: pill.isVertical ? Number.POSITIVE_INFINITY : pillRow.implicitWidth
    Layout.minimumHeight: pillRow.implicitHeight
    Layout.preferredHeight: pillRow.implicitHeight
    Layout.maximumHeight: pill.isVertical ? pillRow.implicitHeight : Number.POSITIVE_INFINITY

    // En un panel vertical la direccion no entra: el original de DMS apila el
    // icono (o la bandera) y el de VPN, y deja el texto fuera
    // (NetIndicator.qml:849). Un Grid sirve para los dos ejes sin instanciar
    // dos pastillas.
    readonly property bool isVertical: Plasmoid.formFactor === PlasmaCore.Types.Vertical

    Grid {
        id: pillRow
        anchors.centerIn: parent
        // Cinco hijos. Con columns: 4 el quinto se iba a una segunda fila y la
        // pastilla se partia en dos. En horizontal no hay tope de columnas.
        rows: pill.isVertical ? 5 : 1
        columns: pill.isVertical ? 1 : 5
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        spacing: (pill.state.showIcon || pill.state.vpnShownInPill) && pill.state.pillText !== "" && !pill.isVertical ? Lib.Theme.spacingXS : 0

        Lib.DankIcon {
            visible: pill.state.showIcon && !pill.state.pillShowsFlag
            name: pill.state.privacyMode ? "visibility_off" : pill.state.iconName
            size: pill.state.pillIconSize
            color: pill.state.effectiveIconColor
        }

        Lib.StyledText {
            visible: pill.state.showIcon && pill.state.pillShowsFlag
            text: pill.state.countryFlag
            font.family: pill.state.flagFontFamily
            // Sized to sit on the same optical line as the icon it replaces.
            font.pixelSize: pill.state.pillIconSize
        }

        Lib.DankIcon {
            visible: pill.state.vpnShownInPill
            name: pill.state.vpnIconName
            size: pill.state.pillIconSize
            color: pill.state.tintPillWhenVpn ? Lib.Theme.success : pill.state.pillIconColor
        }

        Lib.StyledText {
            visible: !pill.isVertical && pill.state.vpnShownInPill && pill.state.showVpnName
            text: pill.state.vpnLabel
            color: pill.state.tintPillWhenVpn ? Lib.Theme.success : pill.state.pillTextColor
            font.pixelSize: pill.state.pillTextSize
        }

        Lib.StyledText {
            visible: !pill.isVertical && pill.state.pillText !== ""
            text: pill.state.pillText
            color: pill.state.pillTextColor
            font.pixelSize: pill.state.pillTextSize
            isMonospace: pill.state.monospace
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
                pill.state.pillSecondaryAction();
            else
                pill.togglePopup(pillMouse.wasExpanded);
        }
    }
}
