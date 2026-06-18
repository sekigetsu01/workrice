import QtQuick
import Quickshell.Io

QtObject {
    id: button

    required property string command
    required property string text
    property var keybind: null

    property var launcher: null

    readonly property var process: Process {
        command: ["sh", "-c", button.command]
    }

    function exec() {
        process.running = true
        if (launcher)
            launcher.active = false
    }
}
