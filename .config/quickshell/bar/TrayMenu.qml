import QtQuick
import Quickshell
import "../"
import "fmt.js" as F

// A tray icon's menu and its submenus (right-click the icon on the bar). Up/Down or Tab move, Enter or Right picks
// or opens a submenu, Left or Esc goes back.
PopupWindow {
    id: menu

    property var handle: null
    property var root: menu
    property var parentMenu: null
    property int current: -1
    property int openIndex: -1
    readonly property var entries: opener.children ? opener.children.values : []

    function open(win, x, y) {
        anchor.window = win;
        anchor.rect.x = x;
        anchor.rect.y = y;
        current = -1;
        visible = true;
    }

    function closeAll() {
        root.visible = false;
    }

    function step(d) {
        const n = entries.length;
        for (let i = 1; i <= n; i++) {
            const j = ((current < 0 && d < 0 ? n : current) + d * i + n * 2) % n;
            if (!entries[j].isSeparator && entries[j].enabled) {
                current = j;
                return;
            }
        }
    }

    function activate(i) {
        const e = entries[i];
        if (!e || e.isSeparator || !e.enabled)
            return;
        if (e.hasChildren) {
            openIndex = i;
            return;
        }
        e.triggered();
        closeAll();
    }

    grabFocus: root === menu
    color: "transparent"
    readonly property int widest: {
        let w = 0;
        for (const c of col.children)
            w = Math.max(w, c.implicitWidth || 0);
        return w;
    }

    implicitWidth: Math.max(52, widest)
    implicitHeight: col.implicitHeight + 8
    onVisibleChanged: if (!visible) openIndex = -1

    QsMenuOpener {
        id: opener
        menu: menu.handle
    }

    Rectangle {
        anchors.fill: parent
        color: Pal.bg
        border.width: 1
        border.color: Pal.borderSurface
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => e.accepted = menu.key(e.key)
        Keys.onReleased: e => {
            if (e.key === Qt.Key_Escape && menu.escClose && !e.isAutoRepeat) {
                menu.escClose = false;
                menu.visible = false;
                e.accepted = true;
            }
        }
    }
    property bool escClose: false

    function key(k) {
        if (sub.item && sub.item.visible)
            return sub.item.key(k);
        if (k === Qt.Key_Down || k === Qt.Key_Tab) step(1);
        else if (k === Qt.Key_Up || k === Qt.Key_Backtab) step(-1);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter || k === Qt.Key_Space || k === Qt.Key_Right) activate(current);
        else if (k === Qt.Key_Escape || k === Qt.Key_Left) {
            if (parentMenu) parentMenu.openIndex = -1;
            else if (k === Qt.Key_Escape) escClose = true;
            else visible = false;
        } else return false;
        return true;
    }

    Column {
        id: col
        y: 4
        width: menu.width

        Repeater {
            model: menu.entries

            Item {
                id: row
                required property var modelData
                required property int index
                readonly property bool sel: menu.current === index && !modelData.isSeparator && modelData.enabled
                readonly property bool check: modelData.buttonType !== QsMenuButtonType.None

                width: col.width
                implicitWidth: modelData.isSeparator ? 0 : 12 + (check ? 20 : 0) + (modelData.icon ? 22 : 0) + label.implicitWidth + (modelData.hasChildren ? 20 : 0)
                height: modelData.isSeparator ? 7 : 24

                Rectangle {
                    visible: row.modelData.isSeparator
                    y: 3
                    width: parent.width
                    height: 1
                    color: Pal.borderSurface
                }

                Rectangle {
                    anchors.fill: parent
                    visible: row.sel || menu.openIndex === row.index
                    color: Pal.over(Pal.color4, 0.35)
                }

                BarText {
                    visible: row.check
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.checkState === Qt.Checked ? (row.modelData.buttonType === QsMenuButtonType.RadioButton ? "●" : "✔") : ""
                    color: label.color
                }

                Image {
                    visible: row.modelData.icon !== "" && !row.modelData.isSeparator
                    x: 6 + (row.check ? 20 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    width: 16
                    height: 16
                    sourceSize.width: 16
                    sourceSize.height: 16
                    source: row.modelData.icon
                }

                BarText {
                    id: label
                    visible: !row.modelData.isSeparator
                    x: 6 + (row.check ? 20 : 0) + (row.modelData.icon ? 22 : 0)
                    anchors.verticalCenter: parent.verticalCenter
                    text: F.menuText(row.modelData.text)
                    color: row.modelData.enabled ? Pal.fg : Pal.color8
                }

                BarText {
                    visible: row.modelData.hasChildren
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    text: "▸"
                    color: label.color
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: {
                        menu.current = row.index;
                        if (row.modelData.hasChildren && row.modelData.enabled) menu.openIndex = row.index;
                        else if (menu.openIndex !== row.index) menu.openIndex = -1;
                    }
                    onClicked: menu.activate(row.index)
                }
            }
        }
    }

    onOpenIndexChanged: {
        if (sub.item && openIndex >= 0 && sub.loadedFor !== openIndex) {
            sub.reloading = true;
            sub.reloading = false;
        }
    }

    Loader {
        id: sub
        property int loadedFor: -1
        property bool reloading: false
        active: menu.openIndex >= 0 && menu.visible && !reloading
        source: "TrayMenu.qml"
        onLoaded: {
            loadedFor = menu.openIndex;
            const e = menu.entries[menu.openIndex];
            let y = 4;
            for (let i = 0; i < menu.openIndex; i++) y += menu.entries[i].isSeparator ? 7 : 24;
            item.root = menu.root;
            item.parentMenu = menu;
            item.handle = e;
            item.open(menu, menu.width, y - 4);
        }
    }
}
