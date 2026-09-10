import QtQuick

// The root every Plasma 6 applet must be.
//
// The split that matters, and that this mock exists to enforce: these are
// properties OF PlasmoidItem, written with no prefix. The uppercase `Plasmoid`
// is a separate attached object - the Plasma::Applet instance - carrying title,
// icon, status, configuration, formFactor and location. Writing
// `Plasmoid.toolTipSubText:` fails with "Cannot assign to non-existent
// property", which is exactly what shipped once.
Item {
    id: root

    property Component compactRepresentation: null
    property Component fullRepresentation: null
    property Component preferredRepresentation: null
    property Component toolTipItem: null
    property string toolTipMainText: ""
    property string toolTipSubText: ""
    property int toolTipTextFormat: 0
    property bool expanded: false
    property real switchWidth: -1
    property real switchHeight: -1
    property bool activationTogglesExpanded: true
    property bool hideOnWindowDeactivate: false
    property var screen: null
}
