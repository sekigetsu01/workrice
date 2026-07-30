import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../"

Item {
    id: root

    Theme { id: theme }

    required property var    emojisFavs
    required property var    panelRef

    signal picked(string emoji)
    signal toggleFav(string emoji, string desc)
    signal requestClose()

    function activate() {
        searchField.text = "";
        if (allEmojis.length === 0) {
            loadProc.running = true;
        } else {
            _buildModel("");
        }
        selectedIndex = 0;
        focusSource = "keyboard";
        listView.positionViewAtBeginning();
        emojiSearchFocusTimer.restart();
    }

    Timer {
        id: emojiSearchFocusTimer
        interval: 30
        onTriggered: searchField.forceActiveFocus()
    }

    property var    allEmojis:    []
    property int    selectedIndex: 0
        property string focusSource:      "keyboard"
    property string currentQuery: ""

    Process {
        id: loadProc
        running: false
        command: ["sh", "-c",
            "EMOJI_FILE=\"${XDG_DATA_HOME:-$HOME/.local/share/characters}/emojis\";" +
            "[ -f \"$EMOJI_FILE\" ] && cat \"$EMOJI_FILE\" || true"]
        onRunningChanged: function() { if (running) root.allEmojis = []; }
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim();
                if (t === "") return;
                var sp = t.indexOf(" ");
                if (sp < 1) return;
                var emojis = root.allEmojis;
                emojis.push({ emoji: t.substring(0, sp), desc: t.substring(sp + 1).trim() });
                root.allEmojis = emojis;
            }
        }
        onExited: function() { root._buildModel(root.currentQuery); }
    }

    function _buildModel(q) {
        root.currentQuery = q;
        var trimmed = q.trim();
        emojiModel.clear();

        if (trimmed === "") {
            var saved = [], unsaved = [];
            for (var i = 0; i < allEmojis.length; i++) {
                if (root.isEmojiSaved(allEmojis[i].emoji))
                    saved.push(allEmojis[i]);
                else
                    unsaved.push(allEmojis[i]);
            }
            var ordered = saved.concat(unsaved);
            for (var j = 0; j < ordered.length; j++)
                emojiModel.append({ emojiChar: ordered[j].emoji, emojiDesc: ordered[j].desc, emojiIndices: "[]" });
        } else {
            var results = [];
            for (var k = 0; k < allEmojis.length; k++) {
                var m = fuzzyMatch(trimmed, allEmojis[k].desc);
                if (m) results.push({ emoji: allEmojis[k].emoji, desc: allEmojis[k].desc, score: m.score, indices: m.indices });
            }
            results.sort(function(a, b) {
                var fd = (root.isEmojiSaved(b.emoji) ? 1 : 0) - (root.isEmojiSaved(a.emoji) ? 1 : 0);
                return fd !== 0 ? fd : b.score - a.score;
            });
            for (var l = 0; l < results.length; l++)
                emojiModel.append({ emojiChar: results[l].emoji, emojiDesc: results[l].desc, emojiIndices: JSON.stringify(results[l].indices) });
        }

        root.selectedIndex = 0;
        focusSource = "keyboard";
        listView.positionViewAtBeginning();
    }

    function refresh() { _buildModel(currentQuery); }

    function isEmojiSaved(emoji) { return !!root.emojisFavs[emoji]; }

    function pickSelected() {
        if (emojiModel.count > 0)
            root.picked(emojiModel.get(root.selectedIndex).emojiChar);
    }

    function fuzzyMatch(query, target) {
        var q = query.toLowerCase(), t = target.toLowerCase(), qi = 0, indices = [];
        for (var ti = 0; ti < t.length && qi < q.length; ti++)
            if (t[ti] === q[qi]) { indices.push(ti); qi++; }
        if (qi < q.length) return null;
        var score = 0, consecutive = 1;
        for (var i = 0; i < indices.length; i++) {
            score++;
            if (i > 0 && indices[i] === indices[i-1]+1) { consecutive++; score += consecutive * 3; } else { consecutive = 1; }
            if (indices[i] === 0) { score += 8; } else {
                var prev = t[indices[i]-1];
                if (prev === " " || prev === "-" || prev === "." || prev === "_") score += 6;
            }
        }
        score -= t.length * 0.01;
        return { score: score, indices: indices };
    }

    ListModel { id: emojiModel }

    function handleKey(ev) {
        if (searchField.activeFocus) return false;

        if (ev.key === Qt.Key_J && (ev.modifiers & Qt.ControlModifier)) {
            if (root.selectedIndex < emojiModel.count - 1) {
                root.selectedIndex++;
                root.focusSource = "keyboard";
                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            }
            ev.accepted = true; return true;
        }
        if (ev.key === Qt.Key_K && (ev.modifiers & Qt.ControlModifier)) {
            if (root.selectedIndex > 0) {
                root.selectedIndex--;
                root.focusSource = "keyboard";
                listView.positionViewAtIndex(root.selectedIndex, ListView.Contain);
            }
            ev.accepted = true; return true;
        }
        if (ev.key === Qt.Key_F || ev.key === Qt.Key_I || ev.key === Qt.Key_A) { searchField.forceActiveFocus(); ev.accepted = true; return true; }
        if (ev.key === Qt.Key_Space) { pickSelected(); ev.accepted = true; return true; }
        if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
            if (emojiModel.count > 0) {
                var e = emojiModel.get(root.selectedIndex);
                root.toggleFav(e.emojiChar, e.emojiDesc);
            }
            ev.accepted = true; return true;
        }
        return false;
        return false;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        Item {
            Layout.fillWidth: true
            height: theme.searchBarH

            Item {
                anchors.fill: parent
                anchors.topMargin:    10
                anchors.bottomMargin: 0
                anchors.leftMargin:   10
                anchors.rightMargin:  10

                Rectangle {
                    anchors.fill: parent
                    radius: 6; color: "transparent"
                    border.color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin:  10
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
                            text: "Search emojis..."
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
                            onTextChanged: root._buildModel(text)
                            Keys.onEscapePressed: function(ev) { root.panelRef.forceActiveFocus(); ev.accepted = true; }
                            Keys.onReturnPressed: function(ev) { if (emojiModel.count > 0) root.pickSelected(); ev.accepted = true; }
                            Keys.onPressed: function(ev) {
                                if ((ev.key === Qt.Key_J || ev.key === Qt.Key_Down) && (ev.modifiers & Qt.ControlModifier)) {
                                    if (root.selectedIndex < emojiModel.count - 1) {
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
                                    if (emojiModel.count > 0) {
                                        var e = emojiModel.get(root.selectedIndex);
                                        root.toggleFav(e.emojiChar, e.emojiDesc);
                                    }
                                    ev.accepted = true;
                                }
                            }
                        }
                    }

                    Text {
                        text: emojiModel.count + " emojis"
                        color: theme.clrTextMuted
                        font.pixelSize: 10; font.family: "monospace"
                        Layout.alignment: Qt.AlignVCenter
                        visible: emojiModel.count > 0
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
            clip: true
            spacing: 0
            model: emojiModel
            topMargin: theme.dividerH / 2
            bottomMargin: 0

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                propagateComposedEvents: true
                onWheel: function(wheel) {
                    if (wheel.angleDelta.y > 0) { if (root.selectedIndex > 0)                  { root.selectedIndex--; listView.positionViewAtIndex(root.selectedIndex, ListView.Contain); } }
                    else                         { if (root.selectedIndex < emojiModel.count-1) { root.selectedIndex++; listView.positionViewAtIndex(root.selectedIndex, ListView.Contain); } }
                    wheel.accepted = true;
                }
            }

            ScrollBar.vertical: ScrollBar {
                id: vsb
                policy: ScrollBar.AsNeeded
                width: 4
                contentItem: Rectangle {
                    implicitWidth: 4; implicitHeight: 60; radius: 2
                    color: vsb.pressed ? theme.clrScrollPrs : theme.clrScrollbar
                    opacity: vsb.active ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                }
                background: Rectangle { color: "transparent" }
            }

            delegate: Rectangle {
                id: emojiRow
                required property int    index
                required property string emojiChar
                required property string emojiDesc
                required property string emojiIndices

                width: listView.width
                height: theme.rowHeight
                color: "transparent"

                property bool mouseOver: false
                property bool isSel:   root.focusSource === "keyboard" && index === root.selectedIndex
                property bool isHov:   root.focusSource === "mouse"    && mouseOver
                property bool saved:   root.isEmojiSaved(emojiChar)
                property var midxList: JSON.parse(emojiIndices)

                Rectangle {
                    anchors.fill: parent
                    anchors.leftMargin: 10; anchors.rightMargin: 10
                    topLeftRadius: 6
                    topRightRadius: 6
                    bottomLeftRadius: (emojiRow.isSel || emojiRow.isHov) ? 0 : 6
                    bottomRightRadius: (emojiRow.isSel || emojiRow.isHov) ? 0 : 6
                    color: emojiRow.isSel ? theme.clrSelRow : emojiRow.isHov ? theme.clrHovRow : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    Rectangle {
                        visible: emojiRow.isSel || emojiRow.isHov
                        anchors.bottom: parent.bottom
                        anchors.left: parent.left; anchors.right: parent.right
                        height: 1
                        color: theme.clrSearchFocus
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin:  14
                    anchors.rightMargin: 10
                    spacing: 11

                    Item {
                        width: 20; height: 20
                        Layout.alignment: Qt.AlignVCenter
                        Text { anchors.centerIn: parent; text: emojiRow.emojiChar; font.pixelSize: 16 }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            Repeater {
                                model: emojiRow.emojiDesc.length
                                Text {
                                    required property int modelData
                                    property bool isMatch: emojiRow.midxList.indexOf(modelData) !== -1
                                    text: emojiRow.emojiDesc[modelData]
                                    font.pixelSize: 13; font.family: "monospace"
                                    font.bold: isMatch; font.underline: isMatch
                                    color: isMatch ? theme.clrMatch : (emojiRow.isSel || emojiRow.isHov ? theme.clrTextPrim : theme.clrTextSecond)
                                    Behavior on color { ColorAnimation { duration: 80 } }
                                }
                            }
                        }
                    }

                    Item {
                        width: 18; height: 18
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            anchors.centerIn: parent
                            text: emojiRow.saved ? "★" : "☆"
                            font.pixelSize: 14
                            color: emojiRow.saved ? theme.clrStar
                                 : starMa.containsMouse ? theme.clrStar
                                 : (emojiRow.isHov || emojiRow.isSel) ? theme.clrStarOff
                                 : "transparent"
                            Behavior on color { ColorAnimation { duration: 100 } }
                        }
                        MouseArea {
                            id: starMa
                            anchors.fill: parent; anchors.margins: -4
                            hoverEnabled: true
                            onClicked: function(ev) {
                                root.toggleFav(emojiRow.emojiChar, emojiRow.emojiDesc);
                                ev.accepted = true;
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent; anchors.rightMargin: 28
                    hoverEnabled: true
                    onEntered: { root.focusSource = "mouse"; root.selectedIndex = index; emojiRow.mouseOver = true; }
                    onExited:  emojiRow.mouseOver = false
                    onClicked: root.picked(emojiRow.emojiChar)
                }
            }
        }
    }
}
