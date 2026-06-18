import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Io

Scope {
    id: root
    signal unlocked

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool showSuccess: false
    property bool _internalChange: false

    property var now: new Date()
    property int secondsLocked: 0
    property bool running: false

    Timer {
        running: root.running
        repeat: true
        interval: 1000
        onTriggered: {
            root.now = new Date();
            root.secondsLocked++;
        }
    }

    function formatLocked(secs) {
        const h = Math.floor(secs / 3600);
        const m = Math.floor((secs % 3600) / 60);
        const s = secs % 60;
        if (h > 0)
            return `Locked for ${h}h ${m}m`;
        if (m > 0)
            return `Locked for ${m}m ${String(s).padStart(2, '0')}s`;
        return `Locked for ${s}s`;
    }

    readonly property string _sinkMuteCmd:
        "pactl list short sinks | awk '{print $1}' | xargs -I{} pactl set-sink-mute {} "

    Process {
        id: muteProc
        command: ["sh", "-c", root._sinkMuteCmd + "1"]
        running: false
    }

    Process {
        id: unmuteProc
        command: ["sh", "-c", root._sinkMuteCmd + "0"]
        running: false
    }

    function lock() {
        if (unlockInProgress)
            return;
        secondsLocked = 0
        showSuccess = false
        showFailure = false

        if (!muteProc.running)
            muteProc.running = true
        root.running = true
    }

    onCurrentTextChanged: {
        if (!_internalChange)
            showFailure = false;
    }

    function tryUnlock() {
        if (currentText === "" || unlockInProgress)
            return;
        root.unlockInProgress = true;
        pam.start();
    }

    PamContext {
        id: pam
        configDirectory: Quickshell.env("HOME") + "/.config/quickshell/lockscreen/pam"
        config: "password.conf"

        onPamMessage: {
            if (this.responseRequired)
                this.respond(root.currentText);
        }

        onCompleted: result => {
            if (result === PamResult.Success) {
                root.unlockInProgress = false;
                root.showFailure = false;
                root.showSuccess = true;
                root.running = false;
                if (!unmuteProc.running)
                    unmuteProc.running = true;
                successTimer.start();
            } else {
                root._internalChange = true;
                root.currentText = "";
                root._internalChange = false;
                root.showFailure = true;
                root.unlockInProgress = false;
            }
        }
    }

    Timer {
        id: successTimer
        interval: 600
        onTriggered: root.unlocked()
    }
}
