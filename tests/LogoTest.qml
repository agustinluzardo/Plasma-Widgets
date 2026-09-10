// El nombre del logo de la distro tiene que EXISTIR.
//
// Se construía como `<ID>-logo`. En Arch el ID es "arch" y el icono se llama
// "archlinux-logo", así que "arch-logo" no existe en ningún tema y lo que se
// dibujaba era el cuadrado blanco de icono ausente.
import QtQuick
import "../netindicator/contents/ui/lib" as Lib

Item {

    // NetState ya no es un singleton: es uno por applet. El test crea el suyo,
    // igual que main.qml.
    Lib.NetState { id: estado }
    Component.onCompleted: {
        console.log("### LOGO-BEGIN");
        console.log(estado.distroLogoProbe);
        console.log("### LOGO-END");
        console.log("### PUB-BEGIN");
        console.log(estado.publicLookupScript);
        console.log("### PUB-END");
        estado.pluginData = { "latencyMode": "custom", "pingTarget": "x$(touch /tmp/PWNED-subst)`touch /tmp/PWNED-tick`" };
        console.log("### PING-BEGIN");
        console.log(estado.pingScript);
        console.log("### PING-END");
    }
}
