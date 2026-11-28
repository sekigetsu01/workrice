import QtQuick
import Quickshell
import Quickshell.Io
import "../"
import "../launcher"
import "when.js" as When
// The calendar (SUPER+C): the month, the chosen day's events and its to-dos (Tab switches between them). h/l a day,
// j/k a week or the list, H/L a month, t today; a or Enter adds an event, e edits, d deletes, x crosses a to-do out;
// z the day's journal, c routines; Esc closes.

LauncherPanel {
    id: root

    theme: LauncherThemeBase {
        id: theme
        panelW: 1000
        searchBarH: 540 - (dividerH + maxVisibleRows * rowHeight + bottomPad)
    }

    readonly property int paneH: 500
    readonly property var todayD: When.fromIso(CalStore.today)
    property string sel: CalStore.today
    readonly property var selD: When.fromIso(sel)
    property int vy: todayD.getFullYear()
    property int vm: todayD.getMonth()
    readonly property var monthCells: When.cells(vy, vm)
    property var events: []
    readonly property var todoData: CalStore.todo
    readonly property var todoItems: sel === CalStore.today ? todoData.now : []
    property var routineTodos: ({})
    property var routineDone: []
    readonly property var todoAll: todoItems.map(x => ({ t: x[1], line: x[0], done: !!x[2], r: false })).concat((routineTodos[sel] || []).map(t => ({ t: t, r: true, done: sel === CalStore.today && routineDone.indexOf(t) >= 0 })))
    readonly property var todoShown: todoAll.filter(x => !x.done).concat(todoAll.filter(x => x.done))
    property string from: ""
    property string to: ""
    readonly property var map: When.byDay(events, from, to)
    readonly property var rows: buildRows()
    property string pane: "grid"
    property string mode: ""
    property int agendaIdx: 0
    property int todoIdx: 0
    readonly property string journalDir: Quickshell.env("HOME") + "/sync/notes/vimwiki/journal"
    property var journaled: ({})
    property string message: ""
    property bool again: false
    property bool resume: false
    property var queue: []
    readonly property color cellBg: Pal.over(Pal.color8, 0.3)
    readonly property color cellSel: Pal.over(Pal.accent, 0.45)
    readonly property bool idle: mode === ""

    onOpened: {
        if (!resume) {
            mode = "";
            pane = "grid";
            message = "";
            from = to = "";
            select(CalStore.today);
        } else {
            load();
        }
        resume = false;
        CalStore.todoRefresh();
        journalProc.running = true;
        CalStore.fetch();
        focusTimer.restart();
    }

    onKey: e => handleKey(e)

    function buildRows() {
        const out = [];
        for (let i = 0; i <= 14; i++) {
            const d = When.addDays(selD, i), k = When.iso(d), list = map[k] || [], head = When.heading(d, todayD);
            if (list.length === 0 && i === 0)
                out.push({ head: head, ev: null, day: k });
            list.forEach((ev, j) => out.push({ head: j === 0 ? head : "", ev: ev, day: k }));
        }
        return out;
    }

    function load() {
        if (rangeProc.running) {
            again = true;
            return;
        }
        const a = monthCells[0].iso, b = monthCells[41].iso, s2 = When.iso(When.addDays(selD, 14));
        rangeProc.want = [sel < a ? sel : a, s2 > b ? s2 : b];
        rangeProc.command = CalStore.cmd(["range"].concat(rangeProc.want));
        rangeProc.running = true;
    }

    function ensure() {
        const s2 = When.iso(When.addDays(selD, 14));
        if (from === "" || sel < from || s2 > to || monthCells[0].iso < from || monthCells[41].iso > to)
            load();
    }

    function firstRow() {
        return rows.length > 1 && !rows[0].ev ? 1 : 0;
    }

    function select(day) {
        sel = day;
        const d = selD;
        if (d.getFullYear() !== vy || d.getMonth() !== vm) {
            vy = d.getFullYear();
            vm = d.getMonth();
        }
        agendaIdx = firstRow();
        agendaList.positionViewAtBeginning();
        ensure();
    }

    function moveDay(n) {
        select(When.iso(When.addDays(selD, n)));
    }

    function moveMonth(n) {
        const t = new Date(selD.getFullYear(), selD.getMonth() + n, 1);
        const last = new Date(t.getFullYear(), t.getMonth() + 1, 0).getDate();
        select(When.iso(new Date(t.getFullYear(), t.getMonth(), Math.min(selD.getDate(), last))));
    }

    function moveAgenda(d) {
        for (let i = agendaIdx + d; i >= 0 && i < rows.length; i += d)
            if (rows[i].ev) {
                agendaIdx = i;
                agendaList.positionViewAtIndex(i, ListView.Contain);
                return;
            }
    }

    function moveTodo(d) {
        todoIdx = Math.max(0, Math.min(todoShown.length - 1, todoIdx + d));
        todoList.positionViewAtIndex(todoIdx, ListView.Contain);
    }

    onTodoShownChanged: todoIdx = Math.max(0, Math.min(todoIdx, todoShown.length - 1))

    function deleteTodo() {
        const it = todoShown[todoIdx];
        if (!it)
            return;
        if (it.r) {
            message = "Routines are read-only here";
            return;
        }
        CalStore.todoDelete(it.line, it.t);
    }

    function crossTodo() {
        const it = todoShown[todoIdx];
        if (!it)
            return;
        if (!it.r)
            write(["todo-done", String(it.line), it.t], {}, null);
        else if (sel !== CalStore.today)
            message = "Only today's routines can be crossed out";
        else
            write(["routine-done", it.t], {}, null);
    }

    function openRoutines() {
        openTodos(false);
    }

    function openJournal(day) {
        if (day > CalStore.today)
            return;
        hide();
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "${1%/*}" && if [ -s "$1" ]; then exec kitty nvim "+normal G" "$1"; else exec kitty nvim +startinsert "$1"; fi', "sh", journalDir + "/" + day.slice(0, 4) + "/" + day + ".md"]);
    }

    function openTodos(add) {
        hide();
        Quickshell.execDetached(CalStore.cmd(["todo-edit"].concat(add ? ["--add"] : [])));
    }

    function cyclePane(d) {
        const p = ["grid", "todo", "agenda"];
        pane = p[(p.indexOf(pane) + d + 3) % 3];
        if (pane === "agenda" && !(rows[agendaIdx] && rows[agendaIdx].ev))
            agendaIdx = firstRow();
    }

    function current() {
        const r = rows[agendaIdx];
        return r && r.ev ? r.ev : null;
    }

    readonly property bool parked: tagHome.parked

    function setAside() {
        tagHome.parked = false;
        if (visible && !closing)
            hide();
    }

    function idleAgain() {
        mode = "";
        focusPanel();
    }

    function newEvent() {
        mode = "form";
        form.openNew(sel);
    }

    function writable(ev) {
        if (ev && ev.ro)
            message = ev.routine ? "Routines are read-only here" : ev.plan ? "Edit the Agenda with c" : "Feed events are read-only";
        return !!ev && !ev.ro;
    }

    function editEvent(ev) {
        if (!writable(ev))
            return;
        mode = "form";
        form.openEdit(ev);
    }

    function deleteEvent(ev, all) {
        if (!writable(ev))
            return;
        const one = !all && (ev.rep !== "none" || !!ev.rid);
        write(["delete"], one ? { uid: ev.uid, rid: ev.rid, only: ev.rid || ev.occ } : { uid: ev.uid });
    }

    function write(args, input, ok) {
        queue.push({ args: args, input: JSON.stringify(input), ok: ok });
        runWrite();
    }

    function runWrite() {
        if (writeProc.running || queue.length === 0)
            return;
        const job = queue.shift();
        writeProc.job = job;
        writeProc.command = CalStore.cmd(job.args);
        writeProc.stdinEnabled = true;
        writeProc.running = true;
    }

    function handleKey(e) {
        const k = e.key, t = e.text;
        e.accepted = true;
        if (mode !== "") {
            if (k === Qt.Key_Escape)
                idleAgain();
            return;
        }
        message = "";
        const ret = k === Qt.Key_Return || k === Qt.Key_Enter;
        if (k === Qt.Key_Escape)
            hideOnRelease();
        else if (k === Qt.Key_Tab)
            cyclePane(1);
        else if (k === Qt.Key_Backtab)
            cyclePane(-1);
        else if (t === "t")
            select(CalStore.today);
        else if (t === "c")
            openRoutines();
        else if (t === "z" || (k === Qt.Key_J && (e.modifiers & Qt.ControlModifier)))
            openJournal(sel);
        else if (t === "H" || t === "[" || k === Qt.Key_PageUp)
            moveMonth(-1);
        else if (t === "L" || t === "]" || k === Qt.Key_PageDown)
            moveMonth(1);
        else if (pane === "todo") {
            if (t === "j" || k === Qt.Key_Down)
                moveTodo(1);
            else if (t === "k" || k === Qt.Key_Up)
                moveTodo(-1);
            else if (t === "a" || t === "o")
                openTodos(true);
            else if (ret || t === "e")
                openTodos(false);
            else if (t === "d")
                deleteTodo();
            else if (t === "x")
                crossTodo();
            else if (t === "h" || k === Qt.Key_Left)
                moveDay(-1);
            else if (t === "l" || k === Qt.Key_Right)
                moveDay(1);
            else
                e.accepted = false;
        } else if (t === "h" || k === Qt.Key_Left)
            moveDay(-1);
        else if (t === "l" || k === Qt.Key_Right)
            moveDay(1);
        else if (ret || t === "a")
            newEvent();
        else if (pane === "grid") {
            if (t === "k" || k === Qt.Key_Up)
                moveDay(-7);
            else if (t === "j" || k === Qt.Key_Down)
                moveDay(7);
            else
                e.accepted = false;
        } else if (t === "j" || k === Qt.Key_Down)
            moveAgenda(1);
        else if (t === "k" || k === Qt.Key_Up)
            moveAgenda(-1);
        else if (t === "e")
            editEvent(current());
        else if (t === "d" || t === "D")
            deleteEvent(current(), t === "D");
        else
            e.accepted = false;
    }

    Connections {
        target: CalStore
        function onRevChanged() {
            if (root.visible)
                root.load();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: root.visible && root.idle
        onActivated: root.hideOnRelease()
    }

    Timer {
        id: focusTimer
        interval: 30
        // back from another tag mid-edit: the field you were in, not the panel (which ignores keys in the form)
        onTriggered: root.mode === "form" ? form.focusField(form.cur) : root.focusPanel()
    }

    TagHome {
        id: tagHome
        panel: root
        onBack: {
            root.resume = true;
            root.open();
        }
    }

    Process {
        id: journalProc
        command: ["find", root.journalDir, "-mindepth", "2", "-maxdepth", "2", "-path", "*/????/????-??-??.md", "-size", "+0c", "-printf", "%f\\n"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = {};
                text.split("\n").forEach(f => {
                    if (f !== "")
                        m[f.slice(0, 10)] = true;
                });
                root.journaled = m;
            }
        }
    }

    Process {
        id: rangeProc
        property var want: []
        stdout: StdioCollector {
            id: rangeOut
        }
        onExited: code => {
            if (root.again) {
                root.again = false;
                root.load();
                return;
            }
            let r = null;
            try {
                r = JSON.parse(rangeOut.text);
            } catch (e) {}
            if (code !== 0 || !r) {
                root.message = "Couldn't read the calendar";
                return;
            }
            root.from = rangeProc.want[0];
            root.to = rangeProc.want[1];
            root.events = r.events;
            root.routineTodos = r.routineTodos;
            root.routineDone = r.routineDone || [];
            if (!root.rows[root.agendaIdx] || !root.rows[root.agendaIdx].ev)
                root.agendaIdx = root.firstRow();
            if (r.errors.length && root.message === "")
                root.message = "Feed: " + r.errors[0];
            if (r.routineErrors.length && root.message === "")
                root.message = r.routineErrors[0];
        }
    }

    Process {
        id: writeProc
        property var job: null
        stdout: StdioCollector {
            id: writeOut
        }
        stderr: StdioCollector {
            id: writeErr
        }
        onStarted: {
            writeProc.write(writeProc.job.input);
            writeProc.stdinEnabled = false;
        }
        onExited: code => {
            if (code === 0) {
                if (writeProc.job.ok) {
                    let r = {};
                    try {
                        r = JSON.parse(writeOut.text);
                    } catch (e) {}
                    writeProc.job.ok(r);
                }
                CalStore.changed();
            } else {
                root.message = writeErr.text.trim() || "Couldn't save";
            }
            root.runWrite();
        }
    }

    Item {
        id: gridPane
        x: 22
        y: 20
        width: 374
        height: root.paneH

        Item {
            width: parent.width
            height: 34

            Row {
                anchors.centerIn: parent
                spacing: 14

                Text {
                    text: "◂"
                    color: Pal.accent
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: root.moveMonth(-1)
                    }
                }

                Text {
                    text: When.monthTitle(root.vy, root.vm)
                    color: theme.clrTextPrim
                    font.pixelSize: 15
                    font.bold: true
                    font.family: "monospace"
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "▸"
                    color: Pal.accent
                    font.pixelSize: 15
                    anchors.verticalCenter: parent.verticalCenter
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        onClicked: root.moveMonth(1)
                    }
                }
            }
        }

        Row {
            y: 40
            spacing: 4
            Repeater {
                model: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
                Text {
                    required property string modelData
                    width: 50
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: theme.clrTextSecond
                    font.pixelSize: 10
                    font.bold: true
                    font.family: "monospace"
                }
            }
        }

        Grid {
            y: 62
            columns: 7
            spacing: 4

            Repeater {
                model: root.monthCells

                Rectangle {
                    id: cell
                    required property var modelData
                    readonly property bool isSel: modelData.iso === root.sel
                    readonly property bool isToday: modelData.iso === CalStore.today
                    readonly property var evs: root.map[modelData.iso]
                    readonly property bool hasEvs: !!evs && evs.some(x => !x.routine)
                    readonly property bool hasJournal: !!root.journaled[modelData.iso]
                    width: 50
                    height: 50
                    radius: 4
                    color: isSel ? (root.pane === "grid" || !root.idle ? root.cellSel : theme.clrSelRow) : modelData.inMonth ? root.cellBg : "transparent"
                    border.width: isToday ? 2 : 0
                    border.color: Pal.accentWarm

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -2
                        text: cell.modelData.day
                        color: cell.modelData.inMonth || cell.isSel ? theme.clrTextPrim : theme.clrTextMuted
                        font.pixelSize: 14
                        font.bold: cell.isToday || cell.isSel
                        font.family: "monospace"
                    }

                    Rectangle {
                        visible: cell.hasEvs
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: cell.hasJournal ? -4 : 0
                        y: parent.height - 9
                        width: 4
                        height: 4
                        radius: 2
                        color: cell.evs && cell.evs.some(x => !x.ro) ? Pal.accentWarm : Pal.accentAlt
                    }

                    Rectangle {
                        visible: cell.hasJournal
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: cell.hasEvs ? 4 : 0
                        y: parent.height - 9
                        width: 4
                        height: 4
                        radius: 2
                        color: Pal.accent
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: m => {
                            if (!root.idle)
                                return;
                            if (m.button === Qt.RightButton) {
                                root.openJournal(cell.modelData.iso);
                                return;
                            }
                            root.pane = "grid";
                            root.select(cell.modelData.iso);
                        }
                        onDoubleClicked: m => {
                            if (root.idle && m.button === Qt.LeftButton)
                                root.newEvent();
                        }
                    }
                }
            }
        }

        Text {
            y: 398
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: When.longDate(root.selD, null)
            color: theme.clrTextSecond
            font.pixelSize: 11
            font.family: "monospace"
        }

        Text {
            y: 420
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            visible: root.message !== ""
            text: root.message
            wrapMode: Text.WordWrap
            maximumLineCount: 2
            elide: Text.ElideRight
            color: Pal.negative
            font.pixelSize: 10
            font.family: "monospace"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: w => {
                if (root.idle)
                    root.moveMonth(w.angleDelta.y > 0 ? -1 : 1);
            }
        }
    }

    Rectangle {
        x: gridPane.x + gridPane.width + 22
        y: 20
        width: 1
        height: root.paneH
        color: theme.clrDivider
    }

    Item {
        id: sidePane
        x: gridPane.x + gridPane.width + 45
        y: 20
        width: theme.panelW - x - 22
        height: root.paneH

        EventForm {
            id: form
            anchors.fill: parent
            visible: root.mode === "form"
            theme: root.theme
            today: root.todayD
            onCancel: root.idleAgain()
            onDayPicked: day => root.select(day)
            onSave: d => root.write([d.uid ? "edit" : "add"], d, () => root.idleAgain())
        }

        Item {
            anchors.fill: parent
            visible: root.mode !== "form"

            Text {
                height: 30
                verticalAlignment: Text.AlignVCenter
                text: "To-do"
                color: root.pane === "todo" ? Pal.accent : theme.clrTextPrim
                font.pixelSize: 15
                font.bold: true
                font.family: "monospace"
            }

            ListView {
                id: todoList
                y: 30
                width: parent.width
                height: Math.max(1, Math.min(root.todoShown.length, 12)) * 26
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.todoShown

                Text {
                    visible: root.todoShown.length === 0
                    y: 6
                    text: "Nothing to do"
                    color: theme.clrTextMuted
                    font.pixelSize: 11
                    font.family: "monospace"
                }

                delegate: Item {
                    id: trow
                    required property var modelData
                    required property int index
                    readonly property bool isSel: root.pane === "todo" && root.idle && index === root.todoIdx
                    width: ListView.view.width
                    height: 26

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 1
                        anchors.bottomMargin: 1
                        radius: 4
                        bottomLeftRadius: trow.isSel ? 0 : 4
                        bottomRightRadius: trow.isSel ? 0 : 4
                        color: trow.isSel ? theme.clrSelRow : "transparent"

                        Rectangle {
                            visible: trow.isSel
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: theme.clrSearchFocus
                        }
                    }

                    Text {
                        id: box
                        x: 6
                        width: 26
                        anchors.verticalCenter: parent.verticalCenter
                        text: (trow.index + 1) + "."
                        color: trow.modelData.done ? theme.clrTextMuted : trow.modelData.r ? Pal.positive : Pal.accent
                        font.pixelSize: 12
                        font.family: "monospace"
                    }

                    Text {
                        anchors.left: box.right
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: trow.modelData.t
                        elide: Text.ElideRight
                        color: trow.modelData.done ? theme.clrTextMuted : theme.clrTextPrim
                        font.strikeout: trow.modelData.done
                        font.pixelSize: 12
                        font.family: "monospace"
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (!root.idle)
                                return;
                            root.pane = "todo";
                            root.todoIdx = trow.index;
                        }
                        onDoubleClicked: if (root.idle) trow.modelData.r ? root.openRoutines() : root.openTodos(false)
                    }
                }
            }

            Item {
                id: agendaHead
                y: todoList.y + todoList.height + 10
                width: parent.width
                height: 24

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Agenda"
                    color: root.pane === "agenda" ? Pal.accent : theme.clrTextPrim
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "monospace"
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: rangeProc.running ? "…" : ""
                    color: theme.clrTextMuted
                    font.pixelSize: 11
                    font.family: "monospace"
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: theme.clrDivider
                }
            }

            ListView {
                id: agendaList
                y: agendaHead.y + 28
                width: parent.width
                height: root.paneH - y
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: root.rows
                delegate: AgendaRow {
                    theme: root.theme
                    today: root.todayD
                    selected: root.pane === "agenda" && root.idle && index === root.agendaIdx
                    onClicked: {
                        if (!root.idle)
                            return;
                        root.pane = "agenda";
                        if (ev)
                            root.agendaIdx = index;
                    }
                    onDoubleClicked: if (root.idle) root.editEvent(ev)
                }
            }

        }
    }
}
