import QtQuick

// Quickshell's Process, over Plasma's executable engine.
//
// The ported plugins drive processes declaratively - set `running` true, read
// the output in StdioCollector.onStreamFinished - so this keeps that shape
// rather than making every call site change to a callback.
QtObject {
    id: proc

    property var command: []
    property bool running: false
    property QtObject stdout: null
    property QtObject stderr: null

    signal started()
    signal exited(int exitCode, int exitStatus)

    onRunningChanged: {
        if (!running)
            return;
        proc.started();
        Sh.exec(proc.command, (out, err, code) => {
            if (proc.stdout) {
                proc.stdout.text = out;
                proc.stdout.streamFinished();
            }
            if (proc.stderr)
                proc.stderr.text = err;
            proc.running = false;
            proc.exited(code, 0);
        });
    }
}
