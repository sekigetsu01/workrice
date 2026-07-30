import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../"

PanelWindow {
    id: root

    property var centerRef: null
    property var _pendingNotifs: []

    onCenterRefChanged: {
        if (centerRef !== null) {
            for (var i = 0; i < _pendingNotifs.length; i++) {
                var n = _pendingNotifs[i];
                centerRef.addNotification(n.appName, n.summary, n.body, n.icon);
            }
            _pendingNotifs = [];
        }
    }

    function showNotif(appName, summary, body, icon) {
        root.currentApp = appName ? appName : "System";
        root.currentSummary = summary ? summary : "";
        root.currentBody = body ? body : "";
        root.currentIcon = icon ? icon : "";
        root.visible = true;
        toast.opacity = 0;
        toast.anchors.rightMargin = -20;
        showAnim.restart();
        hideTimer.restart();
    }

    NotificationServer {
        id: server
        bodySupported: true
        actionsSupported: false

        onNotification: function (notif) {
            root.showNotif(notif.appName, notif.summary, notif.body, notif.appIcon ?? "");
            if (root.centerRef !== null) {
                root.centerRef.addNotification(notif.appName, notif.summary, notif.body, notif.appIcon ?? "");
            } else {
                _pendingNotifs.push({
                    appName: notif.appName,
                    summary: notif.summary,
                    body: notif.body,
                    icon: notif.appIcon ?? ""
                });
            }
            notif.tracked = false;
        }
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.anchors {
        top: true
        right: true
    }

    width: 520
    height: Math.min(toast.height + 90, 300)
    color: "transparent"
    visible: false

    property string currentSummary: ""
    property string currentBody: ""
    property string currentApp: ""
    property string currentIcon: ""

    Timer {
        id: hideTimer
        interval: 2500
        onTriggered: fadeOut.start()
    }

    ParallelAnimation {
        id: showAnim
        NumberAnimation {
            target: toast
            property: "anchors.rightMargin"
            to: 20
            duration: 300
            easing.type: Easing.OutExpo
        }
        NumberAnimation {
            target: toast
            property: "opacity"
            to: 1
            duration: 250
            easing.type: Easing.OutCubic
        }
    }

    NumberAnimation {
        id: fadeOut
        target: toast
        property: "opacity"
        to: 0
        duration: 300
        easing.type: Easing.InCubic
        onFinished: root.visible = false
    }

    Rectangle {
        id: toast
        anchors {
            top: parent.top
            right: parent.right
            topMargin: 20
            rightMargin: 20
        }
        width: 480
        height: toastCol.implicitHeight + 44
        radius: 12
        opacity: 0
        color: Pal.bgToast
        border.color: Pal.borderToast
        border.width: 1

        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
                topMargin: 12
                bottomMargin: 12
            }
            width: 3
            radius: 2
            color: Pal.notifAccent
        }

        ColumnLayout {
            id: toastCol
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: 12
                leftMargin: 18
                rightMargin: 14
            }
            spacing: 4

            RowLayout {
                spacing: 0
                Text {
                    text: root.currentApp.toUpperCase()
                    font.pixelSize: 14
                    font.weight: Font.Bold
                    font.letterSpacing: 1.1
                    color: Pal.notifToastAccent
                    Layout.fillWidth: true
                }
                Text {
                    text: Qt.formatTime(new Date(), "hh:mm")
                    font.pixelSize: 10
                    color: Pal.notifTimeMuted
                }
            }

            Text {
                Layout.fillWidth: true
                text: root.currentSummary
                font.pixelSize: 17
                font.weight: Font.SemiBold
                color: Pal.fgNotifTitle
                wrapMode: Text.WrapAnywhere
            }

            Text {
                Layout.fillWidth: true
                text: root.currentBody
                font.pixelSize: 17
                color: Pal.notifBodyMuted
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                visible: root.currentBody !== ""
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.RightButton | Qt.LeftButton
            onEntered: hideTimer.stop()
            onExited: {
                if (root.visible && toast.opacity > 0)
                    hideTimer.restart()
            }
            onClicked: {
                hideTimer.stop();
                fadeOut.start();
            }
        }
    }
}
