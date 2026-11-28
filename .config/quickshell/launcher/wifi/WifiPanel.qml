import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../"
import "../"
import "../fuzzy.js" as Fuzzy
import "../highlight.js" as Hl

// The wifi menu (Super+F5, or a click on the network in the bar), through NetworkManager (nmcli).
// Enter connects (a new network with a password asks for it); Tab: details (the saved password, the address);
// Ctrl+d disconnects, Ctrl+f forgets a saved network, Ctrl+r scans again, Ctrl+w turns wifi on or off,
// Space or Ctrl+s stars a network (starred ones stay at the top)
PickerPanel {
    id: root

    theme: LauncherThemeBase {
        id: theme
        panelW: 420
        searchBarH: 52
        bgAlpha: 1
    }
    icon: {
        if (!radioOn)
            return "\u{f092e}";
        const a = nets.find(n => n.active && n.type === "wifi");
        return a ? signalIcon(a) : "\u{f092f}";
    }
    iconSize: 16
    iconFont: "JetBrainsMono Nerd Font"
    iconWidth: 20
    iconOffset: -6
    placeholder: "Search networks..."
    itemKey: "key"
    status: noNmcli ? "nmcli isn't installed" : !radioOn ? "wifi off · Ctrl+w" : scanning && items.length === 0 ? "scanning…" : items.length + " networks"

    readonly property string favsJson: JSON.stringify(LauncherPrefs.data.wifiFavs || {})
    readonly property var favs: JSON.parse(favsJson)
    property var nets: []
    property bool scanning: false
    property bool noNmcli: false
    property bool radioOn: true
    property string wifiDev: ""
    property string view: "list"
    property var target: null
    property var detail: ({})
    property bool showSecret: false

    onActivated: {
        view = "list";
        scan(false);
    }
    onQueryChanged: rebuild()
    onFavsChanged: rebuild(true)
    onPick: it => {
        if (it)
            connect(it);
    }
    onFav: it => {
        const f = Object.assign({}, favs);
        if (f[it.name])
            delete f[it.name];
        else
            f[it.name] = true;
        LauncherPrefs.save({ wifiFavs: f });
    }

    keyHook: (ev, typing) => {
        const k = ev.key, ctrl = ev.modifiers & Qt.ControlModifier;
        if (k === Qt.Key_Tab) {
            if (current)
                openDetails(current);
        } else if (ctrl && k === Qt.Key_R) {
            scan(true);
        } else if (ctrl && k === Qt.Key_D) {
            disconnect(current && current.active ? current : nets.find(n => n.active && n.type === "wifi") || nets.find(n => n.active));
        } else if (ctrl && k === Qt.Key_F) {
            if (current && current.saved && current.type === "wifi")
                run(current.uuids.reduce((c, u) => c.concat(["uuid", u]), ["nmcli", "connection", "delete"]), "Forgot " + current.name, "Couldn't forget " + current.name);
        } else if (ctrl && k === Qt.Key_W) {
            run(["nmcli", "radio", "wifi", radioOn ? "off" : "on"], radioOn ? "Wifi off" : "Wifi on", "Couldn't switch wifi");
        } else {
            return false;
        }
        return true;
    }

    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length)
                cur += line[++i];
            else if (c === ":") {
                out.push(cur);
                cur = "";
            } else
                cur += c;
        }
        out.push(cur);
        return out;
    }

    function scan(rescan) {
        if (scanProc.running)
            return;
        scanning = true;
        scanProc.rescan = rescan;
        scanProc.running = true;
    }

    function parse(text) {
        let part = "", radio = true;
        const wifi = {}, saved = {}, eth = [];
        let dev = "", act = "";
        for (const line of text.split("\n")) {
            if (line.startsWith("#")) {
                part = line;
                continue;
            }
            if (line === "")
                continue;
            const f = fields(line);
            if (part === "#radio") {
                radio = line.trim() === "enabled";
            } else if (part === "#wifi" && f.length >= 4 && f[1] !== "") {
                const n = { key: "w:" + f[1], type: "wifi", name: f[1], signal: parseInt(f[2]) || 0, security: f[3] === "--" ? "" : f[3], active: f[0] === "*" };
                const o = wifi[n.name];
                if (!o || n.active || (!o.active && n.signal > o.signal))
                    wifi[n.name] = n;
            } else if (part === "#saved" && f.length >= 2 && f[1] !== "") {
                // uuid:ssid; keyed by SSID, as a profile's name can differ
                (saved[f[1]] = saved[f[1]] || []).push(f[0]);
            } else if (part === "#dev" && f.length >= 4) {
                if (f[1] === "wifi" && (!dev || (act === "" && f[2] === "connected"))) {
                    dev = f[0];
                    act = f[2] === "connected" ? f[4] || "" : "";
                }
                if (f[1] === "ethernet")
                    eth.push({ key: "e:" + f[0], type: "ethernet", name: f[0], conn: f[3], signal: 100, security: "", active: f[2] === "connected", saved: true });
            }
        }
        wifiDev = dev;
        radioOn = radio;
        const list = eth.slice();
        for (const k in wifi) {
            // the active profile first
            wifi[k].uuids = (saved[k] || []).sort((a, b) => (b === act) - (a === act));
            wifi[k].saved = wifi[k].uuids.length > 0;
            list.push(wifi[k]);
        }
        nets = list;
        rebuild(true);
    }

    function rebuild(keep) {
        const q = query.trim();
        const rank = n => (n.active ? 4 : 0) + (favs[n.name] ? 2 : 0) + (n.saved ? 1 : 0);
        let res = [];
        for (const n of nets) {
            const m = q === "" ? { indices: [], score: 0 } : Fuzzy.match(q, n.name);
            if (m)
                res.push(Object.assign({}, n, { hl: m.indices, score: m.score }));
        }
        res.sort((a, b) => q !== "" && b.score !== a.score ? b.score - a.score : rank(b) - rank(a) || b.signal - a.signal || (a.name < b.name ? -1 : 1));
        setItems(res, keep);
    }

    function signalIcon(n) {
        if (n.type === "ethernet")
            return "\u{f0200}";
        return n.signal >= 75 ? "\u{f0928}" : n.signal >= 50 ? "\u{f0925}" : n.signal >= 25 ? "\u{f0922}" : "\u{f091f}";
    }
    function iconColor(n, sel) {
        if (n.active)
            return Pal.positive;
        return sel ? theme.clrTextSecond : theme.clrTextMuted;
    }

    function notify(summary, ok) {
        Quickshell.execDetached(["notify-send", "-a", "Wifi", "-u", ok ? "normal" : "critical", summary]);
    }

    function run(cmd, okText, failText) {
        const p = runner.createObject(root, { command: cmd, okText: okText, failText: failText });
        p.running = true;
    }

    function connect(n) {
        if (n.type === "ethernet") {
            run(["nmcli", "device", "connect", n.name], "Connected: " + n.name, "Couldn't connect " + n.name);
        } else if (n.active) {
            openDetails(n);
        } else if (n.saved) {
            run(["nmcli", "connection", "up", "uuid", n.uuids[0]], "Connected: " + n.name, "Couldn't connect to " + n.name);
        } else if (n.security !== "") {
            target = n;
            pass.text = "";
            showSecret = false;
            view = "password";
            pass.forceActiveFocus();
        } else {
            run(["nmcli", "device", "wifi", "connect", n.name], "Connected: " + n.name, "Couldn't connect to " + n.name);
        }
    }

    function connectWith(password) {
        const n = target;
        if (!n || password === "")
            return;
        const p = runner.createObject(root, {
            command: ["nmcli", "--ask", "device", "wifi", "connect", n.name],
            okText: "Connected: " + n.name,
            failText: "Couldn't connect to " + n.name + " (wrong password?)",
            input: password + "\n"
        });
        p.running = true;
        backToList();
    }

    function disconnect(n) {
        if (!n)
            return;
        if (n.type === "ethernet")
            run(["nmcli", "device", "disconnect", n.name], "Disconnected: " + n.name, "Couldn't disconnect " + n.name);
        else if (n.active && wifiDev !== "")
            run(["nmcli", "device", "disconnect", wifiDev], "Disconnected: " + n.name, "Couldn't disconnect " + n.name);
    }

    function openDetails(n) {
        target = n;
        detail = { password: "", ip: "" };
        showSecret = false;
        view = "details";
        detailsBox.forceActiveFocus();
        const dev = n.type === "ethernet" ? n.name : wifiDev;
        // exec restarts a lookup still running; the output says which network it's for
        detailProc.exec(["sh", "-c", 'printf "#for %s\\n" "$4"; echo "#psk"; [ -n "$1" ] && nmcli -s -g 802-11-wireless-security.psk connection show uuid "$1" 2>/dev/null; echo "#ip"; [ -n "$3" ] && [ "$3" = 1 ] && [ -n "$2" ] && nmcli -g IP4.ADDRESS device show "$2" 2>/dev/null', "sh", n.saved && n.type === "wifi" ? n.uuids[0] : "", dev, n.active ? "1" : "0", n.key]);
    }

    function backToList() {
        view = "list";
        showSecret = false;
        pass.text = "";
        focusSearch();
    }

    Process {
        id: scanProc
        property bool rescan: false
        command: ["sh", "-c", 'command -v nmcli >/dev/null || exit 9; echo "#radio"; nmcli radio wifi; echo "#wifi"; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan "$1" 2>/dev/null; echo "#saved"; nmcli -t -f UUID,TYPE connection show 2>/dev/null | while IFS=: read -r u t; do [ "$t" = 802-11-wireless ] && printf "%s:%s\\n" "$u" "$(nmcli -g 802-11-wireless.ssid connection show uuid "$u" 2>/dev/null)"; done; echo "#dev"; nmcli -t -f DEVICE,TYPE,STATE,CONNECTION,CON-UUID device status 2>/dev/null', "sh", rescan ? "yes" : "auto"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: code => {
            root.scanning = false;
            root.noNmcli = code === 9;
        }
    }

    Process {
        id: detailProc
        stdout: StdioCollector {
            onStreamFinished: {
                let part = "", psk = "", ip = "", key = null;
                for (const line of text.split("\n")) {
                    if (line.startsWith("#for ")) {
                        key = line.slice(5);
                        part = psk = ip = "";
                    } else if (line === "#psk" || line === "#ip")
                        part = line;
                    else if (line !== "" && part === "#psk" && psk === "")
                        psk = line.replace(/\\(.)/g, "$1");
                    else if (line !== "" && part === "#ip" && ip === "")
                        ip = line.split("|")[0].trim();
                }
                if (root.target && key === root.target.key)
                    root.detail = { password: psk, ip: ip };
            }
        }
    }

    Component {
        id: runner
        Process {
            property string okText
            property string failText
            property string input: ""
            stdinEnabled: input !== ""
            onStarted: {
                if (input !== "") {
                    write(input);
                    stdinEnabled = false;
                }
            }
            onExited: code => {
                root.notify(code === 0 ? okText : failText, code === 0);
                root.scan(false);
                destroy();
            }
        }
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.visible && root.view === "list"
        onTriggered: root.scan(false)
    }

    delegate: PickerRow {
        id: r
        star: true
        starred: !!root.favs[r.modelData.name]

        Text {
            text: root.signalIcon(r.modelData)
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            color: root.iconColor(r.modelData, r.isSel || r.isHov)
            Layout.preferredWidth: 20
            Layout.alignment: Qt.AlignVCenter
            Behavior on color {
                ColorAnimation {
                    duration: 80
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                elide: Text.ElideRight
                textFormat: Text.StyledText
                text: Hl.markup(r.modelData.name, r.modelData.hl, theme.clrMatch)
                font.pixelSize: 13
                font.family: "monospace"
                font.bold: r.modelData.active
                color: r.isSel || r.modelData.active ? theme.clrTextPrim : theme.clrTextSecond
            }
        }

        Rectangle {
            visible: r.modelData.active
            implicitWidth: connText.implicitWidth + 12
            implicitHeight: 18
            radius: 9
            color: Qt.rgba(Pal.positive.r, Pal.positive.g, Pal.positive.b, 0.15)
            Layout.alignment: Qt.AlignVCenter
            Text {
                id: connText
                anchors.centerIn: parent
                text: "connected"
                font.pixelSize: 10
                font.family: "monospace"
                color: Pal.positive
            }
        }
        Text {
            visible: !r.modelData.active && r.modelData.saved && r.modelData.type === "wifi"
            text: "saved"
            font.pixelSize: 10
            font.family: "monospace"
            color: theme.clrTextMuted
            Layout.alignment: Qt.AlignVCenter
        }

        Text {
            text: r.modelData.type === "wifi" ? r.modelData.signal + "%" : ""
            font.pixelSize: 10
            font.family: "monospace"
            color: theme.clrTextMuted
            opacity: r.isSel || r.isHov ? 1 : 0.7
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: 30
            Layout.alignment: Qt.AlignVCenter
        }
        Text {
            text: "\u{f033e}"
            opacity: r.modelData.security !== "" ? 1 : 0
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            color: theme.clrTextMuted
            Layout.preferredWidth: 12
            Layout.alignment: Qt.AlignVCenter
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 4
        color: theme.clrBg
        visible: root.view !== "list"

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 14

            Text {
                text: root.target ? (root.view === "password" ? "Password for " : "") + root.target.name : ""
                font.pixelSize: 14
                font.family: "monospace"
                font.bold: true
                color: theme.clrTextPrim
                elide: Text.ElideRight
                Layout.fillWidth: true
            }

            Rectangle {
                visible: root.view === "password"
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: 4
                color: "transparent"
                border.width: 1
                border.color: pass.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                TextInput {
                    id: pass
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    echoMode: root.showSecret ? TextInput.Normal : TextInput.Password
                    color: theme.clrInputText
                    font.pixelSize: 13
                    font.family: "monospace"
                    clip: true
                    Keys.onPressed: ev => {
                        const ctrl = ev.modifiers & Qt.ControlModifier;
                        if (ev.key === Qt.Key_Escape)
                            root.backToList();
                        else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter)
                            root.connectWith(text);
                        else if (ctrl && ev.key === Qt.Key_H)
                            root.showSecret = !root.showSecret;
                        else
                            return;
                        ev.accepted = true;
                    }
                }
            }

            Item {
                id: detailsBox
                visible: root.view === "details"
                Layout.fillWidth: true
                Layout.fillHeight: true
                focus: root.view === "details"
                Keys.onPressed: ev => {
                    const ctrl = ev.modifiers & Qt.ControlModifier;
                    if (ev.key === Qt.Key_Escape || ev.key === Qt.Key_Tab || ev.key === Qt.Key_Q)
                        root.backToList();
                    else if (ev.key === Qt.Key_V)
                        root.showSecret = !root.showSecret;
                    else if (ctrl && ev.key === Qt.Key_C && root.detail.password !== "") {
                        Quickshell.execDetached(["wl-copy", "--", root.detail.password]);
                        root.notify("Password copied", true);
                    } else if (ctrl && ev.key === Qt.Key_D) {
                        root.disconnect(root.target);
                        root.backToList();
                    } else
                        return;
                    ev.accepted = true;
                }

                GridLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    columns: 2
                    columnSpacing: 16
                    rowSpacing: 10

                    Repeater {
                        model: {
                            const n = root.target || {}, d = root.detail;
                            const rows = [["Type", n.type === "ethernet" ? "Ethernet" : "Wifi"]];
                            if (n.type === "wifi") {
                                rows.push(["Security", n.security || "open"], ["Signal", n.signal + "%"], ["Saved", n.saved ? "yes" : "no"]);
                                if (n.saved)
                                    rows.push(["Password", d.password === "" ? "—" : root.showSecret ? d.password : "•".repeat(Math.min(16, d.password.length))]);
                            }
                            rows.push(["State", n.active ? "connected" : "not connected"]);
                            if (n.active)
                                rows.push(["Address", d.ip || "…"]);
                            return rows;
                        }
                        delegate: Repeater {
                            required property var modelData
                            model: 2
                            Text {
                                required property int index
                                text: modelData[index]
                                font.pixelSize: 12
                                font.family: "monospace"
                                color: index === 0 ? theme.clrTextMuted : theme.clrTextPrim
                                Layout.fillWidth: index === 1
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            Item {
                visible: root.view === "password"
                Layout.fillHeight: true
            }

            Text {
                text: root.view === "password" ? "Enter connects · Ctrl+h shows it · Esc back" : "v shows the password · Ctrl+c copies it · Ctrl+d disconnects · Esc back"
                font.pixelSize: 10
                font.family: "monospace"
                color: theme.clrTextMuted
                wrapMode: Text.WordWrap
                Layout.fillWidth: true
            }
        }
    }
}
