import QtQuick
import "../launcher"
import "when.js" as When

// The form for adding or changing a calendar event: title, date, start, end, repeat, reminder and a note. Dates and
// times can be typed loosely (tomorrow, next fri, in 3 days, 5 dec, 14:30).
Item {
    id: form

    property LauncherThemeBase theme
    property var today: new Date()
    property var ev: null
    property int cur: 0
    property string noteOrig: ""
    property string noteShown: ""
    property var repeatOpts: []
    property int repeatIdx: 0
    property var alarmOpts: []
    property int alarmIdx: 0
    property bool repeatTouched: false
    property bool alarmTouched: false
    property bool alarmsAllday: true
    property bool filling: false
    property string error: ""

    signal save(var data)
    signal cancel
    signal dayPicked(string day)

    readonly property var dateD: When.parseDate(dateField.text, today)
    readonly property var startT: When.parseTime(startField.text)
    readonly property bool allday: startT === ""
    readonly property var endT: allday ? "" : When.parseEnd(endField.text, startT)
    readonly property var fields: [titleField, dateField, startField, endField, repeatBox, alarmBox, noteField]
    readonly property var timedAlarms: [
        { v: null, t: "None" }, { v: 0, t: "At start" }, { v: 5, t: "5 min before" }, { v: 10, t: "10 min before" },
        { v: 30, t: "30 min before" }, { v: 60, t: "1 hour before" }, { v: 1440, t: "1 day before" }]
    readonly property var dayAlarms: [{ v: null, t: "None" }, { v: -540, t: "On the day, 09:00" }, { v: 900, t: "Day before, 09:00" }]

    onDateDChanged: if (dateD && visible && !filling) dayPicked(When.iso(dateD))
    onStartTChanged: {
        if (filling || startT === null || alarmsAllday === (startT === ""))
            return;
        alarmTouched = true;
        setAlarms(null, startT === "" ? -540 : 10);
    }

    function fmtDate(d) {
        return When.shortDate(d) + " " + d.getFullYear();
    }

    function nth(n) {
        return n + (n % 10 === 1 && n !== 11 ? "st" : n % 10 === 2 && n !== 12 ? "nd" : n % 10 === 3 && n !== 13 ? "rd" : "th");
    }

    function repeatText(o) {
        const d = dateD;
        if (!d || o.v === "none" || o.v === "keep" || o.v === "daily")
            return o.t;
        if (o.v === "weekly")
            return "Weekly, " + When.DAYS[When.wd(d)] + "s";
        if (o.v === "monthly")
            return "Monthly, on the " + nth(d.getDate());
        return "Yearly, on " + d.getDate() + " " + When.MONTHS[d.getMonth()];
    }

    function setAlarms(keep, want) {
        alarmsAllday = startT === "";
        const opts = (alarmsAllday ? dayAlarms : timedAlarms).slice();
        let i = opts.findIndex(o => o.v === want);
        if (keep !== null) {
            i = opts.findIndex(o => o.v === keep);
            if (i < 0) {
                opts.unshift({ v: "keep", t: "As before" });
                i = 0;
            }
        }
        alarmOpts = opts;
        alarmIdx = Math.max(0, i);
    }

    function openNew(day) {
        filling = true;
        ev = null;
        error = "";
        titleField.text = "";
        dateField.text = fmtDate(When.fromIso(day));
        startField.text = "";
        endField.text = "";
        noteField.text = "";
        noteOrig = noteShown = "";
        repeatOpts = [{ v: "none", t: "Never" }, { v: "daily", t: "Daily" }, { v: "weekly", t: "Weekly" }, { v: "monthly", t: "Monthly" }, { v: "yearly", t: "Yearly" }];
        repeatIdx = 0;
        repeatTouched = alarmTouched = false;
        setAlarms(null, -540);
        filling = false;
        focusField(0);
    }

    function openEdit(e) {
        openNew(e.rid || e.rep === "none" ? e.s.slice(0, 10) : e.d0);
        filling = true;
        ev = e;
        titleField.text = e.title;
        startField.text = e.allday ? "" : e.rid ? e.s.slice(11) : e.t0;
        endField.text = e.allday ? "" : e.rid ? e.e.slice(11) : e.t1;
        noteOrig = e.note;
        noteShown = noteField.text = e.note.split("\n").join(" ↵ ");
        if (e.rid)
            repeatOpts = [{ v: "keep", t: "Just this one of a series" }];
        else if (e.rep === "custom")
            repeatOpts = [{ v: "keep", t: "As before (" + (e.rule || "custom") + ")" }].concat(repeatOpts);
        repeatIdx = Math.max(0, repeatOpts.findIndex(o => o.v === e.rep || o.v === "keep"));
        setAlarms(typeof e.alarm === "number" || e.alarm === null ? e.alarm : "other", null);
        filling = false;
        focusField(0);
    }

    function focusField(i) {
        cur = i;
        fields[i].forceActiveFocus();
    }

    function step(d) {
        let i = cur;
        do
            i = (i + d + fields.length) % fields.length;
        while (i === 3 && allday);
        focusField(i);
    }

    function cycle(i, d) {
        if (i === 4) {
            repeatIdx = (repeatIdx + d + repeatOpts.length) % repeatOpts.length;
            repeatTouched = true;
        } else {
            alarmIdx = (alarmIdx + d + alarmOpts.length) % alarmOpts.length;
            alarmTouched = true;
        }
    }

    function submit() {
        error = titleField.text.trim() === "" ? "Give it a title" : !dateD ? "Can't read the date" : startT === null ? "Can't read the start time" : endT === null ? "Can't read the end time" : "";
        if (error !== "") {
            focusField(titleField.text.trim() === "" ? 0 : !dateD ? 1 : startT === null ? 2 : 3);
            return;
        }
        const r = repeatOpts[repeatIdx].v, a = alarmOpts[alarmIdx].v;
        save({
            uid: ev ? ev.uid : "",
            rid: ev ? ev.rid : "",
            title: titleField.text.trim(),
            date: When.iso(dateD),
            start: startT,
            end: endT,
            repeat: ev && !repeatTouched ? "keep" : r,
            alarm: ev && !alarmTouched || a === "keep" ? "keep" : a,
            note: noteField.text === noteShown ? noteOrig : noteField.text.split(" ↵ ").join("\n")
        });
    }

    function key(e, i) {
        const k = e.key, choice = i === 4 || i === 5;
        if (k === Qt.Key_Escape)
            cancel();
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            submit();
        else if (k === Qt.Key_Tab || k === Qt.Key_Down)
            step(1);
        else if (k === Qt.Key_Backtab || k === Qt.Key_Up)
            step(-1);
        else if (choice && (k === Qt.Key_Left || k === Qt.Key_H))
            cycle(i, -1);
        else if (choice && (k === Qt.Key_Right || k === Qt.Key_L || k === Qt.Key_Space))
            cycle(i, 1);
        else
            return;
        e.accepted = true;
    }

    component Field: Item {
        id: f
        property string label
        property int idx
        property string hint
        property bool bad: false
        property bool dim: false
        default property alias content: box.data
        width: parent.width
        height: 30

        Text {
            width: 74
            height: parent.height
            verticalAlignment: Text.AlignVCenter
            text: f.label
            color: form.cur === f.idx ? form.theme.clrSearchFocus : form.theme.clrTextMuted
            font.pixelSize: 11
            font.family: "monospace"
        }

        Rectangle {
            id: box
            x: 74
            width: parent.width - 74
            height: 26
            anchors.verticalCenter: parent.verticalCenter
            radius: 4
            color: "transparent"
            opacity: f.dim ? 0.45 : 1
            border.width: 1
            border.color: form.cur === f.idx ? form.theme.clrSearchFocus : form.theme.clrBorder

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: f.hint
                color: f.bad ? form.theme.clrCalcError : form.theme.clrTextMuted
                font.pixelSize: 10
                font.family: "monospace"
            }

            MouseArea {
                anchors.fill: parent
                onClicked: form.focusField(f.idx)
            }
        }
    }

    component Input: TextInput {
        property int idx
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        verticalAlignment: TextInput.AlignVCenter
        color: form.theme.clrInputText
        selectionColor: form.theme.clrSelRow
        font.pixelSize: 12
        font.family: "monospace"
        clip: true
        selectByMouse: true
        onActiveFocusChanged: if (activeFocus) form.cur = idx
        Keys.onPressed: e => form.key(e, idx)
    }

    component Choice: Item {
        id: c
        property int idx
        property string value
        anchors.fill: parent
        onActiveFocusChanged: if (activeFocus) form.cur = idx
        Keys.onPressed: e => form.key(e, idx)

        Text {
            x: 8
            anchors.verticalCenter: parent.verticalCenter
            text: "‹ " + c.value + " ›"
            color: form.theme.clrInputText
            font.pixelSize: 12
            font.family: "monospace"
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => {
                form.focusField(c.idx);
                form.cycle(c.idx, m.button === Qt.RightButton ? -1 : 1);
            }
        }
    }

    Column {
        width: parent.width
        spacing: 4

        Text {
            height: 30
            text: !form.ev ? "New event" : form.ev.rid ? "Edit event · this one" : form.ev.rep !== "none" ? "Edit event · all repeats" : "Edit event"
            color: form.theme.clrTextPrim
            font.pixelSize: 15
            font.bold: true
            font.family: "monospace"
        }

        Field {
            label: "Title"
            idx: 0
            Input {
                id: titleField
                idx: 0
            }
        }

        Field {
            label: "Date"
            idx: 1
            hint: form.dateD ? When.longDate(form.dateD, form.today) : "?"
            bad: !form.dateD
            Input {
                id: dateField
                idx: 1
                anchors.rightMargin: 200
            }
        }

        Field {
            label: "Start"
            idx: 2
            hint: form.startT === null ? "?" : form.startT === "" ? "all day" : form.startT
            bad: form.startT === null
            Input {
                id: startField
                idx: 2
                anchors.rightMargin: 80
            }
        }

        Field {
            label: "End"
            idx: 3
            dim: form.allday
            hint: form.allday ? "" : form.endT === null ? "?" : form.endT === "" ? "+1 hour" : form.endT <= form.startT ? form.endT + " next day" : form.endT
            bad: !form.allday && form.endT === null
            Input {
                id: endField
                idx: 3
                anchors.rightMargin: 80
            }
        }

        Field {
            label: "Repeat"
            idx: 4
            Choice {
                id: repeatBox
                idx: 4
                value: form.repeatText(form.repeatOpts[form.repeatIdx] || { v: "none", t: "" })
            }
        }

        Field {
            label: "Remind"
            idx: 5
            Choice {
                id: alarmBox
                idx: 5
                value: (form.alarmOpts[form.alarmIdx] || { t: "" }).t
            }
        }

        Field {
            label: "Note"
            idx: 6
            Input {
                id: noteField
                idx: 6
            }
        }

        Text {
            height: 24
            verticalAlignment: Text.AlignVCenter
            text: form.error
            color: form.theme.clrCalcError
            font.pixelSize: 11
            font.family: "monospace"
        }
    }
}
