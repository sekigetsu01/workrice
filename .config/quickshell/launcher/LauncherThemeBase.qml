import QtQuick
import "../"

// The launcher panels' sizes and colours, from the wallpaper's colours (Pal.qml); each panel changes what it needs
QtObject {

    property int panelW: 400
    property int searchBarH: 56

    readonly property int rowHeight: 40
    property int maxVisibleRows: 9
    readonly property int dividerH: 24
    property int outerPad: 12
    readonly property int bottomPad: 10
    readonly property int panelH: searchBarH + dividerH + maxVisibleRows * rowHeight + bottomPad

    property bool seeThrough: false
    property real bgAlpha: 0.93
    function mix(c, a) { return seeThrough ? Qt.rgba(c.r, c.g, c.b, a) : Pal.over(c, a); }

    readonly property color clrBg: mix(Pal.color0, bgAlpha)
    readonly property color clrBorder: mix(Pal.color8, 0.53)
    readonly property color clrDivider: mix(Pal.color8, 0.40)
    readonly property color clrSelRow: mix(Pal.color8, 0.67)
    readonly property color clrHovRow: mix(Pal.color8, 0.53)
    readonly property color clrTextPrim: Pal.fgPrimary
    readonly property color clrTextSecond: Pal.fgSub
    readonly property color clrTextMuted: Pal.fgMuted
    readonly property color clrSearchIcon: Pal.searchIcon
    readonly property color clrSearchFocus: Pal.borderFocus
    readonly property color clrInputText: Pal.inputText
    readonly property color clrScrollbar: Pal.scrollbar
    readonly property color clrScrollPrs: Pal.scrollbarPressed
    readonly property color clrMatch: Pal.warning
    readonly property color clrStar: Pal.star
    readonly property color clrStarOff: Pal.fgSub
    readonly property color clrCalcError: Pal.negative
}
