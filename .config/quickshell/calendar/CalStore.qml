pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "when.js" as When

// The calendar's shared state, behind every calendar panel: today (turning over at midnight), your events and to-dos
// through the cal helper, feeds fetched every 30 minutes, and alarms as notifications (checked again after sleep).
Singleton {
    id: root

    readonly property string helper: Qt.resolvedUrl("cal").toString().replace("file://", "")
    property int rev: 0
    property string today: When.iso(new Date())
    property real alarmAfter: Math.floor(Date.now() / 1000)
    property bool alarmAgain: false
    property var todo: ({ now: [], days: {} })
    property bool todoAgain: false

    signal tick

    function cmd(args) {
        return ["python3", "-S", helper].concat(args);
    }

    function changed() {
        rev++;
        checkAlarms();
    }

    function fetch() {
        if (!fetchProc.running)
            fetchProc.running = true;
    }

    function checkAlarms() {
        if (alarmProc.running) {
            alarmAgain = true;
            return;
        }
        alarmProc.command = cmd(["next-alarm", String(alarmAfter)]);
        alarmProc.running = true;
    }

    function notify(it) {
        Quickshell.execDetached(["notify-send", "--app-name=" + (it.app || "Calendar"), "--", it.title].concat(it.body ? [it.body] : []));
    }

    function todoRefresh() {
        if (todoProc.running)
            todoAgain = true;
        else
            todoProc.running = true;
    }

    function todoDelete(line, task) {
        Quickshell.execDetached(cmd(["todo-delete", String(line), task]));
    }

    function newDay() {
        todoRefresh();
        const n = new Date();
        today = When.iso(n);
        midnight.interval = new Date(n.getFullYear(), n.getMonth(), n.getDate() + 1).getTime() - n.getTime() + 1000;
        midnight.restart();
    }

    function resumed() {
        newDay();
        checkAlarms();
        fetch();
        tick();
    }

    Component.onCompleted: resumed()

    Timer {
        id: midnight
        onTriggered: {
            root.newDay();
            root.tick();
        }
    }

    Timer {
        interval: 30 * 60000
        running: true
        repeat: true
        onTriggered: {
            root.newDay();
            root.fetch();
            root.tick();
        }
    }

    Timer {
        id: alarmTimer
        onTriggered: root.checkAlarms()
    }

    Process {
        id: alarmProc
        stdout: StdioCollector {
            id: alarmOut
        }
        onExited: code => {
            let r = null;
            try {
                r = JSON.parse(alarmOut.text);
            } catch (e) {}
            const now = Date.now() / 1000;
            if (root.alarmAgain) {
                root.alarmAgain = false;
                root.checkAlarms();
                return;
            }
            if (code !== 0 || !r || !r.at) {
                alarmTimer.interval = 30 * 60000;
                alarmTimer.restart();
                return;
            }
            if (r.at <= now + 1) {
                if (r.at >= now - 3600)
                    r.items.forEach(root.notify);
                root.alarmAfter = Math.max(r.at, Math.floor(now) - 3600);
                root.checkAlarms();
                return;
            }
            alarmTimer.interval = Math.min((r.at - now) * 1000, 30 * 60000);
            alarmTimer.restart();
        }
    }

    Process {
        id: fetchProc
        command: root.cmd(["fetch"])
        stdout: StdioCollector {
            id: fetchOut
        }
        onExited: {
            try {
                if (JSON.parse(fetchOut.text).changed)
                    root.changed();
            } catch (e) {}
        }
    }

    Process {
        id: sleepWatch
        running: true
        command: ["gdbus", "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                if (line.indexOf("PrepareForSleep") !== -1 && line.indexOf("false") !== -1)
                    root.resumed();
            }
        }
        onExited: sleepRestart.start()
    }
    Timer {
        id: sleepRestart
        interval: 30000
        onTriggered: sleepWatch.running = true
    }

    FileView {
        path: Quickshell.env("HOME") + "/sync/calendar/routines.md"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            routinesProc.running = true;
            root.changed();
        }
    }
    Process {
        id: routinesProc
        command: root.cmd(["routines"])
    }

    FileView {
        id: todoFile
        path: Quickshell.env("HOME") + "/sync/calendar/routines.md"
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.todoRefresh();
        }
    }
    Process {
        id: todoProc
        command: root.cmd(["todo"])
        stdout: StdioCollector {
            id: todoOut
        }
        onExited: code => {
            if (root.todoAgain) {
                root.todoAgain = false;
                running = true;
                return;
            }
            try {
                const r = JSON.parse(todoOut.text);
                root.todo = { now: r.now || [], days: r.days || {} };
            } catch (e) {}
        }
    }
}
