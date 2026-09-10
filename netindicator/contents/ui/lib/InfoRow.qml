import QtQuick
import QtQuick.Shapes
import org.kde.kirigami as Kirigami

// Was an inline `component InfoRow:` inside the widget body. Split out because
// the body is now a singleton, and an inline component of a singleton cannot be
// instantiated from the representation files that need it.
Row {
    id: infoRow

    required property string label
    required property string value
    property bool copyable: true
    property string hint: ""
    // An IPv6 address does not fit the value column; wrapping is better than
    // showing two thirds of an address the user came here to read.
    property bool wrap: false
    property bool justCopied: false

    width: parent ? parent.width : 0
    spacing: Theme.spacingS

    // The value is the only flexible column, so every fixed column has to be
    // subtracted from it - including the hint. Leaving the hint out of this
    // is what pushed it off the edge of the popout.
    readonly property real labelWidth: NetState.infoLabelWidth
    // The copy slot is always laid out and only its contents come and go. It
    // used to appear with the value, and being 22px tall it took the row
    // from 14px to 22px - so a row filling in resized the popup window. It
    // lines the columns up across rows as a side effect.
    readonly property bool copyShown: infoRow.copyable && infoRow.value !== ""
    readonly property real copyWidth: 22
    readonly property real hintWidth: infoRow.hint !== "" ? hintText.implicitWidth : 0
    readonly property int gapCount: 2 + (infoRow.hint !== "" ? 1 : 0)

    StyledText {
        text: infoRow.label
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        width: infoRow.labelWidth
        anchors.verticalCenter: parent.verticalCenter
    }

    StyledText {
        text: infoRow.value || "—"
        color: Theme.surfaceText
        font.pixelSize: Theme.fontSizeSmall
        isMonospace: NetState.monospace
        elide: infoRow.wrap ? Text.ElideNone : Text.ElideRight
        wrapMode: infoRow.wrap ? Text.WrapAnywhere : Text.NoWrap
        maximumLineCount: infoRow.wrap ? 2 : 1
        width: Math.max(0, infoRow.width - infoRow.labelWidth - infoRow.hintWidth - infoRow.copyWidth - infoRow.spacing * infoRow.gapCount)
        anchors.verticalCenter: parent.verticalCenter
    }

    StyledText {
        id: hintText

        text: infoRow.hint
        visible: infoRow.hint !== ""
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall - 1
        anchors.verticalCenter: parent.verticalCenter
    }

    Item {
        width: 22
        height: 22
        anchors.verticalCenter: parent.verticalCenter

        DankIcon {
            anchors.centerIn: parent
            visible: infoRow.copyShown
            name: infoRow.justCopied ? "check" : "content_copy"
            size: 14
            color: infoRow.justCopied ? Theme.primary : (copyArea.containsMouse ? Theme.primary : Theme.surfaceVariantText)
        }

        Timer {
            id: copiedTimer
            interval: 1400
            onTriggered: infoRow.justCopied = false
        }

        MouseArea {
            id: copyArea

            anchors.fill: parent
            // Not merely disabled: a disabled MouseArea still applies its
            // cursor, so a row with nothing to copy showed a pointing hand
            // and then did nothing when clicked. An invisible one is not hit
            // tested and sets no cursor.
            visible: infoRow.copyShown
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                NetState.copyValue(infoRow.label, infoRow.value)
                infoRow.justCopied = true
                copiedTimer.restart()
            }
        }
    }
}
