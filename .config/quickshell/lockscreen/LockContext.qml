import QtQuick
import Quickshell
import Quickshell.Services.Pam
import Quickshell.Io

// The lock screen's workings: the password checked through PAM (pam/password.conf), media paused and sound muted
// while locked, a wallpaper from wallpapers/picker.sh, and the locked state kept if quickshell restarts.
Scope {
    id: root

    PersistentProperties {
        id: persist
        reloadableId: "lockContext"
        property bool locked: false
        property real since: 0
        property string look: ""
        onLockedChanged: {
            Quickshell.watchFiles = !locked;
            if (!locked) {
                changedProc.running = true;
                root._maybeReload();
            }
        }
    }
    readonly property bool locked: persist.locked
    readonly property var look: persist.look.split("|")

    property string currentText: ""
    property bool unlockInProgress: false
    property bool showFailure: false
    property bool showSuccess: false
    property bool _internalChange: false

    property var now: new Date()
    readonly property int secondsLocked: Math.max(0, Math.floor((now - persist.since) / 1000))

    Timer {
        running: persist.locked
        repeat: true
        interval: 1000
        onTriggered: root.now = new Date()
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

    Process {
        id: changedProc
        command: ["find", "-L", Quickshell.env("HOME") + "/.config/quickshell", "-newermt", "@" + Math.floor(persist.since / 1000),
            "(", "-name", "*.qml", "-o", "-name", "*.js", "-o", "-name", "qmldir", ")", "-print", "-quit"]
        stdout: SplitParser {
            onRead: {
                root._reloadPending = true;
                root._maybeReload();
            }
        }
    }
    property bool _reloadPending: false
    function _reloadOk() {
        return _reloadPending && !persist.locked && !audioProc.running && _queued === "";
    }
    function _maybeReload() {
        if (_reloadOk())
            Qt.callLater(() => {
                if (_reloadOk()) {
                    _reloadPending = false;
                    Quickshell.reload(false);
                }
            });
    }

    Process {
        id: lookProc
        command: ["sh", Quickshell.env("HOME") + "/.config/quickshell/lockscreen/wallpapers/picker.sh"]
        stdout: SplitParser {
            onRead: line => persist.look = line.trim()
        }
    }

    readonly property string _mutedFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-lock-muted"
    // exists while locked, so a new instance after a crash locks again (Lockscreen.qml)
    readonly property string lockedFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-locked"
    // a muted list left by a crashed lock is kept: the sinks are all muted by now
    readonly property var _audioScripts: ({
            lock: 'f="$1"; : > "$2"; ' +
                '[ -x "$HOME/.config/mango/scripts/pause-all" ] && "$HOME/.config/mango/scripts/pause-all" --pause lock; ' +
                'wl-copy --clear 2>/dev/null; ' +
                'new=1; [ -e "$f" ] && new=0; [ $new = 1 ] && : > "$f"; for s in $(pactl list short sinks | cut -f2); do ' +
                '[ $new = 1 ] && LC_ALL=C pactl get-sink-mute "$s" | grep -q yes && echo "$s" >> "$f"; pactl set-sink-mute "$s" 1; done',
            unlock: 'f="$1"; for s in $(pactl list short sinks | cut -f2); do ' +
                'grep -qxF "$s" "$f" 2>/dev/null || pactl set-sink-mute "$s" 0; done; rm -f "$f" "$2"; ' +
                '[ -x "$HOME/.config/mango/scripts/pause-all" ] && "$HOME/.config/mango/scripts/pause-all" --resume lock; true'
        })
    property string _queued: ""
    function _audio(step) {
        if (audioProc.running) {
            _queued = _queued === "" ? step : "";
            return;
        }
        audioProc.command = ["sh", "-c", _audioScripts[step], "sh", _mutedFile, lockedFile];
        audioProc.running = true;
    }
    Process {
        id: audioProc
        onExited: {
            const next = root._queued;
            root._queued = "";
            if (next !== "")
                root._audio(next);
            root._maybeReload();
        }
    }

    function _clearText() {
        _internalChange = true;
        currentText = "";
        _internalChange = false;
    }

    property bool _lockAgain: false
    function lock() {
        if (unlockInProgress)
            _lockAgain = true;
        if (persist.locked && !showSuccess)
            return;
        successTimer.stop();
        _clearText();
        showSuccess = false;
        showFailure = false;
        Date.timeZoneUpdated();
        now = new Date();
        if (!persist.locked) {
            persist.since = now.getTime();
            persist.look = "";
            lookProc.running = true;
        }
        persist.locked = true;
        Quickshell.execDetached(["sh", "-c", "pkill -x kp; pgrep -x keepassxc >/dev/null && keepassxc --lock >/dev/null 2>&1"]);
        _audio("lock");
    }

    function lockLost() {
        successTimer.stop();
        _clearText();
        showSuccess = false;
        showFailure = false;
        persist.locked = false;
        _audio("unlock");
        Quickshell.execDetached(["notify-send", "-a", "Lock screen", "--urgency=critical", "Lock screen", "The screen could not be locked"]);
    }

    onCurrentTextChanged: {
        if (!_internalChange)
            showFailure = false;
    }

    function tryUnlock() {
        if (currentText === "" || unlockInProgress)
            return;
        unlockInProgress = true;
        if (!pam.start()) {
            unlockInProgress = false;
            showFailure = true;
        }
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
            root._clearText();
            root.unlockInProgress = false;
            if (root._lockAgain) {
                root._lockAgain = false;
                root.showFailure = false;
            } else if (result === PamResult.Success) {
                root.showFailure = false;
                root.showSuccess = true;
                root._audio("unlock");
                successTimer.start();
            } else {
                root.showFailure = true;
            }
        }
    }

    Timer {
        id: successTimer
        interval: 600
        onTriggered: persist.locked = false
    }
}
