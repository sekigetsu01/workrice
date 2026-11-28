import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../launcher"
import "when.js" as When

// Your next 6 events (up to 60 days ahead), top right of the first screen while the calendar is open (CalendarDesk).
PanelWindow {
    id: root

    property LauncherThemeBase theme: LauncherThemeBase {}
    property var rows: []
    property bool again: false
    readonly property var todayD: When.fromIso(CalStore.today)

    anchors.top: true
    anchors.right: true
    margins.top: 10
    margins.right: 10
    exclusionMode: ExclusionMode.Normal
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "calendar-widget"
    implicitWidth: 300
    implicitHeight: box.height
    color: "transparent"

    function refresh() {
        if (proc.running) {
            again = true;
            return;
        }
        proc.command = CalStore.cmd(["range", CalStore.today, When.iso(When.addDays(todayD, 60))]);
        proc.running = true;
    }

    function build(events) {
        const n = new Date(), now = When.iso(n) + "T" + When.pad(n.getHours()) + ":" + When.pad(n.getMinutes()), out = [];
        let last = "";
        for (const ev of events) {
            if (out.length >= 6)
                break;
            if (ev.routine || (ev.allday ? ev.e <= CalStore.today : ev.e <= now && ev.e !== ev.s || ev.s < now && ev.e === ev.s))
                continue;
            const day = ev.s.slice(0, 10) < CalStore.today ? CalStore.today : ev.s.slice(0, 10);
            out.push({ head: day !== last ? When.heading(When.fromIso(day), todayD) : "", ev: ev, day: day });
            last = day;
        }
        rows = out;
    }

    Component.onCompleted: refresh()

    Connections {
        target: CalStore
        function onRevChanged() {
            root.refresh();
        }
        function onTodayChanged() {
            root.refresh();
        }
        function onTick() {
            root.refresh();
        }
    }

    Process {
        id: proc
        stdout: StdioCollector {
            id: out
        }
        onExited: code => {
            if (root.again) {
                root.again = false;
                root.refresh();
                return;
            }
            try {
                if (code === 0)
                    root.build(JSON.parse(out.text).events);
            } catch (e) {}
        }
    }

    Rectangle {
        id: box
        width: root.width
        height: col.height + 28
        color: root.theme.clrBg
        radius: 4
        border.color: root.theme.clrBorder
        border.width: 1

        Column {
            id: col
            x: 14
            y: 14
            width: parent.width - 28
            spacing: 0

            Text {
                text: "Upcoming Schedule"
                color: root.theme.clrTextPrim
                font.pixelSize: 13
                font.bold: true
                font.family: "monospace"
                bottomPadding: 8
            }

            Rectangle {
                width: parent.width
                height: 1
                color: root.theme.clrDivider
            }

            Text {
                visible: root.rows.length === 0
                topPadding: 8
                text: "Nothing coming up"
                color: root.theme.clrTextMuted
                font.pixelSize: 11
                font.family: "monospace"
            }

            Repeater {
                model: root.rows
                AgendaRow {
                    theme: root.theme
                    today: root.todayD
                }
            }
        }
    }
}
