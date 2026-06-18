import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    property bool panelOpen: false
    property bool focused: false
    property int selectedIndex: 0
    property alias historyModel: historyData

    ListModel {
        id: historyData
    }

    onPanelOpenChanged: {
        if (panelOpen)
            notifList.forceActiveFocus();
    }

    function toggle() {
        root.panelOpen = !root.panelOpen;
        root.focused = root.panelOpen;
    }

    function addNotification(appName, summary, body, icon) {
        historyData.insert(0, {
            appName: appName ? appName : "System",
            summary: summary ? summary : "",
            body: body ? body : "",
            appIcon: icon ? icon : "",
            time: Qt.formatTime(new Date(), "hh:mm")
        });
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, historyData.count - 1));
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.panelOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.anchors {
        top: true
        right: true
    }
    WlrLayershell.margins {
        top: 30
        right: 0
    }
    WlrLayershell.exclusiveZone: -1

    color: "transparent"
    width: 500
    height: panelOpen ? Math.min(950, screen.height - 40) : 0
    visible: panelOpen || heightAnim.running

    Behavior on height {
        NumberAnimation {
            id: heightAnim
            duration: 240
            easing.type: Easing.OutExpo
        }
    }

    MouseArea {
        anchors.fill: parent
        propagateComposedEvents: true
        hoverEnabled: true
        onEntered: {
            root.focused = true;
            notifList.forceActiveFocus();
            root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, historyData.count - 1));
        }
        onClicked: {
            root.focused = true;
            notifList.forceActiveFocus();
            root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, historyData.count - 1));
            mouse.accepted = false;
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 10
        radius: 16
        color: "transparent"
        border.color: Pal.borderNotif
        border.width: 1
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        radius: 14
        color: Pal.bgOverlay
        border.color: Pal.borderNotifInner
        border.width: 1
        clip: true

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: "transparent"

            gradient: Gradient {
                orientation: Gradient.Diagonal
                GradientStop {
                    position: 0.0
                    color: Pal.notifGradient
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        RowLayout {
            id: header
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 24
                leftMargin: 20
                rightMargin: 16
            }
            spacing: 8

            Text {
                text: "Notifications"
                font.pixelSize: 16
                font.weight: Font.Bold
                font.letterSpacing: 1.2
                color: Pal.fgNotifTitle
                Layout.fillWidth: true
            }

            Rectangle {
                width: 120
                height: 30
                radius: 7
                color: clearMouse.containsMouse ? Pal.borderNotifBtn : Pal.notifClearBg
                border.color: Pal.borderNotifBtn
                border.width: 1
                Behavior on color {
                    ColorAnimation {
                        duration: 100
                    }
                }

                Text {
                    anchors.centerIn: parent
                    text: "Clear All"
                    font.pixelSize: 12
                    font.weight: Font.Medium
                    color: Pal.fgClearBtn
                }
                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        historyData.clear();
                        root.selectedIndex = 0;
                    }
                }
            }
        }

        Rectangle {
            id: divider
            anchors {
                top: header.bottom
                left: parent.left
                right: parent.right
                topMargin: 20
                leftMargin: 14
                rightMargin: 14
            }
            height: 1
            color: Pal.notifDivider
        }

        Item {
            anchors {
                top: divider.bottom
                bottom: notifCount.top
                left: parent.left
                right: parent.right
            }
            visible: historyData.count === 0

            Column {
                anchors.centerIn: parent
                spacing: 2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "No new notifications"
                    font.pixelSize: 11
                    color: Pal.fgNotifEmpty
                    font.letterSpacing: 0.5
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "You're all caught up!"
                    font.pixelSize: 11
                    color: Pal.fgNotifEmpty
                    font.letterSpacing: 0.5
                }
            }
        }

        ListView {
            id: notifList
            anchors {
                top: divider.bottom
                bottom: notifCount.top
                left: parent.left
                right: parent.right
                topMargin: 8
                bottomMargin: 8
                leftMargin: 8
                rightMargin: 8
            }
            model: historyData
            clip: true
            spacing: 5
            focus: true
            keyNavigationEnabled: false
            boundsBehavior: Flickable.StopAtBounds

            Keys.onPressed: function (event) {
                if (event.key === Qt.Key_J) {
                    root.selectedIndex = Math.min(root.selectedIndex + 1, historyData.count - 1);
                    notifList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    event.accepted = true;
                } else if (event.key === Qt.Key_K) {
                    root.selectedIndex = Math.max(root.selectedIndex - 1, 0);
                    notifList.positionViewAtIndex(root.selectedIndex, ListView.Contain);
                    event.accepted = true;
                } else if (event.key === Qt.Key_D && (event.modifiers & Qt.ShiftModifier)) {
                    historyData.clear();
                    root.selectedIndex = 0;
                    event.accepted = true;
                } else if (event.key === Qt.Key_D || event.key === Qt.Key_Backspace) {
                    if (historyData.count > 0) {
                        historyData.remove(root.selectedIndex);
                        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, historyData.count - 1));
                    }
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.panelOpen = false;
                    root.focused = false;
                    event.accepted = true;
                }
            }

            delegate: Item {
                width: ListView.view.width
                height: notifCard.implicitHeight + 4

                readonly property bool isSelected: root.focused && index === root.selectedIndex

                Rectangle {
                    id: notifCard
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        topMargin: 2
                    }
                    implicitHeight: cardRow.implicitHeight + 26
                    radius: 10
                    color: isSelected ? Pal.notifSelBg : rowMouse.containsMouse ? Pal.notifHovBg : Pal.notifCardBg
                    border.color: isSelected ? Pal.borderNotifSel : Pal.borderNotifCard
                    border.width: 1
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    RowLayout {
                        id: cardRow
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: parent.top
                            topMargin: 10
                            leftMargin: 12
                            rightMargin: 10
                            bottomMargin: 10
                        }
                        spacing: 10

                        Rectangle {
                            width: 46
                            height: 46
                            radius: 8
                            color: Pal.notifSelBg
                            border.color: Pal.borderNotif
                            border.width: 1
                            Layout.alignment: Qt.AlignTop

                            Text {
                                anchors.centerIn: parent
                                text: model.appIcon !== "" ? model.appIcon[0].toUpperCase() : model.appName.length > 0 ? model.appName[0].toUpperCase() : "?"
                                font.pixelSize: 14
                                font.weight: Font.Bold
                                color: Pal.fgNotifAppIcon
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 3

                            RowLayout {
                                spacing: 0
                                Layout.fillWidth: true
                                Text {
                                    text: model.appName
                                    font.pixelSize: 14
                                    font.weight: Font.Bold
                                    font.letterSpacing: 0.6
                                    color: Pal.fgNotifApp
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: model.time
                                    font.pixelSize: 12
                                    color: Pal.fgNotifMeta
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: model.summary !== "" ? model.summary : model.body
                                font.pixelSize: 17
                                font.weight: Font.SemiBold
                                color: Pal.fgNotifBody
                                elide: Text.ElideRight
                                maximumLineCount: 1
                            }

                            Text {
                                Layout.fillWidth: true
                                text: model.body
                                font.pixelSize: 11
                                color: Pal.fgNotifFaint
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                visible: model.body !== "" && model.body !== model.summary
                            }
                        }
                    }

                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        propagateComposedEvents: true
                        onClicked: {
                            root.focused = true;
                            notifList.forceActiveFocus();
                            root.selectedIndex = index;
                            mouse.accepted = false;
                        }
                    }
                }
            }
        }

        Text {
            id: notifCount
            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                bottomMargin: 12
                leftMargin: 18
            }
            text: historyData.count + " notification" + (historyData.count === 1 ? "" : "s")
            font.pixelSize: 13
            color: Pal.notifTimeFaint
            font.letterSpacing: 0.5
        }
    }
}
