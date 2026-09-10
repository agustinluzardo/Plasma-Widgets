// No `pragma ComponentBehavior: Bound`: DMS instantiates the bar pills and the
// popout from Loaders that live in its own files, and a bound component refuses
// to be created outside its creation context. Lookups below are all qualified.

pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami


Item {
    id: root

    // ---- what PluginComponent used to provide ----------------------------
    // On DMS these were injected by the plugin host. On Plasma the host is the
    // panel, and main.qml below fills them in from it. The names are unchanged
    // so nothing downstream had to be touched.
    property var pluginData: ({})
    property real barThickness: 40
    property real widgetThickness: 30
    property real barSpacing: 4
    property var barConfig: null
    property string section: "center"
    property var parentScreen: null
    property string pluginId: "netindicator"
    property var pluginService: null
    readonly property int iconSize: Math.round((barThickness / 48) * (24 - 4))
    readonly property int iconSizeLarge: Math.round((barThickness / 48) * 28)
    // Not readonly: the host sets it from the panel's orientation. DMS derived
    // it from an injected axis object, which is why it was readonly there.
    property bool isVertical: false

    // Declared without a value: the plugin below assigns every one of these,
    // and an initialiser here would be a second assignment to the same property.
    property real popoutWidth

    // ------------------------------------------------------------- settings --
    // What the bar pill prints next to the icon.
    readonly property string pillContent: root.pluginData?.pillContent ?? "localIp"
    readonly property bool showIcon: root.pluginData?.showIcon ?? true
    readonly property string iconName: root.pluginData?.iconName ?? "lan"
    // "icon" is the Material symbol above; "flag" swaps it for the flag of
    // wherever your public address currently geolocates - which is the country
    // you appear to be in, VPN or no VPN.
    readonly property string pillIconMode: root.pluginData?.pillIconMode ?? "icon"
    // "theme" follows the bar's text colour, the rest are explicit.
    readonly property string colorMode: root.pluginData?.colorMode ?? "theme"
    readonly property string customColor: root.pluginData?.customColor ?? "#FFFFFF"
    // The icon is coloured independently of the address text. "match" keeps the
    // two locked together, which is what the widget did before this existed, so
    // an existing configuration is unchanged until you pick something else.
    readonly property string iconColorMode: root.pluginData?.iconColorMode ?? "match"
    readonly property string iconCustomColor: root.pluginData?.iconCustomColor ?? "#FFFFFF"
    readonly property bool monospace: root.pluginData?.monospace ?? true
    readonly property int iconOffset: Math.max(root.iconOffsetMin, Math.min(root.iconOffsetMax, root.pluginData?.iconOffset ?? 0))
    readonly property int iconOffsetMin: -8
    // +12 is where a default bar puts the icon at exactly the pill's own
    // height, which is as large as it can get without spilling out of it.
    readonly property int iconOffsetMax: 12

    // PluginComponent.iconSize passes offset -4; DMS' own icon+text bar widgets
    // (Clock, CpuMonitor, DiskUsage...) pass undefined, which is -6. Match those
    // so this pill is exactly the size of everything else in the bar.
    readonly property int pillIconBaseSize: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.maximizeWidgetIcons, root.barConfig?.iconScale)
    // BasePill fixes the pill's background at widgetThickness across the bar
    // (visualHeight on a horizontal bar, visualWidth on a vertical one), so an
    // icon bigger than that hangs outside its own pill. Grow right up to the
    // pill, never past it - whatever the bar's thickness happens to be.
    readonly property int pillIconCeiling: Math.max(8, Math.round(root.widgetThickness))
    readonly property int pillIconSize: Math.max(6, Math.min(root.pillIconCeiling, root.pillIconBaseSize + root.iconOffset))

    // El TEXTO del pill, con el mismo mecanismo que el icono.
    // En DMS el tamaño venia de la barra (fontScale / maximizeWidgetText) y el
    // usuario lo ajustaba alli. En Plasma no hay barConfig: era null, asi que
    // el texto quedaba clavado al grosor del panel sin ningun control - habia
    // "Icon size" y nada para la IP.
    readonly property int textOffset: Math.max(root.textOffsetMin, Math.min(root.textOffsetMax, root.pluginData?.textOffset ?? 0))
    readonly property int textOffsetMin: -4
    readonly property int textOffsetMax: 14
    readonly property int pillTextBaseSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale, root.barConfig?.maximizeWidgetText)
    // El texto tampoco puede pasarse del alto del pill.
    readonly property int pillTextCeiling: Math.max(8, Math.round(root.widgetThickness))
    readonly property int pillTextSize: Math.max(6, Math.min(root.pillTextCeiling, root.pillTextBaseSize + root.textOffset))
    readonly property bool startPrivate: root.pluginData?.startPrivate ?? false

    readonly property int refreshSeconds: Math.max(0, Math.min(3600, root.pluginData?.refreshSeconds ?? 300))
    // Defaults to the gateway: this row sits in the Local network section, and
    // pinging a public resolver instead reports internet latency, which is an
    // order of magnitude larger and means something else entirely.
    // "gateway"  - the first hop; sub-millisecond on wired, a few ms on Wi-Fi
    // "internet"  - round trip to a public host, which is a different number
    // "custom"    - whatever host you name
    readonly property string latencyMode: root.pluginData?.latencyMode ?? "gateway"
    readonly property string pingTarget: root.pluginData?.pingTarget ?? "1.1.1.1"
    readonly property string latencyHint: {
        if (!root.effectivePingTarget)
            return ""
        return root.latencyMode === "gateway" ? "\u2192 gateway" : ("\u2192 " + root.effectivePingTarget)
    }
    readonly property string effectivePingTarget: {
        if (root.latencyMode === "gateway")
            return root.gateway
        const t = (root.pingTarget || "").trim()
        return t === "gateway" ? root.gateway : t
    }
    readonly property string publicProvider: root.pluginData?.publicProvider ?? "https://ipinfo.io/json"
    readonly property bool lookupPublic: root.pluginData?.lookupPublic ?? true
    readonly property bool lookupIpv6: root.pluginData?.lookupIpv6 ?? true

    readonly property bool showPublicSection: root.pluginData?.showPublicSection ?? true
    readonly property bool showLocalSection: root.pluginData?.showLocalSection ?? true
    readonly property bool showIsp: root.pluginData?.showIsp ?? true
    readonly property bool showLocation: root.pluginData?.showLocation ?? true
    readonly property bool showGateway: root.pluginData?.showGateway ?? true
    readonly property bool showLatency: root.pluginData?.showLatency ?? true
    readonly property bool showDistroLogo: root.pluginData?.showDistroLogo ?? true
    readonly property bool showVpnSection: root.pluginData?.showVpnSection ?? true
    readonly property bool showTunnelSection: root.pluginData?.showTunnelSection ?? true
    // Which address the bar pill prints when it is set to show the local IP.
    // "lan" is the one the router handed out and never changes with a VPN;
    // "tunnel" is the address traffic actually leaves with, the tunnel's own
    // (10.x) while one is up and the LAN one when it is not; "toggle" swaps
    // between them on a middle click. The panel is not affected either way: it
    // has a Tunnel section of its own.
    readonly property string localIpSource: root.pluginData?.localIpSource ?? "lan"

    // Only meaningful in "toggle" mode, and deliberately not saved: it is a
    // glance, not a preference. It resets to the LAN address when the shell
    // restarts, which is the one that is always true.
    property bool showingTunnelIp: false

    readonly property bool localIpIsToggleable: root.localIpSource === "toggle"
    readonly property bool wantsTunnelIp: root.localIpSource === "tunnel" || (root.localIpIsToggleable && root.showingTunnelIp)
    readonly property bool showVpnInPill: root.pluginData?.showVpnInPill ?? true
    readonly property bool showVpnName: root.pluginData?.showVpnName ?? false
    readonly property string vpnIconName: root.pluginData?.vpnIconName ?? "vpn_key"
    // Connecting a second profile while one is up is usually a mistake rather
    // than a plan, so the default is to drop the others first. NetworkManager
    // will happily hold several at once if you turn this off.
    readonly property bool vpnSingleActive: root.pluginData?.vpnSingleActive ?? true
    readonly property bool tintPillWhenVpn: root.pluginData?.tintPillWhenVpn ?? true
    readonly property bool showCountryFlag: root.pluginData?.showCountryFlag ?? true

    // En DMS el host exponia un pluginService y cada ajuste pasaba por el. En
    // Plasma no existe: main.qml inyecta esta funcion, que escribe en
    // Plasmoid.configuration. Enrutar solo por pluginService dejaba a TODOS los
    // controles del panel sin efecto, en silencio - los chips y el stepper de
    // tamaño de icono se dibujaban y no hacian nada.
    //
    // Ademas hay que DECLARARLA: main.qml hacia
    // `Lib.NetState.savePluginData = ...` sobre una propiedad que no existia,
    // y esa asignacion tira antes de llegar al refreshAll() de la linea
    // siguiente.
    property var savePluginData: null

    function saveSetting(key, value) {
        if (root.savePluginData) {
            root.savePluginData(key, value)
            return
        }
        if (root.pluginService?.savePluginData)
            root.pluginService.savePluginData(root.pluginId, key, value)
    }

    function resolveColor(mode, custom) {
        switch (mode) {
        case "white":
            return "#FFFFFF"
        case "accent":
            return Theme.primary
        case "custom":
            return custom
        default:
            return Theme.surfaceText
        }
    }

    readonly property color pillTextColor: root.resolveColor(root.colorMode, root.customColor)
    readonly property color pillIconColor: root.iconColorMode === "match" ? root.pillTextColor : root.resolveColor(root.iconColorMode, root.iconCustomColor)

    // ----------------------------------------------------------- live state --
    property bool privacyMode: false
    property string localIp: ""
    property string localInterface: ""
    property string gateway: ""
    property string publicIp4: ""
    property string publicIp6: ""
    property bool hasIpv6Answer: false

    // Where traffic to the internet actually leaves from, as opposed to the LAN
    // address the router handed out. With a full-tunnel VPN up these differ: the
    // LAN address stays 192.168.x.x while the source address becomes the
    // tunnel's own. Measured with `ip route get`, so it is what the kernel will
    // really do rather than what the VPN service says it did.
    property string routeSourceIp: ""
    property string routeInterface: ""

    // A tunnel that is connected but not carrying traffic still leaves the route
    // to the internet on the LAN interface. That is the difference between "the
    // VPN says it is up" and "the VPN is actually being used".
    readonly property bool trafficLeavesViaTunnel: root.routeInterface !== "" && root.routeInterface !== root.localInterface
    readonly property bool vpnUpButNotRouting: root.vpnConnected && root.routeInterface !== "" && !root.trafficLeavesViaTunnel
    property string isp: ""
    property string location: ""
    // Kept apart from `location` because the flag needs the ISO 3166-1 alpha-2
    // code specifically, and providers disagree about which field carries it:
    // ipinfo puts the code in `country`, ip-api puts the name there and the code
    // in `countryCode`.
    property string countryCode: ""
    property string latency: ""
    property string statusText: "Idle"
    property bool busy: false

    // El nombre del icono del logo de la distro, SI EXISTE de verdad.
    //
    // Antes se construia como `<ID>-logo` y se le pasaba a Kirigami.Icon sin
    // mas. En Arch eso da "arch-logo", que ningun tema tiene - el ID es "arch",
    // el icono se llama "archlinux-logo" - y lo que se dibujaba era el cuadrado
    // blanco de icono ausente. Un nombre inventado no es un icono.
    //
    // os-release tiene un campo para esto: LOGO, definido por la spec como "el
    // nombre de un icono segun la Icon Theme Specification". Se prueba ese
    // primero, luego las variantes derivadas del ID, y cada candidato se busca
    // EN DISCO antes de aceptarlo. Si ninguno existe queda vacio y el logo no
    // se dibuja, que es mejor que un cuadrado.
    property string distroIcon: ""

    readonly property string distroLogoProbe: [
        // La ruta es una variable para poder probar el caso de Arch desde una
        // maquina que no lo es; sin ella el test solo puede comprobar la distro
        // sobre la que corre, que es justamente la que no falla.
        '. "${NETINDICATOR_OSRELEASE:-/etc/os-release}" 2>/dev/null || true',
        'for n in "${LOGO:-}" "${ID:-}-logo" "${ID:-}linux-logo" "distributor-logo-${ID:-}" "${ID:-}"; do',
        '  [ -n "$n" ] && [ "$n" != "-logo" ] && [ "$n" != "linux-logo" ] || continue',
        '  found=$(find /usr/share/icons /usr/share/pixmaps "$HOME/.local/share/icons" \\',
        '      \\( -name "$n.png" -o -name "$n.svg" -o -name "$n.svgz" -o -name "$n.xpm" \\) \\',
        '      -print -quit 2>/dev/null)',
        '  if [ -n "$found" ]; then printf %s "$n"; exit 0; fi',
        "done",
        'printf ""'
    ].join("\n")

    Component.onCompleted: {
        Sh.exec(["sh", "-c", root.distroLogoProbe], (out) => {
            root.distroIcon = (out || "").trim()
        })
        root.privacyMode = root.startPrivate
        // Busy before we even loaded: we cannot know how long it has been, so
        // it is timed from here rather than assumed stale.
        if (root.vpnBusy)
            root.vpnBusySince = Date.now()
        Qt.callLater(root.refreshAll)
    }

    // The compositor-side facts DMS already tracks; no process needed for these.
    readonly property string serviceIp: NetService.ethernetConnected ? (NetService.ethernetIP ?? "") : (NetService.wifiIP ?? "")
    readonly property string serviceInterface: NetService.ethernetConnected ? (NetService.ethernetInterface ?? "") : (NetService.wifiInterface ?? "")
    readonly property string ssid: NetService.currentWifiSSID ?? ""

    onServiceIpChanged: {
        if (root.serviceIp)
            root.localIp = root.serviceIp
    }
    onServiceInterfaceChanged: {
        if (root.serviceInterface)
            root.localInterface = root.serviceInterface
    }

    // A flag emoji is the two regional indicator symbols for the country code.
    // Anything that is not exactly two letters (a full country name, an empty
    // field, "XX") yields no flag rather than two random glyphs.
    function flagFor(code) {
        const c = (code || "").trim().toUpperCase()
        if (!/^[A-Z]{2}$/.test(c))
            return ""
        return String.fromCodePoint(0x1F1E6 + c.charCodeAt(0) - 65, 0x1F1E6 + c.charCodeAt(1) - 65)
    }

    readonly property string countryFlag: root.flagFor(root.countryCode)

    // A flag emoji is a ligature of two regional indicator letters, and plenty
    // of ordinary fonts carry those letters without carrying the ligature -
    // FreeSans, DejaVu Sans and Unifont all do. When one of those wins the
    // fallback you get two boxed capitals instead of a flag, which is the
    // "meaningless symbol" this probe exists to prevent. So: name the emoji
    // font explicitly rather than trusting fallback, and verify it really
    // formed the ligature before drawing anything.
    readonly property var emojiFamilies: ["", "Noto Color Emoji", "Twemoji", "Twitter Color Emoji", "JoyPixels", "OpenMoji Color", "Apple Color Emoji", "Segoe UI Emoji"]

    property string flagFontFamily: ""
    property bool flagFontResolved: false
    readonly property bool flagAvailable: root.flagFontResolved && root.flagFontFamily !== ""

    Item {
        id: flagProbe

        visible: false
        width: 0
        height: 0

        function resolve() {
            for (let i = 0; i < candidates.count; i++) {
                const c = candidates.itemAt(i)
                if (c && c.formsLigature) {
                    root.flagFontFamily = c.candidate
                    root.flagFontResolved = true
                    return
                }
            }
            // No font on this system can draw a flag. The country code alone is
            // a better answer than two boxed letters.
            root.flagFontFamily = ""
            root.flagFontResolved = true
        }

        Repeater {
            id: candidates

            model: root.emojiFamilies

            Item {
                id: candidate

                required property string modelData

                // "" means the theme's own font: if that already draws flags,
                // use it and keep the panel visually consistent.
                readonly property string candidate: candidate.modelData
                // One glyph's worth of advance means the pair was shaped into a
                // single flag; two means it was drawn as two separate letters.
                readonly property bool formsLigature: singleGlyph.implicitWidth > 0 && pairGlyph.implicitWidth < singleGlyph.implicitWidth * 1.6

                visible: false

                Text {
                    id: singleGlyph

                    visible: false
                    text: "\uD83C\uDDE6"
                    font.pixelSize: 20
                    font.family: candidate.candidate
                }

                Text {
                    id: pairGlyph

                    visible: false
                    text: "\uD83C\uDDE6\uD83C\uDDF7"
                    font.pixelSize: 20
                    font.family: candidate.candidate
                }
            }
        }

        Component.onCompleted: Qt.callLater(flagProbe.resolve)
    }

    // What the bar pill prints, and only the pill. The panel's Local IP row
    // always shows the router's address: the Tunnel section right below it
    // already names the tunnel's, and saying it twice in one panel is noise.
    readonly property string displayLocalIp: (root.wantsTunnelIp && root.trafficLeavesViaTunnel && root.routeSourceIp !== "") ? root.routeSourceIp : root.localIp

    function maskIfPrivate(value) {
        if (!value)
            return "—"
        return root.privacyMode ? "••••••••" : value
    }

    readonly property string pillText: {
        switch (root.pillContent) {
        case "none":
            return ""
        case "publicIp":
            return root.maskIfPrivate(root.publicIp4)
        case "interface":
            return root.localInterface || "—"
        case "gateway":
            return root.maskIfPrivate(root.gateway)
        case "ssid":
            return root.ssid || root.localInterface || "—"
        default:
            return root.maskIfPrivate(root.displayLocalIp)
        }
    }

    // --------------------------------------------------------------- VPN ----
    // DMS already talks to NetworkManager through its own daemon, so none of
    // this shells out: NetService exposes the profiles and the active
    // connections as plain QML properties, which means the panel updates itself
    // the moment anything changes. No polling, no refresh button needed.
    //
    // A profile is { name, uuid, type, serviceType, remoteHost, autoconnect } and
    // an active connection is { name, uuid, device, state } - the shapes the
    // daemon's Go structs actually return.
    readonly property bool vpnAvailable: NetService.vpnAvailable ?? false
    readonly property var vpnProfiles: NetService.vpnProfiles ?? []
    readonly property bool vpnConnected: NetService.vpnConnected ?? false
    readonly property bool vpnBusy: NetService.vpnIsBusy ?? false
    readonly property var vpnActiveNames: NetService.activeNames ?? []
    readonly property string vpnLabel: root.vpnActiveNames.length > 0 ? root.vpnActiveNames.join(", ") : ""

    // More than one tunnel up at once is almost always an accident rather than a
    // plan, and with profiles from the same provider it is a broken state: they
    // are typically issued the same tunnel address and each claims the whole
    // routing table, so they fight over both. NetworkManager will do this on its
    // own at boot for every profile left on autoconnect.
    readonly property bool multipleVpnsActive: root.vpnActiveNames.length > 1

    // Whether each profile is set to come up on its own, read from
    // NetworkManager directly. The daemon does carry an `autoconnect` field, but
    // it comes from `connection.autoconnect` only when NetworkManager includes
    // that key in the settings it hands over - a property sitting at its default
    // may simply be absent, and an absent key reads as false. Asking nmcli is
    // one short call and leaves nothing to infer.
    property var autoconnectByUuid: ({})
    property bool autoconnectKnown: false

    Process {
        id: autoconnectProc

        running: false
        command: ["sh", "-c", "nmcli -t -f UUID,AUTOCONNECT connection show 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = (text || "").trim().split("\n")
                const next = {}
                let any = false
                for (let i = 0; i < rows.length; i++) {
                    const parts = rows[i].split(":")
                    if (parts.length < 2)
                        continue
                    next[parts[0].trim()] = parts[1].trim() === "yes"
                    any = true
                }
                root.autoconnectByUuid = next
                root.autoconnectKnown = any
            }
        }
    }

    // Falls back to whatever the daemon reported when nmcli is not there to ask.
    function autoconnectFor(profile) {
        if (!profile)
            return false
        if (root.autoconnectKnown && root.autoconnectByUuid[profile.uuid] !== undefined)
            return root.autoconnectByUuid[profile.uuid] === true
        return profile.autoconnect === true
    }

    function refreshVpn() {
        root.recoverStuckVpnBusy()
        if (NetService.refreshVpnProfiles)
            NetService.refreshVpnProfiles()
        if (NetService.refreshVpnActive)
            NetService.refreshVpnActive()
        autoconnectProc.running = true
    }

    // ---------------------------------------------- the stuck busy flag ----
    // Every VPN control in this panel is disabled while DMS reports an
    // operation in flight, which is right - until the flag never comes back
    // down, and then nothing in the section can be pressed again.
    //
    // It can genuinely never come down. NetService sets `vpnIsBusy` when
    // it sends the request and clears it in three places: the reply carrying an
    // error, a new error arriving in a pushed state, or `updateState` deciding
    // enough changed. For a *disconnect* that last one is "the number of active
    // connections changed" - so disconnecting when nothing is connected (which
    // is what a failed connect leaves you with) can never clear it, because the
    // count is already zero and stays zero. The 30s timeout that would rescue
    // it is only evaluated inside `updateState`, and nothing polls: DMS only
    // calls it when the daemon pushes. On a quiet network no push comes, so the
    // flag sits there indefinitely rather than for 30 seconds.
    //
    // Nothing is cancelled here - there is no request in flight to cancel, the
    // reply that would have cleared the flag is simply never coming. Only the
    // flag is put back down, which unfreezes DMS' own VPN page too.
    readonly property int vpnBusyGraceMs: 30000
    // An operation that provably cannot report back does not get the full
    // grace; a few seconds is more than the reply itself would have taken.
    readonly property int vpnDeadOpGraceMs: 6000

    property real vpnBusySince: 0

    onVpnBusyChanged: root.vpnBusySince = root.vpnBusy ? Date.now() : 0

    function vpnBusyLooksStuck() {
        if (!root.vpnBusy)
            return false
        // Date.now() has to be read when asked, not bound: a binding would be
        // evaluated once and then never age.
        const waited = Date.now() - root.vpnBusySince
        const noPending = (NetService.pendingVpnUuid ?? "") === ""
        const nothingToDisconnect = noPending && root.vpnActiveNames.length === 0
        return waited > (nothingToDisconnect ? root.vpnDeadOpGraceMs : root.vpnBusyGraceMs)
    }

    function recoverStuckVpnBusy() {
        if (!root.vpnBusyLooksStuck())
            return false
        NetService.vpnIsBusy = false
        NetService.pendingVpnUuid = ""
        // DMS measures its own timeout from this; leaving a stale start time
        // behind would make its next operation look instantly expired.
        if (NetService.vpnBusyStartTime !== undefined)
            NetService.vpnBusyStartTime = 0
        root.vpnBusySince = 0
        return true
    }

    // Only runs while something claims to be busy, and stops the moment it is
    // not - no cost on an idle panel.
    Timer {
        interval: 2000
        repeat: true
        running: root.vpnBusy
        onTriggered: root.recoverStuckVpnBusy()
    }

    function vpnIsActive(uuid) {
        return NetService.isActiveVpnUuid ? NetService.isActiveVpnUuid(uuid) : false
    }

    function vpnIsConnecting(uuid) {
        return NetService.isVpnConnectingUuid ? NetService.isVpnConnectingUuid(uuid) : false
    }

    function vpnStateFor(uuid) {
        return NetService.vpnStateForUuid ? NetService.vpnStateForUuid(uuid) : ""
    }

    // NetworkManager calls a WireGuard connection "wireguard" and everything
    // else "vpn" with a service type naming the plugin, so the readable name
    // comes from whichever of the two is present.
    function vpnKindLabel(profile) {
        if (!profile)
            return ""
        if (profile.type === "wireguard")
            return "WireGuard"
        const svc = String(profile.serviceType || "")
        if (svc === "")
            return "VPN"
        const leaf = svc.split(".").pop()
        if (leaf === "openvpn")
            return "OpenVPN"
        if (leaf === "openconnect")
            return "OpenConnect"
        if (leaf === "wireguard")
            return "WireGuard"
        return leaf.charAt(0).toUpperCase() + leaf.slice(1)
    }

    function vpnToggle(profile) {
        if (!profile || !root.vpnAvailable || root.vpnBusy)
            return
        if (root.vpnIsActive(profile.uuid))
            NetService.disconnectVpn(profile.uuid)
        else
            NetService.connectVpn(profile.uuid, root.vpnSingleActive)
    }

    property string lastCopied: ""

    TextEdit {
        id: clipboardHelper
        visible: false
        width: 0
        height: 0
    }

    // DMS has a toast service; Plasma has notifications. notify-send is what
    // every plasmoid that needs one ends up using, and it is already a
    // dependency of nothing - it ships with the notification stack Plasma runs.
    function notify(title, body) {
        Sh.exec(["notify-send", "-a", "Network Indicator", "-i", "network-wired", title, body], null)
    }

    function copyValue(label, value) {
        if (!value || value === "—")
            return
        // Quickshell hands QML a clipboard property; Qt does not, and Plasma
        // has no QML clipboard either. A TextEdit does have copy(), so an
        // invisible one is the shortest honest route - no wl-copy/xclip
        // dependency, and it works the same on X11 and Wayland.
        clipboardHelper.text = value
        clipboardHelper.selectAll()
        clipboardHelper.copy()
        clipboardHelper.deselect()
        root.lastCopied = value
        // Two confirmations on purpose: the row itself acknowledges immediately
        // where the eye already is, and the notification still says so if the
        // pointer has moved on.
        root.notify("Copied " + label, value)
    }

    // ------------------------------------------------------------ gathering --
    // One shell call for everything local: the default route carries both the
    // gateway and the interface, and `ip -j` hands it back as JSON.
    Process {
        id: routeProc
        running: false
        command: ["sh", "-c", "ip -j route show default 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const rows = JSON.parse(text || "[]")
                    // A box with Docker or a VPN up has more than one default
                    // route. Prefer the one on the interface we already know,
                    // then the lowest metric, rather than whichever came first.
                    let best = null
                    for (let i = 0; i < rows.length; i++) {
                        const r = rows[i]
                        if (!r || !r.gateway)
                            continue
                        if (root.localInterface && r.dev === root.localInterface) {
                            best = r
                            break
                        }
                        if (best === null || (r.metric ?? 0) < (best.metric ?? 0))
                            best = r
                    }
                    root.gateway = best ? (best.gateway ?? "") : ""
                    if (best && !root.localInterface)
                        root.localInterface = best.dev ?? ""
                } catch (e) {
                    root.gateway = ""
                }
                // Chained rather than fired in parallel, so a gateway ping is
                // never sent before the gateway has been resolved.
                if (root.showLatency && root.effectivePingTarget)
                    pingProc.running = true
            }
        }
    }

    Process {
        id: localIpProc
        running: false
        command: ["sh", "-c", "ip -j route get 1.1.1.1 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const rows = JSON.parse(text || "[]")
                    if (rows.length > 0) {
                        // Always recorded: this is the tunnel question. It also
                        // still stands in for the LAN address when DMS' own
                        // NetService has nothing, which is what it was
                        // originally here for.
                        const src = rows[0].prefsrc || ""
                        const dev = rows[0].dev || ""
                        if (src !== "")
                            root.routeSourceIp = src
                        if (dev !== "")
                            root.routeInterface = dev

                        // This lookup follows the route to the internet, which a
                        // full tunnel owns - so with a VPN up it returns the
                        // tunnel's address on the tunnel's device. Standing in
                        // for the LAN address with that is what put 10.x under
                        // "Local network", next to the same number under
                        // "Tunnel". A tunnel's source address is never the
                        // address between this machine and the router, so the
                        // fallback is only taken when this route is not one.
                        const isTunnelRoute = dev !== "" && root.serviceInterface !== "" && dev !== root.serviceInterface
                        if (!isTunnelRoute) {
                            if (src !== "" && !root.serviceIp)
                                root.localIp = src
                            if (dev !== "" && !root.serviceInterface)
                                root.localInterface = dev
                        }
                    }
                } catch (e) {
                    // El unico catch vacio a proposito de los dos plugins.
                    // `ip -j route get` puede no traer JSON (iproute2 viejo, o
                    // sin ruta a ese destino). Dejar los valores como estaban es
                    // la respuesta correcta: una consulta que fallo no es una
                    // respuesta de "nada", que es justo el error que llenaba el
                    // panel de rayas en el lookup publico.
                }
            }
        }
    }

    // La cadena de proveedores. El configurado va primero; los otros existen
    // para que uno caido, bloqueado o limitando por IP no sea el final.
    //
    // Que hizo falta: el panel quedaba con IPv4, ISP, ubicacion y bandera en
    // rayas y un "No response" pelado - rc=0 y cuerpo vacio, o sea que curl
    // conecto y no imprimio nada. Eso es HTTP, no red: un 429, un 403 o una
    // redireccion que curl sin -L descarta en silencio.
    readonly property var publicProviders: {
        const chain = [root.publicProvider,
                       "https://ifconfig.co/json",
                       "https://ipwho.is/"]
        const seen = {}
        const out = []
        for (let i = 0; i < chain.length; i++) {
            const u = String(chain[i] || "").trim()
            if (u === "" || seen[u])
                continue
            seen[u] = true
            out.push(u)
        }
        return out
    }

    // -L porque una redireccion sin seguir se ve exactamente igual que una
    // respuesta vacia, y -w para quedarnos con el codigo HTTP: "429" es una
    // respuesta util y "No response" no lo es.
    readonly property string publicLookupScript: [
        "for u in " + root.publicProviders.map(u => Sh.quote(u)).join(" ") + "; do",
        // `4` y vacio, y la bandera se arma con ${f:+-4}: poner `-4` aqui
        // hacia que la cabecera dijera `mode=-4`, que no es lo que el otro
        // lado busca.
        '  for f in 4 ""; do',
        '    body=$(curl ${f:+-4} -sL --max-time 4 -w "\\n#http=%{http_code}" "$u" 2>/dev/null); rc=$?',
        '    code=$(printf %s "$body" | sed -n \'s/^#http=//p\' | tail -1)',
        '    body=$(printf %s "$body" | sed \'/^#http=/d\')',
        // 2xx Y cuerpo. Solo mirar si el cuerpo esta vacio no alcanza:
        // ipinfo.io contesta el 429 CON cuerpo -
        //   {"status":429,"error":{"title":"Rate limit hit",...}}
        // - asi que la cadena aceptaba su pagina de error y no llegaba nunca al
        // proveedor siguiente. El codigo es lo que decide, no el tamaño.
        '    if [ -n "$body" ] && [ "${code:-0}" -ge 200 ] && [ "${code:-0}" -lt 300 ]; then',
        '      printf \'rc=%s mode=%s http=%s url=%s\\n%s\' "$rc" "${f:-any}" "${code:-0}" "$u" "$body"',
        '      exit 0',
        '    fi',
        '    last_rc=$rc; last_code=$code; last_url=$u',
        '  done',
        "done",
        'printf \'rc=%s mode=any http=%s url=%s\\n\' "${last_rc:-0}" "${last_code:-0}" "${last_url:-none}"'
    ].join("\n")

    // Lo que curl dice cuando falla, en palabras. Son los codigos que se ven de
    // verdad; cualquier otro se muestra como numero antes que como nada.
    function curlReason(rc) {
        switch (rc) {
        case 0:  return ""
        case 6:  return "DNS"
        case 7:  return "no route"
        case 28: return "timed out"
        case 35: return "TLS"
        case 60: return "certificate"
        default: return "curl " + rc
        }
    }

    // Sacar los datos SIN saberme el esquema de cada proveedor.
    //
    // La cadena de respaldo existe para que un proveedor bloqueado no sea el
    // final, pero cada uno nombra sus campos a su manera y no hay forma de
    // comprobar los nombres desde aqui. Asi que no se adivinan: se recorre el
    // JSON -el nivel de arriba y uno de anidado, que es donde viven cosas como
    // connection.isp o asn.name- y se elige por forma y por nombre de clave.
    function _flatten(o) {
        const out = []
        if (!o || typeof o !== "object")
            return out
        for (const k in o) {
            const v = o[k]
            if (v === null || v === undefined)
                continue
            if (typeof v === "object") {
                for (const k2 in v) {
                    const v2 = v[k2]
                    if (v2 !== null && v2 !== undefined && typeof v2 !== "object")
                        out.push([String(k).toLowerCase() + "." + String(k2).toLowerCase(), v2])
                }
            } else {
                out.push([String(k).toLowerCase(), v])
            }
        }
        return out
    }

    function _pick(o, needles, validate) {
        const flat = root._flatten(o)
        // Primero por nombre de clave, en el orden en que se piden.
        for (let n = 0; n < needles.length; n++) {
            for (let i = 0; i < flat.length; i++) {
                if (flat[i][0].indexOf(needles[n]) !== -1) {
                    const v = String(flat[i][1]).trim()
                    if (v !== "" && (!validate || validate(v)))
                        return v
                }
            }
        }
        return ""
    }

    // La direccion: por nombre de clave si se puede, y si no, el primer valor
    // del JSON que TENGA forma de direccion.
    function findAddress(o) {
        const byName = root._pick(o, ["ip_addr", "ipaddress", "ip", "query", "address"],
                                  v => root.isIpv4(v) || v.indexOf(":") !== -1)
        if (byName !== "")
            return byName
        const flat = root._flatten(o)
        for (let i = 0; i < flat.length; i++) {
            const v = String(flat[i][1]).trim()
            if (root.isIpv4(v) || /^[0-9a-f]{0,4}(:[0-9a-f]{0,4}){2,7}$/i.test(v))
                return v
        }
        return ""
    }

    function isIpv4(v) {
        return /^\d{1,3}(\.\d{1,3}){3}$/.test(String(v || "").trim())
    }

    // Separado del proceso para poder alimentarlo con la salida real del
    // script sin levantar curl: el parseo de la cabecera y las cuatro
    // formas de fallar son justo lo que hay que probar.
    function applyPublicLookup(text) {
        root.busy = false
        // The lookup is one transaction: nothing is written unless an
        // address actually came back. This used to overwrite every field
        // with an empty string on a failure, so one unanswered request
        // wiped the address, the ISP, the location and the country - the
        // panel filled with dashes, and with no country left the bar fell
        // back from the flag to the plain icon. A question that failed is
        // not an answer of "nothing".
        // La primera linea la escribe el script:
        // `rc=<n> mode=4|any http=<codigo> url=<proveedor>`.
        const raw = String(text || "")
        const nl = raw.indexOf("\n")
        const header = nl === -1 ? raw : raw.substring(0, nl)
        const bodyText = nl === -1 ? "" : raw.substring(nl + 1)
        const rcMatch = header.match(/rc=(\d+)/)
        const rc = rcMatch ? parseInt(rcMatch[1], 10) : 0
        const forcedV4 = header.indexOf("mode=4") !== -1
        const httpMatch = header.match(/http=(\d+)/)
        const http = httpMatch ? parseInt(httpMatch[1], 10) : 0

        let parsed = null
        try {
            parsed = JSON.parse(bodyText || "{}")
        } catch (e) {
            parsed = null
        }

        const answer = parsed ? root.findAddress(parsed) : ""
        if (answer === "") {
            // Con el motivo de curl, no un "No response" que no dice
            // nada. Un cuerpo que no es JSON casi siempre es la pagina
            // de error del proveedor, y eso tambien se distingue.
            // Un codigo HTTP es una respuesta util; "No response" no lo es.
            // Un 429 o un 403 se ven exactamente igual que un cuerpo vacio
            // hasta que se mira el codigo, que es lo que faltaba.
            const why = root.curlReason(rc)
            if (http >= 400)
                root.statusText = "Provider refused - HTTP " + http
            else if (!parsed)
                root.statusText = "Provider did not answer JSON"
            else
                root.statusText = why === "" ? "No response" : "No response - " + why
            root.schedulePublicRetry()
            return
        }

        const j = parsed
        // El proveedor contesta con la direccion por la que le llego la
        // peticion. Si hubo que dejar caer el `-4`, esa puede ser la
        // IPv6, y meterla en la fila de IPv4 seria mentir. El resto de
        // la respuesta - ISP, pais, ciudad - vale igual, que es todo lo
        // que hace falta para la bandera.
        root.publicIp4 = root.isIpv4(answer) ? answer : ""
        root.isp = root._pick(j, ["asn_org", "org", "isp", "asn.name", "connection.", "carrier"],
                              v => /[A-Za-z]/.test(v))
        // `country` is a code on ipinfo and a name on ip-api, so take
        // the first field that actually looks like a code and let the
        // rest fall through to the printed location.
        const codeCandidates = [
            root._pick(j, ["country_iso", "country_code", "countrycode"]),
            root._pick(j, ["country"]),
            j.country_code, j.countryCode, j.country
        ]
        // Resolved into a local and assigned once. Clearing the property
        // first and filling it in the loop meant every binding on it saw
        // an empty value for one evaluation, so the flag and the country
        // code blinked out and back the instant a lookup landed. A
        // property other things are bound to is not scratch space.
        let resolvedCode = ""
        for (let c = 0; c < codeCandidates.length; c++) {
            if (root.flagFor(codeCandidates[c]) !== "") {
                resolvedCode = String(codeCandidates[c]).trim().toUpperCase()
                break
            }
        }
        root.countryCode = resolvedCode
        const parts = []
        const countryLabel = root._pick(j, ["country_name", "country"], v => v.length > 2) || resolvedCode
        if (countryLabel)
            parts.push(countryLabel)
        const place = root._pick(j, ["city"]) || root._pick(j, ["region", "state"])
        if (place)
            parts.push(place)
        root.location = parts.join(" - ")
        root.statusText = root.isIpv4(answer)
            ? "OK"
            : (forcedV4 ? "OK - no IPv4 address" : "OK - answered over IPv6")
        root.publicRetriesLeft = 0
        publicRetryTimer.stop()
}

    Process {
        id: publicProc
        running: false
        // Dos cosas que faltaban, y que juntas dejaban el panel lleno de rayas:
        //
        // 1. `-4` forzado y nada mas. Si la ruta IPv4 al proveedor no anda -
        //    bloqueada, sin ruta, el proveedor limitando por IP - no hay
        //    respuesta, y CON ELLA se pierden el ISP, la ubicacion y el pais, o
        //    sea la bandera. Pero ninguno de esos tres necesita IPv4: si la
        //    peticion sin forzar llega por IPv6, el proveedor contesta lo mismo.
        //    Asi que si `-4` vuelve vacio se repite sin forzar, y lo unico que
        //    queda sin saberse es la direccion v4.
        // 2. El codigo de salida de curl se tiraba. "No response" no dice si fue
        //    un timeout, un DNS que no resuelve o una ruta que no existe, que es
        //    justo lo que hace falta para saber a quien culpar.
        command: ["sh", "-c", root.publicLookupScript]
        stdout: StdioCollector {
            onStreamFinished: root.applyPublicLookup(text)
        }
    }

    Process {
        id: ipv6Proc
        running: false
        command: ["sh", "-c", "curl -6 -s --max-time 6 https://ifconfig.co 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = (text || "").trim()
                if (v.indexOf(":") !== -1) {
                    root.publicIp6 = v
                    root.hasIpv6Answer = true
                } else if (root.statusText === "OK") {
                    // Only believe "there is no IPv6 here" when the round as a
                    // whole succeeded. A tunnel really may have no IPv6, but a
                    // request that failed is not evidence of that.
                    root.publicIp6 = ""
                }
            }
        }
    }

    // Sh.quote, NO JSON.stringify.
    //
    // Esto construia el comando con JSON.stringify(pingTarget), que produce una
    // cadena entre comillas DOBLES de JSON. En shell, dentro de comillas dobles
    // siguen vivos $, ` y \, asi que un destino de ping como
    //     x$(rm -rf algo)   o   x`comando`
    // se ejecutaba. Y pingTarget es un campo de texto libre en la pagina de
    // settings, o sea que el valor entra desde afuera del codigo.
    // Sh.quote usa comillas simples, donde no se interpola nada.
    readonly property string pingScript:
        "ping -c 1 -W 2 " + Sh.quote(root.effectivePingTarget)
        + " 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p' || true"

    Process {
        id: pingProc
        running: false
        command: ["sh", "-c", root.pingScript]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseFloat((text || "").trim())
                root.latency = isNaN(v) ? "" : (v.toFixed(2) + " ms")
            }
        }
    }

    function refreshLocal() {
        routeProc.running = true
        // Runs every time now, not only as a fallback. It answers which
        // interface carries traffic to the internet, which is the whole point of
        // the tunnel row - and that changes the moment a VPN comes up.
        localIpProc.running = true
    }

    // A tunnel that has just come up is not ready to carry a request: routes and
    // DNS take a moment, and asking too early simply fails. Rather than
    // presenting that failure as fact, ask again a few times over the next few
    // seconds. If it still fails after that the failure is real, and worth
    // showing - it usually means the tunnel is not carrying traffic at all.
    property int publicRetriesLeft: 0

    Timer {
        id: publicRetryTimer
        interval: 3000
        onTriggered: {
            if (root.publicRetriesLeft > 0)
                root.runPublicLookup()
        }
    }

    function schedulePublicRetry() {
        if (root.publicRetriesLeft <= 0)
            return
        root.publicRetriesLeft--
        publicRetryTimer.restart()
    }

    function runPublicLookup() {
        root.busy = true
        root.statusText = "Checking…"
        publicProc.running = true
        if (root.lookupIpv6)
            ipv6Proc.running = true
    }

    function refreshPublic(retries) {
        if (!root.lookupPublic) {
            root.statusText = "Public lookup off"
            return
        }
        // Antes esto era 0 por defecto: un fallo suelto se quedaba en pantalla
        // hasta el siguiente tick, cinco minutos despues. Dos intentos separados
        // tres segundos cubren el caso normal sin machacar al proveedor.
        root.publicRetriesLeft = (retries === undefined) ? 2 : retries
        publicRetryTimer.stop()
        root.runPublicLookup()
    }

    function refreshAll() {
        root.refreshLocal()
        root.refreshPublic()
        // The profile list was never asked to refresh, so a profile whose
        // autoconnect had been changed kept showing the value it had when DMS
        // last loaded it.
        root.refreshVpn()
    }

    Timer {
        interval: Math.max(15, root.refreshSeconds) * 1000
        repeat: true
        running: root.refreshSeconds > 0
        onTriggered: root.refreshAll()
    }

    // A reconnect changes the facts underneath us, so re-read rather than
    // waiting for the next tick.
    Connections {
        target: NetService
        function onNetworkStatusChanged() {
            Qt.callLater(root.refreshAll)
        }
    }

    // DMS exposes a session-resumed signal; Plasma does not offer one to QML.
    // Losing it costs one stale cycle after a suspend, which the periodic
    // refresh below already corrects - so nothing is bolted on to fake it.

    // Bringing a VPN up or down changes which address the world sees, so the
    // public lookup has to run again - otherwise the flag and the public IP keep
    // showing the country you were in before the tunnel. The lookup is only
    // re-run once the daemon has stopped working, so a connection in progress
    // does not fire one request per intermediate state.
    Connections {
        target: NetService

        function onVpnConnectedChanged() {
            if (!NetService.vpnIsBusy)
                vpnSettleTimer.restart()
        }

        function onVpnIsBusyChanged() {
            if (!NetService.vpnIsBusy)
                vpnSettleTimer.restart()
        }
    }

    Timer {
        id: vpnSettleTimer
        // The tunnel needs a moment before traffic actually routes through it;
        // asking too early just fails. Four attempts, because how long a fresh
        // tunnel takes to carry a request is not something this can know.
        interval: 1200
        onTriggered: root.refreshPublic(4)
    }

    // --------------------------------------------------------------- pill --
    // Middle-clicking the pill cycles which address it shows; with the toggle
    // off it is a manual refresh instead. Was an injected callback on DMS; here
    // it is a plain function the pill calls, because Plasma injects nothing.
    // Was pillRightClick(). The gesture moved to the middle button on Plasma
    // (the right one belongs to the shell's applet menu), so the name no longer
    // said what it does.
    function pillSecondaryAction() {
        // Alternar solo tiene sentido si hay DOS direcciones que mostrar. Con
        // el ajuste en "Swap on middle click" pero sin ningun tunel llevando
        // trafico, esto invertia un booleano que displayLocalIp ignora: el
        // gesto no hacia absolutamente nada, ni alternaba ni refrescaba. Un
        // boton que a veces no hace nada es peor que uno que hace una sola
        // cosa, asi que sin tunel cae al refresco.
        if (root.localIpIsToggleable && root.trafficLeavesViaTunnel && root.routeSourceIp !== "") {
            root.showingTunnelIp = !root.showingTunnelIp
            return
        }
        root.refreshAll()
    }

    // A VPN is worth knowing about at a glance, so it colours the pill rather
    // than only appearing in the panel.
    readonly property bool vpnShownInPill: root.showVpnInPill && root.vpnAvailable && root.vpnConnected

    // The flag only replaces the icon when there is really a flag to draw: no
    // country resolved yet, no font that can render one, or privacy mode on, and
    // the icon stays. An icon is a worse answer than a flag but a much better
    // one than a blank space.
    readonly property bool pillShowsFlag: root.pillIconMode === "flag" && !root.privacyMode && root.countryFlag !== "" && root.flagAvailable
    readonly property color effectiveIconColor: (root.vpnShownInPill && root.tintPillWhenVpn) ? Theme.success : root.pillIconColor



    // -------------------------------------------------------------- popout --
    // The label column, the copy button, the two gaps between the three
    // columns, and PluginPopout's own spacingS padding on each side: everything
    // the value column does not get.
    readonly property real infoLabelWidth: 92
    readonly property real popoutChrome: root.infoLabelWidth + 22 + Theme.spacingS * 2 + Theme.spacingS * 2

    // A full IPv6 address has to fit on one line, and how wide that is depends
    // on the font and on the user's font scale - so measure it rather than
    // hardcode a number that only holds on one machine. Measured against a
    // maximum-length address rather than the live one, so the box is a constant
    // width and the popout never resizes underneath you when the lookup lands.
    StyledText {
        id: valueProbe

        visible: false
        text: "ffff:ffff:ffff:ffff:ffff:ffff:ffff:ffff"
        font.pixelSize: Theme.fontSizeSmall
        isMonospace: root.monospace
    }

    popoutWidth: Math.round(Math.max(400, Math.min(600, valueProbe.implicitWidth + root.popoutChrome + 10)))

    property bool appearanceOpen: false

    readonly property var pillContentOptions: [
        {
            "label": "Local IP",
            "value": "localIp"
        },
        {
            "label": "Public IP",
            "value": "publicIp"
        },
        {
            "label": "Gateway",
            "value": "gateway"
        },
        {
            "label": "Interface",
            "value": "interface"
        },
        {
            "label": "SSID",
            "value": "ssid"
        },
        {
            "label": "Icon only",
            "value": "none"
        }
    ]
    readonly property var pillIconModeOptions: [
        {
            "label": "Icon",
            "value": "icon"
        },
        {
            "label": "Flag",
            "value": "flag"
        }
    ]
    readonly property var colorModeOptions: [
        {
            "label": "Theme",
            "value": "theme"
        },
        {
            "label": "White",
            "value": "white"
        },
        {
            "label": "Accent",
            "value": "accent"
        },
        {
            "label": "Custom",
            "value": "custom"
        }
    ]
    readonly property var iconColorModeOptions: [
        {
            "label": "Match text",
            "value": "match"
        },
        {
            "label": "Theme",
            "value": "theme"
        },
        {
            "label": "White",
            "value": "white"
        },
        {
            "label": "Accent",
            "value": "accent"
        },
        {
            "label": "Custom",
            "value": "custom"
        }
    ]
    readonly property var latencyModeOptions: [
        {
            "label": "Gateway",
            "value": "gateway"
        },
        {
            "label": "Internet",
            "value": "internet"
        },
        {
            "label": "Custom host",
            "value": "custom"
        }
    ]


    // A label on the left and a - value + stepper on the right, so changing the
    // icon size costs no extra height in the panel and you watch the bar change
    // as you press it.



}
