import QtQuick
import Quickshell
import "../"

// The tooltip under a bar module, shown after hovering on it for half a second.
PopupWindow {
    id: tip

    property var owner: null
    property real px: 0
    property bool want: false
    readonly property string text: owner ? owner.tip : ""

    function show(item, x) {
        owner = item;
        px = item.mapToItem(null, item.width / 2, 0).x;
        want = false;
        delay.restart();
    }

    function hide(item) {
        if (item !== owner)
            return;
        delay.stop();
        want = false;
        owner = null;
    }

    visible: want && text !== ""
    color: "transparent"
    implicitWidth: label.implicitWidth + 16
    implicitHeight: label.implicitHeight + 16
    anchor.rect.x: Math.round(px)
    anchor.rect.y: anchor.window ? anchor.window.height + 4 : 0
    anchor.edges: Edges.Top
    anchor.gravity: Edges.Bottom

    Timer {
        id: delay
        interval: 500
        onTriggered: tip.want = true
    }

    Rectangle {
        anchors.fill: parent
        color: Pal.bg
        border.width: 1
        border.color: Pal.borderSurface
    }

    Text {
        x: 8
        y: 9
        text: label.text
        textFormat: Text.StyledText
        color: Pal.bg
        font: label.font
        renderType: Text.NativeRendering
    }

    Text {
        id: label
        x: 8
        y: 8
        text: tip.text
        textFormat: Text.StyledText
        color: Pal.fg
        renderType: Text.NativeRendering
        font.family: "JetBrainsMono Nerd Font"
        font.bold: true
        font.pointSize: 11.1 * 0.75
        font.hintingPreference: Font.PreferVerticalHinting
    }
}
