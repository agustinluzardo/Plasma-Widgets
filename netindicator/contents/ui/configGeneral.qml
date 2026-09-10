import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// The settings page, with the same 33 keys, labels and defaults the widget had
// on DMS - so a value means the same thing on both. Plasma binds a control to a
// stored key through a `cfg_<key>` property on this page; the combo boxes need
// the two-way form because ComboBox has no single property that is both the
// stored value and the selection.
// Wrapped in a SimpleKCM so the page scrolls. A bare FormLayout makes the
// config dialog open at the height of its content, and with 33 settings that is
// taller than the dialog - everything past the bottom edge is unreachable until
// the window is resized by hand.
KCM.SimpleKCM {
    id: kcmRoot

    // A scroll bar is drawn OVER the content, so the form has to leave room for
    // it or it covers the right-hand edge of every row.
    rightPadding: Kirigami.Units.gridUnit * 2

    property string cfg_pillContent
    property string cfg_colorMode
    property alias cfg_customColor: customColorBox.text
    property string cfg_iconColorMode
    property alias cfg_iconCustomColor: iconCustomColorBox.text
    property alias cfg_showIcon: showIconBox.checked
    property string cfg_pillIconMode
    property alias cfg_iconName: iconNameBox.text
    property alias cfg_iconOffset: iconOffsetBox.value
    property alias cfg_textOffset: textOffsetBox.value
    property alias cfg_monospace: monospaceBox.checked
    property alias cfg_showPublicSection: showPublicSectionBox.checked
    property alias cfg_showIsp: showIspBox.checked
    property alias cfg_showLocation: showLocationBox.checked
    property alias cfg_showLocalSection: showLocalSectionBox.checked
    property alias cfg_showGateway: showGatewayBox.checked
    property alias cfg_showLatency: showLatencyBox.checked
    property alias cfg_showDistroLogo: showDistroLogoBox.checked
    property alias cfg_showCountryFlag: showCountryFlagBox.checked
    property alias cfg_showVpnSection: showVpnSectionBox.checked
    property string cfg_localIpSource
    property alias cfg_showTunnelSection: showTunnelSectionBox.checked
    property alias cfg_showVpnInPill: showVpnInPillBox.checked
    property alias cfg_showVpnName: showVpnNameBox.checked
    property alias cfg_tintPillWhenVpn: tintPillWhenVpnBox.checked
    property alias cfg_vpnSingleActive: vpnSingleActiveBox.checked
    property alias cfg_vpnIconName: vpnIconNameBox.text
    property alias cfg_startPrivate: startPrivateBox.checked
    property alias cfg_lookupPublic: lookupPublicBox.checked
    property alias cfg_lookupIpv6: lookupIpv6Box.checked
    property alias cfg_publicProvider: publicProviderBox.text
    property string cfg_latencyMode
    property alias cfg_pingTarget: pingTargetBox.text
    property alias cfg_refreshSeconds: refreshSecondsBox.value

    Kirigami.FormLayout {
        id: page


        QQC2.ComboBox {
            id: pillContentBox
            Kirigami.FormData.label: "Show:"
            textRole: "text"
            valueRole: "value"
            model: [{"text": "Local IP", "value": "localIp"}, {"text": "Public IP", "value": "publicIp"}, {"text": "Gateway", "value": "gateway"}, {"text": "Interface", "value": "interface"}, {"text": "Wi-Fi network", "value": "ssid"}, {"text": "Icon only", "value": "none"}]
            onActivated: cfg_pillContent = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_pillContent)
            // The stored value is the source of truth; if it was changed
            // elsewhere the box follows rather than overwriting it.
            Connections {
                target: kcmRoot
                function oncfg_pillContentChanged() { pillContentBox.currentIndex = pillContentBox.indexOfValue(kcmRoot.cfg_pillContent) }
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "What the pill prints next to the icon." }

        QQC2.ComboBox {
            id: colorModeBox
            Kirigami.FormData.label: "Text colour:"
            textRole: "text"
            valueRole: "value"
            model: [{"text": "Follow theme", "value": "theme"}, {"text": "White", "value": "white"}, {"text": "Accent", "value": "accent"}, {"text": "Custom", "value": "custom"}]
            onActivated: cfg_colorMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_colorMode)
            // The stored value is the source of truth; if it was changed
            // elsewhere the box follows rather than overwriting it.
            Connections {
                target: kcmRoot
                function oncfg_colorModeChanged() { colorModeBox.currentIndex = colorModeBox.indexOfValue(kcmRoot.cfg_colorMode) }
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Colours the address printed in the pill. Theme follows your bar's text colour; Custom uses the colour picked below." }

        RowLayout {
            Kirigami.FormData.label: "Custom text colour:"
            QQC2.TextField { id: customColorBox; Layout.preferredWidth: Kirigami.Units.gridUnit * 8; placeholderText: "#RRGGBB" }
            Rectangle {
                width: Kirigami.Units.gridUnit * 1.5; height: width; radius: 3
                border.width: 1; border.color: Kirigami.Theme.disabledTextColor
                // An unfinished value must not paint an error; it just shows
                // nothing until it parses.
                color: /^#[0-9A-Fa-f]{6}$/.test(customColorBox.text) ? customColorBox.text : "transparent"
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Used when Text colour is set to Custom." }

        QQC2.ComboBox {
            id: iconColorModeBox
            Kirigami.FormData.label: "Icon colour:"
            textRole: "text"
            valueRole: "value"
            model: [{"text": "Match text", "value": "match"}, {"text": "Follow theme", "value": "theme"}, {"text": "White", "value": "white"}, {"text": "Accent", "value": "accent"}, {"text": "Custom", "value": "custom"}]
            onActivated: cfg_iconColorMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_iconColorMode)
            // The stored value is the source of truth; if it was changed
            // elsewhere the box follows rather than overwriting it.
            Connections {
                target: kcmRoot
                function oncfg_iconColorModeChanged() { iconColorModeBox.currentIndex = iconColorModeBox.indexOfValue(kcmRoot.cfg_iconColorMode) }
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Colours the icon on its own. Match text keeps it locked to the address colour, which is how it behaved before this setting existed." }

        RowLayout {
            Kirigami.FormData.label: "Custom icon colour:"
            QQC2.TextField { id: iconCustomColorBox; Layout.preferredWidth: Kirigami.Units.gridUnit * 8; placeholderText: "#RRGGBB" }
            Rectangle {
                width: Kirigami.Units.gridUnit * 1.5; height: width; radius: 3
                border.width: 1; border.color: Kirigami.Theme.disabledTextColor
                // An unfinished value must not paint an error; it just shows
                // nothing until it parses.
                color: /^#[0-9A-Fa-f]{6}$/.test(iconCustomColorBox.text) ? iconCustomColorBox.text : "transparent"
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Used when Icon colour is set to Custom." }

        QQC2.CheckBox {
            id: showIconBox
            Kirigami.FormData.label: ""
            text: "Show icon"
        }

        QQC2.ComboBox {
            id: pillIconModeBox
            Kirigami.FormData.label: "Bar icon:"
            textRole: "text"
            valueRole: "value"
            model: [{"text": "Icon", "value": "icon"}, {"text": "Country flag", "value": "flag"}]
            onActivated: cfg_pillIconMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_pillIconMode)
            // The stored value is the source of truth; if it was changed
            // elsewhere the box follows rather than overwriting it.
            Connections {
                target: kcmRoot
                function oncfg_pillIconModeChanged() { pillIconModeBox.currentIndex = pillIconModeBox.indexOfValue(kcmRoot.cfg_pillIconMode) }
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Flag shows the country your public address currently geolocates to, so it follows a VPN. It falls back to the icon while no country is known, in privacy mode, or on a system with no emoji font that can draw flags." }

        QQC2.TextField {
            id: iconNameBox
            Kirigami.FormData.label: "Icon:"
            Layout.fillWidth: true
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Any Material Symbols name, for example lan, wifi, public, router." }

        RowLayout {
            Kirigami.FormData.label: "Icon size adjust:"
            QQC2.SpinBox {
                id: iconOffsetBox
                from: -8
                to: 12
                stepSize: 1
                editable: true
            }
            QQC2.Label { text: "px"; color: Kirigami.Theme.disabledTextColor }
        }

        RowLayout {
            Kirigami.FormData.label: "Text size adjust:"
            QQC2.SpinBox {
                id: textOffsetBox
                from: -4
                to: 14
                stepSize: 1
                editable: true
            }
            QQC2.Label { text: "px"; color: Kirigami.Theme.disabledTextColor }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Grows or shrinks the address printed in the panel. 0 matches the size the panel's thickness implies. The pill's own appearance controls have the same setting with a live preview."
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "0 matches the size of every other icon in the bar. The panel has the same control with a live preview, under the sliders button." }

        QQC2.CheckBox {
            id: monospaceBox
            Kirigami.FormData.label: ""
            text: "Monospace addresses"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Keeps the pill from shifting width as the digits change." }

        QQC2.CheckBox {
            id: showPublicSectionBox
            Kirigami.FormData.label: ""
            text: "Public connection section"
        }

        QQC2.CheckBox {
            id: showIspBox
            Kirigami.FormData.label: ""
            text: "Show ISP"
        }

        QQC2.CheckBox {
            id: showLocationBox
            Kirigami.FormData.label: ""
            text: "Show location"
        }

        QQC2.CheckBox {
            id: showLocalSectionBox
            Kirigami.FormData.label: ""
            text: "Local network section"
        }

        QQC2.CheckBox {
            id: showGatewayBox
            Kirigami.FormData.label: ""
            text: "Show gateway"
        }

        QQC2.CheckBox {
            id: showLatencyBox
            Kirigami.FormData.label: ""
            text: "Show latency"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Pings the target below once per refresh." }

        QQC2.CheckBox {
            id: showDistroLogoBox
            Kirigami.FormData.label: ""
            text: "Show the distro logo"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Puts your system's logo beside the Local network heading, using the same mark and colour as your launcher." }

        QQC2.CheckBox {
            id: showCountryFlagBox
            Kirigami.FormData.label: ""
            text: "Show the country flag"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Puts the flag for the country your public address geolocates to beside the Public connection heading. Hidden while privacy mode is on." }

        QQC2.CheckBox {
            id: showVpnSectionBox
            Kirigami.FormData.label: ""
            text: "VPN section in the panel"
        }

        QQC2.ComboBox {
            id: localIpSourceBox
            Kirigami.FormData.label: "Bar shows as local IP:"
            textRole: "text"
            valueRole: "value"
            model: [{"text": "The router's address", "value": "lan"}, {"text": "The tunnel's address", "value": "tunnel"}, {"text": "Swap on middle click", "value": "toggle"}]
            onActivated: cfg_localIpSource = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_localIpSource)
            // The stored value is the source of truth; if it was changed
            // elsewhere the box follows rather than overwriting it.
            Connections {
                target: kcmRoot
                function oncfg_localIpSourceChanged() { localIpSourceBox.currentIndex = localIpSourceBox.indexOfValue(kcmRoot.cfg_localIpSource) }
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Only affects the bar pill. The router's address is the one between this machine and your router; a VPN does not change it. The tunnel's address is the one traffic actually leaves with while a tunnel is up - the 10.x one - and falls back to the router's when there is none. Swap on middle click starts on the router's address and flips between the two each time you middle-click the pill - in that mode middle click no longer refreshes, which the panel's own refresh button still does. The right button is left to Plasma, which uses it for the widget's own menu. The panel always shows the router's address, because its Tunnel section already names the other one." }

        QQC2.CheckBox {
            id: showTunnelSectionBox
            Kirigami.FormData.label: ""
            text: "Tunnel section in the panel"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Where traffic to the internet actually leaves from, measured with the routing table rather than taken from the VPN's own word for it. It says when a tunnel is connected but not carrying anything, which the VPN service itself cannot tell you." }

        QQC2.CheckBox {
            id: showVpnInPillBox
            Kirigami.FormData.label: ""
            text: "Show a VPN marker in the bar"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "A second icon next to the address whenever a tunnel is up." }

        QQC2.CheckBox {
            id: showVpnNameBox
            Kirigami.FormData.label: ""
            text: "Name the VPN in the bar"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Prints which profile is connected, not just that one is." }

        QQC2.CheckBox {
            id: tintPillWhenVpnBox
            Kirigami.FormData.label: ""
            text: "Colour the pill while connected"
        }

        QQC2.CheckBox {
            id: vpnSingleActiveBox
            Kirigami.FormData.label: ""
            text: "One VPN at a time"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Drops the other tunnels when you connect one. Turn it off if you deliberately run several at once." }

        QQC2.TextField {
            id: vpnIconNameBox
            Kirigami.FormData.label: "VPN icon:"
            Layout.fillWidth: true
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Any Material Symbols name, for example vpn_key, vpn_lock, shield, security." }

        QQC2.CheckBox {
            id: startPrivateBox
            Kirigami.FormData.label: ""
            text: "Start in privacy mode"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Masks every address until you click the eye in the panel." }

        QQC2.CheckBox {
            id: lookupPublicBox
            Kirigami.FormData.label: ""
            text: "Look up the public address"
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Turn this off to keep the widget entirely offline - it then only reports what the system already knows." }

        QQC2.CheckBox {
            id: lookupIpv6Box
            Kirigami.FormData.label: ""
            text: "Look up IPv6"
        }

        QQC2.TextField {
            id: publicProviderBox
            Kirigami.FormData.label: "Lookup URL:"
            Layout.fillWidth: true
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Must return JSON. ip / query is read as the address, org / isp as the provider, plus country and city." }

        QQC2.ComboBox {
            id: latencyModeBox
            Kirigami.FormData.label: "Latency measures:"
            textRole: "text"
            valueRole: "value"
            model: [{"text": "First hop (gateway)", "value": "gateway"}, {"text": "Internet round trip", "value": "internet"}, {"text": "A host I name", "value": "custom"}]
            onActivated: cfg_latencyMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(cfg_latencyMode)
            // The stored value is the source of truth; if it was changed
            // elsewhere the box follows rather than overwriting it.
            Connections {
                target: kcmRoot
                function oncfg_latencyModeChanged() { latencyModeBox.currentIndex = latencyModeBox.indexOfValue(kcmRoot.cfg_latencyMode) }
            }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "The first hop to your router is sub-millisecond on ethernet and a few ms on Wi-Fi; a public host is a different number entirely. The panel names whichever one it pinged, so the reading is never ambiguous." }

        QQC2.TextField {
            id: pingTargetBox
            Kirigami.FormData.label: "Host to ping:"
            Layout.fillWidth: true
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "Used when Latency measures is set to Internet or to a named host." }

        RowLayout {
            Kirigami.FormData.label: "Refresh every:"
            QQC2.SpinBox {
                id: refreshSecondsBox
                from: 0
                to: 3600
                stepSize: 1
                editable: true
            }
            QQC2.Label { text: "s"; color: Kirigami.Theme.disabledTextColor }
        }
        QQC2.Label { Layout.fillWidth: true; wrapMode: Text.WordWrap; font: Kirigami.Theme.smallFont; color: Kirigami.Theme.disabledTextColor; text: "0 refreshes only on reconnect, on resume, and when you ask." }
    }
}
