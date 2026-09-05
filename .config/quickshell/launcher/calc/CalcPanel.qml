import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"
import "../apps"

PanelWindow {
    id: root

    Theme {
        id: theme
    }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    anchors.top: false
    anchors.bottom: false
    anchors.left: false
    anchors.right: false

    implicitWidth: theme.panelW + theme.outerPad * 2
    implicitHeight: theme.panelH + theme.outerPad * 2

    margins.left: (screen.width - implicitWidth) / 2
    margins.top: (screen.height - implicitHeight) / 2

    color: "transparent"
    visible: false

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    property real panelOpacity: 0
    property real panelScale: 0.96

    function show() {
        panelOpacity = 0;
        panelScale = 0.96;
        visible = true;
        openAnim.restart();
        appLauncher.activateCalc();
    }

    function hide() {
        panel.forceActiveFocus();
        closeAnim.restart();
    }

    function toggle() {
        if (visible) hide(); else show();
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
        ScriptAction {
            script: {
                root.visible = false;
            }
        }
    }

    Rectangle {
        id: panel
        x: theme.outerPad
        y: theme.outerPad
        width: theme.panelW
        height: theme.panelH
        color: theme.clrBg
        radius: 4
        border.color: theme.clrBorder
        border.width: 1
        clip: false
        opacity: root.panelOpacity
        scale: root.panelScale
        transformOrigin: Item.Center
        focus: true

        Keys.onPressed: function(ev) {
            if (ev.key === Qt.Key_Escape) {
                root.hide();
                ev.accepted = true;
                return;
            }
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                appLauncher.acceptCalcResult();
                ev.accepted = true;
                return;
            }
            appLauncher.handleKey(ev, true);
        }

        AppLauncher {
            id: appLauncher
            anchors.fill: parent
            freq: ({})
            favs: ({})
            calcMode: true
            panelRef: panel
            onLaunched:     root.hide()
            onToggleFav:    function(name) {}
            onFreqBump:     function(name) {}
            onRequestClose: root.hide()
            onAppsLoaded:   {}
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.hide()
    }
}
