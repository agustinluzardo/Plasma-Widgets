pragma Singleton
import QtQuick

// Kirigami.Theme as Plasma provides it. Values are the Breeze Dark scheme, so a
// measurement here means what it will mean on the user's panel.
QtObject {
    property color textColor: "#fcfcfc"
    property color disabledTextColor: "#7f8c8d"
    property color backgroundColor: "#232629"
    property color alternateBackgroundColor: "#31363b"
    property color highlightColor: "#3daee9"
    property color highlightedTextColor: "#fcfcfc"
    property color activeTextColor: "#3daee9"
    property color linkColor: "#1d99f3"
    property color negativeTextColor: "#da4453"
    property color neutralTextColor: "#f67400"
    property color positiveTextColor: "#27ae60"
    property color hoverColor: "#3daee9"
    property font defaultFont
    property font smallFont
    Component.onCompleted: {
        defaultFont.pointSize = 10;
        smallFont.pointSize = 8;
    }
}
