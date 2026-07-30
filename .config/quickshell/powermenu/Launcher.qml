import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

QtObject {
    id: root
    default property list<MenuButton> buttons
    property bool active: false
    function toggle() {
        active = !active;
    }
    property var _window: PanelWindow {
        id: w
        visible: root.active
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        implicitWidth: screen.width
        implicitHeight: screen.height
        color: "transparent"
        onVisibleChanged: {
            if (visible)
                contentItem.forceActiveFocus();
        }
        contentItem {
            focus: root.active
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Escape) {
                    root.active = false;
                    event.accepted = true;
                    return;
                }
                for (let i = 0; i < root.buttons.length; i++) {
                    const button = root.buttons[i];
                    if (button.keybind !== null && button.keybind !== 0 && event.key === button.keybind) {
                        button.exec();
                        event.accepted = true;
                        return;
                    }
                }
            }
        }
        MouseArea {
            anchors.fill: parent
            onClicked: root.active = false
            Rectangle {
                anchors.centerIn: parent
                width: root.buttons.length * 140 + (root.buttons.length - 1) * 10 + 28
                height: 170
                color: Qt.rgba(Pal.bg.r, Pal.bg.g, Pal.bg.b, 0.95)
                radius: 18
                border.color: Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.35)
                border.width: 2
                MouseArea {
                    anchors.fill: parent
                    onClicked: contentItem.forceActiveFocus()
                }
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    Repeater {
                        model: root.buttons
                        delegate: Rectangle {
                            required property MenuButton modelData
                            required property int index
                            Component.onCompleted: modelData.launcher = root
                            width: 140
                            height: 110
                            radius: 12
                            readonly property string labelText: modelData.text.trim()
                            readonly property string iconChar: {
                                let t = labelText.toLowerCase();
                                if (t.indexOf("lock") >= 0)
                                    return "\uf023";
                                if (t.indexOf("reboot") >= 0)
                                    return "\uf021";
                                if (t.indexOf("shutdown") >= 0)
                                    return "\uf011";
                                if (t.indexOf("logout") >= 0)
                                    return "\uf2f5";
                                if (t.indexOf("suspend") >= 0)
                                    return "\uf186";
                                return "\uf1d8";
                            }
                            property bool isHovered: ma.containsMouse
                            color: isHovered ? Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.28) : Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.08)
                            border.color: isHovered ? Pal.accentAlt : Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.30)
                            border.width: isHovered ? 3 : 2
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            Behavior on border.color {
                                ColorAnimation {
                                    duration: 150
                                }
                            }
                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modelData.exec()
                                cursorShape: Qt.PointingHandCursor
                            }
                            Column {
                                anchors.centerIn: parent
                                spacing: 10
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.parent.iconChar
                                    font.pointSize: 28
                                    font.family: "Symbols Nerd Font"
                                    color: isHovered ? Pal.accentAlt : Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.75)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                                Text {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    text: parent.parent.labelText
                                    font.pointSize: 10
                                    font.letterSpacing: 1.0
                                    color: isHovered ? Pal.fgPrimary : Qt.rgba(Pal.fgSub.r, Pal.fgSub.g, Pal.fgSub.b, 0.65)
                                    Behavior on color {
                                        ColorAnimation {
                                            duration: 150
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
