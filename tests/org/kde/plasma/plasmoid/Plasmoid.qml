pragma Singleton
import QtQuick

// The attached Plasma::Applet, modelled as a singleton so READS of
// Plasmoid.configuration / Plasmoid.formFactor resolve offscreen. QML cannot
// declare an attached type, so ASSIGNMENTS through it (Plasmoid.status: ...)
// are stripped by mkut-style handling in the smoke test and reported there.
QtObject {
    id: applet
    property string title: ""
    property string icon: ""
    property int status: 0
    property int formFactor: 2      // Horizontal - a bottom panel
    property int location: 4
    property var configuration: PlasmoidConfigMock
}
