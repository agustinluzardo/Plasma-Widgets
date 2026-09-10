import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Was an inline `component ChipRow:` inside the widget body. Split out because
// the body is now a singleton, and an inline component of a singleton cannot be
// instantiated from the representation files that need it.
Flow {
    id: chipRow


    // El estado del applet, uno por instancia. Lo entrega main.qml: un singleton
    // aqui seria uno para todo el escritorio, y con el widget en dos paneles el
    // segundo pisaba al primero.
    required property QtObject state
    required property string settingKey
    required property string current
    required property var options   // [{label, value}]

    width: parent ? parent.width : 0
    spacing: Theme.spacingXS

    Repeater {
        model: chipRow.options

        Rectangle {
            id: chip
            required property var modelData

            readonly property bool selected: chip.modelData.value === chipRow.current

            radius: height / 2
            height: 26
            width: chipLabel.implicitWidth + Theme.spacingM * 2
            color: chip.selected ? Theme.primary : Theme.surfaceTextHover
            border.width: chip.selected ? 0 : 1
            border.color: Theme.outline

            StyledText {
                id: chipLabel
                anchors.centerIn: parent
                text: chip.modelData.label
                font.pixelSize: Theme.fontSizeSmall
                color: chip.selected ? Theme.surface : Theme.surfaceText
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: chipRow.state.saveSetting(chipRow.settingKey, chip.modelData.value)
            }
        }
    }
}
