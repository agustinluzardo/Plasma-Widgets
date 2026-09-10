import QtQuick
import org.kde.kirigami as Kirigami

// DMS' PopoutComponent: a header line, an optional details line, and the
// content. On Plasma this lives inside Plasmoid.fullRepresentation, which the
// panel sizes itself - so unlike on DMS, a content height change here does NOT
// resize a layer-shell surface and cannot flash. The structure is kept so the
// ported panels need no changes.
Column {
    id: root

    property string headerText: ""
    property string detailsText: ""
    property bool showCloseButton: false
    property var closePopout: null
    property var parentPopout: null
    property alias headerActions: headerActionsLoader.sourceComponent

    spacing: 0

    Item {
        id: popoutHeader
        width: parent.width
        height: visible ? Math.round(Kirigami.Units.gridUnit * 2.2) : 0
        visible: root.headerText.length > 0

        Kirigami.Heading {
            anchors.verticalCenter: parent.verticalCenter
            level: 2
            text: root.headerText
        }

        Loader {
            id: headerActionsLoader
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        id: popoutDetails
        width: parent.width
        bottomPadding: Kirigami.Units.smallSpacing * 2
        text: root.detailsText
        color: Kirigami.Theme.disabledTextColor
        font: Kirigami.Theme.smallFont
        visible: root.detailsText.length > 0
        wrapMode: Text.WordWrap
    }
}
