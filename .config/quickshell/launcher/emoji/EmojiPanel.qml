import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"

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
        emojiPicker.activate();
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

    property var emojisFavs: ({})
    property bool _prefsLoaded: false

    Process {
        id: saveProc
        command: ["sh", "-c", "true"]
        onExited: {
            if (_pendingSave) {
                _pendingSave = false;
                _doSave();
            }
        }
    }
    property bool _pendingSave: false
    function _doSave() {
        var escaped = JSON.stringify({ emojisFavs: root.emojisFavs }).replace(/'/g, "'\\''");
        saveProc.command = ["sh", "-c",
            "mkdir -p ~/.cache && " +
            "existing=$(cat ~/.cache/quickshell-launcher.json 2>/dev/null || echo '{}') && " +
            "updated=$(printf '%s' \"$existing\" | python3 -c \"" +
                "import sys, json; d=json.load(sys.stdin); " +
                "d['emojisFavs']=json.loads(sys.argv[1])['emojisFavs']; print(json.dumps(d))\" '" + escaped + "') && " +
            "printf '%s' \"$updated\" > ~/.cache/quickshell-launcher.json"
        ];
        saveProc.running = true;
    }
    Timer {
        id: saveDebounce
        interval: 300
        repeat: false
        onTriggered: {
            if (saveProc.running) {
                root._pendingSave = true;
            } else {
                root._doSave();
            }
        }
    }
    Process {
        id: loadProc
        running: true
        command: ["sh", "-c", "mkdir -p ~/.cache && cat ~/.cache/quickshell-launcher.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "") return;
                try {
                    var data = JSON.parse(line);
                    root.emojisFavs = data.emojisFavs || {};
                } catch(e) {
                    root.emojisFavs = {};
                }
                root._prefsLoaded = true;
            }
        }
    }

    function saveAll() { saveDebounce.restart(); }
    function toggleEmojiFav(emoji, desc) {
        var f = root.emojisFavs;
        if (f[emoji]) delete f[emoji]; else f[emoji] = desc;
        root.emojisFavs = f; saveAll(); emojiPicker.refresh();
    }

    Process {
        id: copyProc
        command: ["sh", "-c", "true"]
    }

    Process {
        id: notifyProc
        command: ["notify-send", ""]
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
                emojiPicker.pickSelected();
                ev.accepted = true;
                return;
            }
            emojiPicker.handleKey(ev);
        }

        EmojiPicker {
            id: emojiPicker
            anchors.fill: parent
            emojisFavs: root.emojisFavs
            panelRef: panel
            onPicked: function(emoji) {
                var safe = emoji.replace(/'/g, "'\\''");
                copyProc.command = ["sh", "-c", "printf '%s' '" + safe + "' | wl-copy"];
                copyProc.running = true;
                notifyProc.command = ["notify-send", emoji + " Copied to clipboard!"];
                notifyProc.running = true;
                root.hide();
            }
            onToggleFav:    function(emoji, desc) { root.toggleEmojiFav(emoji, desc); }
            onRequestClose: root.hide()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.hide()
    }
}
