pragma Singleton
import QtQuick
import org.kde.kirigami as Kirigami

// Material 3 names on top of Kirigami's palette.
//
// The two plugins between them use 28 Theme properties, and DMS' Theme is
// Material 3 while Kirigami's is Breeze. There is no 1:1 mapping - M3 has four
// surface container levels where Kirigami has two - so this is a deliberate
// approximation, and it is the only file that has to change if it looks wrong.
// Everything downstream keeps the names it already had.
//
// The upside of routing every colour through here: the widgets follow the
// user's Plasma colour scheme automatically, light or dark, without a single
// hardcoded value anywhere in the plugins.
QtObject {
    id: theme

    // ---- text ------------------------------------------------------------
    readonly property color surfaceText: Kirigami.Theme.textColor
    readonly property color surfaceVariantText: Kirigami.Theme.disabledTextColor
    readonly property color surface: Kirigami.Theme.backgroundColor
    readonly property color surfaceTextHover: theme.withAlpha(Kirigami.Theme.textColor, 0.08)

    // ---- accents ---------------------------------------------------------
    readonly property color primary: Kirigami.Theme.highlightColor
    readonly property color tertiary: Kirigami.Theme.activeTextColor
    readonly property color success: Kirigami.Theme.positiveTextColor
    readonly property color error: Kirigami.Theme.negativeTextColor
    readonly property color warning: Kirigami.Theme.neutralTextColor
    readonly property color info: Kirigami.Theme.highlightColor

    // Breeze has no outline colour; a low-alpha text colour reads the same way
    // against both a light and a dark background.
    readonly property color outline: theme.withAlpha(Kirigami.Theme.textColor, 0.25)

    // The panel is dark or light depending on the user's scheme, and a few
    // places need to know which. Rec. 601 luma over the background.
    readonly property bool isLightMode: {
        const c = Kirigami.Theme.backgroundColor;
        return (0.299 * c.r + 0.587 * c.g + 0.114 * c.b) > 0.5;
    }

    // DMS returns "" when the user has not overridden the logo colour, which
    // means "draw it in its own colours". Nothing here overrides it.
    readonly property var effectiveLogoColor: ""

    // ---- metrics ---------------------------------------------------------
    // Kirigami.Units.smallSpacing is 4 at the default scale, which is what
    // DMS' spacingXS is, so the whole scale lines up without inventing numbers.
    readonly property real spacingXS: Kirigami.Units.smallSpacing
    readonly property real spacingS: Kirigami.Units.smallSpacing * 2
    readonly property real spacingM: Kirigami.Units.largeSpacing
    readonly property real spacingL: Kirigami.Units.largeSpacing * 2

    readonly property real iconSize: Kirigami.Units.iconSizes.smallMedium
    readonly property real iconSizeLarge: Kirigami.Units.iconSizes.medium
    readonly property real iconSizeSmall: Kirigami.Units.iconSizes.small

    // cornerRadius arrived in a later Kirigami; fall back rather than bind to
    // undefined, which is a hard error on a real property.
    readonly property real cornerRadius: (Kirigami.Units.cornerRadius !== undefined && Kirigami.Units.cornerRadius > 0)
        ? Kirigami.Units.cornerRadius : 6

    // ---- fonts -----------------------------------------------------------
    // A font carries either a pixelSize or a pointSize, never both; reading the
    // one that is not set gives -1, so the other has to be converted.
    readonly property real _basePx: Kirigami.Theme.defaultFont.pixelSize > 0
        ? Kirigami.Theme.defaultFont.pixelSize
        : Math.round(Kirigami.Theme.defaultFont.pointSize * 96 / 72)

    readonly property real fontSizeSmall: Math.round(theme._basePx * 0.85)
    readonly property real fontSizeMedium: theme._basePx
    readonly property real fontSizeLarge: Math.round(theme._basePx * 1.15)
    readonly property real fontSizeXLarge: Math.round(theme._basePx * 1.45)

    // ---- animation -------------------------------------------------------
    readonly property int shortDuration: Kirigami.Units.shortDuration
    readonly property int shorterDuration: Math.round(Kirigami.Units.shortDuration * 0.7)
    readonly property int mediumDuration: Kirigami.Units.longDuration
    readonly property int standardEasing: Easing.OutCubic

    // ---- functions -------------------------------------------------------
    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a);
    }

    function hoverTint(c) {
        return theme.withAlpha(c, 0.12);
    }

    // Rounds a length to whole device pixels so a 1px line stays 1px on a
    // fractional-scale screen instead of blurring across two.
    function snap(v, dpr) {
        const d = (dpr === undefined || dpr <= 0) ? 1 : dpr;
        return Math.round(v * d) / d;
    }

    function px(v, dpr) {
        return theme.snap(v, dpr);
    }

    // Mirrors DMS' Theme.barTextSize / barIconSize so sizes mean the same thing
    // they meant on the bar these plugins came from. On a Plasma panel the
    // thickness comes from the panel rather than a DMS setting.
    function barTextSize(barThickness, fontScale, maximize) {
        const s = (fontScale === undefined || fontScale <= 0) ? 1.0 : fontScale;
        const base = (maximize ?? false) ? theme.fontSizeMedium : theme.fontSizeSmall;
        return Math.max(8, Math.round(base * s));
    }

    function barIconSize(barThickness, offset, maximizeIcon, iconScale) {
        const defaultOffset = offset !== undefined ? offset : -6;
        const size = (maximizeIcon ?? false) ? theme.iconSizeLarge : theme.iconSize;
        const s = iconScale !== undefined ? iconScale : 1.0;
        return Math.round((barThickness / 48) * (size + defaultOffset) * s);
    }
}
