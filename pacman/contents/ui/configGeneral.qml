import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

// The widget's settings page.
//
// Two structural things this got wrong before, both of which are why it looked
// like a list of loose controls rather than a settings page:
//
//   1. Every control was nested inside one ColumnLayout inside the FormLayout.
//      Kirigami.FormData is an ATTACHED property that FormLayout reads from its
//      DIRECT children only, so wrapping them threw away the entire label
//      column - "Minimum slots:", "Palette:" and the rest were never drawn.
//      Everything here is therefore a direct child of the FormLayout.
//   2. The debug-overlay switch and its help text were children of the
//      SimpleKCM itself, outside the FormLayout. SimpleKCM takes a single
//      content item, so they were never shown at all - the alias still
//      resolved, which is why nothing ever complained.
//
// The rest is ordinary polish: sections, units next to the numbers they belong
// to, and controls that grey out when the setting above them takes over.
KCM.SimpleKCM {
    id: kcmRoot

    // The scroll bar is drawn OVER the content, so the form has to leave room
    // for it or it covers the right-hand edge of every row.
    rightPadding: Kirigami.Units.gridUnit * 2

    // These must live on the page root. Moved inside the FormLayout they still
    // parse, and every one of them silently stops being bound to its setting.
    property alias cfg_workspaceCount: workspaceCountBox.value
    property alias cfg_maxSlots: maxSlotsBox.value
    property alias cfg_perMonitor: perMonitorBox.checked
    property alias cfg_autoIconSize: autoIconSizeBox.checked
    property alias cfg_iconSizeOverride: iconSizeOverrideBox.value
    property alias cfg_autoSpacing: autoSpacingBox.checked
    property alias cfg_spacingOverride: spacingOverrideBox.value
    property alias cfg_pelletSize: pelletSizeBox.value
    property string cfg_palette
    property string cfg_ghostMode
    property string cfg_ghostColorMode
    property string cfg_ghostMotion
    property alias cfg_animations: animationsBox.checked
    property string cfg_animationStyle
    property alias cfg_frightenedGhosts: frightenedGhostsBox.checked
    property alias cfg_scrollToSwitch: scrollToSwitchBox.checked
    property alias cfg_scrollReversed: scrollReversedBox.checked
    property string cfg_slotBackground
    property string cfg_slotBackgroundColorMode
    property color cfg_slotBackgroundColor
    property alias cfg_mouthPellet: mouthPelletBox.checked
    property alias cfg_debugOverlay: debugOverlayBox.checked

    Kirigami.FormLayout {
        id: page

        // ---------------------------------------------------------- slots --
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Workspaces"
        }

        RowLayout {
            Kirigami.FormData.label: "Minimum slots:"
            QQC2.SpinBox {
                id: workspaceCountBox
                from: 1; to: 20; stepSize: 1; editable: true
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Slots always shown, even when those desktops are empty."
        }

        RowLayout {
            Kirigami.FormData.label: "Maximum slots:"
            QQC2.SpinBox {
                id: maxSlotsBox
                from: 1; to: 30; stepSize: 1; editable: true
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: maxSlotsBox.value <= workspaceCountBox.value
                ? "Equal to the minimum: the strip stays a fixed length."
                : "The strip grows past the minimum as you use higher desktops, but never beyond this."
        }

        QQC2.CheckBox {
            id: perMonitorBox
            Kirigami.FormData.label: "Multiple screens:"
            text: "Per-monitor desktops"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Plasma's virtual desktops are shared, but which one is current can differ per screen. On, the strip follows its own screen; off, it follows the session's current desktop. Clicking a slot always switches every screen - Plasma exposes no per-screen switch to widgets."
        }

        // ----------------------------------------------------------- size --
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Size"
        }

        QQC2.CheckBox {
            id: autoIconSizeBox
            Kirigami.FormData.label: "Icons:"
            text: "Size from the panel"
        }

        RowLayout {
            Kirigami.FormData.label: "Icon size:"
            // Greyed out rather than hidden: a value that silently does nothing
            // is worse than one you can see is not in charge.
            enabled: !autoIconSizeBox.checked

            QQC2.SpinBox {
                id: iconSizeOverrideBox
                from: 10; to: 48; stepSize: 1; editable: true
            }
            QQC2.Label {
                text: "px"
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignVCenter
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: autoIconSizeBox.checked
                ? "Derived from the panel's thickness - 21 px on a standard 48 px panel."
                : "Pinned to an exact size, whatever the panel's thickness."
        }

        QQC2.CheckBox {
            id: autoSpacingBox
            Kirigami.FormData.label: "Spacing:"
            text: "Space icons automatically"
        }

        RowLayout {
            Kirigami.FormData.label: "Gap:"
            enabled: !autoSpacingBox.checked

            QQC2.SpinBox {
                id: spacingOverrideBox
                from: 0; to: 24; stepSize: 1; editable: true
            }
            QQC2.Label {
                text: "px"
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignVCenter
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Pellet size:"

            QQC2.SpinBox {
                id: pelletSizeBox
                from: 10; to: 60; stepSize: 1; editable: true
            }
            QQC2.Label {
                text: "%"
                color: Kirigami.Theme.disabledTextColor
                Layout.alignment: Qt.AlignVCenter
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "An untouched desktop's pellet, as a percentage of the icon size. A desktop with windows open is 1.5x this, and an urgent one 2x."
        }

        // ----------------------------------------------------- appearance --
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Appearance"
        }

        QQC2.ComboBox {
            id: paletteBox
            Kirigami.FormData.label: "Palette:"
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "Arcade (authentic)", "value": "arcade" },
                { "text": "Adaptive (follows your colour scheme)", "value": "theme" }
            ]
            onActivated: kcmRoot.cfg_palette = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_palette)
            Connections {
                target: kcmRoot
                function oncfg_paletteChanged() { paletteBox.currentIndex = paletteBox.indexOfValue(kcmRoot.cfg_palette) }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Arcade uses the 1980 cabinet's own colours. Adaptive follows your Plasma colour scheme, for panels where arcade primaries are too loud."
        }

        QQC2.ComboBox {
            id: ghostModeBox
            Kirigami.FormData.label: "Ghosts appear on:"
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "Desktops behind you (chasing)", "value": "behind" },
                { "text": "Desktops with windows open", "value": "occupied" },
                { "text": "Every other desktop", "value": "all" }
            ]
            onActivated: kcmRoot.cfg_ghostMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_ghostMode)
            Connections {
                target: kcmRoot
                function oncfg_ghostModeChanged() { ghostModeBox.currentIndex = ghostModeBox.indexOfValue(kcmRoot.cfg_ghostMode) }
            }
        }

        QQC2.ComboBox {
            id: ghostColorModeBox
            Kirigami.FormData.label: "Ghost colours:"
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "One colour per desktop", "value": "workspace" },
                { "text": "By distance behind you", "value": "distance" }
            ]
            onActivated: kcmRoot.cfg_ghostColorMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_ghostColorMode)
            Connections {
                target: kcmRoot
                function oncfg_ghostColorModeChanged() { ghostColorModeBox.currentIndex = ghostColorModeBox.indexOfValue(kcmRoot.cfg_ghostColorMode) }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Per desktop keeps each desktop's ghost the same colour every time. By distance recolours them as you move, so the ghost right behind you is always the same one."
        }

        QQC2.ComboBox {
            id: slotBackgroundBox
            Kirigami.FormData.label: "Maze background:"
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "None", "value": "none" },
                { "text": "Corridor (outline)", "value": "corridor" },
                { "text": "Corridor (filled)", "value": "corridorTint" },
                { "text": "Rails (two walls)", "value": "rails" }
            ]
            onActivated: kcmRoot.cfg_slotBackground = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_slotBackground)
            Connections {
                target: kcmRoot
                function oncfg_slotBackgroundChanged() { slotBackgroundBox.currentIndex = slotBackgroundBox.indexOfValue(kcmRoot.cfg_slotBackground) }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "A full maze does not fit a panel's height - its walls turn into noise and bury the pellets. One corridor reads, because that is the shape the eye already associates with the game. Off by default: it costs a few pixels of height and the sprites shrink for it."
        }

        QQC2.ComboBox {
            id: bgColorModeBox
            Kirigami.FormData.label: "Background colour:"
            enabled: kcmRoot.cfg_slotBackground !== "none"
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "Automatic (follows the palette)", "value": "auto" },
                { "text": "Custom", "value": "custom" }
            ]
            onActivated: kcmRoot.cfg_slotBackgroundColorMode = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_slotBackgroundColorMode)
            Connections {
                target: kcmRoot
                function oncfg_slotBackgroundColorModeChanged() { bgColorModeBox.currentIndex = bgColorModeBox.indexOfValue(kcmRoot.cfg_slotBackgroundColorMode) }
            }
        }

        RowLayout {
            Kirigami.FormData.label: "Colour:"
            // Sólo con Custom activo, y al volver a Automatic el valor vuelve
            // al de fábrica: si no, la paleta seguía mostrando el color viejo
            // aunque el widget ya dibujara el original.
            enabled: kcmRoot.cfg_slotBackground !== "none" && kcmRoot.cfg_slotBackgroundColorMode === "custom"

            QQC2.TextField {
                id: bgColorBox
                Layout.preferredWidth: Kirigami.Units.gridUnit * 8
                placeholderText: "#RRGGBB"
                text: String(kcmRoot.cfg_slotBackgroundColor)
                onEditingFinished: if (/^#[0-9A-Fa-f]{6}$/.test(text)) kcmRoot.cfg_slotBackgroundColor = text
            }
            Rectangle {
                Layout.preferredWidth: Kirigami.Units.gridUnit
                Layout.preferredHeight: Kirigami.Units.gridUnit
                radius: 3
                border.width: 1
                border.color: Kirigami.Theme.disabledTextColor
                color: /^#[0-9A-Fa-f]{6}$/.test(bgColorBox.text) ? bgColorBox.text : "transparent"
            }
        }

        Connections {
            target: kcmRoot
            function oncfg_slotBackgroundColorModeChanged() {
                if (kcmRoot.cfg_slotBackgroundColorMode !== "custom")
                    kcmRoot.cfg_slotBackgroundColor = "#2121DE";
            }
        }

        // ------------------------------------------------------ animation --
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Animation"
        }

        QQC2.CheckBox {
            id: animationsBox
            Kirigami.FormData.label: "Animate:"
            text: "Chomping, bouncing and drifting"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Setting Plasma's animation speed to Instant disables these too."
        }

        QQC2.ComboBox {
            id: animationStyleBox
            Kirigami.FormData.label: "Style:"
            enabled: animationsBox.checked
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "Arcade (frame-stepped)", "value": "arcade" },
                { "text": "Smooth (continuous)", "value": "smooth" }
            ]
            onActivated: kcmRoot.cfg_animationStyle = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_animationStyle)
            Connections {
                target: kcmRoot
                function oncfg_animationStyleChanged() { animationStyleBox.currentIndex = animationStyleBox.indexOfValue(kcmRoot.cfg_animationStyle) }
            }
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Arcade steps through sprite frames on a shared clock, the way the cabinet does. Smooth tweens the same sprites at your display's refresh rate."
        }

        QQC2.ComboBox {
            id: ghostMotionBox
            Kirigami.FormData.label: "Ghost motion:"
            enabled: animationsBox.checked
            textRole: "text"; valueRole: "value"
            model: [
                { "text": "Arcade (shuffling skirt)", "value": "arcade" },
                { "text": "Float (drifting)", "value": "float" },
                { "text": "Both", "value": "both" }
            ]
            onActivated: kcmRoot.cfg_ghostMotion = currentValue
            Component.onCompleted: currentIndex = indexOfValue(kcmRoot.cfg_ghostMotion)
            Connections {
                target: kcmRoot
                function oncfg_ghostMotionChanged() { ghostMotionBox.currentIndex = ghostMotionBox.indexOfValue(kcmRoot.cfg_ghostMotion) }
            }
        }

        QQC2.CheckBox {
            id: frightenedGhostsBox
            Kirigami.FormData.label: "Energizer:"
            enabled: animationsBox.checked
            text: "Frightened ghosts"
        }

        QQC2.CheckBox {
            id: mouthPelletBox
            Kirigami.FormData.label: "Mouth:"
            // Lo contrario del resto: sólo se ve con las animaciones APAGADAS,
            // porque es lo que llena la boca congelada.
            enabled: !animationsBox.checked
            text: "Pellet in the open mouth"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "With animations off the mouth freezes open, which reads as waiting rather than eating. A pellet in the opening is what the arcade frame shows at that moment - the bite about to happen."
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Going back to a lower desktop counts as eating an energizer: the ghosts turn blue for a few seconds, then flash white before they recover."
        }

        // ---------------------------------------------------------- input --
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Mouse"
        }

        QQC2.CheckBox {
            id: scrollToSwitchBox
            Kirigami.FormData.label: "Wheel:"
            text: "Scroll to switch desktop"
        }

        QQC2.CheckBox {
            id: scrollReversedBox
            enabled: scrollToSwitchBox.checked
            text: "Reverse the direction"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Left-click a slot to go to that desktop. Right-click opens this widget's menu."
        }

        // ------------------------------------------------ troubleshooting --
        Item {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: "Troubleshooting"
        }

        QQC2.CheckBox {
            id: debugOverlayBox
            Kirigami.FormData.label: "Diagnostics:"
            text: "Debug overlay"
        }

        QQC2.Label {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            font: Kirigami.Theme.smallFont
            color: Kirigami.Theme.disabledTextColor
            text: "Outlines the widget's real bounds and prints its size and desktop count. No outline means it is not where you think it is; an empty outline means it is drawing nothing at the right size."
        }
    }
}
