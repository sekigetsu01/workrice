import QtQuick
import "../"
import "../launcher"
import "when.js" as When

// One row of an events list: a day heading, or an event's title and time. Used by the calendar's list and
// CalendarWidget.
Item {
    id: row

    required property var modelData
    required property int index
    property LauncherThemeBase theme
    property bool selected: false
    property var today: new Date()
    readonly property var ev: modelData.ev

    signal clicked
    signal doubleClicked

    width: ListView.view ? ListView.view.width : parent.width
    height: (modelData.head ? 24 : 0) + (ev ? 40 : 24)

    Text {
        visible: !!row.modelData.head
        y: 6
        text: row.modelData.head || ""
        color: Pal.accent
        font.pixelSize: 11
        font.bold: true
        font.family: "monospace"
    }

    Item {
        y: row.modelData.head ? 24 : 0
        width: row.width
        height: row.height - y

        Text {
            visible: !row.ev
            x: 13
            anchors.verticalCenter: parent.verticalCenter
            text: "Nothing on"
            color: row.theme.clrTextMuted
            font.pixelSize: 11
            font.family: "monospace"
        }

        Rectangle {
            visible: !!row.ev
            anchors.fill: parent
            anchors.topMargin: 2
            anchors.bottomMargin: 2
            radius: 4
            bottomLeftRadius: row.selected ? 0 : 4
            bottomRightRadius: row.selected ? 0 : 4
            color: row.selected ? row.theme.clrSelRow : "transparent"

            Rectangle {
                visible: row.selected
                anchors.bottom: parent.bottom
                width: parent.width
                height: 1
                color: row.theme.clrSearchFocus
            }

            Rectangle {
                x: 6
                anchors.verticalCenter: parent.verticalCenter
                width: 3
                height: 26
                radius: 1.5
                color: !row.ev ? "transparent" : row.ev.routine ? Pal.positive : row.ev.ro ? Pal.accentAlt : Pal.accentWarm
            }

            Column {
                x: 17
                width: parent.width - 23
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                    width: parent.width
                    text: row.ev ? row.ev.title || "(no title)" : ""
                    elide: Text.ElideRight
                    color: row.theme.clrTextPrim
                    font.pixelSize: 12
                    font.bold: true
                    font.family: "monospace"
                }

                Text {
                    width: parent.width
                    text: row.ev ? row.ev.routine ? "Routine" : When.timeLine(row.ev, row.modelData.day, row.today) + (row.ev.rep !== "none" || row.ev.rid ? "  ↻" : "") + (row.ev.loc ? "  · " + row.ev.loc : "") : ""
                    elide: Text.ElideRight
                    color: row.theme.clrTextSecond
                    font.pixelSize: 10
                    font.family: "monospace"
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: row.clicked()
                onDoubleClicked: row.doubleClicked()
            }
        }
    }
}
