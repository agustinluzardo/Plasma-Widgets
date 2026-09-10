import QtQuick
// libtaskmanager's VirtualDesktopInfo. currentDesktop is a QVariant: a STRING
// id on Wayland, a uint on X11 - modelled here as the Wayland shape, which is
// the one that breaks code assuming a number.
QtObject {
    property var currentDesktop: ""
    property int numberOfDesktops: 0
    property var desktopIds: []
    property var desktopNames: []
    property int desktopLayoutRows: 1
}
