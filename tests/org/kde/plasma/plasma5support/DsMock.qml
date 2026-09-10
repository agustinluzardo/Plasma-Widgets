pragma Singleton
import QtQuick
QtObject {
    property var responses: ({})
    property var calls: []
    function reset() { responses = {}; calls = []; }
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
