pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property color bg:     _special.background
    readonly property color fg:     _special.foreground
    readonly property color cursor: _special.cursor

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

    readonly property color bgPanel:    color0
    readonly property color bgAlt:      color8   
    readonly property color bgElevated: color8   
    readonly property color bgHover:    Qt.rgba(color8.r, color8.g, color8.b, 0.6)
    readonly property color bgSubtle:   Qt.rgba(color0.r, color0.g, color0.b, 0.85)
    readonly property color bgInput:    Qt.rgba(color8.r, color8.g, color8.b, 0.5)
    readonly property color bgOverlay:  Qt.rgba(color0.r, color0.g, color0.b, 0.80)
    readonly property color bgToast:    Qt.rgba(color0.r, color0.g, color0.b, 0.93)
    readonly property color bgLock:     Qt.rgba(color0.r, color0.g, color0.b, 0.75)
    readonly property color bgPowermenu: Qt.rgba(color0.r, color0.g, color0.b, 0.92)
    readonly property color bgLauncher:  Qt.rgba(color0.r, color0.g, color0.b, 0.92)

    readonly property color fgPrimary:  color15
    readonly property color fgSub:      color7
    readonly property color fgMuted:    color8
    readonly property color fgFaint:    Qt.rgba(color8.r, color8.g, color8.b, 0.7)
    readonly property color fgOnDark:   color15

    readonly property color accent:     color4
    readonly property color accentAlt:  color6
    readonly property color accentWarm: color3

    readonly property color border:        Qt.rgba(color8.r, color8.g, color8.b, 0.5)
    readonly property color borderFocus:   color4
    readonly property color borderHover:   color7
    readonly property color borderAlt:     color3
    readonly property color borderSel:     color6
    readonly property color borderSurface: Qt.rgba(color8.r, color8.g, color8.b, 0.6)

    readonly property color positive:   color2
    readonly property color negative:   color1
    readonly property color warning:    color3
    readonly property color star:       color3
    readonly property color starOff:    Qt.rgba(color8.r, color8.g, color8.b, 0.4)
    readonly property color matchFound: color2
    readonly property color matchNone:  color1

    readonly property color scrollbar:        Qt.rgba(color8.r, color8.g, color8.b, 0.5)
    readonly property color scrollbarPressed: color7

    readonly property color inputText:   color15
    readonly property color searchIcon:  color8
    readonly property color placeholder: Qt.rgba(color7.r, color7.g, color7.b, 0.4)

    readonly property color notifAccent:      color4
    readonly property color notifToastAccent: notifAccent
    readonly property color notifTimeMuted:   Qt.rgba(color8.r, color8.g, color8.b, 0.8)
    readonly property color fgNotifBody:      color7
    readonly property color notifBodyMuted:   fgNotifBody
    readonly property color notifGradient:    Qt.rgba(color5.r, color5.g, color5.b, 0.06)
    readonly property color notifDivider:     Qt.rgba(color4.r, color4.g, color4.b, 0.13)
    readonly property color notifSelBg:       Qt.rgba(color4.r, color4.g, color4.b, 0.13)
    readonly property color notifHovBg:       Qt.rgba(color15.r, color15.g, color15.b, 0.09)
    readonly property color notifCardBg:      Qt.rgba(color15.r, color15.g, color15.b, 0.07)
    readonly property color notifClearBg:     Qt.rgba(color15.r, color15.g, color15.b, 0.10)
    readonly property color notifTimeFaint:   Qt.rgba(color7.r, color7.g, color7.b, 0.27)
    readonly property color fgNotifTitle:     color15
    readonly property color fgNotifApp:       color5
    readonly property color fgNotifAppIcon:   color5
    readonly property color fgNotifMeta:      Qt.rgba(color8.r, color8.g, color8.b, 0.5)
    readonly property color fgNotifFaint:     Qt.rgba(color8.r, color8.g, color8.b, 0.4)
    readonly property color fgNotifEmpty:     Qt.rgba(color7.r, color7.g, color7.b, 0.35)
    readonly property color fgClearBtn:       color7
    readonly property color borderNotif:      Qt.rgba(color4.r, color4.g, color4.b, 0.20)
    readonly property color borderNotifInner: Qt.rgba(color4.r, color4.g, color4.b, 0.33)
    readonly property color borderNotifCard:  Qt.rgba(color4.r, color4.g, color4.b, 0.10)
    readonly property color borderNotifSel:   Qt.rgba(color4.r, color4.g, color4.b, 0.40)
    readonly property color borderToast:      Qt.rgba(color4.r, color4.g, color4.b, 0.16)
    readonly property color borderNotifBtn:   Qt.rgba(color15.r, color15.g, color15.b, 0.20)

    readonly property real _bgLuma: 0.2126 * color0.r + 0.7152 * color0.g + 0.0722 * color0.b
    readonly property color fgLock:       _bgLuma > 0.5 ? "#000000" : "#ffffff"
    readonly property color borderSuccess: color2
    readonly property color borderError:   color1

    readonly property color avatarFallback: Qt.rgba(color8.r, color8.g, color8.b, 0.25)

    FileView {
        path: Quickshell.env("HOME") + "/.cache/wal/colors.json"
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            property JsonObject special: JsonObject {
                id: _special
                property string background: "#1c1917"
                property string foreground: "#ede8e0"
                property string cursor:     "#ede8e0"
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
