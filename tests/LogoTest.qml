// El nombre del logo de la distro tiene que EXISTIR.
//
// Se construía como `<ID>-logo`. En Arch el ID es "arch" y el icono se llama
// "archlinux-logo", así que "arch-logo" no existe en ningún tema y lo que se
// dibujaba era el cuadrado blanco de icono ausente.
import QtQuick
import "../netindicator/contents/ui/lib" as Lib

Item {
    Component.onCompleted: {
        console.log("### LOGO-BEGIN");
        console.log(Lib.NetState.distroLogoProbe);
        console.log("### LOGO-END");
        console.log("### PUB-BEGIN");
        console.log(Lib.NetState.publicLookupScript);
        console.log("### PUB-END");
        Lib.NetState.pluginData = { "latencyMode": "custom", "pingTarget": "x$(touch /tmp/PWNED-subst)`touch /tmp/PWNED-tick`" };
        console.log("### PING-BEGIN");
        console.log(Lib.NetState.pingScript);
        console.log("### PING-END");
    }
}
