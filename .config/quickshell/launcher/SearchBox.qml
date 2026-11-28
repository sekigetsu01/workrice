import QtQuick
import QtQuick.Layouts

// The search bar at the top of a picker panel: a box holding the icon and the text, its border lit while you type in it
Item {
    id: root

    required property LauncherThemeBase theme
    property bool active: false
    default property alias content: row.data

    Layout.fillWidth: true
    Layout.preferredHeight: theme.searchBarH

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        radius: 4
        color: "transparent"
        border.color: root.active ? root.theme.clrSearchFocus : root.theme.clrBorder
        border.width: 1
        Behavior on border.color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    RowLayout {
        id: row
        anchors.fill: parent
        anchors.topMargin: 10
        anchors.leftMargin: 20
        anchors.rightMargin: 20
        spacing: 8
    }
}
