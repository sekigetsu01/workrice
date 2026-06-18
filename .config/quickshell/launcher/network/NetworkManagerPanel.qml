import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../../"

PanelWindow {
    id: root

    Theme { id: theme }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    anchors.top:    false
    anchors.bottom: false
    anchors.left:   false
    anchors.right:  false

    implicitWidth:  theme.panelW + theme.outerPad * 2
    implicitHeight: panelH       + theme.outerPad * 2

            readonly property int infoStripH: netManager.activeConnName !== "" ? 34 : 0
    readonly property int listH:    theme.searchBarH + 1 + infoStripH + (infoStripH > 0 ? 1 : 0) + theme.maxVisibleRows * theme.rowHeight
    readonly property int connectH: theme.searchBarH + 1 + 300
    readonly property int panelH:   netManager.view === "connect" ? connectH : listH

    margins.left: (screen.width  - implicitWidth)  / 2
    margins.top:  (screen.height - implicitHeight) / 2

    color:   "transparent"
    visible: false

    WlrLayershell.keyboardFocus: visible
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None

    property real panelOpacity: 0
    property real panelScale:   0.96

    function show() {
        panelOpacity = 0
        panelScale   = 0.96
        visible = true
        openAnim.restart()
        netManager.activate()
    }

    function hide() {
        panel.forceActiveFocus()
        closeAnim.restart()
    }

    function toggle() {
        if (visible) hide()
        else         show()
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation { target: root; property: "panelOpacity"; to: 1.0; duration: 120; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "panelScale";   to: 1.0; duration: 120; easing.type: Easing.OutCubic }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation { target: root; property: "panelOpacity"; to: 0.0; duration: 90; easing.type: Easing.InCubic }
            NumberAnimation { target: root; property: "panelScale";   to: 0.96; duration: 90; easing.type: Easing.InCubic }
        }
        ScriptAction { script: { root.visible = false } }
    }

    Rectangle {
        id: panel
        x: theme.outerPad
        y: theme.outerPad
        width:  theme.panelW
        height: root.panelH
        color:  theme.clrBg
        radius: 4
        border.color: theme.clrBorder
        border.width: 1
        clip:   true
        opacity: root.panelOpacity
        scale:   root.panelScale
        transformOrigin: Item.Center
        focus: true

        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

        Keys.onPressed: function(ev) {
            if (ev.key === Qt.Key_Escape) {
                if (netManager.view === "connect") {
                    netManager.view = "list"
                } else {
                    root.hide()
                }
                ev.accepted = true
            }
        }

        NetworkManager {
            id: netManager
            anchors.fill: parent
            panelRef: panel
            onRequestClose: root.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.hide()
    }
}
