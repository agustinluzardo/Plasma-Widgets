import QtQuick
import org.kde.kirigami as Kirigami

// DMS draws icons from the Material Symbols font by ligature name. Plasma draws
// them from the user's icon theme by freedesktop name, and following the icon
// theme is the whole point of porting - a widget that ignored it would stand out
// against every other thing in the panel.
//
// So: the names the plugins use are translated, and anything else is passed
// through untouched, which lets a freedesktop name typed into the settings work
// directly. Kirigami.Icon shows its own fallback for a name the theme lacks.
Kirigami.Icon {
    id: icon

    property string name: ""
    property real size: Kirigami.Units.iconSizes.smallMedium
    // No `color` here: Kirigami.Icon already has one, and redeclaring it would
    // shadow the real property and then assign it twice.

    readonly property var _map: ({
        "lan":              "network-wired",
        "wifi":             "network-wireless",
        "public":           "internet-web-browser",
        "router":           "network-server",
        "cable":            "network-wired",
        "vpn_key":          "network-vpn",
        "vpn_lock":         "network-vpn",
        "lock":             "object-locked",
        "visibility":       "view-visible",
        "visibility_off":   "view-hidden",
        "tune":             "configure",
        "refresh":          "view-refresh",
        "check":            "dialog-ok",
        "content_copy":     "edit-copy",
        "hourglass_empty":  "process-working",
        "expand_more":      "arrow-down",
        "expand_less":      "arrow-up",
        "close":            "window-close",
        "warning":          "dialog-warning",
        "error":            "dialog-error"
    })

    source: icon._map[icon.name] !== undefined ? icon._map[icon.name] : icon.name
    implicitWidth: icon.size
    implicitHeight: icon.size
    width: icon.size
    height: icon.size
}
