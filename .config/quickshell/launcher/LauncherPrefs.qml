pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// What the launcher panels remember (how often and how lately each app was opened, and the starred apps, emoji,
// time zones and wifi networks), kept in ~/.cache/quickshell-launcher.json
Singleton {
    id: root

    property var data: ({})
    property bool ready: false

    function save(keys) {
        data = Object.assign({}, data, keys);
        debounce.restart();
    }

    Timer {
        id: debounce
        interval: 300
        onTriggered: file.setText(JSON.stringify(root.data))
    }

    FileView {
        id: file
        path: Quickshell.env("HOME") + "/.cache/quickshell-launcher.json"
        onLoaded: {
            let d = null;
            try {
                d = JSON.parse(text());
            } catch (e) {}
            if (d && typeof d === "object" && !Array.isArray(d))
                root.data = Object.assign(d, root.data);
            root.ready = true;
        }
        onLoadFailed: root.ready = true
    }
}
