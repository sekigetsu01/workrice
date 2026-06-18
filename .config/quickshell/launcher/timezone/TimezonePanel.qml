import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"

PanelWindow {
    id: root

    Theme { id: theme }

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay

    anchors.top: false; anchors.bottom: false
    anchors.left: false; anchors.right: false

    implicitWidth:  theme.panelW + theme.outerPad * 2
    implicitHeight: theme.panelH + theme.outerPad * 2

    margins.left: (screen.width  - implicitWidth)  / 2
    margins.top:  (screen.height - implicitHeight) / 2

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
        picker.activate();
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
        ScriptAction { script: { root.visible = false; } }
    }

        property var favs: ({})

    Process {
        id: saveProc
        command: ["sh", "-c", "true"]
        onExited: {
            if (root._pendingSave) { root._pendingSave = false; root._doSave(); }
        }
    }
    property bool _pendingSave: false
    function _doSave() {
        var escaped = JSON.stringify({ timezoneFavs: root.favs }).replace(/'/g, "'\\''");
        saveProc.command = ["sh", "-c",
            "mkdir -p ~/.cache && " +
            "existing=$(cat ~/.cache/quickshell-launcher.json 2>/dev/null || echo '{}') && " +
            "updated=$(printf '%s' \"$existing\" | python3 -c \"" +
                "import sys, json; d=json.load(sys.stdin); " +
                "d['timezoneFavs']=json.loads(sys.argv[1])['timezoneFavs']; print(json.dumps(d))\" '" + escaped + "') && " +
            "printf '%s' \"$updated\" > ~/.cache/quickshell-launcher.json"
        ];
        saveProc.running = true;
    }
    Timer {
        id: saveDebounce; interval: 300; repeat: false
        onTriggered: {
            if (saveProc.running) root._pendingSave = true;
            else root._doSave();
        }
    }
    Process {
        id: loadProc
        running: true
        command: ["sh", "-c", "mkdir -p ~/.cache && cat ~/.cache/quickshell-launcher.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "") return;
                try { root.favs = JSON.parse(line).timezoneFavs || {}; }
                catch(e) { root.favs = {}; }
            }
        }
    }

    function toggleFav(zone, display) {
        var key = display || zone;
        var f = root.favs;
        if (f[key]) delete f[key]; else f[key] = true;
        root.favs = f;
        saveDebounce.restart();
        picker.isFav(zone, display); 
        picker._rebuildModel();
    }

        Rectangle {
        id: panel
        x: theme.outerPad; y: theme.outerPad
        width: theme.panelW; height: theme.panelH
        color: theme.clrBg
        radius: 4
        border.color: theme.clrBorder; border.width: 1
        clip: true
        opacity: root.panelOpacity
        scale: root.panelScale
        transformOrigin: Item.Center
        focus: true

        Keys.onPressed: function(ev) {
            if (ev.key === Qt.Key_Escape) {
                root.hide(); ev.accepted = true; return;
            }
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                picker.applySelected(); ev.accepted = true; return;
            }
            picker.handleKey(ev);
        }

        TimezonePicker {
            id: picker
            anchors.fill: parent
            favs: root.favs
            panelRef: panel
            panelVisible: root.visible
            onToggleFav: function(zone, display) { root.toggleFav(zone, display); }
            onRequestClose: root.hide()
        }
    }

    MouseArea {
        anchors.fill: parent; z: -1
        onClicked: root.hide()
    }
}
