pragma Singleton
import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support

// Running a command from a plasmoid.
//
// Quickshell has a Process type; Plasma does not. What it has is the executable
// data engine, reached through org.kde.plasma.plasma5support - deprecated in
// Plasma 6, and still the only supported way to run a command from QML, which
// is why every plasmoid that shells out uses it.
//
// The engine is keyed by the command string: connectSource(cmd) starts it and
// onNewData arrives with sourceName === cmd. Two identical commands in flight
// at once would therefore be indistinguishable, so callbacks are queued per
// command and answered in order.
QtObject {
    id: sh

    property var _pending: ({})

    property QtObject _engine: Plasma5Support.DataSource {
        engine: "executable"
        connectedSources: []

        onNewData: (sourceName, data) => {
            sh._engine.disconnectSource(sourceName);

            const queue = sh._pending[sourceName];
            if (!queue || queue.length === 0)
                return;
            const cb = queue.shift();
            if (queue.length === 0)
                delete sh._pending[sourceName];

            if (cb)
                cb(data["stdout"] || "", data["stderr"] || "", data["exit code"] ?? 0);
        }
    }

    // Wraps a value so the shell sees it as one argument, whatever is in it.
    // Single quotes take everything literally; the only thing that cannot
    // appear inside them is a single quote, which is closed, escaped and
    // reopened.
    function quote(s) {
        return "'" + String(s).split("'").join("'\\''") + "'";
    }

    // argv the way Quickshell's Process takes it. The common "sh -c <script>"
    // shape is handed to the engine as the script itself, because that is
    // already exactly what the engine runs.
    function join(argv) {
        if (!argv || argv.length === 0)
            return "";
        if (argv.length === 3 && argv[0] === "sh" && argv[1] === "-c")
            return argv[2];
        const out = [];
        for (let i = 0; i < argv.length; i++)
            out.push(sh.quote(argv[i]));
        return out.join(" ");
    }

    // cb(stdout, stderr, exitCode)
    function exec(argv, cb) {
        const cmd = sh.join(argv);
        if (cmd === "") {
            if (cb)
                cb("", "", 0);
            return;
        }
        if (!sh._pending[cmd])
            sh._pending[cmd] = [];
        sh._pending[cmd].push(cb);
        sh._engine.connectSource(cmd);
    }
}
