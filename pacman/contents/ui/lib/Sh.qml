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
// are therefore ONE source and produce ONE reply - not two - so that reply is
// the answer for everyone who asked, and the whole queue is drained with it.
//
// This used to shift() a single callback per reply, on the assumption that a
// second identical command would bring a second reply. It does not: the second
// caller was never answered and its entry stayed in the map for the life of the
// session. Two fast clicks on the same workspace were enough.
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

            // La cola se VACIA EN SITIO con splice, y la clave no se borra
            // nunca. Dos motivos:
            //
            // 1. Un callback puede volver a lanzar el mismo comando. Sacar los
            //    pendientes de una antes de llamar a nadie deja el sitio limpio
            //    para esa segunda tanda sin perderla.
            // 2. Insertar y borrar claves a repeticion sobre un objeto JS
            //    guardado en una propiedad `var` revienta el motor: Qt 6.4 se
            //    va a SIGSEGV en QV4::Object::insertMember despues de unos
            //    cientos de ciclos. Las claves se insertan una vez por comando
            //    distinto y se quedan; el conjunto de comandos distintos es
            //    finito, asi que el mapa no crece.
            const pend = queue.splice(0, queue.length);

            const out = data["stdout"] || "";
            const err = data["stderr"] || "";
            const code = data["exit code"] ?? 0;
            for (let i = 0; i < pend.length; i++) {
                const cb = pend[i];
                if (cb)
                    cb(out, err, code);
            }
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
