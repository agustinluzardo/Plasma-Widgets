import QtQuick
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import "lib" as Lib

// The full representation.
//
// This exists because Plasma REQUIRES it, not because the DMS plugin had a
// popout. AppletQuickItemPrivate::appletShouldBeExpanded() begins with:
//
//     if (!fullRepresentation) {
//         // ... the one and only representation of the plasmoid are our
//         // direct contents, so we consider it always expanded
//         return true;
//     }
//
// That check runs BEFORE preferredRepresentation is consulted, so an applet
// that declares only a compactRepresentation is treated as expanded, takes the
// full branch of compactRepresentationCheck(), gets a null item back from
// createFullRepresentationItem(), and shows nothing at all - no error, no
// warning, no representation, just an applet-shaped hole in the panel. That is
// what made this widget invisible, and why nothing changed inside PacmanStrip
// ever had any effect: the strip was never instantiated.
//
// So rather than a stub, this is the smallest popup that earns its place: the
// desktop list the strip draws, in words, reachable by keyboard (Plasma opens
// it on Enter/Space) and by accessibility tooling. Mouse clicks still go to the
// strip's own cells - CompactApplet's wrapper handles hover and keys, not
// clicks - so the panel behaviour is unchanged.
Item {
    id: popup

    // main.qml owns the PlasmoidItem and is the only place that can close the
    // popup, so the row reports the switch and lets it decide.
    signal switched()

    readonly property var desktops: {
        Lib.WorkspaceService.revision;
        return Lib.WorkspaceService.workspaces();
    }
    readonly property int focusedNum: Lib.WorkspaceService.focusedNum

    readonly property int rowHeight: Math.round(Kirigami.Units.gridUnit * 2)

    // CompactApplet's popup sizes itself from these, falling back to a fixed
    // 35x25 gridUnits when they are absent - which would be a mostly empty box.
    Layout.minimumWidth: Kirigami.Units.gridUnit * 12
    Layout.preferredWidth: Kirigami.Units.gridUnit * 14
    Layout.minimumHeight: popup.rowHeight * 2 + Kirigami.Units.smallSpacing * 2
    Layout.preferredHeight: Math.min(popup.rowHeight * Math.max(1, popup.desktops.length)
                                     + header.height + Kirigami.Units.smallSpacing * 4,
                                     Kirigami.Units.gridUnit * 24)

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Kirigami.Units.smallSpacing
        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            id: header
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            Text {
                text: "Desktops"
                color: Lib.Theme.surfaceText
                font.pixelSize: Lib.Theme.fontSizeLarge
                font.bold: true
                Layout.fillWidth: true
            }

            Text {
                text: Math.max(0, popup.focusedNum) + " / " + popup.desktops.length
                color: Lib.Theme.surfaceVariantText
                font.pixelSize: Lib.Theme.fontSizeSmall
            }
        }

        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: popup.desktops
            currentIndex: popup.focusedNum - 1
            boundsBehavior: Flickable.StopAtBounds

            delegate: Item {
                id: row

                required property int index
                required property var modelData

                readonly property bool isFocused: row.index + 1 === popup.focusedNum

                width: list.width
                height: popup.rowHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Lib.Theme.cornerRadius
                    color: row.isFocused ? Lib.Theme.withAlpha(Lib.Theme.primary, 0.18)
                         : (rowMouse.containsMouse ? Lib.Theme.surfaceTextHover : "transparent")
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Kirigami.Units.smallSpacing * 2
                    anchors.rightMargin: Kirigami.Units.smallSpacing * 2
                    spacing: Kirigami.Units.smallSpacing * 2

                    // The same two shapes the strip uses, at list scale: a
                    // filled circle for where you are, a small pellet for the
                    // rest. Drawn as rectangles rather than Shapes because at
                    // this size the arc is not readable anyway.
                    Rectangle {
                        Layout.alignment: Qt.AlignVCenter
                        implicitWidth: row.isFocused ? Kirigami.Units.gridUnit * 0.85 : Kirigami.Units.gridUnit * 0.4
                        implicitHeight: implicitWidth
                        radius: width / 2
                        color: row.isFocused ? "#FFFF00"
                             : (row.modelData.windows > 0 ? Lib.Theme.surfaceText : Lib.Theme.surfaceVariantText)
                    }

                    Text {
                        Layout.fillWidth: true
                        text: row.modelData.name
                        elide: Text.ElideRight
                        color: Lib.Theme.surfaceText
                        font.pixelSize: Lib.Theme.fontSizeMedium
                        font.bold: row.isFocused
                    }

                    Text {
                        visible: row.modelData.windows > 0
                        text: row.modelData.windows === 1 ? "1 window" : (row.modelData.windows + " windows")
                        color: Lib.Theme.surfaceVariantText
                        font.pixelSize: Lib.Theme.fontSizeSmall
                    }
                }

                MouseArea {
                    id: rowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Lib.WorkspaceService.switchTo(row.modelData.key);
                        popup.switched();
                    }
                }
            }
        }
    }
}
