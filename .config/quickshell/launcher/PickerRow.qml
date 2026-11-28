import QtQuick
import QtQuick.Layouts

// One row of a picker panel's list: highlighted when it's picked with the keys or under the mouse, with a star if starred
Item {
    id: row

    required property int index
    required property var modelData
    readonly property var picker: ListView.view.picker
    readonly property LauncherThemeBase theme: picker.theme
    readonly property bool isSel: picker.focusSource === "keyboard" && index === picker.selectedIndex
    readonly property bool isHov: picker.focusSource === "mouse" && index === picker.selectedIndex
    property bool mouseOver: false
    property bool star: false
    property bool starred: false
    default property alias content: layout.data

    width: ListView.view.width
    height: theme.rowHeight

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        topLeftRadius: 4
        topRightRadius: 4
        bottomLeftRadius: row.isSel ? 0 : 4
        bottomRightRadius: row.isSel ? 0 : 4
        color: row.isSel ? row.theme.clrSelRow : row.isHov ? row.theme.clrHovRow : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 80
            }
        }

        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: row.theme.clrSearchFocus
            opacity: row.isSel ? 1 : 0
            Behavior on opacity {
                NumberAnimation {
                    duration: 80
                }
            }
        }
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: row.star ? 39 : 14
        spacing: 11
    }

    Item {
        visible: row.star
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        Text {
            anchors.centerIn: parent
            text: row.starred || starMa.containsMouse ? "★" : "☆"
            font.pixelSize: 17
            color: row.starred || starMa.containsMouse ? row.theme.clrStar : row.mouseOver || row.isSel ? row.theme.clrStarOff : "transparent"
            Behavior on color {
                ColorAnimation {
                    duration: 100
                }
            }
        }
        MouseArea {
            id: starMa
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            onClicked: row.picker.fav(row.modelData)
        }
    }

    MouseArea {
        anchors.fill: parent
        anchors.rightMargin: row.star ? 28 : 0
        hoverEnabled: true
        onEntered: row.mouseOver = true
        onExited: row.mouseOver = false
        onPositionChanged: m => {
            const p = mapToItem(null, m.x, m.y), last = row.picker.lastMouse;
            row.picker.lastMouse = p;
            if (last.x < 0 || p.x === last.x && p.y === last.y)
                return;
            row.picker.focusSource = "mouse";
            row.mouseOver = true;
            row.picker.selectedIndex = row.index;
        }
        onClicked: {
            row.picker.selectedIndex = row.index;
            row.picker.pick(row.modelData);
        }
    }
}
