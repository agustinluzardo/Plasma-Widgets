import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Was an inline `component VpnButton:` inside the widget body. Split out because
// the body is now a singleton, and an inline component of a singleton cannot be
// instantiated from the representation files that need it.
Rectangle {
    id: vpnBtn

    required property bool on
    required property bool busy
    property bool enabled: true
    signal activated

    radius: height / 2
    height: 26
    // Held at the width of the longer of the two labels it can show.
    width: Math.max(labelRow.implicitWidth, widest.implicitWidth) + Theme.spacingM * 2
    color: vpnBtn.on ? Theme.primary : Theme.surfaceTextHover
    border.width: vpnBtn.on ? 0 : 1
    border.color: vpnBtn.on ? "transparent" : Theme.outline
    opacity: vpnBtn.enabled ? 1 : 0.45

    StyledText {
        id: widest
        visible: false
        text: "Disconnect"
        font.pixelSize: Theme.fontSizeSmall
    }

    Row {
        id: labelRow
        anchors.centerIn: parent
        spacing: Theme.spacingXS

        DankIcon {
            visible: vpnBtn.busy
            name: "hourglass_empty"
            size: Theme.fontSizeSmall + 2
            color: vpnBtn.on ? Theme.surface : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter

            RotationAnimation on rotation {
                running: vpnBtn.busy
                loops: Animation.Infinite
                from: 0
                to: 360
                duration: 1200
            }
        }

        StyledText {
            text: vpnBtn.busy ? "…" : (vpnBtn.on ? "Disconnect" : "Connect")
            font.pixelSize: Theme.fontSizeSmall
            color: vpnBtn.on ? Theme.surface : Theme.surfaceText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    MouseArea {
        id: vpnBtnArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: vpnBtn.enabled && !vpnBtn.busy
        cursorShape: Qt.PointingHandCursor
        onClicked: vpnBtn.activated()
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.surfaceText
        opacity: vpnBtnArea.containsMouse && vpnBtn.enabled ? 0.08 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }
}
