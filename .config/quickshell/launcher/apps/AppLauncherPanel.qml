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
        appLauncher.activate();
    }

    function hide() {
        panel.forceActiveFocus();
        closeAnim.restart();
    }

    function toggle() {
        if (visible)
            hide();
        else
            show();
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: root
            property: "panelOpacity"
            to: 1.0
            duration: 120
            easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root
            property: "panelScale"
            to: 1.0
            duration: 120
            easing.type: Easing.OutCubic
        }
    }
    SequentialAnimation {
        id: closeAnim
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "panelOpacity"
                to: 0.0
                duration: 90
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root
                property: "panelScale"
                to: 0.96
                duration: 90
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: {
                appLauncher.clearSearch();
                root.visible = false;
            }
        }
    }

    property var freq: ({})
    property var favs: ({})
    property bool _appsLoaded: false
    property bool _prefsLoaded: false

    property var _cachedEmojisFavs: ({})

    Process {
        id: saveProc
        command: ["sh", "-c", "true"]
        onExited: {
            if (root._pendingSave) {
                root._pendingSave = false;
                root._doSave();
            }
        }
    }
    property bool _pendingSave: false
    function _doSave() {
        var data = JSON.stringify({
            freq: root.freq,
            favs: root.favs,
            emojisFavs: root._cachedEmojisFavs
        });
        var escaped = data.replace(/'/g, "'\\''");
        saveProc.command = ["sh", "-c",
            "mkdir -p ~/.cache && " +
            "existing=$(cat ~/.cache/quickshell-launcher.json 2>/dev/null || echo '{}') && " +
            "updated=$(printf '%s' \"$existing\" | python3 -c \"" +
                "import sys, json; d=json.load(sys.stdin); " +
                "n=json.loads(sys.argv[1]); d['freq']=n['freq']; d['favs']=n['favs']; d['emojisFavs']=n['emojisFavs']; print(json.dumps(d))\" '" + escaped + "') && " +
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
            onRead: function (line) {
                if (line.trim() === "")
                    return;
                try {
                    var data = JSON.parse(line);
                    root.freq = data.freq || {};
                    root.favs = data.favs || {};
                    root._cachedEmojisFavs = data.emojisFavs || {};
                } catch (e) {
                    root.freq = {};
                    root.favs = {};
                    root._cachedEmojisFavs = {};
                }
                root._prefsLoaded = true;
                root._rebuildIfReady();
            }
        }
    }

    function saveAll() {
        saveDebounce.restart();
    }
    function freqBump(name) {
        var f = root.freq, e = f[name] || {
            count: 0,
            lastUsed: 0
        };
        e.count++;
        e.lastUsed = Date.now();
        f[name] = e;
        root.freq = f;
        saveAll();
    }
    function toggleFav(name) {
        var f = root.favs;
        if (f[name])
            delete f[name];
        else
            f[name] = true;
        root.favs = f;
        saveAll();
        appLauncher.rebuildFilter();
    }
    function _rebuildIfReady() {
        if (root._appsLoaded && root._prefsLoaded)
            appLauncher.rebuildFilter();
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

        Keys.onPressed: function (ev) {
            if (ev.key === Qt.Key_Escape) {
                if (appLauncher.searchQuery !== "") {
                    appLauncher.clearSearch();
                    panel.forceActiveFocus();
                } else {
                    root.hide();
                }
                ev.accepted = true;
                return;
            }
            if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                appLauncher.launchSelected();
                ev.accepted = true;
                return;
            }
            appLauncher.handleKey(ev, false);
        }

        AppLauncher {
            id: appLauncher
            anchors.fill: parent
            freq: root.freq
            favs: root.favs
            calcMode: false
            panelRef: panel
            onLaunched: root.hide()
            onToggleFav: function (name) {
                root.toggleFav(name);
            }
            onFreqBump: function (name) {
                root.freqBump(name);
            }
            onRequestClose: root.hide()
            onAppsLoaded: {
                root._appsLoaded = true;
                root._rebuildIfReady();
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1
        onClicked: root.hide()
    }
}
