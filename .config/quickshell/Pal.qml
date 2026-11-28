pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The colours everything in the shell uses, read from pywal's ~/.cache/wal/colors.json and updated when the wallpaper
// changes: the 16 wallpaper colours, plus named ones for panels, text and accents.
Singleton {
    id: root

    readonly property color bg:     _special.background
    readonly property color fg:     _special.foreground
    readonly property string wallpaper: _wal.wallpaper

    readonly property color color0:  _colors.color0
    readonly property color color1:  _colors.color1
    readonly property color color2:  _colors.color2
    readonly property color color3:  _colors.color3
    readonly property color color4:  _colors.color4
    readonly property color color5:  _colors.color5
    readonly property color color6:  _colors.color6
    readonly property color color7:  _colors.color7
    readonly property color color8:  _colors.color8
    readonly property color color9:  _colors.color9
    readonly property color color10: _colors.color10
    readonly property color color11: _colors.color11
    readonly property color color12: _colors.color12
    readonly property color color13: _colors.color13
    readonly property color color14: _colors.color14
    readonly property color color15: _colors.color15

    function over(c, a) { return Qt.tint(color0, Qt.rgba(c.r, c.g, c.b, a)); }

    readonly property color bgPanel:    color0
    readonly property color bgSubtle:   over(color0, 0.85)
    readonly property color bgInput:    over(color8, 0.5)
    readonly property color bgOverlay:  over(color0, 0.80)

    readonly property color fgPrimary:  color15
    readonly property color fgSub:      color7
    readonly property color fgMuted:    color8
    readonly property color fgFaint:    over(color8, 0.7)
    readonly property color fgOnDark:   color15

    readonly property color accent:     color4
    readonly property color accentAlt:  color6
    readonly property color accentWarm: color3

    readonly property color borderFocus:   color4
    readonly property color borderSurface: over(color8, 0.6)

    readonly property color positive:   themedGood
    readonly property color negative:   themedBad
    readonly property color warning:    themedWarn
    readonly property real _schemeSat: Math.min(0.65, Math.max(0.34, 1.2 *
        (color1.hslSaturation + color2.hslSaturation + color3.hslSaturation + color4.hslSaturation + color5.hslSaturation + color6.hslSaturation) / 6))
    readonly property real _schemeLight: Math.min(0.68, Math.max(0.5,
        (color1.hslLightness + color2.hslLightness + color3.hslLightness + color4.hslLightness + color5.hslLightness + color6.hslLightness) / 6))
    function themed(hue) { return Qt.tint(Qt.hsla(hue / 360, _schemeSat, _schemeLight, 1), Qt.rgba(color4.r, color4.g, color4.b, 0.22)); }
    readonly property color themedGood: themed(125)
    readonly property color themedWarn: themed(30)
    readonly property color themedBad:  themed(358)
    readonly property color star:       color3
    readonly property color matchFound: positive
    readonly property color matchNone:  negative

    readonly property color scrollbar:        over(color8, 0.5)
    readonly property color scrollbarPressed: color7

    readonly property color inputText:   color15
    readonly property color searchIcon:  color8

    readonly property color notifAccent:      color4
    readonly property color fgNotifBody:      color7
    readonly property color notifDivider:     over(color4, 0.13)
    readonly property color notifSelBg:       over(color4, 0.13)
    readonly property color notifHovBg:       over(color15, 0.09)
    readonly property color notifCardBg:      over(color15, 0.07)
    readonly property color notifClearBg:     over(color15, 0.10)
    readonly property color notifTimeFaint:   over(color7, 0.55)
    readonly property color fgNotifTitle:     color15
    readonly property color fgNotifMeta:      over(color7, 0.7)
    readonly property color fgNotifFaint:     over(color7, 0.55)
    readonly property color fgNotifEmpty:     over(color7, 0.35)
    readonly property color fgClearBtn:       color7
    readonly property color borderNotifInner: over(color4, 0.33)
    readonly property color borderNotifCard:  over(color4, 0.10)
    readonly property color borderNotifSel:   over(color4, 0.40)
    readonly property color borderNotifBtn:   over(color15, 0.20)
    readonly property color notifBody:        over(color7, 0.82)
    readonly property color notifToastBg:     bgOverlay
    readonly property color notifCrit:        negative
    readonly property color notifCritBg:      over(negative, 0.10)
    readonly property color borderNotifLow:   over(color8, 0.45)
    readonly property color notifTrack:       over(color15, 0.12)

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: _wal
            property string wallpaper: ""
            property JsonObject special: JsonObject {
                id: _special
                property string background: "#1c1917"
                property string foreground: "#ede8e0"
            }
            property JsonObject colors: JsonObject {
                id: _colors
                property string color0:  "#1c1917"
                property string color1:  "#c87868"
                property string color2:  "#78c898"
                property string color3:  "#c8a870"
                property string color4:  "#8898c8"
                property string color5:  "#a888c8"
                property string color6:  "#78b8c8"
                property string color7:  "#ede8e0"
                property string color8:  "#5a5248"
                property string color9:  "#c87868"
                property string color10: "#78c898"
                property string color11: "#c8a870"
                property string color12: "#8898c8"
                property string color13: "#a888c8"
                property string color14: "#78b8c8"
                property string color15: "#ede8e0"
            }
        }
    }
}
