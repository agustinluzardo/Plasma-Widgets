pragma Singleton
import QtQuick
QtObject {
    property var responses: ({})
    property var calls: []
    // Modo diferido: connectSource NO contesta al instante, como el motor de
    // verdad. Es la unica forma de tener dos comandos identicos EN VUELO a la
    // vez, que es el caso que el mapa de callbacks tiene que sobrevivir.
    property bool defer: false
    property var deferred: []
    function reset() { responses = {}; calls = []; defer = false; deferred = []; }
    function resultFor(line) {
        const keys = Object.keys(responses);
        for (let i = 0; i < keys.length; i++)
            if (line.indexOf(keys[i]) !== -1) {
                const r = responses[keys[i]];
                if (typeof r === "string") return { "out": r, "err": "", "code": 0 };
                return { "out": r.out ?? "", "err": r.err ?? "", "code": r.code ?? 0 };
            }
        return { "out": "", "err": "", "code": 0 };
    }
}
