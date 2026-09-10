pragma Singleton
import QtQuick

// plasmoid.configuration with the REAL defaults from both main.xml schemas.
// Zeroed values made the strip compute one slot and a ten-pixel cell, which is
// not what a fresh install looks like.
QtObject {
    property string animationStyle: "arcade"
    property bool animations: true
    property bool autoIconSize: true
    property bool autoSpacing: true
    property bool debugOverlay: false
    property bool mouthPellet: true
    property string slotBackground: "none"
    property string slotBackgroundColorMode: "auto"
    property color slotBackgroundColor: "#2121DE"
    property string colorMode: "theme"
    property color customColor: "#FFFFFF"
    property bool frightenedGhosts: false
    property string ghostColorMode: "workspace"
    property string ghostMode: "behind"
    property string ghostMotion: "arcade"
    property string iconColorMode: "match"
    property color iconCustomColor: "#FFFFFF"
    property string iconName: "lan"
    property int iconOffset: 0
    property int iconSizeOverride: 21
    property string latencyMode: "gateway"
    property string localIpSource: "lan"
    property bool lookupIpv6: true
    property bool lookupPublic: true
    property int maxSlots: 10
    property int textOffset: 0
    property bool monospace: true
    property string palette: "arcade"
    property int pelletSize: 30
    property bool perMonitor: true
    property string pillContent: "localIp"
    property string pillIconMode: "icon"
    property string pingTarget: "1.1.1.1"
    property string publicProvider: "https://ipinfo.io/json"
    property int refreshSeconds: 300
    property bool scrollReversed: false
    property bool scrollToSwitch: true
    property bool showCountryFlag: true
    property bool showDistroLogo: true
    property bool showGateway: true
    property bool showIcon: true
    property bool showIsp: true
    property bool showLatency: true
    property bool showLocalSection: true
    property bool showLocation: true
    property bool showPublicSection: true
    property bool showTunnelSection: true
    property bool showVpnInPill: true
    property bool showVpnName: false
    property bool showVpnSection: true
    property int spacingOverride: 6
    property bool startPrivate: false
    property bool tintPillWhenVpn: true
    property string vpnIconName: "vpn_key"
    property bool vpnSingleActive: true
    property int workspaceCount: 5
}
