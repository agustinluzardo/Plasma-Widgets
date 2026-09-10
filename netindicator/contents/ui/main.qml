import QtQuick
import org.kde.plasma.plasmoid
import "lib" as Lib

// Nombra las dos representaciones y crea EL estado de este applet.
//
// NetState no es un singleton: plasmashell corre todos los applets en un solo
// motor QML, asi que un singleton seria uno para todo el escritorio. Con el
// widget puesto en dos paneles, el segundo pisaba los ajustes del primero y sus
// clics escribian en la configuracion del otro. Los hechos de red si son
// globales y siguen compartidos en NetService.
PlasmoidItem {
    id: root

    // UNO POR APPLET. Antes esto era un singleton, o sea uno para todo el
    // escritorio: con el widget puesto en dos paneles, el segundo pisaba los
    // ajustes del primero y sus clics escribian en la configuracion del otro.
    property QtObject netState: Lib.NetState {}

    compactRepresentation: NetPill { state: root.netState }
    fullRepresentation: NetPanel { state: root.netState }

    toolTipMainText: "Network"
    toolTipSubText: root.netState.statusText

    // El unico sitio por el que los ajustes de Plasma entran al estado.
    Binding {
        target: root.netState
        property: "pluginData"
        value: ({
        "pillContent": Plasmoid.configuration.pillContent,
        "colorMode": Plasmoid.configuration.colorMode,
        "customColor": Plasmoid.configuration.customColor,
        "iconColorMode": Plasmoid.configuration.iconColorMode,
        "iconCustomColor": Plasmoid.configuration.iconCustomColor,
        "showIcon": Plasmoid.configuration.showIcon,
        "pillIconMode": Plasmoid.configuration.pillIconMode,
        "iconName": Plasmoid.configuration.iconName,
        "iconOffset": Plasmoid.configuration.iconOffset,
        "textOffset": Plasmoid.configuration.textOffset,
        "monospace": Plasmoid.configuration.monospace,
        "showPublicSection": Plasmoid.configuration.showPublicSection,
        "showIsp": Plasmoid.configuration.showIsp,
        "showLocation": Plasmoid.configuration.showLocation,
        "showLocalSection": Plasmoid.configuration.showLocalSection,
        "showGateway": Plasmoid.configuration.showGateway,
        "showLatency": Plasmoid.configuration.showLatency,
        "showDistroLogo": Plasmoid.configuration.showDistroLogo,
        "showCountryFlag": Plasmoid.configuration.showCountryFlag,
        "showVpnSection": Plasmoid.configuration.showVpnSection,
        "localIpSource": Plasmoid.configuration.localIpSource,
        "showTunnelSection": Plasmoid.configuration.showTunnelSection,
        "showVpnInPill": Plasmoid.configuration.showVpnInPill,
        "showVpnName": Plasmoid.configuration.showVpnName,
        "tintPillWhenVpn": Plasmoid.configuration.tintPillWhenVpn,
        "vpnSingleActive": Plasmoid.configuration.vpnSingleActive,
        "vpnIconName": Plasmoid.configuration.vpnIconName,
        "startPrivate": Plasmoid.configuration.startPrivate,
        "lookupPublic": Plasmoid.configuration.lookupPublic,
        "lookupIpv6": Plasmoid.configuration.lookupIpv6,
        "publicProvider": Plasmoid.configuration.publicProvider,
        "latencyMode": Plasmoid.configuration.latencyMode,
        "pingTarget": Plasmoid.configuration.pingTarget,
        "refreshSeconds": Plasmoid.configuration.refreshSeconds
        })
    }

    // isVertical estaba clavado en `false` en NetState y nadie lo movia.
    Binding {
        target: root.netState
        property: "isVertical"
        value: Plasmoid.formFactor === 3   // PlasmaCore.Types.Vertical
    }

    Component.onCompleted: {
        root.netState.savePluginData = (key, value) => root.saveSetting(key, value);
        root.netState.refreshAll();
    }

    onExpandedChanged: if (root.expanded) root.netState.refreshAll()

    function saveSetting(key, value) {
        switch (key) {
        case "pillContent": Plasmoid.configuration.pillContent = value; break;
        case "colorMode": Plasmoid.configuration.colorMode = value; break;
        case "customColor": Plasmoid.configuration.customColor = value; break;
        case "iconColorMode": Plasmoid.configuration.iconColorMode = value; break;
        case "iconCustomColor": Plasmoid.configuration.iconCustomColor = value; break;
        case "showIcon": Plasmoid.configuration.showIcon = value; break;
        case "pillIconMode": Plasmoid.configuration.pillIconMode = value; break;
        case "iconName": Plasmoid.configuration.iconName = value; break;
        case "iconOffset": Plasmoid.configuration.iconOffset = value; break;
        case "textOffset": Plasmoid.configuration.textOffset = value; break;
        case "monospace": Plasmoid.configuration.monospace = value; break;
        case "showPublicSection": Plasmoid.configuration.showPublicSection = value; break;
        case "showIsp": Plasmoid.configuration.showIsp = value; break;
        case "showLocation": Plasmoid.configuration.showLocation = value; break;
        case "showLocalSection": Plasmoid.configuration.showLocalSection = value; break;
        case "showGateway": Plasmoid.configuration.showGateway = value; break;
        case "showLatency": Plasmoid.configuration.showLatency = value; break;
        case "showDistroLogo": Plasmoid.configuration.showDistroLogo = value; break;
        case "showCountryFlag": Plasmoid.configuration.showCountryFlag = value; break;
        case "showVpnSection": Plasmoid.configuration.showVpnSection = value; break;
        case "localIpSource": Plasmoid.configuration.localIpSource = value; break;
        case "showTunnelSection": Plasmoid.configuration.showTunnelSection = value; break;
        case "showVpnInPill": Plasmoid.configuration.showVpnInPill = value; break;
        case "showVpnName": Plasmoid.configuration.showVpnName = value; break;
        case "tintPillWhenVpn": Plasmoid.configuration.tintPillWhenVpn = value; break;
        case "vpnSingleActive": Plasmoid.configuration.vpnSingleActive = value; break;
        case "vpnIconName": Plasmoid.configuration.vpnIconName = value; break;
        case "startPrivate": Plasmoid.configuration.startPrivate = value; break;
        case "lookupPublic": Plasmoid.configuration.lookupPublic = value; break;
        case "lookupIpv6": Plasmoid.configuration.lookupIpv6 = value; break;
        case "publicProvider": Plasmoid.configuration.publicProvider = value; break;
        case "latencyMode": Plasmoid.configuration.latencyMode = value; break;
        case "pingTarget": Plasmoid.configuration.pingTarget = value; break;
        case "refreshSeconds": Plasmoid.configuration.refreshSeconds = value; break;
        default:
            console.warn("netindicator: setting desconocido", key);
        }
    }
}
