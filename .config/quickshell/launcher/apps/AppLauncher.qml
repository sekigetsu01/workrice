import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../"

Item {
    id: root

    Theme {
        id: theme
    }

    required property var freq
    required property var favs
    required property var panelRef
    required property bool calcMode

    property bool calcDividerInset: false

    signal launched
    signal toggleFav(string name)
    signal freqBump(string name)
    signal requestClose
    signal appsLoaded

    function activate() {
        searchField.text = "";
        searchQuery = "";
        selectedIndex = 0;
        focusSource = "keyboard";
        calcInput = "";
        calcResult = "";
        calcError = "";
        rebuildFilter();
        searchFocusTimer.restart();
    }

    Timer {
        id: searchFocusTimer
        interval: 30
        onTriggered: searchField.forceActiveFocus()
    }

    function activateCalc() {
        calcInput = "";
        calcResult = "";
        calcError = "";
        calcField.text = "";
        calcFocusTimer.restart();
    }

    function clearSearch() {
        searchField.text = "";
        searchQuery = "";
        rebuildFilter();
    }

    function acceptCalcResult() {
        if (calcResult !== "") {
            var res = calcResult;
            calcField.text = res;
            calcInput = res;
            calcResult = "";
            calcError = "";
        }
    }

    function copyCalcResult() {
        if (calcResult !== "") {
            var safe = calcResult.replace(/'/g, "'\''");
            copyResultProc.command = ["sh", "-c", "printf '%s' '" + safe + "' | wl-copy"];
            copyResultProc.running = true;
        }
    }

    function resetCalc() {
        calcInput = "";
        calcResult = "";
        calcError = "";
        calcField.text = "";
    }

    property var allApps: []
    property var _rawApps: []
    property int    selectedIndex: 0
        property string focusSource:   "keyboard"
    property string searchQuery: ""
    property bool _appsLoaded: false

    property string calcInput: ""
    property string calcResult: ""
    property string calcError: ""

    ListModel {
        id: appModel
    }

    Process {
        id: appListProc
        running: !root.calcMode
        command: ["sh", "-c", "find /usr/share/applications" + " ${HOME}/.local/share/applications" + " /var/lib/flatpak/exports/share/applications" + " ${HOME}/.local/share/flatpak/exports/share/applications" + " -name '*.desktop' 2>/dev/null | sort -u | xargs -r awk '" + "FNR==1 { n=\"\"; e=\"\"; ic=\"\"; nd=\"\"; tm=\"\"; inEntry=0 }" + "/^\\[Desktop Entry\\]/ { inEntry=1; next }" + "/^\\[/ { inEntry=0 }" + "inEntry && /^Name=/ && n==\"\"   { n=substr($0,6) }" + "inEntry && /^Exec=/ && e==\"\"   { e=substr($0,6) }" + "inEntry && /^Icon=/ && ic==\"\"  { ic=substr($0,6) }" + "inEntry && /^NoDisplay=/         { nd=substr($0,11) }" + "inEntry && /^Terminal=/          { tm=substr($0,10) }" + "ENDFILE {" + "  if (n!=\"\" && nd!=\"true\") {" + "    gsub(/ *%[a-zA-Z]/, \"\", e);" + "    print n \"\\t\" e \"\\t\" ic \"\\t\" tm" + "  }" + "}' 2>/dev/null | sort -t'\t' -k1,1"]
        onRunningChanged: function() { if (running) root._rawApps = []; }
        stdout: SplitParser {
            onRead: function (line) {
                if (line.trim() === "")
                    return;
                var p = line.split("\t");
                if (p[0]) {
                    var apps = root._rawApps;
                    apps.push({
                        name: p[0],
                        exec: p[1] || "",
                        icon: p[2] || "",
                        terminal: (p[3] || "").toLowerCase() === "true"
                    });
                    root._rawApps = apps;
                }
            }
        }
        onExited: function () {
            var seen = {}, deduped = [];
            for (var i = 0; i < root._rawApps.length; i++) {
                if (!seen[root._rawApps[i].name]) {
                    seen[root._rawApps[i].name] = true;
                    deduped.push(root._rawApps[i]);
                }
            }
            root.allApps = deduped;
            root._rawApps = [];
            root._appsLoaded = true;
            root.appsLoaded();
        }
    }

    function launchSelected() {
        if (appModel.count > 0) {
            var a = appModel.get(selectedIndex);
            launch(a.appExec, a.appTerminal, a.appName);
        }
    }

    Process {
        id: launchProc
        command: ["sh", "-c", "true"]
    }
    Process {
        id: copyResultProc
        command: ["sh", "-c", "true"]
    }

    readonly property var terminalCandidates: ["kitty", "alacritty", "foot", "wezterm", "ghostty", "xterm", "uxterm", "xfce4-terminal", "gnome-terminal"]

    function launch(exec_, terminal_, appName_) {
        if (!exec_ || exec_.trim() === "")
            return;
        if (launchProc.running)
            return;
        var cmd = exec_;
        if (terminal_) {
            var safeExec = "'" + exec_.replace(/'/g, "'\\''") + "'";
            var chain = "";
            for (var j = 0; j < terminalCandidates.length; j++) {
                var t = terminalCandidates[j];
                var flag = (t === "gnome-terminal") ? "-- " : "-e ";
                if (chain !== "")
                    chain += " || ";
                chain += "command -v " + t + " >/dev/null 2>&1 && " + t + " " + flag + safeExec;
            }
            cmd = chain;
        }
        launchProc.command = ["sh", "-c", cmd];
        launchProc.running = true;
        root.freqBump(appName_);
        root.launched();
    }

    function calcEvaluate(expr) {
        var s = expr.replace(/[xX×]/g, "*").replace(/\s+/g, "").toLowerCase();
        var pos = 0;
        function peek() {
            return s[pos];
        }
        function consume() {
            return s[pos++];
        }
        function parseExpr() {
            return parseAddSub();
        }
        function parseAddSub() {
            var left = parseMulDiv();
            while (pos < s.length && (peek() === "+" || peek() === "-")) {
                var op = consume();
                var right = parseMulDiv();
                left = op === "+" ? left + right : left - right;
            }
            return left;
        }
        function parseMulDiv() {
            var left = parsePower();
            while (pos < s.length && (peek() === "*" || peek() === "/")) {
                var op = consume();
                var right = parsePower();
                if (op === "/" && right === 0)
                    throw "Division by zero";
                left = op === "*" ? left * right : left / right;
            }
            return left;
        }
        function parsePower() {
            var base = parseUnary();
            if (pos < s.length && peek() === "^") {
                consume();
                var exp = parsePower();
                return Math.pow(base, exp);
            }
            return base;
        }
        function parseUnary() {
            if (peek() === "-") {
                consume();
                return -parseUnary();
            }
            if (peek() === "+") {
                consume();
                return parseUnary();
            }
            return parsePrimary();
        }
        function parsePrimary() {
            if (s.substr(pos, 5) === "sqrt(") {
                pos += 5;
                var val = parseExpr();
                if (peek() !== ")")
                    throw "Missing )";
                consume();
                if (val < 0)
                    throw "sqrt of negative";
                return Math.sqrt(val);
            }
            if (peek() === "(") {
                consume();
                var inner = parseExpr();
                if (peek() !== ")")
                    throw "Missing )";
                consume();
                return inner;
            }
            var start = pos;
            var seenDot = false;
            while (pos < s.length) {
                if (s[pos] === '.') {
                    if (seenDot) break;
                    seenDot = true;
                } else if (!/\d/.test(s[pos])) {
                    break;
                }
                pos++;
            }
            if (pos === start)
                throw "Expected number";
            var num = parseFloat(s.substring(start, pos));
            if (pos < s.length && s[pos] === "%") {
                pos++;
                num = num / 100;
            }
            return num;
        }
        try {
            var result = parseExpr();
            if (pos !== s.length)
                throw "Unexpected: " + s[pos];
            if (!isFinite(result))
                return {
                    ok: false,
                    msg: "Math error"
                };
            return {
                ok: true,
                value: parseFloat(result.toPrecision(10)).toString()
            };
        } catch (err) {
            return {
                ok: false,
                msg: err.toString()
            };
        }
    }

    function fuzzyMatch(query, target) {
        var q = query.toLowerCase(), t = target.toLowerCase(), qi = 0, indices = [];
        for (var ti = 0; ti < t.length && qi < q.length; ti++)
            if (t[ti] === q[qi]) {
                indices.push(ti);
                qi++;
            }
        if (qi < q.length)
            return null;
        var score = 0, consecutive = 1;
        for (var i = 0; i < indices.length; i++) {
            score++;
            if (i > 0 && indices[i] === indices[i - 1] + 1) {
                consecutive++;
                score += consecutive * 3;
            } else {
                consecutive = 1;
            }
            if (indices[i] === 0) {
                score += 8;
            } else {
                var prev = t[indices[i] - 1];
                if (prev === " " || prev === "-" || prev === "." || prev === "_")
                    score += 6;
            }
        }
        score -= t.length * 0.01;
        return {
            score: score,
            indices: indices
        };
    }

    function rebuildFilter() {
        var q = searchQuery.trim(), results = [], searching = q !== "";
        for (var i = 0; i < allApps.length; i++) {
            if (!searching) {
                results.push({
                    app: allApps[i],
                    score: 0,
                    indices: []
                });
            } else {
                var m = fuzzyMatch(q, allApps[i].name);
                if (m)
                    results.push({
                        app: allApps[i],
                        score: m.score,
                        indices: m.indices
                    });
            }
        }
        results.sort(function (a, b) {
            var fd = (isFav(b.app.name) ? 1 : 0) - (isFav(a.app.name) ? 1 : 0);
            if (fd !== 0)
                return fd;
            if (searching && b.score !== a.score)
                return b.score - a.score;
            var cd = freqCount(b.app.name) - freqCount(a.app.name);
            if (cd !== 0)
                return cd;
            var ld = freqLastUsed(b.app.name) - freqLastUsed(a.app.name);
            if (ld !== 0)
                return ld;
            return a.app.name.localeCompare(b.app.name);
        });
        selectedIndex = 0;
        focusSource = "keyboard";
        appModel.clear();
        for (var j = 0; j < results.length; j++)
            appModel.append({
                appName: results[j].app.name,
                appExec: results[j].app.exec,
                appIcon: results[j].app.icon,
                appTerminal: results[j].app.terminal || false,
                matchIndices: JSON.stringify(results[j].indices)
            });
        listView.positionViewAtBeginning();
    }

    function isFav(name) {
        return !!root.favs[name];
    }
    function freqCount(name) {
        var e = root.freq[name];
        return e ? (e.count || 0) : 0;
    }
    function freqLastUsed(name) {
        var e = root.freq[name];
        return e ? (e.lastUsed || 0) : 0;
    }

    function letterColor(name) {
        if (!name || name.length === 0)
            return Pal.avatarFallback;
        var hash = 0;
        for (var i = 0; i < name.length; i++)
            hash = (hash * 31 + name.charCodeAt(i)) & 0xffffffff;
        return Qt.hsla((Math.abs(hash) % 360) / 360, 0.30, 0.28, 1.0);
    }

    function handleKey(ev, isCalcMode) {
        if (searchField.activeFocus || (isCalcMode && calcField.activeFocus))
            return false;

        if (ev.key === Qt.Key_Space) {
            if (appModel.count > 0) {
                var a = appModel.get(selectedIndex);
                launch(a.appExec, a.appTerminal, a.appName);
            }
            ev.accepted = true;
            return true;
        }
        if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
            if (appModel.count > 0)
                root.toggleFav(appModel.get(selectedIndex).appName);
            ev.accepted = true;
            return true;
        }
        if (ev.key === Qt.Key_D) {
            if (searchQuery !== "") {
                searchField.text = "";
                searchQuery = "";
                rebuildFilter();
            } else
                root.requestClose();
            ev.accepted = true;
            return true;
        }
        if (ev.key === Qt.Key_F || ev.key === Qt.Key_I || ev.key === Qt.Key_A) {
            searchField.forceActiveFocus();
            ev.accepted = true;
            return true;
        }
        if (ev.key === Qt.Key_J && (ev.modifiers & Qt.ControlModifier)) {
            if (selectedIndex < appModel.count - 1) {
                selectedIndex++;
                root.focusSource = "keyboard";
                listView.positionViewAtIndex(selectedIndex, ListView.Contain);
            }
            ev.accepted = true;
            return true;
        }
        if (ev.key === Qt.Key_K && (ev.modifiers & Qt.ControlModifier)) {
            if (selectedIndex > 0) {
                selectedIndex--;
                root.focusSource = "keyboard";
                listView.positionViewAtIndex(selectedIndex, ListView.Contain);
            }
            ev.accepted = true;
            return true;
        }
        return false;
    }

    Timer {
        id: calcFocusTimer
        interval: 30
        onTriggered: calcField.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            height: theme.searchBarH

            Item {
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: 0
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                visible: !root.calcMode

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: "🔍"
                        font.pixelSize: 11
                        color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrSearchIcon
                        Layout.alignment: Qt.AlignVCenter
                        Behavior on color {
                            ColorAnimation {
                                duration: 120
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Text {
                            anchors.fill: parent
                            text: "Search apps..."
                            color: theme.clrTextMuted
                            font.pixelSize: 12
                            font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter
                            visible: searchField.text.length === 0
                            opacity: 0.5
                        }
                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            color: theme.clrInputText
                            font.pixelSize: 12
                            font.family: "monospace"
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onTextChanged: {
                                root.searchQuery = text;
                                root.rebuildFilter();
                            }
                            Keys.onEscapePressed: function (ev) {
                                if (text === "")
                                    root.requestClose();
                                else
                                    root.panelRef.forceActiveFocus();
                                ev.accepted = true;
                            }
                            Keys.onReturnPressed: function (ev) {
                                if (appModel.count > 0) {
                                    var a = appModel.get(root.selectedIndex);
                                    root.launch(a.appExec, a.appTerminal, a.appName);
                                }
                                ev.accepted = true;
                            }
                            Keys.onPressed: function (ev) {
                                if ((ev.key === Qt.Key_J || ev.key === Qt.Key_Down) && (ev.modifiers & Qt.ControlModifier)) {
                                    if (root.selectedIndex < appModel.count - 1) {
                                        root.selectedIndex++;
                                        root.focusSource = "keyboard";
                                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                    }
                                    ev.accepted = true;
                                } else if ((ev.key === Qt.Key_K || ev.key === Qt.Key_Up) && (ev.modifiers & Qt.ControlModifier)) {
                                    if (root.selectedIndex > 0) {
                                        root.selectedIndex--;
                                        root.focusSource = "keyboard";
                                        listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                                    }
                                    ev.accepted = true;
                                } else if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
                                    if (appModel.count > 0)
                                        root.toggleFav(appModel.get(root.selectedIndex).appName);
                                    ev.accepted = true;
                                }
                            }
                        }
                    }

                    Text {
                        text: appModel.count + " apps"
                        color: theme.clrTextMuted
                        font.pixelSize: 10
                        font.family: "monospace"
                        Layout.alignment: Qt.AlignVCenter
                        visible: appModel.count > 0
                    }
                }
            }

            Item {
                anchors.fill: parent
                anchors.topMargin: 10
                anchors.bottomMargin: 0
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                visible: root.calcMode

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.color: calcField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                    border.width: 1
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 8

                    Text {
                        text: ">"
                        color: theme.clrCalcAccent
                        font.pixelSize: 13
                        font.bold: true
                        font.family: "monospace"
                        Layout.alignment: Qt.AlignVCenter
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Text {
                            anchors.fill: parent
                            text: "e.g. 10% x 200 + 5"
                            color: theme.clrTextMuted
                            font.pixelSize: 12
                            font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter
                            visible: calcField.text.length === 0
                        }
                        TextInput {
                            id: calcField
                            anchors.fill: parent
                            color: theme.clrInputText
                            font.pixelSize: 12
                            font.family: "monospace"
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onTextChanged: {
                                root.calcInput = text;
                                var t = text.trim();
                                if (t === "") {
                                    root.calcResult = "";
                                    root.calcError = "";
                                    return;
                                }
                                var r = root.calcEvaluate(t);
                                if (r.ok) {
                                    root.calcResult = r.value;
                                    root.calcError = "";
                                } else {
                                    var opens = 0;
                                    for (var ci = 0; ci < t.length; ci++) {
                                        if (t[ci] === "(")
                                            opens++;
                                        else if (t[ci] === ")")
                                            opens--;
                                    }
                                    var complete = opens === 0 && /\d$/.test(t);
                                    root.calcResult = "";
                                    root.calcError = (complete && r.msg !== "Missing )") ? r.msg : "";
                                }
                            }
                            Keys.onEscapePressed: function (ev) {
                                root.requestClose();
                                ev.accepted = true;
                            }
                            Keys.onReturnPressed: function (ev) {
                                if (root.calcResult !== "") {
                                    calcField.text = root.calcResult;
                                    root.calcInput = root.calcResult;
                                    root.calcResult = "";
                                }
                                ev.accepted = true;
                            }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            height: theme.dividerH
            visible: root.calcMode
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: root.calcDividerInset ? 10 : 0
                anchors.rightMargin: root.calcDividerInset ? 10 : 0
                height: 1
                color: theme.clrDivider
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: visible ? theme.maxVisibleRows * theme.rowHeight : 0
            color: "transparent"
            visible: root.calcMode
            Text {
                anchors.centerIn: parent
                width: parent.width - 48
                horizontalAlignment: Text.AlignHCenter
                text: root.calcError !== "" ? root.calcError : root.calcResult
                color: root.calcError !== "" ? theme.clrCalcError : theme.clrCalcResult
                font.pixelSize: 32
                minimumPixelSize: 12
                fontSizeMode: Text.Fit
                wrapMode: Text.WordWrap
                font.family: "monospace"
                font.bold: root.calcResult !== ""
                visible: root.calcResult !== "" || root.calcError !== ""
            }
        }

        Item {
            Layout.fillWidth: true
            height: theme.dividerH
            visible: !root.calcMode
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                height: 1
                color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrDivider
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }

        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 0
            model: appModel
            visible: !root.calcMode
            topMargin: theme.dividerH / 2
            bottomMargin: 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
                onWheel: function (wheel) {
                    if (wheel.angleDelta.y > 0) {
                        if (root.selectedIndex > 0) {
                            root.selectedIndex--;
                            root.focusSource = "keyboard";
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                    } else {
                        if (root.selectedIndex < appModel.count - 1) {
                            root.selectedIndex++;
                            root.focusSource = "keyboard";
                            listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                        }
                    }
                    wheel.accepted = true;
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vsb
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle {
                    implicitWidth: 4
                    implicitHeight: 60
                    radius: 2
                    color: vsb.pressed ? theme.clrScrollPrs : theme.clrScrollbar
                    opacity: vsb.active ? 1.0 : 0.0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                }
                background: Rectangle {
                    color: "transparent"
                }
            }

            delegate: Rectangle {
                id: row
                required property string appName
                required property string appExec
                required property string appIcon
                required property bool appTerminal
                required property string matchIndices
                required property int index

                width: listView.width
                height: theme.rowHeight
                color: "transparent"

                property bool mouseOver: false
                property bool isSel: root.focusSource === "keyboard" && index === root.selectedIndex
                property bool isHov: root.focusSource === "mouse"    && mouseOver
                property bool starred: root.isFav(appName)
                property var midxList: JSON.parse(matchIndices)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    topLeftRadius: 6
                    topRightRadius: 6
                    bottomLeftRadius: (row.isSel || row.isHov) ? 0 : 6
                    bottomRightRadius: (row.isSel || row.isHov) ? 0 : 6
                    color: row.isSel ? theme.clrSelRow : row.isHov ? theme.clrHovRow : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 80
                        }
                    }

                    Rectangle {
                        visible: row.isSel || row.isHov
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 1
                        color: theme.clrSearchFocus
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 10
                    spacing: 11

                    Item {
                        width: 20
                        height: 20
                        Layout.alignment: Qt.AlignVCenter
                        Rectangle {
                            anchors.fill: parent
                            radius: 4
                            color: root.letterColor(row.appName)
                            visible: iconImg.status !== Image.Ready
                            Text {
                                anchors.centerIn: parent
                                text: row.appName.charAt(0).toUpperCase()
                                font.pixelSize: 10
                                font.bold: true
                                color: Pal.fgOnDark
                            }
                        }
                        Image {
                            id: iconImg
                            anchors.fill: parent
                            source: row.appIcon !== "" ? ("image://icon/" + row.appIcon) : ""
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            asynchronous: true
                            visible: status === Image.Ready
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Repeater {
                                model: row.appName.length
                                Text {
                                    required property int modelData
                                    property bool isMatch: row.midxList.indexOf(modelData) !== -1
                                    text: row.appName[modelData]
                                    font.pixelSize: 13
                                    font.family: "monospace"
                                    font.bold: isMatch
                                    font.underline: isMatch
                                    color: isMatch ? theme.clrMatch : (row.isSel || row.isHov ? theme.clrTextPrim : theme.clrTextSecond)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 80
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width: 18
                        height: 18
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            anchors.centerIn: parent
                            text: row.starred ? "★" : "☆"
                            font.pixelSize: 14
                            color: row.starred ? theme.clrStar : starMa.containsMouse ? theme.clrStar : (row.isHov || row.isSel) ? theme.clrStarOff : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                        }
                        MouseArea {
                            id: starMa
                            anchors.fill: parent
                            anchors.margins: -4
                            hoverEnabled: true
                            onClicked: function (ev) {
                                root.toggleFav(row.appName);
                                ev.accepted = true;
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    anchors.rightMargin: 28
                    hoverEnabled: true
                    onEntered: { root.focusSource = "mouse"; root.selectedIndex = index; row.mouseOver = true; }
                    onExited:  row.mouseOver = false
                    onClicked: root.launch(row.appExec, row.appTerminal, row.appName)
                }
            }
        }
    }
}
