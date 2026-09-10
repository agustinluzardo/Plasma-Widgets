import QtQuick
// Kirigami.Heading: a Text at one of six sizes, level 1 the largest.
Text {
    property int level: 1
    color: "#fcfcfc"
    font.pixelSize: Math.round(18 - (level - 1) * 2)
    font.weight: Font.DemiBold
}
