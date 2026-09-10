import QtQuick
import org.kde.plasma.plasmoid
import "lib" as Lib

// Pac-Man Workspaces. Only names the representations; each one is a
// self-contained file that reads WorkspaceService and Plasmoid.configuration
// itself, so no representation reaches into another file's scope.
//
// BOTH representations are declared on purpose, and the widget is invisible
// without the full one. libplasma's appletShouldBeExpanded() opens with
// `if (!fullRepresentation) return true;` - before preferredRepresentation is
// even looked at - so an applet declaring only a compactRepresentation is
// considered expanded, asks for a full representation that does not exist, gets
// nullptr, and renders nothing at all: no error, no warning, no fallback icon.
// See DesktopList.qml.
PlasmoidItem {
    id: root

    preferredRepresentation: compactRepresentation
    compactRepresentation: PacmanStrip {}
    fullRepresentation: DesktopList {
        onSwitched: root.expanded = false
    }

    toolTipMainText: "Desktops"
    toolTipSubText: "Desktop " + Math.max(1, Lib.WorkspaceService.focusedNum)
                  + " of " + Math.max(1, Lib.WorkspaceService.count)
}
