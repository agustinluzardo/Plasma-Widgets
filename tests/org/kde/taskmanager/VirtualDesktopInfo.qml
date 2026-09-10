import QtQuick
// libtaskmanager's VirtualDesktopInfo. currentDesktop is a QVariant: a STRING
// id on Wayland, a uint on X11 - modelled here as the Wayland shape, which is
// the one that breaks code assuming a number.
QtObject {
    id: info

    property var currentDesktop: ""
    property int numberOfDesktops: 0
    property var desktopIds: []
    property var desktopNames: []
    property int desktopLayoutRows: 1

    // El escritorio actual POR SALIDA. En el de verdad esto es
    // currentDesktops[outputName], que llena PlasmaVirtualDesktop::
    // outputEntered; una pantalla sin entrada propia cae al global.
    property var currentDesktops: ({})

    signal currentDesktopForScreenChanged(string screenName)

    function currentDesktopByScreenName(screenName) {
        const v = info.currentDesktops[screenName];
        return (v === undefined) ? info.currentDesktop : v;
    }

    // Para los tests: fija el escritorio de una pantalla y avisa como el de
    // verdad.
    function _setForScreen(screenName, id) {
        const m = {};
        const k = Object.keys(info.currentDesktops);
        for (let i = 0; i < k.length; i++) m[k[i]] = info.currentDesktops[k[i]];
        m[screenName] = id;
        info.currentDesktops = m;
        info.currentDesktopForScreenChanged(screenName);
    }
}
