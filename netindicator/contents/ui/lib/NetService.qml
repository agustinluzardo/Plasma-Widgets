pragma Singleton
import QtQuick

// What DMS' NetworkService and DMSNetworkService provided, rebuilt on nmcli.
//
// DMS gets this from its own Go daemon over a socket. Plasma has no equivalent,
// so the source of truth here is NetworkManager itself, asked directly. That is
// not a downgrade: the daemon was asking NetworkManager too, and one of the
// bugs we fixed in the DMS version came from its profile records carrying a
// stale `autoconnect` that nmcli always had right.
//
// Everything is read in ONE launch per refresh. The alternative - a process per
// field - would be five to eight processes every cycle on a widget that sits in
// the panel all day.
//
// nmcli -t separates fields with ':' and escapes literal colons as '\:'. Rather
// than unescape, every query below puts the one field that can contain a colon
// (NAME / CONNECTION) LAST, so everything after the n-th colon is that field
// and no unescaping is needed.
QtObject {
    id: net

    // ---- NetworkService surface ------------------------------------------
    property bool ethernetConnected: false
    property string ethernetIP: ""
    property string ethernetInterface: ""
    property bool wifiConnected: false
    property string wifiIP: ""
    property string wifiInterface: ""
    property string currentWifiSSID: ""

    signal networkStatusChanged()

    // What the panel shows as "your address": the wired one when there is one,
    // the wireless one otherwise. A tunnel's address is deliberately NOT this -
    // it is the address between this machine and the router, and a VPN does not
    // change it.
    readonly property string localAddress: net.ethernetConnected ? net.ethernetIP : net.wifiIP
    readonly property string localInterface: net.ethernetConnected ? net.ethernetInterface : net.wifiInterface

    // Qt gives QML no clipboard, and neither does Plasma. wl-copy is the
    // Wayland tool and xclip the X11 one; trying both in one line means the
    // widget does not have to know which session it is in.
    function copy(text) {
        if (!text || text === "")
            return;
        Sh.exec(["sh", "-c",
                 "printf %s " + Sh.quote(text) + " | { wl-copy 2>/dev/null || xclip -selection clipboard 2>/dev/null; }"],
                null);
    }

    // ---- DMSNetworkService surface ---------------------------------------
    property bool vpnAvailable: true
    property var vpnProfiles: []
    property var vpnActive: []
    property bool vpnIsBusy: false
    property string pendingVpnUuid: ""
    property var vpnBusyStartTime: 0
    property string vpnError: ""
    property string vpnErrorUuid: ""

    readonly property var activeUuids: net.vpnActive.map(v => v.uuid).filter(u => !!u)
    readonly property var activeNames: net.vpnActive.map(v => v.name).filter(n => !!n)
    readonly property bool vpnConnected: net.activeUuids.length > 0

    function vpnStateForUuid(uuid) {
        for (let i = 0; i < net.vpnActive.length; i++)
            if (net.vpnActive[i].uuid === uuid)
                return net.vpnActive[i].state || "";
        return "";
    }

    function isActiveVpnUuid(uuid) {
        return net.activeUuids.indexOf(uuid) !== -1;
    }

    function isVpnConnectingUuid(uuid) {
        return net.vpnStateForUuid(uuid) === "activating" || (net.vpnIsBusy && net.pendingVpnUuid === uuid);
    }

    // ---- parsing ---------------------------------------------------------
    // Splits an nmcli -t line into `count` fields, with everything after the
    // last separator kept whole - that trailing field is the one allowed to
    // contain colons.
    function splitTail(line, count) {
        const out = [];
        let rest = line;
        for (let i = 0; i < count - 1; i++) {
            const at = rest.indexOf(":");
            if (at === -1) {
                out.push(rest);
                rest = "";
                continue;
            }
            out.push(rest.substring(0, at));
            rest = rest.substring(at + 1);
        }
        out.push(rest);
        return out;
    }

    function section(text, name) {
        const start = text.indexOf("#" + name + "\n");
        if (start === -1)
            return "";
        const from = start + name.length + 2;
        const next = text.indexOf("\n#", from - 1);
        return (next === -1 ? text.substring(from) : text.substring(from, next + 1)).trim();
    }

    // NetworkManager calls OpenVPN and friends "vpn" with the plugin named in
    // vpn.service-type; WireGuard is its own type with no service type at all.
    function isVpnType(t) {
        return t === "vpn" || t === "wireguard";
    }

    readonly property string probeScript: [
        "echo '#DEV'",
        "nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status 2>/dev/null",
        "echo '#ACT'",
        "nmcli -t -f UUID,TYPE,DEVICE,STATE,NAME connection show --active 2>/dev/null",
        "echo '#PRO'",
        // vpn.service-type needs a second query per profile, so it is only asked
        // for the handful of connections that are VPNs at all.
        "nmcli -t -f UUID,TYPE,AUTOCONNECT,NAME connection show 2>/dev/null | while IFS= read -r l; do",
        "  u=${l%%:*}; r=${l#*:}; t=${r%%:*}",
        "  case \"$t\" in vpn|wireguard)",
        "    s=$(nmcli -t -f vpn.service-type connection show \"$u\" 2>/dev/null | cut -d: -f2-)",
        "    printf '%s:%s\\n' \"$l\" \"$s\" ;;",
        "  esac",
        "done",
        "echo '#ADDR'",
        "ip -j -4 addr 2>/dev/null",
        "echo '#SSID'",
        "nmcli -t -f ACTIVE,SSID device wifi list 2>/dev/null | sed -n 's/^yes://p' | head -1",
        "echo '#END'"
    // UNIDO CON SALTOS DE LINEA, no con "; ".
    // Esto se unia con "; ", que produce `do;`, `case "$t" in vpn|wireguard);`
    // y `;;;` - tres errores de sintaxis. `sh -c` analiza el script entero
    // antes de ejecutar nada, asi que el probe completo moria sin correr una
    // sola linea y la lista de perfiles VPN salia siempre vacia.
    // Un salto de linea es separador valido en todos esos sitios.
    ].join("\n")

    // La firma del estado que este widget dibuja.
    //
    // Se calcula sobre lo PARSEADO, nunca sobre el texto crudo del probe:
    // `ip -j addr` trae valid_life_time / preferred_life_time, que bajan un
    // segundo por segundo en una direccion DHCP, asi que el texto difiere en
    // cada lectura aunque la red este completamente quieta.
    function stateSignature() {
        const profiles = (net.vpnProfiles ?? [])
            .map(p => p.uuid + "," + p.name + "," + p.autoconnect + "," + p.type).join("|");
        const active = (net.vpnActive ?? [])
            .map(v => v.uuid + "," + v.name + "," + v.device).join("|");
        return [net.ethernetInterface, net.ethernetIP, net.ethernetConnected,
                net.wifiInterface, net.wifiIP, net.wifiConnected, net.currentWifiSSID,
                profiles, active].join(";");
    }

    property string _lastSignature: ""

    function applyProbe(text) {
        net.parseDevices(net.section(text, "DEV"), net.section(text, "ADDR"), net.section(text, "SSID"));
        net.parseProfiles(net.section(text, "PRO"));
        net.parseActive(net.section(text, "ACT"));

        // networkStatusChanged significa "la red CAMBIO", no "acabamos de
        // releer la red". NetState la escucha y responde con refreshAll(), que
        // vuelve a correr este mismo probe: emitirla al final de cada lectura
        // cierra el bucle y el widget se relee tan rapido como conteste nmcli
        // - "checking" permanente y la latencia saltando sin parar.
        //
        // Estuvo latente mientras el script tenia el error de sintaxis: la
        // salida vacia se descartaba antes de llegar aca, asi que la señal no
        // se emitia nunca. Arreglar el probe encendio el bucle.
        const sig = net.stateSignature();
        if (sig === net._lastSignature)
            return;
        net._lastSignature = sig;
        net.networkStatusChanged();
    }

    function parseDevices(devText, addrText, ssidText) {
        let ethDev = "";
        let wifiDev = "";
        const rows = devText === "" ? [] : devText.split("\n");
        for (let i = 0; i < rows.length; i++) {
            const f = net.splitTail(rows[i], 4);
            const dev = f[0], type = f[1], state = f[2];
            if (state !== "connected")
                continue;
            if (type === "ethernet" && ethDev === "")
                ethDev = dev;
            else if (type === "wifi" && wifiDev === "")
                wifiDev = dev;
        }

        // Addresses come from `ip -j addr` rather than nmcli: it is already JSON,
        // and the plugin parses ip's JSON elsewhere anyway.
        const byDev = {};
        try {
            const parsed = JSON.parse(addrText || "[]");
            for (let j = 0; j < parsed.length; j++) {
                const entry = parsed[j];
                const infos = entry.addr_info || [];
                for (let k = 0; k < infos.length; k++) {
                    if (infos[k].family === "inet" && infos[k].scope === "global") {
                        byDev[entry.ifname] = infos[k].local;
                        break;
                    }
                }
            }
        } catch (e) {
            // A machine without iproute2's JSON support leaves addresses empty
            // rather than taking the whole refresh down.
        }

        net.ethernetInterface = ethDev;
        net.ethernetIP = ethDev !== "" ? (byDev[ethDev] || "") : "";
        net.ethernetConnected = ethDev !== "";
        net.wifiInterface = wifiDev;
        net.wifiIP = wifiDev !== "" ? (byDev[wifiDev] || "") : "";
        net.wifiConnected = wifiDev !== "";
        net.currentWifiSSID = wifiDev !== "" ? (ssidText || "").trim() : "";
    }

    function parseProfiles(text) {
        const out = [];
        const rows = text === "" ? [] : text.split("\n");
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].trim() === "")
                continue;
            // UUID:TYPE:AUTOCONNECT:NAME:SERVICETYPE - the service type is
            // appended by the probe after the name, so the name is read from a
            // fixed position and the tail is split off the end.
            const lastColon = rows[i].lastIndexOf(":");
            const serviceType = lastColon === -1 ? "" : rows[i].substring(lastColon + 1);
            const head = lastColon === -1 ? rows[i] : rows[i].substring(0, lastColon);
            const f = net.splitTail(head, 4);
            if (!net.isVpnType(f[1]))
                continue;
            out.push({
                "uuid": f[0],
                "type": f[1],
                "autoconnect": f[2] === "yes",
                "name": f[3],
                "serviceType": serviceType,
                "remoteHost": "",
                "username": ""
            });
        }
        net.vpnProfiles = out;
        net.vpnAvailable = true;
    }

    function parseActive(text) {
        const out = [];
        const rows = text === "" ? [] : text.split("\n");
        for (let i = 0; i < rows.length; i++) {
            if (rows[i].trim() === "")
                continue;
            const f = net.splitTail(rows[i], 5);
            if (!net.isVpnType(f[1]))
                continue;
            out.push({ "uuid": f[0], "device": f[2], "state": f[3], "name": f[4] });
        }

        const before = net.vpnActive.length;
        net.vpnActive = out;

        // The same rule DMS uses to decide an operation finished, minus the trap
        // we hit there: DMS only ever evaluated its timeout when the daemon
        // happened to push a state, so on a quiet network the busy flag could
        // never come down. Here the refresh itself is the tick.
        if (net.vpnIsBusy) {
            const waited = Date.now() - net.vpnBusyStartTime;
            const settled = net.pendingVpnUuid !== ""
                ? net.isActiveVpnUuid(net.pendingVpnUuid)
                : before !== out.length;
            if (settled || waited > 30000) {
                net.vpnIsBusy = false;
                net.pendingVpnUuid = "";
                net.vpnBusyStartTime = 0;
            }
        }
    }

    // ---- actions ---------------------------------------------------------
    function refreshVpnProfiles() { net.refresh(); }
    function refreshVpnActive() { net.refresh(); }

    property bool _refreshing: false

    function refresh() {
        if (net._refreshing)
            return;
        net._refreshing = true;
        Sh.exec(["sh", "-c", net.probeScript], (out, err, code) => {
            net._refreshing = false;
            if ((out || "").indexOf("#END") === -1 && (out || "").trim() === "")
                return;
            net.applyProbe(out || "");
        });
    }

    function connectVpn(uuidOrName, singleActive) {
        if (net.vpnIsBusy)
            return;
        net.vpnIsBusy = true;
        net.pendingVpnUuid = uuidOrName;
        net.vpnBusyStartTime = Date.now();
        net.vpnError = "";
        net.vpnErrorUuid = "";

        const pre = (singleActive === true && net.activeUuids.length > 0)
            ? net.activeUuids.map(u => "nmcli connection down uuid " + Sh.quote(u) + " >/dev/null 2>&1;").join(" ")
            : "";

        Sh.exec(["sh", "-c", pre + " nmcli connection up uuid " + Sh.quote(uuidOrName) + " 2>&1"], (out, err, code) => {
            if (code !== 0) {
                net.vpnIsBusy = false;
                net.pendingVpnUuid = "";
                net.vpnBusyStartTime = 0;
                // nmcli explains itself on stdout here, and its last line names
                // the actual reason - far more use than the exit code.
                const lines = (out || err || "").trim().split("\n");
                net.vpnError = lines.length > 0 ? lines[lines.length - 1] : "Failed to connect";
                net.vpnErrorUuid = uuidOrName;
            }
            net.refresh();
        });
    }

    function disconnectVpn(uuidOrName) {
        if (net.vpnIsBusy)
            return;
        net.vpnIsBusy = true;
        net.pendingVpnUuid = "";
        net.vpnBusyStartTime = Date.now();
        Sh.exec(["sh", "-c", "nmcli connection down uuid " + Sh.quote(uuidOrName) + " 2>&1"], (out, err, code) => {
            if (code !== 0) {
                net.vpnIsBusy = false;
                net.vpnBusyStartTime = 0;
            }
            net.refresh();
        });
    }

    function disconnectAllVpns() {
        if (net.vpnIsBusy || net.activeUuids.length === 0)
            return;
        net.vpnIsBusy = true;
        net.pendingVpnUuid = "";
        net.vpnBusyStartTime = Date.now();
        const cmd = net.activeUuids.map(u => "nmcli connection down uuid " + Sh.quote(u) + " >/dev/null 2>&1;").join(" ");
        Sh.exec(["sh", "-c", cmd + " true"], () => net.refresh());
    }

    function toggleVpn(uuid) {
        if (net.isActiveVpnUuid(uuid))
            net.disconnectVpn(uuid);
        else
            net.connectVpn(uuid, true);
    }
}
