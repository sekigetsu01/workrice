import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Fusion
import Quickshell

// What the lock screen shows: the wallpaper, the time and date, the password box, and how long it's been locked.
Rectangle {
    id: root
    required property LockContext context

    color: "black"
    readonly property real k: 1 / (Number(Quickshell.env("QT_SCALE_FACTOR")) || 1)
    readonly property string wallpaperPath: context.look[0] || ""
    readonly property var theme: ({
            clock: context.look[1] || "#4B0082",
            locked: context.look[2] || "#7675C4",
            verticalOffset: isNaN(parseInt(context.look[3])) ? -75 : parseInt(context.look[3])
        })

    Image {
        anchors.fill: parent
        source: root.wallpaperPath ? "file://" + root.wallpaperPath.split("/").map(encodeURIComponent).join("/") : ""
        fillMode: Image.PreserveAspectCrop
    }

    ColumnLayout {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root.theme.verticalOffset * root.k
        spacing: 2 * root.k

        Item {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: clockText.implicitWidth
            implicitHeight: clockText.implicitHeight

            Repeater {
                model: [[-2, -2], [2, -2], [-2, 2], [2, 2], [-3, 0], [3, 0], [0, -3], [0, 3]]
                Text {
                    font.pointSize: 75 * root.k
                    font.weight: Font.Black
                    color: "#000000"
                    x: modelData[0] * root.k
                    y: modelData[1] * root.k
                    text: clockText.text
                }
            }

            Text {
                id: clockText
                font.pointSize: 75 * root.k
                font.weight: Font.Black
                color: root.theme.clock
                text: Qt.formatTime(root.context.now, "hh:mm")
            }
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -8 * root.k
            implicitWidth: dateText.implicitWidth
            implicitHeight: dateText.implicitHeight

            Repeater {
                model: [[-1, -1], [1, -1], [-1, 1], [1, 1]]
                Text {
                    font.pointSize: 14 * root.k
                    font.weight: Font.Bold
                    color: "#000000"
                    x: modelData[0] * root.k
                    y: modelData[1] * root.k
                    text: dateText.text
                }
            }

            Text {
                id: dateText
                font.pointSize: 14 * root.k
                font.weight: Font.Bold
                color: root.theme.locked
                text: Qt.formatDate(root.context.now, "dddd, d MMMM yyyy")
            }
        }

        Rectangle {
            id: passwordBox
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 6 * root.k
            implicitWidth: 340 * root.k
            implicitHeight: 44 * root.k
            color: "#262525"
            radius: 4 * root.k
            border.width: (root.context.showSuccess || root.context.showFailure) ? 1.5 * root.k : 0
            border.color: root.context.showSuccess ? "#00c44f" : root.context.showFailure ? "#e53935" : "transparent"

            property real shake: 1
            transform: Translate {
                x: 10 * root.k * Math.sin(passwordBox.shake * Math.PI * 6) * (1 - passwordBox.shake)
            }
            NumberAnimation {
                id: shakeAnim
                target: passwordBox
                property: "shake"
                from: 0
                to: 1
                duration: 300
            }

            TextField {
                id: field
                anchors {
                    fill: parent
                    leftMargin: 12 * root.k
                    rightMargin: 12 * root.k
                }
                background: null
                color: "#ffffff"
                placeholderText: root.context.unlockInProgress ? "verifying…" : "password"
                placeholderTextColor: Qt.tint("#262525", "#80ffffff")
                font.pointSize: 13 * root.k

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

        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 2 * root.k
            font.pointSize: 13 * root.k
            font.weight: Font.Bold
            color: root.theme.locked
            text: root.context.formatLocked(root.context.secondsLocked)
        }
    }
}
