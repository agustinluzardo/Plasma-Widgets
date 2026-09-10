import QtQuick

// Plasma's executable data engine. Canned stdout/exit codes keyed by a
// substring of the command, plus a log of everything that was run.
QtObject {
    id: ds
    property string engine: ""
    property var connectedSources: []
    signal newData(string sourceName, var data)

    function connectSource(cmd) {
        // El log se acota. Un array que crece sin limite Y se copia entero en
        // cada concat es O(n^2) en memoria, y falsea cualquier medicion de
        // consumo hecha con este mock: aparecian 6 MB de "fuga" que eran del
        // instrumento, no del widget.
        DsMock.calls = (DsMock.calls.length >= 200 ? DsMock.calls.slice(-100) : DsMock.calls).concat([cmd]);
        if (DsMock.defer) {
            // El motor deduplica por nombre de source: conectar dos veces el
            // mismo comando NO produce dos respuestas.
            if (DsMock.deferred.indexOf(cmd) === -1)
                DsMock.deferred = DsMock.deferred.concat([cmd]);
            return;
        }
        const r = DsMock.resultFor(cmd);
        ds.newData(cmd, { "stdout": r.out, "stderr": r.err, "exit code": r.code });
    }

    // Contesta UNA vez por source pendiente, como haria el proceso al terminar.
    function flush() {
        const pend = DsMock.deferred;
        DsMock.deferred = [];
        for (let i = 0; i < pend.length; i++) {
            const r = DsMock.resultFor(pend[i]);
            ds.newData(pend[i], { "stdout": r.out, "stderr": r.err, "exit code": r.code });
        }
    }
    function disconnectSource(cmd) {}
}
