import QtQuick
import Quickshell
import Quickshell.Io

// A panel that's only built the first time it's opened, then just shown and hidden. ipc: the name its key calls
// (qs ipc call NAME toggle). Each panel in shell.qml is one.
LazyLoader {
    id: root

    property string ipc: ""

    signal opening
    signal loaded

    function toggle() {
        opening();
        if (item)
            item.toggle();
        else
            loading = true;
    }

    onItemChanged: {
        if (item) {
            item.toggle();
            loaded();
        }
    }

    property IpcHandler handler: IpcHandler {
        target: root.ipc
        enabled: root.ipc !== ""
        function toggle(): void {
            root.toggle();
        }
    }
}
