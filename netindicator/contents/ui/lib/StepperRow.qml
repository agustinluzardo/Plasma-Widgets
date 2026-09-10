import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Was an inline `component StepperRow:` inside the widget body. Split out because
// the body is now a singleton, and an inline component of a singleton cannot be
// instantiated from the representation files that need it.
Row {
    id: stepper

    required property string label
    required property int value
    required property int minimum
    required property int maximum
    required property string suffix
    required property var apply   // function(newValue)

    width: parent ? parent.width : 0
    height: 28
    spacing: Theme.spacingM

    StyledText {
        anchors.verticalCenter: parent.verticalCenter
        text: stepper.label
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spacingXS

        Repeater {
            model: ["minus", "value", "plus"]

            Rectangle {
                id: part

                required property string modelData

                readonly property bool isButton: part.modelData !== "value"
                readonly property int step: part.modelData === "plus" ? 1 : -1
                readonly property bool atEnd: part.modelData === "plus" ? (stepper.value >= stepper.maximum) : (stepper.value <= stepper.minimum)

                width: part.isButton ? 26 : Math.max(44, partLabel.implicitWidth + Theme.spacingM)
                height: 26
                radius: part.isButton ? height / 2 : Theme.cornerRadius / 2
                color: part.isButton ? Theme.surfaceTextHover : "transparent"
                border.width: part.isButton ? 0 : 1
                border.color: Theme.outline
                opacity: (part.isButton && part.atEnd) ? 0.35 : 1

                StyledText {
                    id: partLabel

                    anchors.centerIn: parent
                    text: part.modelData === "value" ? (stepper.value + stepper.suffix) : (part.modelData === "plus" ? "+" : "\u2212")
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeSmall
                    isMonospace: part.modelData === "value"
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: part.isButton && !part.atEnd
                    cursorShape: Qt.PointingHandCursor
                    onClicked: stepper.apply(Math.max(stepper.minimum, Math.min(stepper.maximum, stepper.value + part.step)))
                }
            }
        }
    }
}
