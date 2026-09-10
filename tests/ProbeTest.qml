// El script del probe tiene que ser shell VALIDO.
//
// Se unia con "; ", que produce `do;`, `case ... in vpn|wireguard);` y `;;;`.
// `sh -c` analiza todo el script antes de ejecutar una linea, asi que el probe
// entero moria: sin dispositivos, sin direcciones y - lo que se veia - sin
// perfiles VPN, con NetworkManager teniendo tres cargados.
// Este test lo escupe a un archivo y run.sh lo pasa por `bash -n`.
import QtQuick
import "../netindicator/contents/ui/lib" as Lib

Item {
    Component.onCompleted: {
        const script = Lib.NetService.probeScript;
        console.log("### PROBE-BEGIN");
        console.log(script);
        console.log("### PROBE-END");
    }
}
