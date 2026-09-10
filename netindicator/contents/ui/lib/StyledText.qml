import QtQuick
import org.kde.kirigami as Kirigami

// DMS' StyledText: a Text bound to the shell's configured font, with
// `isMonospace` as the supported way to ask for the mono face. Assigning
// font.family directly overwrites that binding, which is why the property
// exists rather than each call site setting a family.
Text {
    id: txt

    property bool isMonospace: false

    color: Kirigami.Theme.textColor
    font.family: txt.isMonospace ? "monospace" : Kirigami.Theme.defaultFont.family
    font.pixelSize: Kirigami.Theme.defaultFont.pixelSize > 0
        ? Kirigami.Theme.defaultFont.pixelSize
        : Math.round(Kirigami.Theme.defaultFont.pointSize * 96 / 72)
    renderType: Text.NativeRendering
}
