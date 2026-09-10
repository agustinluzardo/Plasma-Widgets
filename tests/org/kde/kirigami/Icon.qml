import QtQuick
// Kirigami.Icon: resolves a freedesktop icon name against the user's theme.
// Offscreen there is no theme, so this models its size contract only - which is
// all a layout measurement needs.
Item {
    property var source: ""
    property color color: "transparent"
    property bool isMask: false
    implicitWidth: 22
    implicitHeight: 22
}
