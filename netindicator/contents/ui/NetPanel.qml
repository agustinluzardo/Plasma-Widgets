import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "lib" as Lib

// The popout. The DMS panel, unchanged, with the same move applied.
    Lib.PopoutComponent {
        id: panel


    // El estado del applet, uno por instancia. Lo entrega main.qml: un singleton
    // aqui seria uno para todo el escritorio, y con el widget en dos paneles el
    // segundo pisaba al primero.
    required property QtObject state
        headerText: "Network"
        detailsText: panel.state.statusText
        showCloseButton: true

        // Whether a profile comes up on its own is NetworkManager's state,
        // not ours: flipping autostart in DMS's own settings (or in nmcli)
        // changes nothing here until something asks again, which is why the
        // "connects at boot" note stayed missing on a profile that had it.
        // Opening the panel is the moment to ask. DMS injects itself as
        // `parentPopout` once the content is loaded, and the loader may be
        // kept alive between opens, so the first open is covered by
        // onCompleted and every later one by the popout's own visibility.
        Component.onCompleted: panel.state.refreshVpn()

        Connections {
            target: panel.parentPopout
            function onShouldBeVisibleChanged() {
                if (panel.parentPopout && panel.parentPopout.shouldBeVisible)
                    panel.state.refreshVpn()
            }
        }

        headerActions: Component {
            Row {
                spacing: Lib.Theme.spacingXS

                Repeater {
                    // Static model. It used to carry the privacy icon name,
                    // which made the model itself change on every toggle and
                    // rebuilt all three buttons; the icon is resolved in the
                    // delegate instead so nothing is recreated.
                    model: ["privacy", "appearance", "refresh"]

                    Item {
                        id: actionItem

                        required property string modelData

                        readonly property string iconFor: {
                            if (actionItem.modelData === "privacy")
                                return panel.state.privacyMode ? "visibility_off" : "visibility"
                            if (actionItem.modelData === "appearance")
                                return "tune"
                            return "refresh"
                        }

                        width: 28
                        height: 28

                        Lib.DankIcon {
                            anchors.centerIn: parent
                            name: actionItem.iconFor
                            size: Lib.Theme.iconSize - 6
                            color: actionArea.containsMouse ? Lib.Theme.primary : (actionItem.modelData === "appearance" && panel.state.appearanceOpen ? Lib.Theme.primary : Lib.Theme.surfaceText)
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switch (actionItem.modelData) {
                                case "privacy":
                                    panel.state.privacyMode = !panel.state.privacyMode
                                    break
                                case "appearance":
                                    panel.state.appearanceOpen = !panel.state.appearanceOpen
                                    break
                                default:
                                    panel.state.refreshAll()
                                }
                            }
                        }
                    }
                }
            }
        }

        // DMS binds the popup's height to this content's implicitHeight
        // (PluginPopout.qml), so anything that grows the content resizes the
        // layer-shell window - and a resizing popup flashes its old frame.
        // The two views are stacked at a shared height instead, so opening
        // the appearance controls never changes the window size.
        Item {
            width: parent.width
            implicitHeight: Math.max(infoView.implicitHeight, appearanceView.implicitHeight)

            Column {
    // Plasma sizes the popup from these; without them it opens at whatever it
    // guesses, which is how the panel ended up behind other widgets.
    Layout.minimumWidth: panel.state.popoutWidth
    Layout.preferredWidth: panel.state.popoutWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

                id: infoView

                width: parent.width
                spacing: Lib.Theme.spacingM
                visible: !panel.state.appearanceOpen

                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: panel.state.showPublicSection

                    Row {
                        width: parent.width
                        spacing: Lib.Theme.spacingXS

                        Lib.StyledText {
                            text: "Public connection"
                            color: Lib.Theme.primary
                            font.pixelSize: Lib.Theme.fontSizeSmall
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Where this address geolocates. Hidden under
                        // privacy mode along with the addresses themselves -
                        // the country is one of the things being masked.
                        Lib.StyledText {
                            // Drawn only once a font has been proven able
                            // to draw it; otherwise the code below stands
                            // on its own.
                            visible: panel.state.showCountryFlag && !panel.state.privacyMode && panel.state.countryFlag !== "" && panel.state.flagAvailable
                            text: panel.state.countryFlag
                            font.family: panel.state.flagFontFamily
                            font.pixelSize: Lib.Theme.fontSizeSmall + 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Printed next to the flag so the row still says
                        // which country it is on a system with no colour
                        // emoji font installed.
                        Lib.StyledText {
                            visible: panel.state.showCountryFlag && !panel.state.privacyMode && panel.state.countryCode !== ""
                            text: panel.state.countryCode
                            color: Lib.Theme.surfaceVariantText
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.InfoRow {

                        state: panel.state
                        label: "IPv4"
                        value: panel.state.maskIfPrivate(panel.state.publicIp4)
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "IPv6"
                        value: panel.state.maskIfPrivate(panel.state.publicIp6)
                        wrap: true
                        visible: panel.state.lookupIpv6
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "ISP"
                        value: panel.state.isp
                        visible: panel.state.showIsp
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "Location"
                        value: panel.state.location
                        visible: panel.state.showLocation
                    }
                }

                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: panel.state.showLocalSection

                    Row {
                        width: parent.width
                        spacing: Lib.Theme.spacingXS

                        Lib.StyledText {
                            text: "Local network"
                            color: Lib.Theme.primary
                            font.pixelSize: Lib.Theme.fontSizeSmall
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // DMS has a SystemLogo widget that reads
                        // /etc/os-release and honours the launcher logo
                        // colour. Plasma has no such widget, but every icon
                        // theme carries the distro mark, and taking it from
                        // the theme is what makes it match the rest of the
                        // desktop. The name is resolved once at startup.
                        Kirigami.Icon {
                            visible: panel.state.showDistroLogo && panel.state.distroIcon !== ""
                            source: panel.state.distroIcon
                            width: Lib.Theme.iconSize - 8
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.InfoRow {

                        state: panel.state
                        label: "Local IP"
                        value: panel.state.maskIfPrivate(panel.state.localIp)
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "Gateway"
                        value: panel.state.maskIfPrivate(panel.state.gateway)
                        visible: panel.state.showGateway
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "Interface"
                        value: panel.state.localInterface
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "Latency"
                        value: panel.state.latency
                        // Names the hop, so a first-hop reading is never
                        // mistaken for a round trip to the internet.
                        hint: panel.state.latencyHint
                        visible: panel.state.showLatency
                    }
                }

                // -- Tunnel --
                // Always laid out when the setting is on, empty when there
                // is no tunnel. Making the section appear with the VPN would
                // grow the panel exactly when you are watching it, and DMS
                // binds the popup window to this content's height.
                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: panel.state.showTunnelSection

                    Row {
                        width: parent.width
                        spacing: Lib.Theme.spacingXS

                        Lib.StyledText {
                            text: "Tunnel"
                            color: Lib.Theme.primary
                            font.pixelSize: Lib.Theme.fontSizeSmall
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // The one thing the VPN service cannot tell you:
                        // whether traffic is actually taking the tunnel.
                        Lib.StyledText {
                            visible: panel.state.vpnUpButNotRouting
                            text: "connected, but traffic is not using it"
                            color: Lib.Theme.error
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.InfoRow {

                        state: panel.state
                        label: "Exit address"
                        value: panel.state.trafficLeavesViaTunnel ? panel.state.maskIfPrivate(panel.state.routeSourceIp) : ""
                        hint: panel.state.trafficLeavesViaTunnel ? "" : "\u2192 not tunnelled"
                    }
                    Lib.InfoRow {
                        state: panel.state
                        label: "Exit device"
                        value: panel.state.trafficLeavesViaTunnel ? panel.state.routeInterface : ""
                    }
                }

                // -- VPN --
                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: panel.state.showVpnSection && panel.state.vpnAvailable

                    Row {
                        width: parent.width
                        spacing: Lib.Theme.spacingXS

                        Lib.StyledText {
                            text: "VPN"
                            color: Lib.Theme.primary
                            font.pixelSize: Lib.Theme.fontSizeSmall
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Lib.StyledText {
                            text: panel.state.vpnConnected ? panel.state.vpnLabel : "Disconnected"
                            color: panel.state.vpnConnected ? Lib.Theme.success : Lib.Theme.surfaceVariantText
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Sits on the header's existing row, so saying it
                        // costs no height.
                        Lib.StyledText {
                            visible: panel.state.multipleVpnsActive
                            text: "· several at once"
                            color: Lib.Theme.error
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.StyledText {
                        width: parent.width
                        visible: panel.state.vpnProfiles.length === 0
                        wrapMode: Text.WordWrap
                        color: Lib.Theme.surfaceVariantText
                        font.pixelSize: Lib.Theme.fontSizeSmall
                        text: "No profiles yet. Import a .conf or .ovpn under Settings → Network → VPN and it will appear here."
                    }

                    Repeater {
                        model: panel.state.vpnProfiles

                        Row {
                            id: vpnRow

                            required property var modelData

                            readonly property bool isOn: panel.state.vpnIsActive(vpnRow.modelData.uuid)
                            readonly property bool isBusy: panel.state.vpnIsConnecting(vpnRow.modelData.uuid)
                            readonly property string failure: (Lib.NetService.vpnErrorUuid === vpnRow.modelData.uuid) ? (Lib.NetService.vpnError || "") : ""

                            width: parent ? parent.width : 0
                            spacing: Lib.Theme.spacingS

                            Column {
                                width: parent.width - vpnToggleButton.width - Lib.Theme.spacingS
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                Lib.StyledText {
                                    width: parent.width
                                    text: vpnRow.modelData.name || vpnRow.modelData.uuid
                                    color: Lib.Theme.surfaceText
                                    font.pixelSize: Lib.Theme.fontSizeSmall
                                    elide: Text.ElideRight
                                }

                                // A failure replaces this line rather than
                                // adding one: an extra row would resize the
                                // popup, and a resizing popup flashes.
                                Lib.StyledText {
                                    width: parent.width
                                    color: vpnRow.failure !== "" ? Lib.Theme.error : Lib.Theme.surfaceVariantText
                                    font.pixelSize: Lib.Theme.fontSizeSmall - 1
                                    elide: Text.ElideRight
                                    text: {
                                        if (vpnRow.failure !== "")
                                            return vpnRow.failure
                                        const bits = [panel.state.vpnKindLabel(vpnRow.modelData)]
                                        if (panel.state.autoconnectFor(vpnRow.modelData))
                                            bits.push("connects at boot")
                                        if (vpnRow.isOn) {
                                            const st = panel.state.vpnStateFor(vpnRow.modelData.uuid)
                                            bits.push(st !== "" ? st : "connected")
                                        } else if (vpnRow.modelData.remoteHost) {
                                            bits.push(vpnRow.modelData.remoteHost)
                                        }
                                        return bits.join(" · ")
                                    }
                                }
                            }

                            Lib.VpnButton {
                                id: vpnToggleButton

                                anchors.verticalCenter: parent.verticalCenter
                                on: vpnRow.isOn
                                busy: vpnRow.isBusy
                                enabled: !panel.state.vpnBusy || vpnRow.isBusy
                                onActivated: panel.state.vpnToggle(vpnRow.modelData)
                            }
                        }
                    }
                }

                Lib.StyledText {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                    text: "Middle-click the bar pill to refresh. The eye masks every address, the sliders open the appearance controls. Right-click opens this widget's Plasma menu."
                }
            }

            Column {
                id: appearanceView

                width: parent.width
                spacing: Lib.Theme.spacingS
                visible: panel.state.appearanceOpen

                Lib.StyledText {
                    text: "Bar pill shows"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {

                    state: panel.state
                    settingKey: "pillContent"
                    current: panel.state.pillContent
                    options: panel.state.pillContentOptions
                }

                Lib.StyledText {
                    text: "Bar icon"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {

                    state: panel.state
                    settingKey: "pillIconMode"
                    current: panel.state.pillIconMode
                    options: panel.state.pillIconModeOptions
                }

                Lib.StyledText {
                    text: "Text colour"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {

                    state: panel.state
                    settingKey: "colorMode"
                    current: panel.state.colorMode
                    options: panel.state.colorModeOptions
                }

                Lib.StyledText {
                    text: "Icon colour"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {

                    state: panel.state
                    settingKey: "iconColorMode"
                    current: panel.state.iconColorMode
                    options: panel.state.iconColorModeOptions
                }

                Lib.StepperRow {
                    // Prints the size the icon actually ends up at rather
                    // than the offset, so "18" means 18 pixels and there is
                    // no 0 to puzzle over.
                    label: "Icon size"
                    value: panel.state.pillIconSize
                    minimum: Math.max(6, panel.state.pillIconBaseSize + panel.state.iconOffsetMin)
                    maximum: Math.min(panel.state.pillIconCeiling, panel.state.pillIconBaseSize + panel.state.iconOffsetMax)
                    suffix: "px"
                    apply: size => panel.state.saveSetting("iconOffset", size - panel.state.pillIconBaseSize)
                }

                Lib.StepperRow {
                    // Lo mismo para el texto. Faltaba: el tamaño del texto
                    // venia de la barra de DMS, que en Plasma no existe, asi
                    // que la IP no se podia agrandar de ninguna manera.
                    label: "Text size"
                    value: panel.state.pillTextSize
                    minimum: Math.max(6, panel.state.pillTextBaseSize + panel.state.textOffsetMin)
                    maximum: Math.min(panel.state.pillTextCeiling, panel.state.pillTextBaseSize + panel.state.textOffsetMax)
                    suffix: "px"
                    apply: size => panel.state.saveSetting("textOffset", size - panel.state.pillTextBaseSize)
                }

                Lib.StyledText {
                    text: "Latency measures"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {

                    state: panel.state
                    settingKey: "latencyMode"
                    current: panel.state.latencyMode
                    options: panel.state.latencyModeOptions
                }
            }
        }
    }
