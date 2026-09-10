import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import "lib" as Lib

// The popout. The DMS panel, unchanged, with the same move applied.
    Lib.PopoutComponent {
        id: panel

        headerText: "Network"
        detailsText: Lib.NetState.statusText
        showCloseButton: true

        // Whether a profile comes up on its own is NetworkManager's state,
        // not ours: flipping autostart in DMS's own settings (or in nmcli)
        // changes nothing here until something asks again, which is why the
        // "connects at boot" note stayed missing on a profile that had it.
        // Opening the panel is the moment to ask. DMS injects itself as
        // `parentPopout` once the content is loaded, and the loader may be
        // kept alive between opens, so the first open is covered by
        // onCompleted and every later one by the popout's own visibility.
        Component.onCompleted: Lib.NetState.refreshVpn()

        Connections {
            target: panel.parentPopout
            function onShouldBeVisibleChanged() {
                if (panel.parentPopout && panel.parentPopout.shouldBeVisible)
                    Lib.NetState.refreshVpn()
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
                                return Lib.NetState.privacyMode ? "visibility_off" : "visibility"
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
                            color: actionArea.containsMouse ? Lib.Theme.primary : (actionItem.modelData === "appearance" && Lib.NetState.appearanceOpen ? Lib.Theme.primary : Lib.Theme.surfaceText)
                        }

                        MouseArea {
                            id: actionArea

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                switch (actionItem.modelData) {
                                case "privacy":
                                    Lib.NetState.privacyMode = !Lib.NetState.privacyMode
                                    break
                                case "appearance":
                                    Lib.NetState.appearanceOpen = !Lib.NetState.appearanceOpen
                                    break
                                default:
                                    Lib.NetState.refreshAll()
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
    Layout.minimumWidth: Lib.NetState.popoutWidth
    Layout.preferredWidth: Lib.NetState.popoutWidth
    Layout.minimumHeight: implicitHeight
    Layout.preferredHeight: implicitHeight

                id: infoView

                width: parent.width
                spacing: Lib.Theme.spacingM
                visible: !Lib.NetState.appearanceOpen

                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: Lib.NetState.showPublicSection

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
                            visible: Lib.NetState.showCountryFlag && !Lib.NetState.privacyMode && Lib.NetState.countryFlag !== "" && Lib.NetState.flagAvailable
                            text: Lib.NetState.countryFlag
                            font.family: Lib.NetState.flagFontFamily
                            font.pixelSize: Lib.Theme.fontSizeSmall + 2
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Printed next to the flag so the row still says
                        // which country it is on a system with no colour
                        // emoji font installed.
                        Lib.StyledText {
                            visible: Lib.NetState.showCountryFlag && !Lib.NetState.privacyMode && Lib.NetState.countryCode !== ""
                            text: Lib.NetState.countryCode
                            color: Lib.Theme.surfaceVariantText
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.InfoRow {
                        label: "IPv4"
                        value: Lib.NetState.maskIfPrivate(Lib.NetState.publicIp4)
                    }
                    Lib.InfoRow {
                        label: "IPv6"
                        value: Lib.NetState.maskIfPrivate(Lib.NetState.publicIp6)
                        wrap: true
                        visible: Lib.NetState.lookupIpv6
                    }
                    Lib.InfoRow {
                        label: "ISP"
                        value: Lib.NetState.isp
                        visible: Lib.NetState.showIsp
                    }
                    Lib.InfoRow {
                        label: "Location"
                        value: Lib.NetState.location
                        visible: Lib.NetState.showLocation
                    }
                }

                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: Lib.NetState.showLocalSection

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
                            visible: Lib.NetState.showDistroLogo && Lib.NetState.distroIcon !== ""
                            source: Lib.NetState.distroIcon
                            width: Lib.Theme.iconSize - 8
                            height: width
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.InfoRow {
                        label: "Local IP"
                        value: Lib.NetState.maskIfPrivate(Lib.NetState.localIp)
                    }
                    Lib.InfoRow {
                        label: "Gateway"
                        value: Lib.NetState.maskIfPrivate(Lib.NetState.gateway)
                        visible: Lib.NetState.showGateway
                    }
                    Lib.InfoRow {
                        label: "Interface"
                        value: Lib.NetState.localInterface
                    }
                    Lib.InfoRow {
                        label: "Latency"
                        value: Lib.NetState.latency
                        // Names the hop, so a first-hop reading is never
                        // mistaken for a round trip to the internet.
                        hint: Lib.NetState.latencyHint
                        visible: Lib.NetState.showLatency
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
                    visible: Lib.NetState.showTunnelSection

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
                            visible: Lib.NetState.vpnUpButNotRouting
                            text: "connected, but traffic is not using it"
                            color: Lib.Theme.error
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.InfoRow {
                        label: "Exit address"
                        value: Lib.NetState.trafficLeavesViaTunnel ? Lib.NetState.maskIfPrivate(Lib.NetState.routeSourceIp) : ""
                        hint: Lib.NetState.trafficLeavesViaTunnel ? "" : "\u2192 not tunnelled"
                    }
                    Lib.InfoRow {
                        label: "Exit device"
                        value: Lib.NetState.trafficLeavesViaTunnel ? Lib.NetState.routeInterface : ""
                    }
                }

                // -- VPN --
                Column {
                    width: parent.width
                    spacing: Lib.Theme.spacingXS
                    visible: Lib.NetState.showVpnSection && Lib.NetState.vpnAvailable

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
                            text: Lib.NetState.vpnConnected ? Lib.NetState.vpnLabel : "Disconnected"
                            color: Lib.NetState.vpnConnected ? Lib.Theme.success : Lib.Theme.surfaceVariantText
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        // Sits on the header's existing row, so saying it
                        // costs no height.
                        Lib.StyledText {
                            visible: Lib.NetState.multipleVpnsActive
                            text: "· several at once"
                            color: Lib.Theme.error
                            font.pixelSize: Lib.Theme.fontSizeSmall - 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Lib.StyledText {
                        width: parent.width
                        visible: Lib.NetState.vpnProfiles.length === 0
                        wrapMode: Text.WordWrap
                        color: Lib.Theme.surfaceVariantText
                        font.pixelSize: Lib.Theme.fontSizeSmall
                        text: "No profiles yet. Import a .conf or .ovpn under Settings → Network → VPN and it will appear here."
                    }

                    Repeater {
                        model: Lib.NetState.vpnProfiles

                        Row {
                            id: vpnRow

                            required property var modelData

                            readonly property bool isOn: Lib.NetState.vpnIsActive(vpnRow.modelData.uuid)
                            readonly property bool isBusy: Lib.NetState.vpnIsConnecting(vpnRow.modelData.uuid)
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
                                        const bits = [Lib.NetState.vpnKindLabel(vpnRow.modelData)]
                                        if (Lib.NetState.autoconnectFor(vpnRow.modelData))
                                            bits.push("connects at boot")
                                        if (vpnRow.isOn) {
                                            const st = Lib.NetState.vpnStateFor(vpnRow.modelData.uuid)
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
                                enabled: !Lib.NetState.vpnBusy || vpnRow.isBusy
                                onActivated: Lib.NetState.vpnToggle(vpnRow.modelData)
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
                visible: Lib.NetState.appearanceOpen

                Lib.StyledText {
                    text: "Bar pill shows"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {
                    settingKey: "pillContent"
                    current: Lib.NetState.pillContent
                    options: Lib.NetState.pillContentOptions
                }

                Lib.StyledText {
                    text: "Bar icon"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {
                    settingKey: "pillIconMode"
                    current: Lib.NetState.pillIconMode
                    options: Lib.NetState.pillIconModeOptions
                }

                Lib.StyledText {
                    text: "Text colour"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {
                    settingKey: "colorMode"
                    current: Lib.NetState.colorMode
                    options: Lib.NetState.colorModeOptions
                }

                Lib.StyledText {
                    text: "Icon colour"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {
                    settingKey: "iconColorMode"
                    current: Lib.NetState.iconColorMode
                    options: Lib.NetState.iconColorModeOptions
                }

                Lib.StepperRow {
                    // Prints the size the icon actually ends up at rather
                    // than the offset, so "18" means 18 pixels and there is
                    // no 0 to puzzle over.
                    label: "Icon size"
                    value: Lib.NetState.pillIconSize
                    minimum: Math.max(6, Lib.NetState.pillIconBaseSize + Lib.NetState.iconOffsetMin)
                    maximum: Math.min(Lib.NetState.pillIconCeiling, Lib.NetState.pillIconBaseSize + Lib.NetState.iconOffsetMax)
                    suffix: "px"
                    apply: size => Lib.NetState.saveSetting("iconOffset", size - Lib.NetState.pillIconBaseSize)
                }

                Lib.StepperRow {
                    // Lo mismo para el texto. Faltaba: el tamaño del texto
                    // venia de la barra de DMS, que en Plasma no existe, asi
                    // que la IP no se podia agrandar de ninguna manera.
                    label: "Text size"
                    value: Lib.NetState.pillTextSize
                    minimum: Math.max(6, Lib.NetState.pillTextBaseSize + Lib.NetState.textOffsetMin)
                    maximum: Math.min(Lib.NetState.pillTextCeiling, Lib.NetState.pillTextBaseSize + Lib.NetState.textOffsetMax)
                    suffix: "px"
                    apply: size => Lib.NetState.saveSetting("textOffset", size - Lib.NetState.pillTextBaseSize)
                }

                Lib.StyledText {
                    text: "Latency measures"
                    color: Lib.Theme.surfaceVariantText
                    font.pixelSize: Lib.Theme.fontSizeSmall
                }

                Lib.ChipRow {
                    settingKey: "latencyMode"
                    current: Lib.NetState.latencyMode
                    options: Lib.NetState.latencyModeOptions
                }
            }
        }
    }
