import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Services.Notifications
import "../"

// Pop-ups, top right: up to three at once, newest on top, each on screen 1.5 s
// (then they're only in the notification center), with a line along the bottom counting down.
// Each card is as tall as its text, at most a title line and two lines of text; longer text ends in '…'
// (the notification center has all of it).
// Left-click closes one, middle-click opens the notification center, right-click closes them all.
// Reminders (remind) stay until handled: a click marks one done, Snooze 5 min / Snooze… put it off.
PanelWindow {
    id: root

    property var centerRef: null
    signal openCenter
    property var _pendingNotifs: []
    readonly property int maxShown: 3
    property int overflow: 0     // pushed out of the stack since it was last empty; they're in the center
    property int _uid: 0
    property int _quietN: 0
    // the pointer on the cards: every card stops counting down and stays where it is; new ones wait until it leaves
    readonly property bool held: stackHover.hovered && toasts.count > 0 && root.visible
    property var _waiting: []
    onHeldChanged: {
        if (!held && _waiting.length) {
            const w = _waiting;
            _waiting = [];
            w.forEach(c => _show(c));
        }
    }

    // holding pop-ups back while the screen is being recorded (they'd be in the video); not for a recording started to
    // show them (record-screen -s, Super+Ctrl+F1)
    PersistentProperties {
        id: rec
        reloadableId: "recording"
        property int recorderPid: 0
        property int heldCount: 0
        property string heldWhy: ""
        property bool showing: false
    }
    readonly property bool recording: rec.recorderPid > 0
    readonly property bool hiding: recording && !rec.showing
    function setRecorder(pid, show) {
        // in this order, so hiding doesn't flick on for a moment as a pop-up recording starts or ends (that closes
        // the cards on screen)
        if (pid > 0) {
            rec.showing = !!show;
            rec.recorderPid = pid;
        } else {
            rec.recorderPid = 0;
            rec.showing = false;
        }
    }
    onHidingChanged: {
        if (hiding) {
            // ones waiting for the pointer to leave the cards are held back too (closing the cards would show them);
            // a waiting reminder comes up again once the recording ends
            const w = _waiting;
            _waiting = w.filter(c => c.app === "Screen Recorder");
            w.forEach(c => {
                if (c.reminder)
                    delete _remShown[c.remKey];
                else if (c.app !== "Screen Recorder")
                    _hold("recording");
            });
            for (let i = toasts.count - 1; i >= 0; i--)
                if (toasts.get(i).app !== "Screen Recorder")
                    _close(i, true);
        } else {
            if (rec.heldCount > 0)
                _showHeldCount();
            _checkReminders();
        }
    }

    Process {
        id: recWatch
        property int pid: 0
        property int startedFor: 0
        command: ["sh", "-c", 'grep -qa record-screen "/proc/$1/cmdline" 2>/dev/null && exec tail --pid="$1" -f /dev/null', "sh", String(pid)]
        onStarted: startedFor = pid
        onExited: {
            if (rec.recorderPid === startedFor)
                root.setRecorder(0);
        }
    }
    function _watchRecorder() {
        recWatch.running = false;
        if (rec.recorderPid > 0) {
            recWatch.pid = rec.recorderPid;
            recWatch.running = true;
        }
    }
    Connections {
        target: rec
        function onRecorderPidChanged() { root._watchRecorder(); }
    }
    Component.onCompleted: _watchRecorder()

    function _hold(why) {
        rec.heldCount++;
        rec.heldWhy = rec.heldWhy === "" || rec.heldWhy === why ? why : "busy";
    }

    function _showHeldCount() {
        const n = rec.heldCount;
        const why = { recording: "recording" }[rec.heldWhy] || "busy";
        rec.heldCount = 0;
        rec.heldWhy = "";
        _show({ app: "Notifications", summary: n + (n === 1 ? " notification" : " notifications") + " came in while you were " + why,
                body: "They're in the notification center", urgency: 1, ms: 1500 });
    }

    readonly property string remindCmd: Quickshell.env("HOME") + "/.local/bin/remind"
    property var reminders: []
    property var _remShown: ({})
    // the reminders already in the notification center (one coming back after a recording isn't added again)
    property var _remCentered: ({})
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/reminders.json"
        watchChanges: true
        // not there until the first reminder: no error for that (the watch still sees it appear)
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.reminders = JSON.parse(text()).reminders || [];
            } catch (e) {
                return;
            }
            root._checkReminders();
        }
        onLoadFailed: root.reminders = []
    }
    Timer {
        interval: 1000
        repeat: true
        running: root.reminders.length > 0
        onTriggered: root._checkReminders()
    }
    function _checkReminders() {
        if (hiding)
            return;
        const now = Date.now() / 1000;
        let onScreen = 0;
        for (let i = 0; i < toasts.count; i++)
            if (toasts.get(i).reminder !== "")
                onScreen++;
        for (const r of reminders) {
            const key = r.id + ":" + r.due;
            // no more reminders than fit: the rest come up as these are handled (pushed out, they'd be lost)
            if (onScreen >= maxShown)
                break;
            if (r.due <= now && !_remShown[key]) {
                onScreen++;
                _remShown[key] = true;
                const d = new Date(r.due * 1000);
                const at = Qt.formatTime(d, d.getSeconds() ? "hh:mm:ss" : "hh:mm");
                const info = { desktopEntry: "", notif: null, open: "none", window: "" };
                if (!_remCentered[key]) {
                    _remCentered[key] = true;
                    if (centerRef !== null)
                        centerRef.addNotification("Reminder", r.text, at, "", "", info);
                    else
                        _pendingNotifs.push({ appName: "Reminder", summary: r.text, body: at, icon: "", tag: "", info: info });
                }
                _show({ app: "Reminder", summary: r.text, body: at, urgency: 2, ms: 0, reminder: r.id, remKey: key });
            }
        }
    }
    function _remind(args) {
        Quickshell.execDetached([remindCmd].concat(args));
    }
    function snooze(i, edit) {
        const t = toasts.get(i);
        _remind(edit ? ["edit", "--again", t.reminder] : ["snooze", t.reminder, "300"]);
        _close(i, true);
    }
    function dismissTop() {
        for (let i = 0; i < toasts.count; i++)
            if (toasts.get(i).reminder !== "")
                return _close(i);
        _close(0);
    }

    property var rules: ({})
    FileView {
        path: Qt.resolvedUrl("rules.json").toString().replace(/^file:\/\//, "")
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.rules = JSON.parse(text());
            } catch (e) {
                console.warn("notifications/rules.json:", e);
                root.rules = {};
            }
        }
        onLoadFailed: root.rules = {}
    }
    function _rule(app) {
        const r = rules[app];
        return r && typeof r === "object" ? r : {};
    }

    onCenterRefChanged: {
        if (centerRef !== null) {
            for (const n of _pendingNotifs)
                centerRef.addNotification(n.appName, n.summary, n.body, n.icon, n.tag, n.info);
            _pendingNotifs = [];
        }
    }

    // quietTag: set for quiet notifications (hint x-quiet): they only go to the notification center.
    // A newer one with the same sync tag (x-canonical-private-synchronous) replaces the older one there,
    // and changes the pop-up on screen in place; quiet ones without one are each kept.
    // extra: { urgency 0 low / 1 normal / 2 critical, expire ms the app asked for, value 0-100 progress }
    function incoming(appName, summary, body, icon, quietTag, syncTag, extra) {
        appName = appName && appName !== "notify-send" ? appName : "System";
        summary = summary || "";
        body = body || "";
        icon = icon || "";
        extra = extra || {};
        quietTag = quietTag || "";
        const rule = _rule(appName);
        const tag = quietTag || syncTag || "";
        const info = { desktopEntry: extra.desktopEntry || "", notif: extra.notif || null,
                       open: rule.open === false ? "none" : typeof rule.open === "string" ? rule.open : "",
                       window: typeof rule.window === "string" ? rule.window : "" };
        if (centerRef !== null)
            centerRef.addNotification(appName, summary, body, icon, tag, info);
        else
            _pendingNotifs.push({ appName: appName, summary: summary, body: body, icon: icon, tag: tag, info: info });
        if (quietTag !== "" || rule.quiet === true)
            return false;
        const urgency = extra.urgency ?? 1;
        if (hiding && appName !== "Screen Recorder") {
            _hold("recording");
            return false;
        }
        return _show({ app: appName, summary: summary, body: body, icon: icon, urgency: urgency,
                       tag: syncTag || "", value: extra.value ?? -1,
                       ms: 1500 });   // every one, whatever the app asks for; critical ones too (the center keeps them)
    }

    // a new card, or the one on screen changed in place: the same sync tag, or the very same text again soon after (×2, ×3…)
    function _show(t) {
        const now = Date.now();
        const card = {
            app: t.app, summary: t.summary || "", body: t.body || "", icon: t.icon || "",
            urgency: t.urgency ?? 1, tag: t.tag || "", value: t.value ?? -1, ms: t.ms ?? 1500,
            reminder: t.reminder || "", remKey: t.remKey || ""
        };
        for (let i = 0; i < toasts.count; i++) {
            const o = toasts.get(i);
            const same = o.app === card.app && o.summary === card.summary && o.body === card.body;
            if ((card.tag !== "" && o.tag === card.tag) || (same && now - o.born < 10000)) {
                card.count = same ? o.count + 1 : 1;
                card.born = now;
                card.uid = o.uid;
                toasts.set(i, card);
                if (i !== 0 && !held)   // held: changed where it is, nothing moves
                    toasts.move(i, 0, 1);
                return o.uid;
            }
        }
        if (held) {   // shown when the pointer leaves the cards
            t.uid = t.uid || ++_uid;
            _waiting = _waiting.concat([t]);
            return t.uid;
        }
        card.count = 1;
        card.born = now;
        card.uid = t.uid || ++_uid;
        toasts.insert(0, card);
        while (toasts.count > maxShown) {
            let j = toasts.count - 1;
            while (j > 0 && toasts.get(j).reminder !== "")
                j--;
            // every older card a reminder: the new one gives way (it's in the center), unless it's a reminder too,
            // and then the oldest goes but comes up again once there's room
            if (j === 0 && toasts.get(0).reminder !== "") {
                j = toasts.count - 1;
                delete _remShown[toasts.get(j).remKey];
            }
            _close(j, true);
            overflow++;
        }
        return card.uid;
    }

    function _close(i, keep) {
        if (i < 0 || i >= toasts.count)
            return;
        const t = toasts.get(i);
        if (t.reminder !== "") {
            if (!keep)
                _remind(["done", t.reminder]);
            else if (hiding)
                delete _remShown[t.remKey];
        }
        toasts.remove(i);
    }
    // right-click: every pop-up but the reminders (those stay until clicked, snoozed or Alt+BackSpace)
    function _closeAll() {
        for (let i = toasts.count - 1; i >= 0; i--)
            if (toasts.get(i).reminder === "")
                _close(i);
        overflow = 0;
    }

    NotificationServer {
        actionsSupported: true
        keepOnReload: false
        onNotification: function (notif) {
            const h = notif.hints || {};
            const quiet = h["x-quiet"] === true || h["x-quiet"] === 1;
            const sync = h["x-canonical-private-synchronous"] ?? "";
            // quiet and normal ones with the same sync tag share one key, so they replace each other in the center;
            // a quiet one without gets a key of its own (two in a row are both kept)
            const tag = quiet ? (sync !== "" ? "s:" + notif.appName + ":" + sync : "q:" + notif.appName + ":" + Date.now() + ":" + (++root._quietN)) : "";
            const v = Number(h["value"]);
            const live = Array.prototype.some.call(notif.actions, a => a.identifier === "default");
            notif.tracked = live;
            root.incoming(notif.appName, notif.summary, notif.body, notif.appIcon ?? "", tag, sync !== "" ? "s:" + notif.appName + ":" + sync : "", {
                urgency: notif.urgency === NotificationUrgency.Critical ? 2 : notif.urgency === NotificationUrgency.Low ? 0 : 1,
                expire: notif.expireTimeout > 0 ? Math.round(notif.expireTimeout) : 0,   // ms (the docs say seconds, but it's the raw D-Bus ms)
                value: h["value"] !== undefined && !isNaN(v) ? Math.max(0, Math.min(100, v)) : -1,
                desktopEntry: notif.desktopEntry ?? "",
                notif: live ? notif : null,
            });
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.anchors {
        top: true
        right: true
    }

    // one fixed size (three cards and the chip fit): mango doesn't repaint what a shrinking overlay gives up,
    // so a window that shrank as cards left would leave their last picture on screen
    implicitWidth: 440
    implicitHeight: Math.min(660, (screen ? screen.height : 1080) - 40)
    color: "transparent"
    visible: false
    mask: Region {
        item: stack
        Region {
            item: chip
        }
    }

    ListModel {
        id: toasts
        onCountChanged: {
            if (count > 0) {
                linger.stop();
                root.visible = true;
            } else {
                root.overflow = 0;
                linger.restart();
            }
        }
    }
    Timer {
        id: linger   // the last card's fade-out finishes before the window goes
        interval: 350
        onTriggered: {
            if (toasts.count === 0)
                root.visible = false;
        }
    }

    ListView {
        id: stack
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 20
            rightMargin: 15
        }
        width: 400
        height: contentHeight
        interactive: false
        spacing: 8
        model: toasts

        add: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "x"; from: 24; to: 0; duration: 300; easing.type: Easing.OutExpo }
            }
        }
        remove: Transition {
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: 250; easing.type: Easing.InCubic }
                NumberAnimation { property: "x"; to: 24; duration: 250; easing.type: Easing.InCubic }
            }
        }
        // a card pushed down while it was still sliding in finishes arriving (else it can stay half see-through)
        displaced: Transition {
            ParallelAnimation {
                NumberAnimation { properties: "y"; duration: 220; easing.type: Easing.OutCubic }
                NumberAnimation { property: "opacity"; to: 1; duration: 220 }
                NumberAnimation { property: "x"; to: 0; duration: 220; easing.type: Easing.OutCubic }
            }
        }
        move: displaced

        HoverHandler {
            id: stackHover
        }

        delegate: Rectangle {
            id: card
            readonly property int cardIndex: model.index
            width: ListView.view.width
            height: body.implicitHeight + 30
            radius: 12
            color: model.urgency === 2 ? Pal.notifCritBg : Pal.notifToastBg
            border.width: model.urgency === 2 ? 1.5 : 1
            border.color: model.urgency === 2 ? Pal.notifCrit : model.urgency === 0 ? Pal.borderNotifLow : Pal.borderNotifInner
            clip: true

            // time left, 1 → 0, by the clock (an animation would stall whenever the window stops redrawing);
            // the pointer on the cards pauses it (on leaving, it carries on, with a second at least), and a change
            // to the card starts it again
            property real remaining: 1
            property double deadline: Date.now() + model.ms
            property double paused: model.ms   // what was left when it paused
            readonly property double born: model.born
            readonly property bool held: root.held
            onBornChanged: {
                card.deadline = Date.now() + model.ms;
                card.paused = model.ms;
                card.remaining = 1;
                life.running = model.ms > 0 && !root.held;
            }
            onHeldChanged: {
                if (held) {
                    card.paused = Math.max(0, card.deadline - Date.now());
                    life.running = false;
                } else {
                    card.deadline = Date.now() + Math.max(card.paused, 1000);
                    life.running = model.ms > 0;
                }
            }
            Timer {
                id: life
                interval: 50
                repeat: true
                running: model.ms > 0 && !root.held
                onTriggered: {
                    const left = card.deadline - Date.now();
                    card.remaining = Math.max(0, Math.min(1, left / Math.max(1, model.ms)));
                    if (left <= 0) {
                        running = false;
                        root._close(model.index);
                    }
                }
            }

            Rectangle {   // urgency: none for low, a bar for normal, a thicker one for critical
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                    topMargin: 12
                    bottomMargin: 12
                }
                width: model.urgency === 2 ? 4 : 3
                radius: 2
                color: model.urgency === 2 ? Pal.notifCrit : Pal.notifAccent
                visible: model.urgency > 0
            }

            ColumnLayout {
                id: body
                z: 1   // above the card's click area, so the copy button gets its clicks
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 12
                    leftMargin: 18
                    rightMargin: 14
                }
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    Text {
                        text: model.app.toUpperCase()
                        font.pixelSize: 12
                        color: Pal.fgNotifMeta
                        textFormat: Text.PlainText
                    }
                    Text {
                        text: "×" + model.count
                        font.pixelSize: 12
                        font.weight: Font.Bold
                        color: Pal.notifAccent
                        visible: model.count > 1
                    }
                    Item { Layout.fillWidth: true }
                }

                Text {
                    Layout.fillWidth: true
                    text: model.summary !== "" ? model.summary : model.body
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                    color: Pal.fgNotifTitle
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: model.summary !== "" && model.body !== "" ? 1 : 3
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    visible: model.summary !== "" && model.body !== ""
                    text: model.body
                    font.pixelSize: 14
                    color: Pal.notifBody
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    maximumLineCount: model.value >= 0 ? 1 : 2
                    elide: Text.ElideRight
                }

                Rectangle {   // progress (the 'value' hint, 0-100)
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    implicitHeight: 4
                    radius: 2
                    color: Pal.notifTrack
                    visible: model.value >= 0
                    Rectangle {
                        width: parent.width * Math.max(0, Math.min(100, model.value)) / 100
                        height: parent.height
                        radius: 2
                        color: Pal.notifAccent
                        Behavior on width {
                            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 8
                    visible: model.reminder !== ""
                    Repeater {
                        model: [{ label: "Snooze 5 min", edit: false }, { label: "Snooze…", edit: true }]
                        Rectangle {
                            required property var modelData
                            implicitWidth: btnText.implicitWidth + 24
                            implicitHeight: 26
                            radius: 8
                            color: btnMouse.containsMouse ? Pal.notifHovBg : "transparent"
                            border.width: 1
                            border.color: Pal.borderNotifInner
                            Text {
                                id: btnText
                                anchors.centerIn: parent
                                text: parent.modelData.label
                                font.pixelSize: 12
                                color: Pal.fgNotifTitle
                            }
                            MouseArea {
                                id: btnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.snooze(card.cardIndex, parent.modelData.edit)
                            }
                        }
                    }
                    Item { Layout.fillWidth: true }
                }
            }

            Rectangle {   // the countdown, kept inside the rounded corners
                anchors {
                    left: parent.left
                    bottom: parent.bottom
                    leftMargin: card.radius
                    bottomMargin: 1
                }
                height: 2
                radius: 1
                width: (parent.width - 2 * card.radius) * card.remaining
                color: Pal.notifAccent
                opacity: hover.containsMouse ? 0.9 : 0.55
                visible: model.ms > 0
            }

            MouseArea {
                id: hover
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                cursorShape: Qt.PointingHandCursor
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton) {
                        root._closeAll();
                    } else {
                        if (mouse.button === Qt.MiddleButton)
                            root.openCenter();
                        root._close(model.index);
                    }
                }
            }
        }
    }

    Rectangle {   // more than fit: they're in the notification center
        id: chip
        anchors {
            top: stack.bottom
            right: stack.right
            topMargin: 8
        }
        visible: root.overflow > 0 && toasts.count > 0
        width: visible ? chipText.implicitWidth + 24 : 0   // the click mask follows its size, seen or not
        height: 26
        radius: 13
        color: chipMouse.containsMouse ? Pal.notifHovBg : Pal.notifToastBg
        border.color: Pal.borderNotifInner
        border.width: 1
        Text {
            id: chipText
            anchors.centerIn: parent
            text: "+" + root.overflow + " more in the notification center"
            font.pixelSize: 11
            color: Pal.fgNotifMeta
        }
        MouseArea {
            id: chipMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                root.openCenter();
                root._closeAll();
            }
        }
    }
}
