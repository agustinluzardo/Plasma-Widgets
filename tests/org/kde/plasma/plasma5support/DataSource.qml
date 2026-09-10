import QtQuick

// Plasma's executable data engine. Canned stdout/exit codes keyed by a
// substring of the command, plus a log of everything that was run.
QtObject {
    id: ds
    property string engine: ""
    property var connectedSources: []
    signal newData(string sourceName, var data)

    function connectSource(cmd) {
        DsMock.calls = DsMock.calls.concat([cmd]);
        const r = DsMock.resultFor(cmd);
        ds.newData(cmd, { "stdout": r.out, "stderr": r.err, "exit code": r.code });
    }
    function disconnectSource(cmd) {}
}
