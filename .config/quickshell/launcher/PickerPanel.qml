import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// A search box over a list: the apps, emoji, time zone and wifi panels are built on it. Typing filters; Ctrl+j / Ctrl+k
// or the arrows move, Enter picks, Ctrl+s stars. Esc leaves the box (then j/k move, Space stars, / or i types again);
// with the box empty, Esc closes
LauncherPanel {
    id: root

    property string icon: "🔍"
    property int iconSize: 11
    property string iconFont: ""
    property int iconWidth: -1
    property int iconOffset: 0
    property string placeholder
    property string status
    property alias searchEnabled: searchField.enabled
    property alias delegate: list.delegate
    property var items: []
    property string itemKey: "name"
    property int selectedIndex: 0
    property string focusSource: "keyboard"
    property point lastMouse: Qt.point(-1, -1)
    readonly property alias query: searchField.text
    readonly property var current: items[selectedIndex]
    property var keyHook: null

    signal activated
    signal pick(var item)
    signal fav(var item)

    onOpened: {
        lastMouse = Qt.point(-1, -1);
        focusSource = "keyboard";
        searchField.text = "";
        selectedIndex = 0;
        list.positionViewAtBeginning();
        focusSearch();
        activated();
    }

    onKey: ev => {
        if (!searchField.activeFocus)
            handleKey(ev, false);
    }

    function focusSearch() {
        focusTimer.restart();
    }

    function setItems(a, sel) {
        if (sel === true) {
            const c = current;
            sel = c ? a.findIndex(x => x[itemKey] === c[itemKey]) : -1;
        }
        items = a;
        if (sel === undefined || sel < 0) {
            selectedIndex = 0;
            list.positionViewAtBeginning();
        } else {
            selectedIndex = Math.max(0, Math.min(sel, a.length - 1));
            list.positionViewAtIndex(selectedIndex, ListView.Contain);
        }
    }

    function move(d, src) {
        const n = selectedIndex + d;
        if (n < 0 || n >= items.length)
            return;
        focusSource = src;
        selectedIndex = n;
        list.positionViewAtIndex(n, ListView.Contain);
    }

    function handleKey(ev, typing) {
        if (keyHook && keyHook(ev, typing)) {
            ev.accepted = true;
            return;
        }
        const k = ev.key, ctrl = ev.modifiers & Qt.ControlModifier, cmd = ctrl || !typing;
        if (k === Qt.Key_Escape) {
            if (query === "")
                hideOnRelease();
            else if (typing)
                focusPanel();
            else
                searchField.text = "";
        } else if (k === Qt.Key_Return || k === Qt.Key_Enter) {
            pick(current);
        } else if (k === Qt.Key_Down || cmd && k === Qt.Key_J) {
            move(1, "keyboard");
        } else if (k === Qt.Key_Up || cmd && k === Qt.Key_K) {
            move(-1, "keyboard");
        } else if (ctrl && k === Qt.Key_S || !typing && k === Qt.Key_Space) {
            if (current)
                fav(current);
        } else if (!typing && [Qt.Key_Slash, Qt.Key_F, Qt.Key_I, Qt.Key_A].includes(k)) {
            searchField.forceActiveFocus();
        } else {
            return;
        }
        ev.accepted = true;
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: searchField.forceActiveFocus()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        SearchBox {
            theme: root.theme
            active: searchField.activeFocus

            Text {
                text: root.icon
                font.pixelSize: root.iconSize
                font.family: root.iconFont !== "" ? root.iconFont : Qt.application.font.family
                horizontalAlignment: Text.AlignHCenter
                color: searchField.activeFocus ? root.theme.clrSearchFocus : root.theme.clrSearchIcon
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: root.iconWidth
                Layout.leftMargin: root.iconOffset
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
                    leftPadding: 3
                    text: root.placeholder
                    color: root.theme.clrTextMuted
                    font.pixelSize: 12
                    font.family: "monospace"
                    verticalAlignment: Text.AlignVCenter
                    visible: searchField.text.length === 0
                    opacity: 0.5
                }
                TextInput {
                    id: searchField
                    anchors.fill: parent
                    color: root.theme.clrInputText
                    font.pixelSize: 12
                    font.family: "monospace"
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    selectByMouse: true
                    Keys.onPressed: ev => root.handleKey(ev, true)
                }
            }

            Text {
                text: root.status
                color: root.theme.clrTextMuted
                font.pixelSize: 10
                font.family: "monospace"
                Layout.alignment: Qt.AlignVCenter
                visible: text !== ""
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: root.theme.dividerH
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                height: 1
                color: searchField.activeFocus ? root.theme.clrSearchFocus : root.theme.clrDivider
                Behavior on color {
                    ColorAnimation {
                        duration: 120
                    }
                }
            }
        }

        ListView {
            id: list
            readonly property var picker: root
            Layout.fillWidth: true
            Layout.preferredHeight: root.theme.maxVisibleRows * root.theme.rowHeight
            clip: true
            model: root.items

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    root.move(wheel.angleDelta.y > 0 ? -1 : 1, "mouse");
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
                    color: vsb.pressed ? root.theme.clrScrollPrs : root.theme.clrScrollbar
                    opacity: vsb.active ? 1 : 0
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
        }

        Item {
            Layout.fillHeight: true
        }
    }
}
