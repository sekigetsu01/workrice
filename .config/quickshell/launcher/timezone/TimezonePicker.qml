import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../"

Item {
    id: root

    Theme { id: theme }

    required property var  favs
    required property var  panelRef
    property bool panelVisible: false

    signal toggleFav(string zone, string display)
    signal applied(string zone)
    signal requestClose()

        function activate() {
        searchField.text = "";
        searchQuery = "";
        selectedIndex = 0;
        focusSource = "keyboard";
        listView.positionViewAtBeginning();
        sudoOverlay.visible = false;
        sudoOverlay.pendingZone = "";
        searchFocusTimer.restart();
    }

    function handleKey(ev) {
        if (sudoOverlay.visible) return false;
        if (searchField.activeFocus) return false;
        if (ev.key === Qt.Key_J && (ev.modifiers & Qt.ControlModifier)) {
            if (selectedIndex < tzModel.count - 1) {
                selectedIndex++;
                listView.positionViewAtIndex(selectedIndex, ListView.Contain);
            }
            ev.accepted = true; return true;
        }
        if (ev.key === Qt.Key_K && (ev.modifiers & Qt.ControlModifier)) {
            if (selectedIndex > 0) {
                selectedIndex--;
                listView.positionViewAtIndex(selectedIndex, ListView.Contain);
            }
            ev.accepted = true; return true;
        }
        if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
            if (tzModel.count > 0) {
                var itm = tzModel.get(selectedIndex);
                root.toggleFav(itm.tzZone, itm.tzDisplay);
            }
            ev.accepted = true; return true;
        }
        if (ev.key === Qt.Key_F || ev.key === Qt.Key_I || ev.key === Qt.Key_A) {
            searchField.forceActiveFocus(); ev.accepted = true; return true;
        }
        return false;
    }

    function applySelected() {
        if (tzModel.count === 0) return;
        var zone = tzModel.get(selectedIndex).tzZone;
        sudoOverlay.pendingZone = zone;
        sudoOverlay.errorMsg = "";
        sudoField.text = "";
        sudoOverlay.visible = true;
        sudoFocusTimer.restart();
    }

    function isFav(zone, display) { return !!root.favs[display || zone]; }

                function timeFromOffset(offsetSecs) {
        var now = new Date();
        var utcMs = now.getTime() + now.getTimezoneOffset() * 60000;
        var local = new Date(utcMs + offsetSecs * 1000);
        var h = local.getHours();
        var m = local.getMinutes();
        return (h < 10 ? "0" + h : "" + h) + ":" + (m < 10 ? "0" + m : "" + m);
    }

        Timer {
        id: clockTick
        interval: 10000
        repeat: true
        running: panelVisible
        triggeredOnStart: true
        onTriggered: root.clockEpoch++
    }
    property int clockEpoch: 0

        property var    allZones:    []
    property int    selectedIndex: 0
        property string focusSource:      "keyboard"
    property string searchQuery: ""
    property bool   loading:     true
    ListModel { id: tzModel }

    Timer { id: searchFocusTimer; interval: 30; onTriggered: searchField.forceActiveFocus() }
    Timer { id: sudoFocusTimer;   interval: 30; onTriggered: sudoField.forceActiveFocus() }

        Process {
        id: listProc
        running: true
        command: ["python3",
            Qt.resolvedUrl("./timezone-list.py").toString().replace("file://", "")]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "") return;

                                var offsetSecs = 0;
                var atIdx = line.lastIndexOf("@@");
                if (atIdx !== -1) {
                    offsetSecs = parseInt(line.substring(atIdx + 2).trim(), 10) || 0;
                    line = line.substring(0, atIdx).trim();
                }

                var display, zone;
                var arrowIdx = line.indexOf("→");
                if (arrowIdx !== -1) {
                    display = line.substring(0, arrowIdx).trim();
                    zone    = line.substring(arrowIdx + 1).trim();
                } else {
                    var spIdx = line.indexOf("  ");
                    zone    = spIdx !== -1 ? line.substring(0, spIdx).trim() : line.trim();
                    display = line.trim();
                }

                var arr = root.allZones;
                arr.push({ display: display, zone: zone, offset: offsetSecs });
                root.allZones = arr;
            }
        }
        onExited: function() {
            root.loading = false;
            root._rebuildModel();
        }
    }

        function fuzzyMatch(query, target) {
        var q = query.toLowerCase(), t = target.toLowerCase(), qi = 0, indices = [];
        for (var ti = 0; ti < t.length && qi < q.length; ti++)
            if (t[ti] === q[qi]) { indices.push(ti); qi++; }
        if (qi < q.length) return null;
        var score = 0, consecutive = 1;
        for (var i = 0; i < indices.length; i++) {
            score++;
            if (i > 0 && indices[i] === indices[i-1]+1) { consecutive++; score += consecutive * 3; }
            else { consecutive = 1; }
            if (indices[i] === 0) { score += 8; }
            else {
                var prev = t[indices[i]-1];
                if (prev === " " || prev === "-" || prev === "." || prev === "_") score += 6;
            }
        }
        score -= t.length * 0.01;
        return { score: score, indices: indices };
    }

    function _rebuildModel() {
        var q = searchQuery.trim();
        var results = [];
        for (var i = 0; i < allZones.length; i++) {
            var e = allZones[i];
            if (q === "") {
                results.push({ e: e, score: 0, indices: [] });
            } else {
                var m = fuzzyMatch(q, e.display);
                if (m) results.push({ e: e, score: m.score, indices: m.indices });
            }
        }
        results.sort(function(a, b) {
            var fd = (isFav(b.e.zone, b.e.display) ? 1 : 0) - (isFav(a.e.zone, a.e.display) ? 1 : 0);
            if (fd !== 0) return fd;
            if (q !== "" && b.score !== a.score) return b.score - a.score;
            return a.e.display.localeCompare(b.e.display);
        });
        selectedIndex = 0;
        focusSource = "keyboard";
        tzModel.clear();
        for (var j = 0; j < results.length; j++)
            tzModel.append({
                tzDisplay: results[j].e.display,
                tzZone:    results[j].e.zone,
                tzOffset:  results[j].e.offset,
                tzIndices: JSON.stringify(results[j].indices)
            });
        listView.positionViewAtBeginning();
    }

        Process {
        id: applyProc
        property string zone: ""
        onExited: function(code) {
            sudoField.text = "";
            if (code === 0) {
                sudoOverlay.visible = false;
                notifyProc.command = ["notify-send", "🌍 Timezone Changed", "Now using " + applyProc.zone];
                notifyProc.running = true;
                root.applied(applyProc.zone);
                root.requestClose();
            } else {
                sudoOverlay.errorMsg = "Incorrect password — try again";
                sudoFocusTimer.restart();
            }
        }
    }

    Process { id: notifyProc; command: ["notify-send", ""] }

        Item {
        id: mainContent
        anchors.fill: parent

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

                    Rectangle {
                        anchors.fill: parent
                        radius: 6; color: "transparent"
                        border.color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
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
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Text {
                                anchors.fill: parent
                                text: root.loading ? "Loading timezones…" : "Search timezone, country, city…"
                                color: theme.clrTextMuted
                                font.pixelSize: 12; font.family: "monospace"
                                verticalAlignment: Text.AlignVCenter
                                visible: searchField.text.length === 0
                                opacity: 0.5
                            }
                            TextInput {
                                id: searchField
                                anchors.fill: parent
                                color: theme.clrInputText
                                font.pixelSize: 12; font.family: "monospace"
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true; selectByMouse: true
                                enabled: !root.loading && !sudoOverlay.visible
                                onTextChanged: {
                                    root.searchQuery = text;
                                    root._rebuildModel();
                                }
                                Keys.onEscapePressed: function(ev) {
                                    if (text === "") root.requestClose();
                                    else root.panelRef.forceActiveFocus();
                                    ev.accepted = true;
                                }
                                Keys.onReturnPressed: function(ev) {
                                    root.applySelected(); ev.accepted = true;
                                }
                                Keys.onPressed: function(ev) {
                                    if ((ev.key === Qt.Key_J || ev.key === Qt.Key_Down) && (ev.modifiers & Qt.ControlModifier)) {
                                        if (root.selectedIndex < tzModel.count - 1) { root.selectedIndex++; root.focusSource = "keyboard"; listView.positionViewAtIndex(root.selectedIndex, ListView.Contain); }
                                        ev.accepted = true;
                                    } else if ((ev.key === Qt.Key_K || ev.key === Qt.Key_Up) && (ev.modifiers & Qt.ControlModifier)) {
                                        if (root.selectedIndex > 0) { root.selectedIndex--; root.focusSource = "keyboard"; listView.positionViewAtIndex(root.selectedIndex, ListView.Contain); }
                                        ev.accepted = true;
                                    } else if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
                                        if (tzModel.count > 0) { var si = tzModel.get(root.selectedIndex); root.toggleFav(si.tzZone, si.tzDisplay); }
                                        ev.accepted = true;
                                    }
                                }
                            }
                        }

                        Text {
                            text: tzModel.count + " results"
                            color: theme.clrTextMuted
                            font.pixelSize: 10; font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                            visible: !root.loading && tzModel.count > 0
                        }
                    }
                }
            }

                        Item {
                Layout.fillWidth: true
                height: theme.dividerH
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    height: 1
                    color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrDivider
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }

                        ListView {
                id: listView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true; spacing: 0
                model: tzModel
                topMargin: theme.dividerH / 2
                bottomMargin: 0

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    propagateComposedEvents: true
                    onWheel: function(wheel) {
                        if (wheel.angleDelta.y > 0) {
                            if (root.selectedIndex > 0) { root.selectedIndex--; root.focusSource = "keyboard"; listView.positionViewAtIndex(root.selectedIndex, ListView.Contain); }
                        } else {
                            if (root.selectedIndex < tzModel.count - 1) { root.selectedIndex++; root.focusSource = "keyboard"; listView.positionViewAtIndex(root.selectedIndex, ListView.Contain); }
                        }
                        wheel.accepted = true;
                    }
                }

                ScrollBar.vertical: ScrollBar {
                    id: vsb
                    policy: ScrollBar.AsNeeded; width: 4
                    contentItem: Rectangle {
                        implicitWidth: 4; implicitHeight: 60; radius: 2
                        color: vsb.pressed ? theme.clrScrollPrs : theme.clrScrollbar
                        opacity: vsb.active ? 1.0 : 0.0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    background: Rectangle { color: "transparent" }
                }

                delegate: Rectangle {
                    id: row
                    required property int    index
                    required property string tzDisplay
                    required property string tzZone
                    required property int    tzOffset
                    required property string tzIndices

                    width: listView.width
                    height: theme.rowHeight
                    color: "transparent"

                    property bool mouseOver: false
                    property bool isSel:    root.focusSource === "keyboard" && index === root.selectedIndex
                    property bool isHov:    root.focusSource === "mouse"    && mouseOver
                    property bool starred:  root.isFav(tzZone, tzDisplay)
                    property var  midxList: JSON.parse(tzIndices)

                                        property string liveTime: root.timeFromOffset(tzOffset)
                    property int _epoch: root.clockEpoch
                    on_EpochChanged: liveTime = root.timeFromOffset(tzOffset)

                    Rectangle {
                        anchors.fill: parent
                        anchors.leftMargin: 10; anchors.rightMargin: 10
                        topLeftRadius: 6; topRightRadius: 6
                        bottomLeftRadius:  (row.isSel || row.isHov) ? 0 : 6
                        bottomRightRadius: (row.isSel || row.isHov) ? 0 : 6
                        color: row.isSel ? theme.clrSelRow : row.isHov ? theme.clrHovRow : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Rectangle {
                            visible: row.isSel || row.isHov
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left; anchors.right: parent.right
                            height: 1; color: theme.clrSearchFocus
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 10
                        spacing: 11

                        Text {
                            text: "🌍"; font.pixelSize: 14
                            Layout.alignment: Qt.AlignVCenter
                        }

                                                Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0
                                Repeater {
                                    model: row.tzDisplay.length
                                    Text {
                                        required property int modelData
                                        property bool isMatch: row.midxList.indexOf(modelData) !== -1
                                        text: row.tzDisplay[modelData]
                                        font.pixelSize: 13; font.family: "monospace"
                                        font.bold: isMatch; font.underline: isMatch
                                        color: isMatch ? theme.clrMatch
                                             : (row.isSel || row.isHov ? theme.clrTextPrim : theme.clrTextSecond)
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                    }
                                }
                            }
                        }

                                                Text {
                            text: row.liveTime
                            font.pixelSize: 13; font.family: "monospace"
                            color: row.isSel ? theme.clrSearchFocus : theme.clrTextMuted
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 80 } }
                        }

                                                Item {
                            width: 18; height: 18
                            Layout.alignment: Qt.AlignVCenter
                            Text {
                                anchors.centerIn: parent
                                text: row.starred ? "★" : "☆"
                                font.pixelSize: 14
                                color: row.starred          ? theme.clrStar
                                     : starMa.containsMouse ? theme.clrStar
                                     : (row.isHov || row.isSel) ? theme.clrStarOff
                                     : "transparent"
                                Behavior on color { ColorAnimation { duration: 100 } }
                            }
                            MouseArea {
                                id: starMa
                                anchors.fill: parent; anchors.margins: -4
                                hoverEnabled: true
                                onClicked: function(ev) {
                                    root.toggleFav(row.tzZone, row.tzDisplay); ev.accepted = true;
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent; anchors.rightMargin: 28
                        hoverEnabled: true
                        onEntered: { root.focusSource = "mouse"; root.selectedIndex = index; row.mouseOver = true; }
                        onExited:  row.mouseOver = false
                        onClicked: root.applySelected()
                    }
                }
            }
        }
    }

        Rectangle {
        id: sudoOverlay
        anchors.fill: parent
        color: theme.clrBg
        radius: 4
        visible: false
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        property string pendingZone: ""
        property string errorMsg:    ""

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
                    text: "sudo password required"
                    color: theme.clrTextPrim
                    font.pixelSize: 13; font.family: "monospace"
                    font.bold: true
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: sudoOverlay.pendingZone !== ""
                        ? "Setting timezone to: " + sudoOverlay.pendingZone
                        : ""
                    color: theme.clrTextMuted
                    font.pixelSize: 11; font.family: "monospace"
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    wrapMode: Text.WordWrap
                }
            }

            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: "transparent"
                border.color: sudoField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                border.width: 1
                Behavior on border.color { ColorAnimation { duration: 120 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
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
                        font.pixelSize: 12; font.family: "monospace"
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        enabled: sudoOverlay.visible && !applyProc.running

                        Keys.onReturnPressed: function(ev) { doApply(); ev.accepted = true; }
                        Keys.onEscapePressed: function(ev) {
                            sudoField.text = "";
                            sudoOverlay.visible = false;
                            sudoOverlay.errorMsg = "";
                            searchFocusTimer.restart();
                            ev.accepted = true;
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: sudoOverlay.errorMsg
                color: theme.clrCalcError
                font.pixelSize: 11; font.family: "monospace"
                visible: sudoOverlay.errorMsg !== ""
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                Rectangle {
                    Layout.fillWidth: true
                    height: 32; radius: 6
                    color: cancelMa.containsMouse ? theme.clrHovRow : "transparent"
                    border.color: theme.clrBorder; border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: "Cancel"; color: theme.clrTextSecond; font.pixelSize: 12; font.family: "monospace" }
                    MouseArea {
                        id: cancelMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: { sudoField.text = ""; sudoOverlay.visible = false; sudoOverlay.errorMsg = ""; searchFocusTimer.restart(); }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 32; radius: 6
                    color: applyBtnMa.containsMouse
                        ? Qt.rgba(theme.clrSearchFocus.r, theme.clrSearchFocus.g, theme.clrSearchFocus.b, 0.25)
                        : Qt.rgba(theme.clrSearchFocus.r, theme.clrSearchFocus.g, theme.clrSearchFocus.b, 0.15)
                    border.color: theme.clrSearchFocus; border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Text { anchors.centerIn: parent; text: applyProc.running ? "Applying…" : "Apply"; color: theme.clrSearchFocus; font.pixelSize: 12; font.family: "monospace"; font.bold: true }
                    MouseArea { id: applyBtnMa; anchors.fill: parent; hoverEnabled: true; enabled: !applyProc.running; onClicked: doApply() }
                }
            }
        }
    }

        function doApply() {
        if (applyProc.running) return;
        var pw   = sudoField.text;
        var zone = sudoOverlay.pendingZone;
        applyProc.zone = zone;
        applyProc.command = [
            "sh", "-c",
            "printf '%s\n' " + shellEscape(pw) +
            " | sudo -S ln -sf /usr/share/zoneinfo/" + zone + " /etc/localtime 2>/dev/null"
        ];
        applyProc.running = true;
    }

    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'";
    }
}
