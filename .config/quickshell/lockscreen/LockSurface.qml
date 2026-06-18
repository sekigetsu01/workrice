import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../"

Rectangle {
    id: root
    required property LockContext context

    property string wallpaperPath: ""
    property var theme: ({
            clock: "#4B0082",
            locked: "#7675C4",
            verticalOffset: -75
        })

    Process {
        id: wallpaperPicker
        command: ["bash", Quickshell.env("HOME") + "/.config/quickshell/lockscreen/wallpapers/picker.sh"]
        running: false
        stdout: SplitParser {
            onRead: line => {
                const parts = line.trim().split("|");
                root.wallpaperPath = parts[0];
                root.theme = {
                    clock: parts[1],
                    locked: parts[2],
                    verticalOffset: parseInt(parts[3])
                };
            }
        }
    }

    Component.onCompleted: {
        wallpaperPicker.running = true
    }

    Connections {
        target: root.context
        function onRunningChanged() {
            if (root.context.running && !wallpaperPicker.running) {
                wallpaperPicker.running = true
            }
        }
    }

    Image {
        anchors.fill: parent
        source: root.wallpaperPath ? "file://" + root.wallpaperPath : ""
        fillMode: Image.PreserveAspectCrop
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.theme.verticalOffset
        spacing: 2

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: clockText.implicitWidth
            implicitHeight: clockText.implicitHeight

            Repeater {
                model: [[-2, -2], [2, -2], [-2, 2], [2, 2], [-3, 0], [3, 0], [0, -3], [0, 3]]
                Text {
                    font.pointSize: 75
                    font.weight: Font.Black
                    color: "#000000"
                    x: modelData[0]
                    y: modelData[1]
                    text: clockText.text
                }
            }

            Text {
                id: clockText
                font.pointSize: 75
                font.weight: Font.Black
                color: root.theme.clock
                text: {
                    const h = root.context.now.getHours().toString().padStart(2, '0');
                    const m = root.context.now.getMinutes().toString().padStart(2, '0');
                    return h + ":" + m;
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -8
            implicitWidth: dateText.implicitWidth
            implicitHeight: dateText.implicitHeight

            Repeater {
                model: [[-1, -1], [1, -1], [-1, 1], [1, 1]]
                Text {
                    font.pointSize: 14
                    font.weight: Font.Bold
                    color: "#000000"
                    x: modelData[0]
                    y: modelData[1]
                    text: dateText.text
                }
            }

            Text {
                id: dateText
                font.pointSize: 14
                font.weight: Font.Bold
                color: root.theme.locked
                text: {
                    const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
                    const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
                    const d = root.context.now;
                    return days[d.getDay()] + ", " + d.getDate() + " " + months[d.getMonth()] + " " + d.getFullYear();
                }
            }
        }

        Rectangle {
            id: passwordBox
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6
            width: 340
            height: 44
            color: "#262525"
            radius: 8
            border.width: (root.context.showSuccess || root.context.showFailure) ? 1.5 : 0
            border.color: root.context.showSuccess ? "#00c44f" : root.context.showFailure ? "#e53935" : "transparent"

            property real shakeOffset: 0
            x: shakeOffset

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation {
                    target: passwordBox
                    property: "shakeOffset"
                    to: -10
                    duration: 50
                }
                NumberAnimation {
                    target: passwordBox
                    property: "shakeOffset"
                    to: 10
                    duration: 50
                }
                NumberAnimation {
                    target: passwordBox
                    property: "shakeOffset"
                    to: -8
                    duration: 50
                }
                NumberAnimation {
                    target: passwordBox
                    property: "shakeOffset"
                    to: 8
                    duration: 50
                }
                NumberAnimation {
                    target: passwordBox
                    property: "shakeOffset"
                    to: -4
                    duration: 50
                }
                NumberAnimation {
                    target: passwordBox
                    property: "shakeOffset"
                    to: 0
                    duration: 50
                }
            }

            TextField {
                id: field
                anchors {
                    fill: parent
                    leftMargin: 12
                    rightMargin: 12
                }
                background: null
                color: "#ffffff"
                placeholderText: root.context.unlockInProgress ? "verifying…" : "password"
                placeholderTextColor: "#80ffffff"
                font.pointSize: 13

                focus: true
                enabled: !root.context.unlockInProgress
                echoMode: TextInput.Password
                inputMethodHints: Qt.ImhSensitiveData

                onTextChanged: root.context.currentText = text
                onAccepted: root.context.tryUnlock()

                Connections {
                    target: root.context
                    function onCurrentTextChanged() {
                        if (field.text !== root.context.currentText)
                            field.text = root.context.currentText;
                    }
                    function onShowFailureChanged() {
                        if (root.context.showFailure)
                            shakeAnim.start();
                    }
                }
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2
            implicitWidth: lockedText.implicitWidth
            implicitHeight: lockedText.implicitHeight

            Text {
                id: lockedText
                font.pointSize: 13
                font.weight: Font.Bold
                color: root.theme.locked
                text: root.context.formatLocked(root.context.secondsLocked)
            }
        }
    }
}
