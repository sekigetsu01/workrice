import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../"

// Every notification in full, newest first: j/k move, d deletes, Shift+d clears all, Esc closes.
// A click opens what it's about: the app's window (or starts the app), its own click action, or a panel (rules.json).
PanelWindow {
    id: root

    property bool panelOpen: false
    property int selectedIndex: 0

    signal openPanel(string name)

    ListModel {
        id: historyData
    }

    property var _live: ({})
    function _remove(i) {
        const n = _live[historyData.get(i).nid];
        if (n) {
            delete _live[historyData.get(i).nid];
            n.dismiss();
        }
        historyData.remove(i);
    }

    PersistentProperties {
        id: persist
        reloadableId: "notifHistory"
        property string history: "[]"
        onLoaded: {
            if (historyData.count > 0)
                return;
            try {
                for (const n of JSON.parse(history).slice(0, 200))
                    historyData.append({ appName: n.appName, summary: n.summary, body: n.body, quietTag: n.quietTag || "", time: n.time || 0,
                                         desktopEntry: n.desktopEntry || "", open: n.open || "", window: n.window || "", nid: 0 });
            } catch (e) {}
        }
    }
    function _save() {
        const all = [];
        for (let i = 0; i < historyData.count; i++) {
            const n = historyData.get(i);
            all.push({ appName: n.appName, summary: n.summary, body: n.body, quietTag: n.quietTag, time: n.time,
                       desktopEntry: n.desktopEntry, open: n.open, window: n.window });
        }
        persist.history = JSON.stringify(all);
        selectedIndex = Math.max(0, Math.min(selectedIndex, historyData.count - 1));
    }

    function toggle() {
        panelOpen = !panelOpen;
    }


    function addNotification(appName, summary, body, icon, quietTag, info) {
        quietTag = quietTag || "";
        info = info || {};
        if (quietTag !== "")
            for (let i = historyData.count - 1; i >= 0; i--)
                if (historyData.get(i).quietTag === quietTag)
                    _remove(i);
        const nid = info.notif ? info.notif.id : 0;
        if (info.notif) {
            const n = info.notif;
            _live[nid] = n;
            n.closed.connect(() => {
                if (root._live[nid] === n)
                    delete root._live[nid];
            });
        }
        historyData.insert(0, { appName: appName || "System", summary: summary || "", body: body || "", quietTag: quietTag, time: Date.now(),
                                desktopEntry: info.desktopEntry || "", open: info.open || "", window: info.window || "", nid: nid });
        while (historyData.count > 200)
            _remove(historyData.count - 1);
        _save();
    }

    Component.onCompleted: DesktopEntries.applications

    function _app(n) {
        const names = [n.desktopEntry, n.appName].filter(s => s && s !== "System").map(s => s.toLowerCase());
        let entry = null;
        for (const s of names) {
            const e = DesktopEntries.byId(s);
            if (e && !e.noDisplay) {
                entry = e;
                break;
            }
        }
        if (!entry)
            entry = Array.prototype.find.call(DesktopEntries.applications.values, e => !e.noDisplay && names.some(s => s === e.id.toLowerCase()
                || s === e.name.toLowerCase() || s === (e.startupClass || "").toLowerCase())) || null;
        const ids = entry ? [entry.id, entry.startupClass, n.window].concat(names).filter(s => s).map(s => s.toLowerCase()) : [];
        return { entry: entry, ids: ids };
    }

    function activate(i) {
        const n = historyData.get(i);
        if (n.open === "none")
            return false;
        if (n.open !== "") {
            openPanel(n.open);
            return true;
        }
        const live = _live[n.nid];
        const act = live ? Array.prototype.find.call(live.actions, a => a.identifier === "default") : null;
        const app = _app(n);
        const shown = app.ids.length > 0 && Array.prototype.some.call(ToplevelManager.toplevels.values, t => app.ids.includes((t.appId || "").toLowerCase()));
        const start = !shown && !act && app.entry !== null && !app.entry.runInTerminal;
        if (!act && !shown && !start)
            return false;
        if (shown)
            Quickshell.execDetached([Quickshell.env("HOME") + "/.config/mango/scripts/mm", "goto"].concat(app.ids));
        else if (start)
            app.entry.execute();
        if (act)
            act.invoke();
        return true;
    }

    function when(t) {
        if (!t)
            return "";
        const d = new Date(t);
        return Qt.formatDateTime(d, d.toDateString() === new Date().toDateString() ? "HH:mm" : "d MMM HH:mm");
    }

    function _clearAll() {
        for (let i = historyData.count - 1; i >= 0; i--)
            _remove(i);
        _save();
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.anchors {
        top: true
        right: true
    }
    WlrLayershell.margins.top: 20
    WlrLayershell.exclusiveZone: -1

    color: "transparent"
    implicitWidth: 420
    implicitHeight: Math.min(850, (screen ? screen.height : 1080) - 40)
    visible: false
    onPanelOpenChanged: {
        if (panelOpen) {
            closeDone.stop();
            selectedIndex = 0;
            notifList.positionViewAtBeginning();
            visible = true;
            notifList.forceActiveFocus();
        } else {
            closeDone.restart();
        }
    }
    Timer {
        id: closeDone
        interval: 280
        onTriggered: {
            if (!root.panelOpen)
                root.visible = false;
        }
    }

    Item {
        width: parent.width
        height: root.panelOpen ? parent.height : 0
        clip: true
        Behavior on height {
            NumberAnimation {
                duration: 240
                easing.type: Easing.OutExpo
            }
        }

        Rectangle {
            x: 12
            y: 12
            width: root.width - 18
            height: root.height - 24
            radius: 6
            color: Pal.bgOverlay
            border.color: Pal.borderNotifInner
            border.width: 1
            clip: true

            RowLayout {
                id: header
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    topMargin: 24
                    leftMargin: 20
                    rightMargin: 16
                }
                spacing: 8

                Text {
                    text: "Notifications"
                    font.pixelSize: 13
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: Pal.fgNotifTitle
                    Layout.fillWidth: true
                }

                Rectangle {
                    implicitWidth: 90
                    implicitHeight: 24
                    radius: 4
                    color: clearMouse.containsMouse ? Pal.borderNotifBtn : Pal.notifClearBg
                    border.color: Pal.borderNotifBtn
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Clear All"
                        font.pixelSize: 10
                        font.weight: Font.Medium
                        color: Pal.fgClearBtn
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root._clearAll()
                    }
                }
            }

            Rectangle {
                id: divider
                anchors {
                    top: header.bottom
                    left: parent.left
                    right: parent.right
                    topMargin: 20
                    leftMargin: 14
                    rightMargin: 14
                }
                height: 1
                color: Pal.notifDivider
            }

            Text {
                anchors.centerIn: notifList
                visible: historyData.count === 0
                horizontalAlignment: Text.AlignHCenter
                text: "No new notifications\nYou're all caught up!"
                font.pixelSize: 11
                font.letterSpacing: 0.5
                lineHeight: 1.2
                color: Pal.fgNotifEmpty
            }

            ListView {
                id: notifList
                anchors {
                    top: divider.bottom
                    bottom: notifCount.top
                    left: parent.left
                    right: parent.right
                    margins: 8
                }
                model: historyData
                clip: true
                spacing: 5
                focus: true
                keyNavigationEnabled: false
                boundsBehavior: Flickable.StopAtBounds

                Keys.onPressed: event => {
                    const k = event.key;
                    if (k === Qt.Key_J || k === Qt.Key_Down || k === Qt.Key_K || k === Qt.Key_Up) {
                        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex + (k === Qt.Key_J || k === Qt.Key_Down ? 1 : -1), historyData.count - 1));
                        positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    } else if (k === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
                        root._clearAll();
                    } else if (k === Qt.Key_D || k === Qt.Key_Backspace) {
                        if (historyData.count > 0) {
                            root._remove(root.selectedIndex);
                            root._save();
                        }
                    } else if (k === Qt.Key_Escape) {
                        escClose = true;
                    } else {
                        return;
                    }
                    event.accepted = true;
                }
                property bool escClose: false
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Escape && escClose && !event.isAutoRepeat) {
                        escClose = false;
                        root.panelOpen = false;
                        event.accepted = true;
                    }
                }

                delegate: Rectangle {
                    id: notifCard
                    required property int index
                    required property string appName
                    required property string summary
                    required property string body
                    required property double time
                    readonly property bool isSelected: index === root.selectedIndex

                    width: ListView.view.width
                    implicitHeight: col.implicitHeight + 20
                    radius: 4
                    color: isSelected ? Pal.notifSelBg : rowMouse.containsMouse ? Pal.notifHovBg : Pal.notifCardBg
                    border.color: isSelected ? Pal.borderNotifSel : Pal.borderNotifCard
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    ColumnLayout {
                        id: col
                        z: 1
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: 10
                            leftMargin: 12
                            rightMargin: 10
                        }
                        spacing: 3

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: notifCard.appName
                                font.pixelSize: 11
                                color: Pal.fgNotifMeta
                                textFormat: Text.PlainText
                                elide: Text.ElideRight
                            }
                            Text {
                                text: root.when(notifCard.time)
                                font.pixelSize: 11
                                color: Pal.notifTimeFaint
                                textFormat: Text.PlainText
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: notifCard.summary !== "" ? notifCard.summary : notifCard.body
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                            color: Pal.fgNotifBody
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                        }
                        Text {
                            Layout.fillWidth: true
                            visible: notifCard.summary !== "" && notifCard.body !== "" && notifCard.body !== notifCard.summary
                            text: notifCard.body
                            font.pixelSize: 11
                            color: Pal.fgNotifFaint
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: {
                            notifList.forceActiveFocus();
                            const i = notifCard.index;
                            root.selectedIndex = i;
                            if (root.activate(i)) {
                                root.panelOpen = false;
                                root._remove(i);
                                root._save();
                            }
                        }
                    }
                }
            }

            Text {
                id: notifCount
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    bottomMargin: 12
                    leftMargin: 18
                }
                text: historyData.count + " notification" + (historyData.count === 1 ? "" : "s")
                font.pixelSize: 13
                font.letterSpacing: 0.5
                color: Pal.notifTimeFaint
            }
        }
    }
}
