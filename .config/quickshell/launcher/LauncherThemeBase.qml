import QtQuick
import "../"

QtObject {

    property int panelW: 400
    property int searchBarH: 56

    readonly property int rowHeight: 46
    readonly property int maxVisibleRows: 10
    readonly property int dividerH: 24
    readonly property int outerPad: 12
    readonly property int panelH: searchBarH + dividerH + maxVisibleRows * rowHeight

    readonly property color clrBg: Qt.rgba(Pal.color0.r, Pal.color0.g, Pal.color0.b, 0.93)
    readonly property color clrBorder: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.53)
    readonly property color clrDivider: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.40)
    readonly property color clrSelRow: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.67)
    readonly property color clrHovRow: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.53)
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
    readonly property color clrStarOff: Pal.starOff
    readonly property color clrCalcResult: Pal.positive
    readonly property color clrCalcError: Pal.negative
    readonly property color clrCalcAccent: Pal.accentAlt
}
