import QtQuick
import "../"
import "fmt.js" as F

// One tag on the bar: its name, coloured and underlined while you're on it; a click goes to it.
Item {
    id: b

    required property var modelData
    readonly property var ws: modelData
    property int barH: 22

    readonly property real px: 11.1 * Sys.barScale
    readonly property real textW: F.runWidth(ws.name, px, false, Sys.barScale)
    readonly property int innerW: Math.max(Sys.barPx(16), textW)
    readonly property bool hover: area.containsMouse
    readonly property var runs: [{ t: ws.name, px: px }]

    width: Sys.barPx(16) + innerW
    height: barH

    Rectangle {
        visible: b.hover
        width: parent.width
        height: 2
        color: Pal.fg
    }

    Rectangle {
        visible: b.ws.active
        y: b.barH - 2
        width: parent.width
        height: 2
        color: Pal.color4
    }

    BarText {
        x: Sys.barPx(8) + Math.floor((b.innerW - b.textW) / 2)
        y: F.baseline(b.barH, b.hover ? 2 : 0, 2, b.runs) - baselineOffset
        px: b.px
        text: b.ws.name
        color: !b.ws.shouldDisplay ? Pal.fg : b.ws.active ? Pal.color4 : Pal.color8
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: if (b.ws.canActivate) b.ws.activate()
    }
}
