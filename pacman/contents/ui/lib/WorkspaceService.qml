pragma Singleton
import QtQuick
import org.kde.taskmanager as TaskManager

// Plasma's virtual desktops, in the shape the Pac-Man plugin already speaks.
//
// The plugin was written compositor-agnostic - _hyprlandWorkspaces() and
// _niriWorkspaces() both return {num, key, name, windows, urgent} - so this is
// a third backend rather than a rewrite.
//
// Two things about VirtualDesktopInfo decide the design here, both verified
// against libtaskmanager/virtualdesktopinfo.h:
//
//   1. `currentDesktop` is a QVariant: a STRING id on Wayland, a uint on X11.
//      Nothing may assume it is a number.
//   2. `position()` and `requestActivate()` are NOT Q_INVOKABLE, so QML cannot
//      call either. Position is therefore computed from desktopIds, and
//      switching goes through KWin's DBus - which works the same on X11 and
//      Wayland.
QtObject {
    id: ws

    property QtObject _info: TaskManager.VirtualDesktopInfo {}

    // TasksModel is a heavyweight model and is used here for ONE cosmetic
    // thing: how many windows sit on each desktop. Held behind a Loader so that
    // if it fails to build - a missing dependency, a context it does not like -
    // the counts go to zero and the strip still draws. Constructed inline, its
    // failure would take the whole singleton down, and with it every widget
    // that imports this file.
    property QtObject _tasksLoader: Loader {
        active: true
        sourceComponent: Component {
            TaskManager.TasksModel {
                groupMode: TaskManager.TasksModel.GroupDisabled
            }
        }
    }

    readonly property var _tasks: ws._tasksLoader ? ws._tasksLoader.item : null

    // Everything the strip draws from, as one value that changes when any of it
    // does. This used to be an int bumped by two Connections objects held in
    // properties of this singleton, targeting the singleton's own children
    // while it was still being constructed - which is fragile, and needless:
    // VirtualDesktopInfo and TasksModel are reactive, so an ordinary binding
    // does the job and nothing has to be wired by hand.
    readonly property string revision: {
        if (!ws._info)
            return "";
        const ids = ws._info.desktopIds ?? [];
        const names = ws._info.desktopNames ?? [];
        return String(ws._info.currentDesktop) + "|" + (ws._info.numberOfDesktops ?? 0)
             + "|" + ids.join(",") + "|" + names.join(",")
             + "|" + (ws._tasks ? ws._tasks.count : 0);
    }

    readonly property var desktopIds: ws._info ? (ws._info.desktopIds ?? []) : []
    readonly property var desktopNames: ws._info ? (ws._info.desktopNames ?? []) : []
    readonly property int count: ws._info ? (ws._info.numberOfDesktops ?? 0) : 0

    // 1-based, and 0 when the current desktop is not in the list - which is
    // what the plugin reads as "state not available right now" rather than
    // snapping the strip back to the first slot.
    readonly property int focusedNum: {
        ws.revision;
        if (!ws._info)
            return 0;
        const cur = ws._info.currentDesktop;
        if (cur === undefined || cur === null)
            return 0;
        const ids = ws.desktopIds;
        for (let i = 0; i < ids.length; i++)
            if (String(ids[i]) === String(cur))
                return i + 1;
        return 0;
    }

    // How many windows sit on each desktop, by position. A window can be on all
    // desktops (an empty list), which counts for none of them rather than all -
    // a pinned window is not what "this desktop is in use" means.
    function windowCounts() {
        const counts = {};
        if (!ws._tasks)
            return counts;
        const model = ws._tasks;
        for (let i = 0; i < model.count; i++) {
            let desks;
            try {
                desks = model.data(model.index(i, 0), TaskManager.AbstractTasksModel.VirtualDesktops);
            } catch (e) {
                continue;
            }
            if (!desks || desks.length === 0)
                continue;
            for (let j = 0; j < desks.length; j++) {
                const at = ws.positionOf(desks[j]);
                if (at > 0)
                    counts[at] = (counts[at] ?? 0) + 1;
            }
        }
        return counts;
    }

    function positionOf(id) {
        const ids = ws.desktopIds;
        for (let i = 0; i < ids.length; i++)
            if (String(ids[i]) === String(id))
                return i + 1;
        return 0;
    }

    // The normalised records the plugin's slot maths consumes.
    function workspaces() {
        ws.revision;
        const counts = ws.windowCounts();
        const out = [];
        const ids = ws.desktopIds;
        const names = ws.desktopNames;
        for (let i = 0; i < ids.length; i++) {
            const num = i + 1;
            out.push({
                "num": num,
                "key": String(ids[i]),
                "name": (names[i] && names[i].length > 0) ? names[i] : String(num),
                "windows": counts[num] ?? 0,
                // KWin tracks demands-attention per window rather than per
                // desktop, and TasksModel does not surface it per desktop, so
                // nothing here claims urgency it cannot know.
                "urgent": false
            });
        }
        return out;
    }

    // requestActivate() is not callable from QML, so this goes to KWin the way
    // anything outside libtaskmanager has to: by setting the property on
    // /VirtualDesktopManager. dbus-send is used rather than qdbus because its
    // binary name has moved between Qt versions (qdbus, qdbus-qt6, qdbus6) and
    // dbus-send has not.
    function switchTo(key) {
        if (!key)
            return;
        Sh.exec(["dbus-send", "--session", "--dest=org.kde.KWin", "--type=method_call",
                 "/VirtualDesktopManager", "org.freedesktop.DBus.Properties.Set",
                 "string:org.kde.KWin.VirtualDesktopManager", "string:current",
                 "variant:string:" + key], null);
    }

    function switchToNum(num) {
        const ids = ws.desktopIds;
        if (num >= 1 && num <= ids.length)
            ws.switchTo(String(ids[num - 1]));
    }
}
