import QtQuick
import Quickshell
import Quickshell.Io

// keeps a panel on the tag it was opened on
Scope {
    id: root

    required property var panel
    property var tags: []
    property int home: 0
    property bool parked: false

    signal back

    Connections {
        target: root.panel
        function onOpened() {
            root.parked = false;
            root.home = root.tags.length === 1 ? root.tags[0] : 0;
        }
    }

    onTagsChanged: {
        const here = tags.length === 1 && tags[0] === home;
        if (panel.visible && !panel.closing && !home && tags.length === 1) {
            home = tags[0];
        } else if (panel.visible && !panel.closing && home && !here) {
            parked = true;
            panel.hide();
        } else if (parked && here) {
            parked = false;
            back();
        }
    }

    Socket {
        id: mango
        path: Quickshell.env("MANGO_INSTANCE_SIGNATURE") || ""
        connected: path !== ""
        onConnectedChanged: {
            if (connected) {
                write("watch all-monitors\n");
                flush();
            } else if (path !== "") {
                reconnect.start();
            }
        }
        parser: SplitParser {
            onRead: line => {
                let o;
                try {
                    o = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (!o || !Array.isArray(o.monitors))
                    return;
                const name = root.panel.screen ? root.panel.screen.name : "";
                const m = o.monitors.find(m => m.name === name) || o.monitors.find(m => m.active);
                if (m && Array.isArray(m.active_tags) && m.active_tags.join() !== root.tags.join())
                    root.tags = m.active_tags;
            }
        }
    }

    Timer {
        id: reconnect
        interval: 2000
        onTriggered: mango.connected = true
    }
}
