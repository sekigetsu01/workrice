import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../"

// a row of buttons: each one's key, or 1-9 by position; Esc or a click outside closes
QtObject {
    id: root
    default property list<MenuButton> buttons
    property bool active: false
    property bool escClose: false
    function toggle() {
        active = !active;
    }
    function run(button) {
        active = false;
        button.exec();
    }
    readonly property var icons: ({ lock: "", reboot: "", shutdown: "" })
    function tint(a) {
        return Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, a);
    }

    property var _window: PanelWindow {
        id: w
        visible: root.active
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: "transparent"
        onVisibleChanged: {
            if (visible)
                contentItem.forceActiveFocus();
        }
        contentItem {
            focus: root.active
            Keys.onPressed: event => {
                const n = event.key - Qt.Key_1;
                let b = n >= 0 && n < 9 ? root.buttons[n] : null;
                for (let i = 0; !b && event.key && i < root.buttons.length; i++)
                    if (root.buttons[i].keybind === event.key)
                        b = root.buttons[i];
                if (event.key === Qt.Key_Escape)
                    root.escClose = true;  // closes on the release, so the app underneath doesn't get it too
                else if (b)
                    root.run(b);
                else
                    return;
                event.accepted = true;
            }
            Keys.onReleased: event => {
                if (event.key === Qt.Key_Escape && root.escClose && !event.isAutoRepeat) {
                    root.escClose = false;
                    root.active = false;
                    event.accepted = true;
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.active = false
            Rectangle {
                anchors.centerIn: parent
                width: row.implicitWidth + 28
                height: 150
                color: Pal.bg
                radius: 18
                border.color: root.tint(0.35)
                border.width: 2
                MouseArea {
                    anchors.fill: parent
                }
                RowLayout {
                    id: row
                    anchors.centerIn: parent
                    spacing: 10
                    Repeater {
                        model: root.buttons
                        delegate: Rectangle {
                            id: btn
                            required property MenuButton modelData
                            readonly property string label: modelData.text.trim()
                            readonly property bool hovered: ma.containsMouse
                            implicitWidth: 120
                            implicitHeight: 90
                            radius: 12
                            color: root.tint(hovered ? 0.28 : 0.08)
                            border.color: hovered ? Pal.accentAlt : root.tint(0.30)
                            border.width: hovered ? 3 : 2
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.run(btn.modelData)
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.modelData.icon || (root.icons[btn.label.toLowerCase()] ?? "")
                                    font.pointSize: 28
                                    font.family: "Symbols Nerd Font"
                                    scale: btn.modelData.iconScale
                                    color: btn.hovered ? Pal.accentAlt : root.tint(0.75)
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: btn.label
                                    font.pointSize: 10
                                    font.letterSpacing: 1.0
                                    color: btn.hovered ? Pal.fgPrimary : Qt.rgba(Pal.fgSub.r, Pal.fgSub.g, Pal.fgSub.b, 0.65)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
