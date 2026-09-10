// NOTE: no `pragma ComponentBehavior: Bound` here. DMS instantiates
// the strip through a Loader, and a component built outside its own creation
// context comes out empty. Plasma's representation loader is exactly such a
// context, which is how the ported version ended up invisible with no error.
// The strip is now a direct child of this file's root, so nothing crosses.

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid
import "lib" as Lib

// Pac-Man style workspace indicator.
//
// Everything is drawn with QtQuick.Shapes (scene-graph vector geometry) rather
// than Canvas. Canvas keeps a raster backing store that is not re-rendered when
// the surface is torn down and rebuilt (DPMS off, suspend/resume, output hotplug)
// or when the item is resized while unexposed, which is what made Pac-Man come
// back stretched and pixelated after sleep, and what made ghosts stop appearing
// once a queued requestPaint() was dropped. Shapes have no backing store: the
// scene graph regenerates them from the live bindings on every frame it needs.
Item {
    id: root

    // ---- what PluginComponent used to provide ----------------------------
    // Read here, not passed in: a representation that reaches into another
    // file's scope is the thing this rewrite exists to remove.
    readonly property var pluginData: ({
        "workspaceCount": Plasmoid.configuration.workspaceCount,
        "maxSlots": Plasmoid.configuration.maxSlots,
        "autoIconSize": Plasmoid.configuration.autoIconSize,
        "iconSizeOverride": Plasmoid.configuration.iconSizeOverride,
        "autoSpacing": Plasmoid.configuration.autoSpacing,
        "spacingOverride": Plasmoid.configuration.spacingOverride,
        "pelletSize": Plasmoid.configuration.pelletSize,
        "perMonitor": Plasmoid.configuration.perMonitor,
        "palette": Plasmoid.configuration.palette,
        "ghostMode": Plasmoid.configuration.ghostMode,
        "ghostColorMode": Plasmoid.configuration.ghostColorMode,
        "ghostMotion": Plasmoid.configuration.ghostMotion,
        "frightenedGhosts": Plasmoid.configuration.frightenedGhosts,
        "animations": Plasmoid.configuration.animations,
        "animationStyle": Plasmoid.configuration.animationStyle,
        "scrollToSwitch": Plasmoid.configuration.scrollToSwitch,
        "scrollReversed": Plasmoid.configuration.scrollReversed,
        "slotBackground": Plasmoid.configuration.slotBackground,
        "slotBackgroundColorMode": Plasmoid.configuration.slotBackgroundColorMode,
        "slotBackgroundColor": Plasmoid.configuration.slotBackgroundColor,
        "mouthPellet": Plasmoid.configuration.mouthPellet
    })
    // The panel's thickness, not a number carried over from the DMS bar.
    property real barThickness: root.height > 0 ? root.height : 40
    property real widgetThickness: 30
    property var barConfig: null
    property string section: "center"
    property var parentScreen: null
    property string pluginId: "pacmanworkspaces"
    property var pluginService: null
    readonly property int iconSize: Math.round((barThickness / 48) * (24 - 4))

    // ------------------------------------------------------------- settings --
    readonly property int minSlots: Math.max(1, Math.min(20, root.pluginData?.workspaceCount ?? 5))
    readonly property int maxSlots: Math.max(root.minSlots, Math.min(30, root.pluginData?.maxSlots ?? 10))
    // "behind"   - ghosts chase you: every slot with a lower number than the focused one
    // "occupied" - ghosts sit on every workspace that has windows open
    // "all"      - ghosts on every slot that is not the focused one
    readonly property string ghostMode: root.pluginData?.ghostMode ?? "behind"
    // "workspace" - each workspace always gets the same ghost (stable colours)
    // "distance"  - ghost colour follows how far behind you the slot is
    readonly property string ghostColorMode: root.pluginData?.ghostColorMode ?? "workspace"
    readonly property bool perMonitor: root.pluginData?.perMonitor ?? true
    readonly property bool animationsEnabled: root.pluginData?.animations ?? true
    readonly property bool scrollEnabled: root.pluginData?.scrollToSwitch ?? true
    readonly property bool scrollReversed: root.pluginData?.scrollReversed ?? false
    // Sizing is either derived from the bar or pinned to an exact value. A slider
    // parked at 0 meaning "derive it" read as switched off, so the choice is an
    // explicit flag and the slider always shows a real pixel size.
    readonly property bool autoIconSize: root.pluginData?.autoIconSize ?? true
    readonly property int iconSizeOverride: Math.max(10, Math.min(48, root.pluginData?.iconSizeOverride ?? 21))
    readonly property bool autoSpacing: root.pluginData?.autoSpacing ?? true
    readonly property int spacingOverride: Math.max(0, Math.min(24, root.pluginData?.spacingOverride ?? 6))
    // "arcade" - the sprite's skirt shuffles between two frames, as on the cabinet
    // "float"  - the ghosts drift up and down instead
    // "both"   - drifting, with the skirt still shuffling
    readonly property string ghostMotion: root.pluginData?.ghostMotion ?? "arcade"
    readonly property bool ghostSkirtMoves: root.ghostMotion === "arcade" || root.ghostMotion === "both"
    readonly property bool ghostFloats: root.ghostMotion === "float" || root.ghostMotion === "both"
    // Diameter of an empty slot's pellet, as a percentage of the icon size. An
    // untouched-but-reachable workspace reads as a power pellet rather than a
    // speck; occupied and urgent slots scale up from it and stay distinguishable.
    readonly property int pelletSizePercent: Math.max(10, Math.min(60, root.pluginData?.pelletSize ?? 30))
    readonly property real pelletFraction: root.pelletSizePercent / 100
    readonly property real occupiedPelletFraction: Math.min(0.52, root.pelletFraction * 1.5)
    readonly property real urgentPelletFraction: Math.min(0.70, root.pelletFraction * 2)

    // anchors.centerIn puts the pellet at (cellSize - diameter) / 2, so unless
    // the diameter has the same parity as the cell that lands on a half pixel:
    // a 6px dot in a 21px cell centres at y=7.5 and renders visibly higher than
    // its 9px neighbour, which centres at exactly 6. Match the parity.
    function pelletDiameter(fraction, minimum) {
        let d = Math.max(minimum, Math.round(root.cellSize * fraction))
        if (((root.cellSize - d) % 2) !== 0)
            d += 1
        return d
    }

    // DMS' global "no animations" setting collapses every duration to 0; honour it.
    readonly property bool animationsOn: root.animationsEnabled && Lib.Theme.shortDuration > 0

    // ------------------------------------------------------------- geometry --
    // Qt already knows the scale of the screen this item is on; DMS needed its
    // own lookup because a Quickshell bar is not a normal window.
    readonly property real dpr: Screen.devicePixelRatio > 0 ? Screen.devicePixelRatio : 1

    // Follows the bar's calibrated icon size (and its thickness / icon-scale
    // settings) instead of a hardcoded pixel count, and is snapped to whole
    // device pixels so nothing lands on a half pixel under fractional scaling.
    // 21px at the reference 48px bar - the size the Canvas version used, which is
    // what this is calibrated to. Lib.Theme.barIconSize(48, -4) would give 20 instead
    // (Lib.Theme.iconSize is 24), so the bar's icon metric is scaled rather than used
    // directly. Still tracks bar thickness and the bar's icon-scale setting, and
    // is snapped to whole device pixels so nothing lands on a half pixel under
    // fractional scaling.
    readonly property real referenceCellSize: 21
    readonly property int cellSize: {
        if (!root.autoIconSize)
            return Math.max(10, Math.round(Lib.Theme.snap(root.iconSizeOverride, root.dpr)))
        const scale = root.barConfig?.iconScale ?? 1
        const base = (root.barThickness / 48) * root.referenceCellSize * scale
        return Math.max(10, Math.round(Lib.Theme.snap(base, root.dpr)))
    }
    readonly property real cellSpacing: {
        const base = root.autoSpacing ? Math.max(3, Math.round(root.cellSize * 0.3)) : root.spacingOverride
        return Lib.Theme.snap(base, root.dpr)
    }

    // --------------------------------------------------------------- colours --
    // "arcade"  - the 1980 cabinet's own palette
    // "theme"   - Material You colours from DMS, for bars where pure arcade
    //             primaries are too loud
    readonly property string palette: root.pluginData?.palette ?? "arcade"
    readonly property bool arcadePalette: root.palette !== "theme"

    // ------------------------------------------------------- slot background --
    // Un laberinto entero no entra a la altura de un panel - a 36px sus paredes
    // se vuelven ruido y entierran los pellets, que son la informacion. Un
    // corredor solo si se lee, porque es la forma que el ojo ya asocia al juego.
    //
    // Apagado por defecto: el borde se come unos 6px de alto y los sprites
    // encogen para dejarle sitio. Es un cambio de verdad, no un adorno gratis.
    readonly property string slotBackground: root.pluginData?.slotBackground ?? "none"
    readonly property bool hasCorridor: root.slotBackground === "corridor" || root.slotBackground === "corridorTint"
    // Las dos paredes y nada mas. Dejar los extremos abiertos hace que la tira
    // se lea como un tramo de corredor que sigue mas alla del widget en vez de
    // como una caja, y cuesta menos alto que el corredor completo porque no hay
    // esquinas redondeadas que dejar libres.
    readonly property bool hasRails: root.slotBackground === "rails"
    readonly property bool hasSlotBackground: root.hasCorridor || root.hasRails
    // Automatico deja lo que la paleta ya decidio - azul de cabina en arcade, el
    // acento de tu tema en adaptativo - asi que el default es el mismo color de
    // siempre. Custom pisa solo esto, sin tocar los fantasmas ni a Pac-Man.
    readonly property string slotBackgroundColorMode: root.pluginData?.slotBackgroundColorMode ?? "auto"
    readonly property color slotBackgroundCustomColor: root.pluginData?.slotBackgroundColor ?? "#2121DE"
    readonly property color corridorColor: root.slotBackgroundColorMode === "custom"
        ? root.slotBackgroundCustomColor
        : (root.arcadePalette ? "#2121DE" : Lib.Theme.primary)
    readonly property real railThickness: Math.max(1, Math.round(root.cellSize / 11))

    // Con las animaciones apagadas la boca se congela abierta, y eso se lee como
    // esperar, no como comer. Un pellet en la abertura es lo que muestra el
    // frame del arcade en ese momento - el mordisco a punto de pasar. Encendido
    // por defecto porque una boca abierta y vacia es la peor de las dos, pero es
    // un look, asi que es una eleccion.
    readonly property bool mouthPellet: root.pluginData?.mouthPellet ?? true

    readonly property color pacmanColor: root.arcadePalette ? "#FFFF00" : Lib.Theme.primary

    // Blinky, Pinky, Inky, Clyde - the cabinet's exact values, in the order they
    // leave the ghost house.
    readonly property var arcadeGhosts: ["#FF0000", "#FFB8FF", "#00FFFF", "#FFB852"]
    readonly property var themeGhosts: [Lib.Theme.error, Lib.Theme.tertiary, Lib.Theme.info, Lib.Theme.warning]
    readonly property var ghostPalette: root.arcadePalette ? root.arcadeGhosts : root.themeGhosts

    // The arcade maze draws dots and energizers in the same peach; on a light bar
    // that has almost no contrast, so it is darkened there.
    // On the cabinet's CRT the maze food reads as white, not as the peach the
    // sprite sheet stores - which on a dark bar just looked brown. Size, not
    // colour, is what separates an occupied workspace from an untouched one.
    readonly property color pelletColor: {
        if (!root.arcadePalette)
            return Lib.Theme.surfaceText
        return Lib.Theme.isLightMode ? "#33270F" : "#FFFFFF"
    }
    readonly property color dimPelletColor: root.arcadePalette ? Lib.Theme.withAlpha(root.pelletColor, 0.65) : Lib.Theme.surfaceVariantText

    // Classic frightened mode: walking back the way you came is Pac-Man eating an
    // energizer, so the ghosts turn blue, then flash white just before it wears
    // off, exactly as the cabinet does.
    readonly property bool frightenedEnabled: root.pluginData?.frightenedGhosts ?? false
    readonly property int frightenedMs: 5000
    property bool frightened: false
    property bool frightenedFlash: false
    readonly property bool frightenedWhite: root.frightened && root.frightenedFlash && root.animationsOn && (root.spriteFrame % 2 === 0)
    readonly property color frightenedBodyColor: root.frightenedWhite ? "#FFFFFF" : (root.arcadePalette ? "#2121DE" : Lib.Theme.info)
    readonly property color frightenedPupilColor: root.frightenedWhite ? "#FF0000" : "#FFFFFF"

    Timer {
        id: frightenedFlashTimer
        interval: Math.max(1000, root.frightenedMs - 2000)
        onTriggered: root.frightenedFlash = true
    }

    Timer {
        id: frightenedTimer
        interval: root.frightenedMs
        onTriggered: {
            root.frightened = false
            root.frightenedFlash = false
        }
    }

    // What a slot renders as. Lives here rather than in the delegate so the root
    // can also tell whether any ghost is on screen at all.
    function kindFor(info) {
        if (info.focused)
            return "pacman"
        if (info.urgent)
            return "pellet"
        switch (root.ghostMode) {
        case "all":
            return "ghost"
        case "occupied":
            return info.occupied ? "ghost" : "dot"
        default:
            return info.behind ? "ghost" : "dot"
        }
    }

    readonly property int visibleGhostCount: {
        const s = root.wsSlots ?? []
        let n = 0
        for (let i = 0; i < s.length; i++)
            if (root.kindFor(s[i]) === "ghost")
                n++
        return n
    }

    // With no ghost on screen there is nothing to frighten, and letting the
    // effect burn down invisibly means the next ghost you walk back towards
    // shows up already blue and part-spent. End it instead.
    onVisibleGhostCountChanged: {
        if (root.visibleGhostCount === 0)
            Qt.callLater(root.clearFrightenedIfStillEmpty)
    }

    // Deferred on purpose. Switching workspace rebuilds the whole slot list, and
    // the ghost count can pass through zero part-way through that rebuild.
    // Acting on that transient tore the effect down a frame after arming it.
    function clearFrightenedIfStillEmpty() {
        if (root.visibleGhostCount === 0)
            root.clearFrightened()
    }

    function clearFrightened() {
        root.frightened = false
        root.frightenedFlash = false
        frightenedTimer.stop()
        frightenedFlashTimer.stop()
    }

    function startFrightened() {
        if (!root.frightenedEnabled)
            return
        root.frightened = true
        root.frightenedFlash = false
        frightenedFlashTimer.restart()
        frightenedTimer.restart()
    }

    onFrightenedEnabledChanged: {
        if (!root.frightenedEnabled)
            root.clearFrightened()
    }

    readonly property color ghostEyeColor: "#FFFFFF"
    readonly property color ghostPupilColor: root.arcadePalette ? "#2121DE" : Lib.Theme.primary

    function ghostColorFor(info) {
        const n = root.ghostPalette.length
        if (root.ghostColorMode === "distance") {
            const d = Math.max(1, info.distance)
            return root.ghostPalette[(d - 1) % n]
        }
        return root.ghostPalette[((info.num - 1) % n + n) % n]
    }

    // ---------------------------------------------------------- sprite clock --
    // The arcade animates on a frame counter, not on smooth tweens: Pac-Man
    // steps through three mouth frames, the ghosts' skirt alternates, and the
    // energizers blink hard on and off. One shared timer drives all of it, so
    // every sprite in the bar stays in step the way it does in the game - and it
    // costs four property writes a second instead of a full per-frame animation.
    // "arcade" - stepped on a frame counter, like the cabinet
    // "smooth"  - tweened continuously at the display's refresh rate
    readonly property string animationStyle: root.pluginData?.animationStyle ?? "arcade"
    readonly property bool smoothAnimation: root.animationStyle === "smooth"

    // Continuous 0..1 ramp that drives everything in smooth mode, so the two
    // styles share one set of sprites and only differ in how they are driven.
    property real smoothPhase: 0

    SequentialAnimation {
        running: root.animationsOn && root.smoothAnimation && root.visible && true /* Plasma exposes no sleep flag to QML */
        loops: Animation.Infinite

        NumberAnimation {
            target: root
            property: "smoothPhase"
            to: 1
            duration: 260
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            target: root
            property: "smoothPhase"
            to: 0
            duration: 260
            easing.type: Easing.InOutSine
        }

        onRunningChanged: {
            if (!running)
                root.smoothPhase = 0
        }
    }

    property int spriteFrame: 0
    // Mouth aperture per frame: wide, half, closed, half.
    readonly property var mouthFrames: [38, 20, 0, 20]
    readonly property real mouthRestDeg: 30

    Timer {
        interval: 130
        repeat: true
        running: root.animationsOn && !root.smoothAnimation && root.visible && true /* Plasma exposes no sleep flag to QML */
        onTriggered: root.spriteFrame = (root.spriteFrame + 1) % 4
        onRunningChanged: {
            if (!running)
                root.spriteFrame = 0
        }
    }

    // ------------------------------------------------------------ compositor --
    // Plasma has one set of virtual desktops for the whole session - they are
    // not per monitor the way Hyprland workspaces are - so the two branches
    // that existed to keep a strip pinned to its own monitor have nothing to
    // choose between here. niriMode stays false and the Plasma backend is the
    // one that answers.
    readonly property bool niriMode: false
    readonly property string screenName: ""
    // When true the widget mirrors whichever monitor currently has focus instead
    // of pinning itself to the monitor its bar lives on.
    // Always true: there is only one set of desktops to follow.
    readonly property bool followFocus: true

    // Single revision counter every derived binding depends on. Compositor state
    // is also read live, so ordinary QML reactivity does the work; the counter is
    // what lets an explicit signal (or the watchdog below) force a recompute when
    // an event is missed instead of leaving the widget frozen until it is
    // reloaded by hand.
    property int revision: 0

    function bumpRevision() {
        root.revision = root.revision + 1
    }

    // 0 means "the compositor state is not readable right now". Snapping to 1 in
    // that case made a momentary blip - a refreshWorkspaces() from the watchdog,
    // for instance - look like a walk back to the first workspace, which turned
    // the ghosts blue every few seconds and kept re-arming the effect before it
    // could expire.
    readonly property int resolvedFocusId: {
        root.revision
        // WorkspaceService returns 0 when the current desktop is not in the
        // list yet, which is the same "state not readable right now" that the
        // original guarded against - snapping to 1 there made a momentary blip
        // look like a walk back to the first workspace.
        return Lib.WorkspaceService.focusedNum
    }

    property int lastKnownFocusId: 1

    onResolvedFocusIdChanged: {
        if (root.resolvedFocusId > 0)
            root.lastKnownFocusId = root.resolvedFocusId
    }

    readonly property int focusedWorkspaceId: root.resolvedFocusId > 0 ? root.resolvedFocusId : root.lastKnownFocusId

    // Normalised workspace records, so the slot maths below is compositor
    // agnostic: `num` is the number shown in the bar, `key` is what the
    // compositor needs to focus it. On Plasma the key is the desktop's id - a
    // string on Wayland, a number on X11 - so it is never treated as a number.
    function _plasmaWorkspaces() {
        root.revision
        return Lib.WorkspaceService.workspaces()
    }

    // Kept as the name the rest of the file calls, so the slot maths below did
    // not have to change at all.
    function _liveWorkspaces() {
        return root._plasmaWorkspaces()
    }

    // The full strip, recomputed from live compositor state. `minSlots` is a
    // floor, not a fixed size: the strip grows as higher workspaces are used and
    // shrinks again when they are destroyed, bounded by `maxSlots` so a stray
    // high workspace id can never blow the bar up into dozens of icons.
    readonly property var wsSlots: {
        root.revision
        root.minSlots
        root.maxSlots
        root.followFocus
        root.screenName
        root.niriMode

        const live = root._liveWorkspaces()
        const focused = root.focusedWorkspaceId

        const byNum = {}
        let lo = 0
        let hi = 0
        for (let i = 0; i < live.length; i++) {
            const w = live[i]
            byNum[w.num] = w
            if (lo === 0 || w.num < lo)
                lo = w.num
            if (w.num > hi)
                hi = w.num
        }
        if (lo === 0) {
            lo = 1
            hi = 1
        }
        if (focused >= 1) {
            if (focused > hi)
                hi = focused
            if (focused < lo)
                lo = focused
        }

        const minS = root.minSlots
        const maxS = Math.max(minS, root.maxSlots)

        // Anchor the strip at 1 for ordinary setups. Only follow a high block
        // (Hyprland per-monitor ranges such as 11..20) when the workspaces in
        // play genuinely start above the strip we would otherwise draw.
        let start = (lo <= minS || hi <= maxS) ? 1 : lo
        let end = Math.max(start + minS - 1, hi)

        if (end - start + 1 > maxS) {
            if (focused >= 1 && focused - start > maxS - 1)
                start = Math.max(1, focused - maxS + 1)
            end = start + maxS - 1
            if (focused > end) {
                end = focused
                start = Math.max(1, end - maxS + 1)
            }
        }

        const out = []
        for (let n = start; n <= end; n++) {
            const w = byNum[n]
            const isFocused = (n === focused)
            out.push({
                "num": n,
                // A slot with no live workspace can still be focused on Hyprland
                // (the dispatcher creates it); on niri there is nothing to focus.
                "key": w ? w.key : (root.niriMode ? null : n),
                "name": w ? w.name : String(n),
                "exists": !!w,
                "windows": w ? w.windows : 0,
                "occupied": !!w && w.windows > 0,
                "urgent": !!w && w.urgent && !isFocused,
                "focused": isFocused,
                "behind": n < focused,
                "distance": focused - n
            })
        }
        return out
    }

    readonly property int slotCount: root.wsSlots.length

    readonly property var fallbackSlot: ({
            "num": 1,
            "key": 1,
            "name": "1",
            "exists": false,
            "windows": 0,
            "occupied": false,
            "urgent": false,
            "focused": false,
            "behind": false,
            "distance": 0
        })

    function slotAt(i) {
        const s = root.wsSlots ?? []
        return (i >= 0 && i < s.length) ? s[i] : root.fallbackSlot
    }

    // Pac-Man turns to face the direction you just travelled in - except on the
    // first slot, where there is nothing further left to eat, so he turns back
    // around against the wall.
    property int previousFocusedId: -1
    property bool facingLeft: false

    onFocusedWorkspaceIdChanged: {
        const slots = root.wsSlots ?? []
        const firstNum = slots.length > 0 ? slots[0].num : 1
        const movedBack = root.previousFocusedId > 0 && root.focusedWorkspaceId < root.previousFocusedId
        if (root.focusedWorkspaceId <= firstNum)
            root.facingLeft = false
        else if (root.previousFocusedId > 0 && root.focusedWorkspaceId !== root.previousFocusedId)
            root.facingLeft = root.focusedWorkspaceId < root.previousFocusedId
        if (movedBack)
            root.startFrightened()
        root.previousFocusedId = root.focusedWorkspaceId
    }

    // ---------------------------------------------------------- interaction --
    function switchTo(slot) {
        if (!slot)
            return
        // VirtualDesktopInfo::requestActivate is not Q_INVOKABLE, so QML
        // cannot call it. Switching goes to KWin over DBus instead - see
        // Compat/Lib.WorkspaceService.qml.
        if (slot.key !== null && slot.key !== undefined)
            Lib.WorkspaceService.switchTo(slot.key)
        else
            Lib.WorkspaceService.switchToNum(slot.num)
    }

    // Where the last step sent us, until the compositor confirms it. Two
    // notches in quick succession both used to be measured from the same
    // not-yet-updated focus, and the rate limiter that hid that problem dropped
    // the second notch outright - after the wheel accumulator had already
    // debited it - so a quick spin moved one workspace and the rest vanished.
    // Stepping from where we are heading instead means every notch counts.
    property int pendingFocusNum: 0

    Timer {
        id: pendingFocusTimer
        // Only a safety net: if the compositor never confirms the move, stop
        // stepping from a workspace we never actually reached.
        interval: 600
        onTriggered: root.pendingFocusNum = 0
    }

    function stepWorkspace(delta) {
        const s = root.wsSlots
        if (s.length === 0)
            return

        let idx = -1
        if (root.pendingFocusNum > 0) {
            for (let i = 0; i < s.length; i++) {
                if (s[i].num === root.pendingFocusNum) {
                    idx = i
                    break
                }
            }
        }
        if (idx < 0) {
            for (let i = 0; i < s.length; i++) {
                if (s[i].focused) {
                    idx = i
                    break
                }
            }
        }
        if (idx < 0)
            idx = 0

        const next = idx + delta
        if (next < 0 || next >= s.length)
            return

        root.pendingFocusNum = s[next].num
        pendingFocusTimer.restart()
        root.switchTo(s[next])
    }

    // ------------------------------------------------------------ freshness --
    // DMS subscribed to Hyprland's raw event stream and filtered it down to
    // the couple of dozen event names that can change what this draws. Plasma
    // has no such stream: VirtualDesktopInfo and TasksModel are models that
    // notify on their own, and WorkspaceService already folds them into one
    // counter, so the filter has nothing left to filter.

    // On DMS this asked Hyprland for a fresh snapshot, because the compositor
    // socket could miss events. VirtualDesktopInfo and TasksModel are live
    // models rather than a socket, so there is nothing to ask for - a resync
    // here is just a recompute. Kept because the watchdog below and the
    // visibility handler both call it.
    function resync() {
        root.bumpRevision()
    }

    // DMS also has a session-resumed signal, which Plasma does not offer to
    // QML. It mattered there for the same socket reason; here the models
    // reconnect themselves, so nothing is bolted on to fake it.

    Component.onCompleted: {
        Qt.callLater(root.resync)
        // The same line on disk, so it can be read without squinting at a panel
        // where the thing is invisible in the first place.
        Qt.callLater(function () {
            Lib.Sh.exec(["sh", "-c",
                "printf '%s\\n' " + Lib.Sh.quote("pacman: " + root.diagnostic)
                + " > \"${XDG_RUNTIME_DIR:-/tmp}/pacman-workspaces.diag\""], null)
        })
    }

    onVisibleChanged: {
        if (root.visible)
            Qt.callLater(root.resync)
    }

    // Cheap self-healing watchdog. It hashes the live compositor state and only
    // bumps the revision when that hash disagrees with what we last drew, so it
    // costs nothing while events are flowing and still repairs the widget within
    // a few seconds if one is ever dropped - no more reloading the plugin by hand.
    property string lastStateSignature: ""

    // The watchdog stays, because a cheap self-healing check costs nothing and
    // a frozen strip is the worst failure this widget has. What it hashes is
    // now the model state rather than a compositor socket's view of it.
    function stateSignature() {
        const wss = Lib.WorkspaceService.workspaces()
        let s = "p:" + Lib.WorkspaceService.focusedNum + "/" + wss.length
        for (let i = 0; i < wss.length; i++) {
            const w = wss[i]
            s += "|" + w.num + "," + w.key + "," + w.windows
        }
        return s
    }

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.visible && true /* Plasma exposes no sleep flag to QML */
        onTriggered: {
            const sig = root.stateSignature()
            if (sig === root.lastStateSignature)
                return
            root.lastStateSignature = sig
            root.bumpRevision()
        }
    }

    // ------------------------------------------------------------- delegate --
    Component {
        id: cellDelegate

        Item {
            id: cell

            required property int index

            readonly property var info: root.slotAt(cell.index)
            readonly property bool isFocused: cell.info.focused
            readonly property bool isUrgent: cell.info.urgent
            readonly property bool isOccupied: cell.info.occupied
            readonly property bool hovered: cellMouse.containsMouse
            // Both bar pills are instantiated at once; only the one matching the
            // bar orientation is visible. Item.visible is inherited, so this also
            // keeps the hidden strip from animating in the background.
            readonly property bool animate: root.animationsOn && cell.visible

            readonly property string kind: root.kindFor(cell.info)

            // Each sprite carries its own colour. A single shared tint with a
            // ColorAnimation on it cross-faded through the ghost's colour when a
            // slot turned into Pac-Man, so clicking a ghost painted a blue or red
            // Pac-Man for a moment before it settled on yellow.
            function shade(c) {
                return cell.hovered ? Lib.Theme.hoverTint(c) : c
            }
            readonly property color pacmanTint: cell.shade(root.pacmanColor)
            readonly property color ghostTint: cell.shade(root.frightened ? root.frightenedBodyColor : root.ghostColorFor(cell.info))
            readonly property color pelletTint: cell.shade(cell.kind === "dot" && !cell.isOccupied ? root.dimPelletColor : root.pelletColor)

            width: root.cellSize
            height: root.cellSize

            readonly property real cx: cell.width / 2
            readonly property real cy: cell.height / 2

            // -- Pac-Man ---------------------------------------------------
            readonly property real mouthAngle: {
                if (!cell.animate)
                    return root.mouthRestDeg
                if (root.smoothAnimation)
                    return 2 + (root.mouthFrames[0] - 2) * root.smoothPhase
                return root.mouthFrames[root.spriteFrame]
            }
            // The bounce scales the radius that feeds the path, not the item, so
            // the wedge is re-tessellated at the new size instead of a finished
            // image being stretched.
            property real bounce: 1.0
            readonly property real pacRestRadius: root.cellSize / 2 - Math.max(1, root.cellSize * 0.08)
            // Clamped so a bounce can never reach the cell edge and get shaved off
            // at small icon sizes (at 21px the unclamped peak left 0.1px of room).
            readonly property real pacRadius: Math.min(root.cellSize / 2 - 0.5, cell.pacRestRadius * cell.bounce)

            SequentialAnimation {
                id: bounceAnim

                NumberAnimation {
                    target: cell
                    property: "bounce"
                    to: 1.18
                    duration: 90
                    easing.type: Easing.OutQuad
                }
                NumberAnimation {
                    target: cell
                    property: "bounce"
                    to: 1.0
                    duration: 170
                    easing.type: Easing.OutBack
                }
            }

            onIsFocusedChanged: {
                if (cell.isFocused && cell.animate)
                    bounceAnim.restart()
                else if (!cell.isFocused)
                    cell.bounce = 1.0
            }

            // Changing the slot count regenerates every delegate (Repeater rebuilds
            // on an integer model change), so the already-focused cell never sees an
            // isFocused transition. Bounce once on creation instead of staying flat.
            Component.onCompleted: {
                if (cell.isFocused)
                    Qt.callLater(() => {
                            if (cell.isFocused && cell.animate)
                                bounceAnim.restart()
                        })
            }

            // -- Ghost geometry --------------------------------------------
            readonly property real gMargin: Math.max(1, root.cellSize * 0.07)
            readonly property real gR: root.cellSize / 2 - cell.gMargin
            readonly property real gDomeY: cell.gMargin + cell.gR
            readonly property real gFoot: cell.gR * 0.32
            readonly property real gBaseY: root.cellSize - cell.gMargin - cell.gFoot
            readonly property real gBump: cell.gR / 2
            readonly property real eyeR: cell.gR * 0.35
            readonly property real eyeY: cell.gDomeY - cell.gR * 0.1
            readonly property real eyeDX: cell.gR * 0.4
            // Ghosts watch Pac-Man.
            readonly property bool ghostLooksLeft: cell.info.num > root.focusedWorkspaceId

            // The arcade ghosts do not bob; their skirt shuffles between two
            // frames. Alternating which set of feet hangs lower reproduces that.
            readonly property bool skirtMoves: cell.animate && root.ghostSkirtMoves
            readonly property int skirtPhase: cell.skirtMoves ? (root.spriteFrame < 2 ? 0 : 1) : 0

            // Drifting ghosts, for anyone who prefers them to the arcade shuffle.
            // Neighbouring slots move in opposite phase so the row is not in lockstep.
            readonly property real ghostBob: {
                if (!cell.animate || !root.ghostFloats)
                    return 0
                const t = root.smoothAnimation ? root.smoothPhase : (root.spriteFrame < 2 ? 0 : 1)
                const swing = (cell.index % 2 === 0) ? t : 1 - t
                return -Math.max(1, root.cellSize * 0.08) * swing
            }

            function footDepth(index) {
                if (cell.skirtMoves && root.smoothAnimation) {
                    const t = (index % 2) === 0 ? root.smoothPhase : 1 - root.smoothPhase
                    return cell.gFoot * (0.4 + 0.6 * t)
                }
                if (!cell.skirtMoves)
                    return cell.gFoot * 0.7
                return cell.gFoot * ((index % 2) === cell.skirtPhase ? 1 : 0.4)
            }

            // -- Visuals ---------------------------------------------------
            Rectangle {
                anchors.centerIn: parent
                width: root.cellSize + Math.round(root.cellSpacing * 0.6)
                height: width
                radius: width / 2
                color: Lib.Theme.surfaceTextHover
                antialiasing: true
                opacity: cell.hovered ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    enabled: root.animationsOn
                    NumberAnimation {
                        duration: Lib.Theme.shortDuration
                    }
                }
            }

            Shape {
                id: pacShape
                anchors.fill: parent
                visible: cell.kind === "pacman"
                // Qt 6.6+ only; a declared assignment stops this file loading on
                // older Qt. Set through the id rather than `this`, which is not
                // guaranteed to be the Shape here.
                Component.onCompleted: if ("preferredRendererType" in pacShape) pacShape.preferredRendererType = Shape.CurveRenderer
                transformOrigin: Item.Center
                rotation: root.facingLeft ? 180 : 0

                Behavior on rotation {
                    enabled: root.animationsOn
                    RotationAnimation {
                        duration: Lib.Theme.shortDuration
                        direction: RotationAnimation.Shortest
                    }
                }

                ShapePath {
                    fillColor: cell.pacmanTint
                    strokeColor: "transparent"
                    startX: cell.cx
                    startY: cell.cy

                    PathAngleArc {
                        centerX: cell.cx
                        centerY: cell.cy
                        radiusX: cell.pacRadius
                        radiusY: cell.pacRadius
                        startAngle: cell.mouthAngle
                        sweepAngle: 360 - 2 * cell.mouthAngle
                        moveToStart: false
                    }
                    PathLine {
                        x: cell.cx
                        y: cell.cy
                    }
                }
            }

            Item {
                anchors.fill: parent
                visible: cell.kind === "ghost"

                transform: Translate {
                    y: cell.ghostBob

                    Behavior on y {
                        enabled: root.animationsOn && !root.smoothAnimation
                        NumberAnimation {
                            duration: 240
                            easing.type: Easing.InOutSine
                        }
                    }
                }

                Shape {
                    id: ghostShape
                    anchors.fill: parent
                    // The SAME renderer as every other shape here, and as the
                    // DMS original. This briefly ran on GeometryRenderer to work
                    // around a fill-colour update, on the reasoning that "the
                    // only curve in a ghost is the dome across its head" - which
                    // is simply wrong: the four scalloped feet are PathQuads and
                    // the dome is a 180-degree arc, so the geometry renderer
                    // flattens all five into facets and the sprite comes out
                    // jagged. That is the ghost that looked wrong.
                    // Qt 6.6+ only; a declared assignment stops this file loading on
                    // older Qt. Set through the id rather than `this`, which is not
                    // guaranteed to be the Shape here.
                    Component.onCompleted: if ("preferredRendererType" in ghostShape) ghostShape.preferredRendererType = Shape.CurveRenderer

                    ShapePath {
                        fillColor: cell.ghostTint
                        strokeColor: "transparent"
                        startX: cell.cx - cell.gR
                        startY: cell.gDomeY

                        // Rounded dome across the top.
                        PathAngleArc {
                            centerX: cell.cx
                            centerY: cell.gDomeY
                            radiusX: cell.gR
                            radiusY: cell.gR
                            startAngle: 180
                            sweepAngle: 180
                            moveToStart: false
                        }
                        // Straight right flank down to the skirt.
                        PathLine {
                            x: cell.cx + cell.gR
                            y: cell.gBaseY
                        }
                        // Four scalloped feet, right to left.
                        PathQuad {
                            x: cell.cx + cell.gR - cell.gBump
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 0.5
                            controlY: cell.gBaseY + cell.footDepth(0)
                        }
                        PathQuad {
                            x: cell.cx + cell.gR - cell.gBump * 2
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 1.5
                            controlY: cell.gBaseY + cell.footDepth(1)
                        }
                        PathQuad {
                            x: cell.cx + cell.gR - cell.gBump * 3
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 2.5
                            controlY: cell.gBaseY + cell.footDepth(2)
                        }
                        PathQuad {
                            x: cell.cx - cell.gR
                            y: cell.gBaseY
                            controlX: cell.cx + cell.gR - cell.gBump * 3.5
                            controlY: cell.gBaseY + cell.footDepth(3)
                        }
                        // Left flank back up to the dome.
                        PathLine {
                            x: cell.cx - cell.gR
                            y: cell.gDomeY
                        }
                    }
                }

                Repeater {
                    model: 2

                    Rectangle {
                        id: eye

                        required property int index

                        readonly property real side: eye.index === 0 ? -1 : 1

                        x: cell.cx + eye.side * cell.eyeDX - cell.eyeR
                        y: cell.eyeY - cell.eyeR
                        width: cell.eyeR * 2
                        height: cell.eyeR * 2
                        radius: width / 2
                        color: root.ghostEyeColor
                        antialiasing: true

                        Rectangle {
                            width: cell.eyeR
                            height: cell.eyeR
                            radius: width / 2
                            color: root.frightened ? root.frightenedPupilColor : root.ghostPupilColor
                            antialiasing: true
                            x: (parent.width - width) / 2 + (cell.ghostLooksLeft ? -cell.eyeR * 0.42 : cell.eyeR * 0.42)
                            y: (parent.height - height) / 2 + cell.eyeR * 0.2

                            Behavior on x {
                                enabled: root.animationsOn
                                NumberAnimation {
                                    duration: Lib.Theme.shortDuration
                                    easing.type: Lib.Theme.standardEasing
                                }
                            }
                        }
                    }
                }
            }

            // Pellet (an urgent workspace, drawn as a blinking energizer) and the
            // plain dot for an untouched slot share one circle.
            Rectangle {
                id: pellet

                anchors.centerIn: parent
                // The maze energizers blink hard on and off rather than fading.
                visible: (cell.kind === "dot") || (cell.kind === "pellet" && (!cell.animate || root.smoothAnimation || root.spriteFrame < 2))
                // Smooth mode pulses the energizer instead of cutting it in and out.
                opacity: (cell.kind === "pellet" && cell.animate && root.smoothAnimation) ? (0.3 + 0.7 * root.smoothPhase) : 1
                width: {
                    if (cell.kind === "pellet")
                        return root.pelletDiameter(root.urgentPelletFraction, 6)
                    return root.pelletDiameter(cell.isOccupied ? root.occupiedPelletFraction : root.pelletFraction, 4)
                }
                height: width
                radius: width / 2
                color: cell.pelletTint
                antialiasing: true

            }

            // Con la boca quieta, el pellet que esta a punto de comerse.
            // Solo con la boca quieta: mientras mastica habria un pellet
            // apareciendo y desapareciendo varias veces por segundo, que es
            // ruido, no informacion.
            Rectangle {
                id: mouthPellet

                visible: root.mouthPellet && cell.kind === "pacman" && !cell.animate
                // Dentro de la cuña, del lado hacia el que abre la boca.
                x: cell.cx + (root.facingLeft ? -1 : 1) * cell.pacRestRadius * 0.52 - width / 2
                y: cell.cy - height / 2
                width: root.pelletDiameter(root.pelletFraction, 3)
                height: width
                radius: width / 2
                color: cell.shade(root.pelletColor)
                antialiasing: true
                z: 1
            }

            MouseArea {
                id: cellMouse

                anchors.fill: parent
                // Grow the hit target into half the gap on each side so the icons
                // are comfortable to click without the targets overlapping.
                anchors.margins: -Math.floor(root.cellSpacing / 2)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                acceptedButtons: Qt.LeftButton
                onClicked: root.switchTo(cell.info)
            }
        }
    }

    // One notch of a mouse wheel is 120 units; a touchpad sends many small deltas,
    // so they are accumulated to the same threshold instead of firing per event.
    component WorkspaceWheel: WheelHandler {
        id: wheel

        property real accumulated: 0

        enabled: root.scrollEnabled
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

        onWheel: event => {
            const delta = event.angleDelta.y !== 0 ? event.angleDelta.y : event.angleDelta.x
            if (delta === 0)
                return
            // Reversing direction mid-gesture should not fire off a leftover step.
            if ((delta > 0 && wheel.accumulated < 0) || (delta < 0 && wheel.accumulated > 0))
                wheel.accumulated = 0

            wheel.accumulated += delta
            const dir = root.scrollReversed ? -1 : 1
            while (wheel.accumulated >= 120) {
                wheel.accumulated -= 120
                root.stepWorkspace(-dir)
            }
            while (wheel.accumulated <= -120) {
                wheel.accumulated += 120
                root.stepWorkspace(dir)
            }
        }
    }

    // The model is a plain slot COUNT, never the slot array. The previous version
    // handed the Repeater a freshly built array on every change, so every delegate
    // was destroyed and rebuilt on each workspace switch - the churn that left
    // Pac-Man stranded on an old slot. With a count, a workspace switch changes
    // only the delegates' bindings and nothing is recreated.
    // (Changing the count itself does still regenerate the strip - that is how
    // Repeater behaves - but a regenerated Shape draws correctly on its first
    // frame, unlike the Canvas it replaced.)
    // The strip itself, a direct child rather than a Component handed to a
    // loader in another context. That indirection is what made this invisible:
    // Plasma builds a representation in its own context and could not create a
    // Component defined in this file's scope, so the Loader loaded nothing and
    // reported no error at all.
    // El fondo del slot ocupa sitio, asi que entra en el tamaño que el panel
    // lee. Sin esto el corredor se dibujaria fuera de los limites del applet y
    // el panel lo recortaria.
    readonly property real stripBoxWidth: stripRow.implicitWidth + (root.hasCorridor ? root.cellSpacing * 2 : 0)
    readonly property real stripBoxHeight: stripRow.implicitHeight
        + (root.hasCorridor ? 6 : 0)
        + (root.hasRails ? root.railThickness * 4 : 0)

    implicitWidth: root.stripBoxWidth
    implicitHeight: Math.max(root.stripBoxHeight, 12)

    // CÓMO SE DIMENSIONA UNA REPRESENTACIÓN COMPACTA EN PLASMA.
    // El panel la coloca en un Layout y lee Layout.preferredWidth/Height.
    // implicitWidth es apenas el último recurso, y confiar en él es lo que
    // dejó a este widget con un ancho por defecto - texto cortado en uno,
    // espacio vacío sin alto en el otro.
    Layout.minimumWidth: root.stripBoxWidth
    Layout.preferredWidth: root.stripBoxWidth
    Layout.maximumWidth: root.stripBoxWidth
    Layout.minimumHeight: Math.max(root.stripBoxHeight, 12)
    Layout.preferredHeight: Math.max(root.stripBoxHeight, 12)

    // ---- why nothing is on screen ---------------------------------------
    // Seven rounds of this failed the same way: it loads, takes space, raises
    // no error, and draws nothing - and every configuration reproducible off a
    // real panel works. So instead of another guess, it says what it sees.
    //
    // The badge appears ONLY when the strip would otherwise be empty, so on a
    // working panel it is never seen. An invisible failure becomes a visible
    // one with the numbers that explain it.
    // Even with no desktop data the strip pads to minSlots and draws, so
    // "empty" almost never fires - which means it is NOT a data problem when
    // nothing shows. Hence the explicit switch: turned on, it outlines the
    // item's real bounds and prints what it thinks it is, so one screenshot
    // says whether the widget is the wrong size, in the wrong place, or drawing
    // nothing at the right size. Those are three different bugs.
    readonly property bool debugOverlay: Plasmoid.configuration.debugOverlay ?? false

    // Measured, not computed. What "invisible" looks like from inside is the
    // item having collapsed - not the numbers that feed it - so this reads the
    // geometry the scene graph actually got. Items do not clip by default, so
    // the badge is still drawn even when the strip itself is 0x0.
    readonly property bool wouldBeEmpty: root.slotCount < 1 || root.cellSize < 2
                                       || stripRow.implicitWidth < 2
                                       || root.width < 4 || root.height < 4
                                       || stripBox.width < 2 || stripBox.height < 2

    readonly property string diagnostic:
        "slots=" + root.slotCount
        + " cell=" + root.cellSize
        + " w=" + Math.round(root.width)
        + " h=" + Math.round(root.height)
        + " rowW=" + Math.round(stripRow.width)
        + " boxW=" + Math.round(stripBox.width)
        + " bar=" + Math.round(root.barThickness)
        + " desktops=" + (Lib.WorkspaceService.count ?? -1)
        + " focus=" + (Lib.WorkspaceService.focusedNum ?? -1)
        + " ids=" + JSON.stringify(Lib.WorkspaceService.desktopIds ?? null)

    // The item's real bounds. If this outline does not appear at all, the
    // widget is not where it is thought to be; if it appears empty, the
    // drawing is the problem.
    Rectangle {
        anchors.fill: parent
        visible: root.debugOverlay
        color: "#3000ff00"
        border.color: "#ff00ff"
        border.width: 1
        z: 99
    }

    Rectangle {
        anchors.centerIn: parent
        visible: root.wouldBeEmpty || root.debugOverlay
        z: 100
        width: Math.max(diagText.implicitWidth + 8, 40)
        height: Math.max(diagText.implicitHeight + 4, 14)
        color: "#c0208080"
        radius: 3

        Text {
            id: diagText
            anchors.centerIn: parent
            text: root.diagnostic
            color: "#ffffff"
            font.pixelSize: 9
            font.family: "monospace"
        }
    }

    Item {
        id: stripBox

        anchors.centerIn: parent
        width: root.stripBoxWidth
        height: root.stripBoxHeight

        // Detras de la tira, nunca encima: los sprites tienen que seguir siendo
        // lo primero que se lee.
        Rectangle {
            anchors.fill: parent
            visible: root.hasCorridor
            radius: height / 2.6
            color: root.slotBackground === "corridorTint" ? Qt.rgba(0, 0, 0, 0.25) : "transparent"
            border.color: root.slotBackground === "corridorTint"
                ? Qt.rgba(root.corridorColor.r, root.corridorColor.g, root.corridorColor.b, 0.75)
                : root.corridorColor
            border.width: 2
            z: -1
        }

        // Rieles: dos paredes y nada mas, detras de la tira igual que el
        // corredor.
        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.railThickness
            radius: height / 2
            visible: root.hasRails
            color: root.corridorColor
            z: -1
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: root.railThickness
            radius: height / 2
            visible: root.hasRails
            color: root.corridorColor
            z: -1
        }

        Row {
            id: stripRow
            anchors.centerIn: parent
            spacing: root.cellSpacing

            WorkspaceWheel {}

            Repeater {
                model: root.slotCount
                delegate: cellDelegate
            }
        }
    }
}
