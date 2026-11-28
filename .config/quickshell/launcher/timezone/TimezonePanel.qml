import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../"
import "../fuzzy.js" as Fuzzy
import "../highlight.js" as Hl

// The time zone picker (Super+F3): search by place or zone, or type an offset like utc+2; each shows its time now.
// Enter sets the system's time zone (set-zone: the first time, it asks your password to install its helper).
// Starred ones stay at the top
PickerPanel {
    id: root

    theme: LauncherThemeBase {
        id: theme
        panelW: 500
    }
    panelClip: true
    placeholder: loading ? "Loading timezones…" : "Search timezones…"
    status: !loading && items.length > 0 ? items.length + " results" : ""
    searchEnabled: !loading && !overlay.visible

    readonly property string favsJson: JSON.stringify(LauncherPrefs.data.timezoneFavs || {})
    readonly property var favs: JSON.parse(favsJson)
    property var zones: []
    property bool loading: true
    property real loadedAt: 0
    property int clockEpoch: 0

    onQueryChanged: rebuild()
    onFavsChanged: rebuild(true)
    onActivated: {
        overlay.visible = false;
        overlay.pendingZone = "";
        if (!listProc.running && Date.now() - loadedAt > 30 * 60000)
            listProc.running = true;
    }
    onPick: it => {
        if (!it)
            return;
        overlay.pendingZone = it.zone;
        overlay.errorMsg = "";
        sudoField.text = "";
        apply(false);
    }
    onFav: it => {
        const f = Object.assign({}, favs);
        if (f[it.name])
            delete f[it.name];
        else
            f[it.name] = true;
        LauncherPrefs.save({ timezoneFavs: f });
    }

    function timeAt(offsetSecs) {
        const d = new Date(Date.now() + offsetSecs * 1000), h = d.getUTCHours(), m = d.getUTCMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    function offsetQuery(q) {
        const m = /^(?:utc|gmt)?\s*([+\-−])\s*(\d{1,2})(?:[:.]?(\d{2}))?$/i.exec(q);
        return m ? (m[1] === "+" ? 1 : -1) * (m[2] * 3600 + (m[3] ? m[3] * 60 : 0)) : null;
    }

    function rebuild(keep) {
        const q = query.trim(), res = [], off = offsetQuery(q);
        for (const z of zones) {
            const m = q === "" ? { score: 0, indices: [] } : off !== null ? (z.offset === off ? { score: 0, indices: [] } : null)
                : Fuzzy.match(q, z.display) || (Fuzzy.match(q, z.keys) ? { score: -1000, indices: [] } : null);
            if (m)
                res.push({ name: z.name, display: z.display, zone: z.zone, offset: z.offset, hl: m.indices, score: m.score, fav: favs[z.name] ? 1 : 0 });
        }
        res.sort((a, b) => b.fav - a.fav || q !== "" && b.score - a.score || a.display.localeCompare(b.display));
        setItems(res, keep);
    }

    function closeOverlay() {
        sudoField.text = "";
        overlay.visible = false;
        overlay.errorMsg = "";
        focusSearch();
    }

    function apply(install) {
        if (applyProc.running)
            return;
        applyProc.zone = overlay.pendingZone;
        applyProc.pw = install ? sudoField.text : "";
        applyProc.stdinEnabled = install;
        applyProc.command = ["sh", Qt.resolvedUrl("./set-zone").toString().replace("file://", ""), overlay.pendingZone].concat(install ? ["--install"] : []);
        applyProc.running = true;
    }
    function doApply() {
        apply(true);
    }

    Timer {
        interval: 10000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: root.clockEpoch++
    }

    Timer {
        id: sudoFocusTimer
        interval: 30
        onTriggered: sudoField.forceActiveFocus()
    }

    Process {
        id: listProc
        running: true
        command: ["python3", Qt.resolvedUrl("./timezone-list.py").toString().replace("file://", "")]
        property var buf: []
        onRunningChanged: if (running) {
            buf = [];
            root.loading = true;
        }
        stdout: SplitParser {
            onRead: line => {
                const p = line.split("\t");
                if (p.length >= 4)
                    listProc.buf.push({ name: p[0], display: p[0] + "  [" + p[1] + "]", zone: p[2], offset: parseInt(p[3]) || 0, keys: p[4] || p[2] });
            }
        }
        onExited: {
            root.zones = buf;
            root.loadedAt = Date.now();
            root.loading = false;
            root.rebuild();
            if (!overlay.visible)
                root.focusSearch();
        }
    }

    Process {
        id: applyProc
        property string zone: ""
        property string pw: ""
        stdinEnabled: true
        stderr: StdioCollector { id: applyErr }
        onStarted: {
            if (stdinEnabled) {
                write(pw + "\n");
                stdinEnabled = false;
            }
            pw = "";
        }
        onExited: code => {
            sudoField.text = "";
            if (code === 0) {
                Date.timeZoneUpdated();
                overlay.visible = false;
                Quickshell.execDetached(["notify-send", "-a", "Time zone", "🌍 Timezone Changed", "Now using " + zone]);
                root.hide();
            } else if (code === 3 && !overlay.visible) {
                overlay.visible = true;
                sudoFocusTimer.restart();
            } else {
                if (!overlay.visible) {
                    overlay.visible = true;
                    sudoFocusTimer.restart();
                }
                const err = applyErr.text.trim();
                overlay.errorMsg = !err || /incorrect password|try again|no password|password is required/i.test(err)
                    ? "Incorrect password — try again" : err.split("\n").pop();
                sudoFocusTimer.restart();
            }
        }
    }

    delegate: PickerRow {
        id: r
        star: true
        starred: !!root.favs[r.modelData.name]

        Text {
            text: "🌍"
            font.pixelSize: 14
            Layout.alignment: Qt.AlignVCenter
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: Hl.markup(r.modelData.display, r.modelData.hl, theme.clrMatch)
                font.pixelSize: 13
                font.family: "monospace"
                color: r.isSel ? theme.clrTextPrim : theme.clrTextSecond
                Behavior on color {
                    ColorAnimation {
                        duration: 80
                    }
                }
            }
        }

        Text {
            text: (root.clockEpoch, root.timeAt(r.modelData.offset))
            font.pixelSize: 13
            font.family: "monospace"
            color: r.isSel ? theme.clrSearchFocus : theme.clrTextMuted
            Layout.alignment: Qt.AlignVCenter
            Behavior on color {
                ColorAnimation {
                    duration: 80
                }
            }
        }
    }

    Rectangle {
        id: overlay
        anchors.fill: parent
        color: theme.clrBg
        radius: 4
        visible: false
        opacity: visible ? 1 : 0
        Behavior on opacity {
            NumberAnimation {
                duration: 120
            }
        }
        Keys.onPressed: ev => ev.accepted = true

        property string pendingZone: ""
        property string errorMsg: ""

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.AllButtons
            onWheel: w => w.accepted = true
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 340)
            spacing: 14

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "🔒"
                    font.pixelSize: 28
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Your password, this once"
                    color: theme.clrTextPrim
                    font.pixelSize: 13
                    font.family: "monospace"
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: overlay.pendingZone !== "" ? "Setting the time zone to " + overlay.pendingZone + ". After this, changing it never asks." : ""
                    color: theme.clrTextMuted
                    font.pixelSize: 11
                    font.family: "monospace"
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 4
                color: "transparent"
                border.color: sudoField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                border.width: 1
                Behavior on border.color {
                    ColorAnimation {
                        duration: 120
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "🔑"
                        font.pixelSize: 11
                        Layout.alignment: Qt.AlignVCenter
                        color: theme.clrSearchIcon
                    }

                    TextInput {
                        id: sudoField
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        echoMode: TextInput.Password
                        color: theme.clrInputText
                        font.pixelSize: 12
                        font.family: "monospace"
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        enabled: overlay.visible && !applyProc.running
                        Keys.onReturnPressed: ev => {
                            root.doApply();
                            ev.accepted = true;
                        }
                        Keys.onEnterPressed: ev => {
                            root.doApply();
                            ev.accepted = true;
                        }
                        Keys.onEscapePressed: ev => {
                            root.closeOverlay();
                            ev.accepted = true;
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: overlay.errorMsg
                color: theme.clrCalcError
                font.pixelSize: 11
                font.family: "monospace"
                visible: overlay.errorMsg !== ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 4
                    color: cancelMa.containsMouse ? theme.clrHovRow : "transparent"
                    border.color: theme.clrBorder
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: theme.clrTextSecond
                        font.pixelSize: 12
                        font.family: "monospace"
                    }
                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.closeOverlay()
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 4
                    color: Pal.over(theme.clrSearchFocus, applyBtnMa.containsMouse ? 0.25 : 0.15)
                    border.color: theme.clrSearchFocus
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: applyProc.running ? "Applying…" : "Apply"
                        color: theme.clrSearchFocus
                        font.pixelSize: 12
                        font.family: "monospace"
                        font.bold: true
                    }
                    MouseArea {
                        id: applyBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !applyProc.running
                        onClicked: root.doApply()
                    }
                }
            }
        }
    }
}
