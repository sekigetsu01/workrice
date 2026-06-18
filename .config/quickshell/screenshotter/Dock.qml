import QtQuick
import "../"

Item {
    id: dock

    property string activeTool: "none"
    property color drawColor: Pal.accentAlt
    property int strokeWidth: 3
    property bool userMoved: false
    property bool vertical: false
    property bool colourWheelVisible: false
    property int popupDistance: 5

    onActiveToolChanged: colourWheelVisible = false

    signal undoRequested
    signal redoRequested

    readonly property var toolList: ["pen", "highlighter", "rect", "circle", "arrow", "text", "line", "number"]
    property int nextNumber: 1

    function cycleTool(dir) {
        const idx = toolList.indexOf(activeTool);
        if (idx === -1)
            activeTool = dir > 0 ? toolList[0] : toolList[toolList.length - 1];
        else
            activeTool = toolList[(idx + dir + toolList.length) % toolList.length];
    }

    width: vertical ? (buttonRow.height + 28) : (buttonRow.width + 48)
    height: vertical ? (buttonRow.width + 48) : (buttonRow.height + 28)

    property string _tipText: ""
    property var _tipSource: null

    readonly property bool _isLeft: dock.parent ? (dock.x + dock.width / 2) < (dock.parent.width / 2) : false
    readonly property bool _isTop:  dock.parent ? (dock.y + dock.height / 2) < (dock.parent.height / 2) : false

    Rectangle {
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: Qt.rgba(0.04, 0.04, 0.08, 0.88)
        border.color: Pal.accentAlt
        border.width: 1.5
    }

    DragHandler {
        target: dock
        cursorShape: Qt.SizeAllCursor
        grabPermissions: PointerHandler.TakeOverForbidden
        onActiveChanged: if (active) dock.userMoved = true
    }

    Item {
        id: rotationContainer
        anchors.centerIn: parent
        width: buttonRow.width
        height: buttonRow.height
        rotation: dock.vertical ? 90 : 0
        Behavior on rotation {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Row {
            id: buttonRow
            spacing: 10

            DockButton {
                toolTip: dock.vertical ? "Horizontal" : "Vertical"
                onClicked: dock.vertical = !dock.vertical
                Text {
                    anchors.centerIn: parent
                    text: "⇅"
                    font.pixelSize: 18
                    color: Pal.accentAlt
                    rotation: dock.vertical ? -90 : 0
                    Behavior on rotation {
                        NumberAnimation { duration: 180 }
                    }
                }
            }

            Rectangle {
                width: 1; height: 26
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0, 1, 1, 0.25)
            }

            DockButton {
                toolTip: "Pen"
                active: dock.activeTool === "pen"
                onClicked: dock.activeTool = (dock.activeTool === "pen" ? "none" : "pen")
                onRightClicked: {
                    if (dock.activeTool !== "pen") dock.activeTool = "pen";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Text {
                    anchors.centerIn: parent
                    text: "✏️"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
                ColorDot {}
            }
            DockButton {
                toolTip: "Highlighter"
                active: dock.activeTool === "highlighter"
                onClicked: dock.activeTool = (dock.activeTool === "highlighter" ? "none" : "highlighter")
                onRightClicked: {
                    if (dock.activeTool !== "highlighter") dock.activeTool = "highlighter";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Text {
                    anchors.centerIn: parent
                    text: "🖊️"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
                ColorDot {}
            }
            DockButton {
                toolTip: "Rectangle"
                active: dock.activeTool === "rect"
                onClicked: dock.activeTool = (dock.activeTool === "rect" ? "none" : "rect")
                onRightClicked: {
                    if (dock.activeTool !== "rect") dock.activeTool = "rect";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Text {
                    anchors.centerIn: parent
                    text: "⬜"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
                ColorDot {}
            }
            DockButton {
                toolTip: "Circle"
                active: dock.activeTool === "circle"
                onClicked: dock.activeTool = (dock.activeTool === "circle" ? "none" : "circle")
                onRightClicked: {
                    if (dock.activeTool !== "circle") dock.activeTool = "circle";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Text {
                    anchors.centerIn: parent
                    text: "⭕"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
                ColorDot {}
            }
            DockButton {
                toolTip: "Arrow"
                active: dock.activeTool === "arrow"
                onClicked: dock.activeTool = (dock.activeTool === "arrow" ? "none" : "arrow")
                onRightClicked: {
                    if (dock.activeTool !== "arrow") dock.activeTool = "arrow";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Text {
                    anchors.centerIn: parent
                    text: "⬆️"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
                ColorDot {}
            }
            DockButton {
                toolTip: "Text"
                active: dock.activeTool === "text"
                onClicked: dock.activeTool = (dock.activeTool === "text" ? "none" : "text")
                onRightClicked: {
                    if (dock.activeTool !== "text") dock.activeTool = "text";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Text {
                    anchors.centerIn: parent
                    text: "T"
                    font.pixelSize: 18
                    font.bold: true
                    color: dock.activeTool === "text" ? "black" : Pal.accentAlt
                    rotation: dock.vertical ? -90 : 0
                }
                ColorDot {}
            }
            DockButton {
                toolTip: "Line"
                active: dock.activeTool === "line"
                onClicked: dock.activeTool = (dock.activeTool === "line" ? "none" : "line")
                onRightClicked: {
                    if (dock.activeTool !== "line") dock.activeTool = "line";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Canvas {
                    anchors.centerIn: parent
                    width: 24; height: 24
                    rotation: dock.vertical ? -90 : 0
                    property bool isActive: dock.activeTool === "line"
                    onIsActiveChanged: requestPaint()
                    property color _watchColor: dock.drawColor
                    on_WatchColorChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = isActive ? "black" : Pal.accentAlt;
                        ctx.lineWidth = 2.5;
                        ctx.lineCap = "round";
                        ctx.beginPath();
                        ctx.moveTo(3, 21);
                        ctx.lineTo(21, 3);
                        ctx.stroke();
                    }
                }
                ColorDot {}
            }

            DockButton {
                toolTip: "Number Badge"
                active: dock.activeTool === "number"
                onClicked: dock.activeTool = (dock.activeTool === "number" ? "none" : "number")
                onRightClicked: {
                    if (dock.activeTool !== "number") dock.activeTool = "number";
                    else dock.colourWheelVisible = !dock.colourWheelVisible;
                }
                Rectangle {
                    anchors.centerIn: parent
                    width: 22; height: 22; radius: 11
                    color: "transparent"
                    border.color: dock.activeTool === "number" ? "black" : Pal.accentAlt
                    border.width: 2
                    Text {
                        anchors.centerIn: parent
                        text: dock.nextNumber
                        color: dock.activeTool === "number" ? "black" : Pal.accentAlt
                        font.pixelSize: 11
                        font.bold: true
                        rotation: dock.vertical ? -90 : 0
                    }
                }
                ColorDot {}
            }

            Rectangle {
                width: 1; height: 26
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0, 1, 1, 0.25)
            }

            Item {
                id: strokeItem
                width: 44; height: 44
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    anchors.centerIn: parent
                    text: dock.strokeWidth
                    color: Pal.accentAlt
                    font.pixelSize: 13
                    rotation: dock.vertical ? -90 : 0
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onContainsMouseChanged: {
                        if (containsMouse) {
                            dock._tipText = "Stroke: " + dock.strokeWidth;
                            dock._tipSource = strokeItem;
                        } else if (dock._tipSource === strokeItem) {
                            dock._tipSource = null;
                        }
                    }
                }
            }

            Rectangle {
                width: 1; height: 26
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0, 1, 1, 0.25)
            }

            DockButton {
                toolTip: "Undo"
                onClicked: dock.undoRequested()
                Text {
                    anchors.centerIn: parent
                    text: "↩️"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
            }
            DockButton {
                toolTip: "Redo"
                onClicked: dock.redoRequested()
                Text {
                    anchors.centerIn: parent
                    text: "↪️"
                    font.pixelSize: 20
                    rotation: dock.vertical ? -90 : 0
                }
            }
        }
    }

    Rectangle {
        id: sharedTip
        visible: dock._tipSource !== null && !dock.colourWheelVisible
        color: Qt.rgba(0.04, 0.04, 0.08, 0.95)
        border.color: Pal.accentAlt
        border.width: 1
        radius: 4
        width: sharedTipText.width + 16
        height: sharedTipText.height + 10
        z: 1000

        x: {
            if (!dock._tipSource) return 0;
            if (dock.vertical)
                return dock._isLeft ? (dock.width + dock.popupDistance) : (-width - dock.popupDistance);
            const p = dock.mapFromItem(dock._tipSource, dock._tipSource.width / 2, 0);
            return p.x - width / 2;
        }
        y: {
            if (!dock._tipSource) return 0;
            if (dock.vertical) {
                const p = dock.mapFromItem(dock._tipSource, 0, dock._tipSource.height / 2);
                return p.y - height / 2;
            }
            return dock._isTop ? (dock.height + dock.popupDistance) : (-height - dock.popupDistance);
        }

        Text {
            id: sharedTipText
            anchors.centerIn: parent
            text: dock._tipText
            color: Pal.accentAlt
            font.pixelSize: 12
            font.family: "monospace"
        }
    }

    Rectangle {
        id: colourWheel
        visible: dock.colourWheelVisible
        width: 220
        height: 270
        radius: 12
        color: Qt.rgba(0.04, 0.04, 0.08, 0.95)
        border.color: Pal.accentAlt
        border.width: 1.5
        z: 1001

        x: {
            if (dock.vertical)
                return dock._isLeft ? dock.width + dock.popupDistance : -width - dock.popupDistance;
            const centered = dock.width / 2 - width / 2;
            const parentW = dock.parent ? dock.parent.width : 9999;
            return Math.max(-dock.x, Math.min(parentW - dock.x - width, centered));
        }
        y: {
            if (dock.vertical) {
                const p = dock.height / 2 - height / 2;
                const parentH = dock.parent ? dock.parent.height : 9999;
                return Math.max(-dock.y, Math.min(parentH - dock.y - height, p));
            }
            return dock._isTop ? dock.height + dock.popupDistance : -height - dock.popupDistance;
        }

        Item {
            id: pickerContainer
            anchors { fill: parent; margins: 15; bottomMargin: 70 }
            property real h: 0.5
            property real s: 1.0
            property real v: 1.0

            Canvas {
                id: svBox
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const gH = ctx.createLinearGradient(0, 0, width, 0);
                    gH.addColorStop(0, "white");
                    gH.addColorStop(1, Qt.hsva(pickerContainer.h, 1, 1, 1));
                    ctx.fillStyle = gH;
                    ctx.fillRect(0, 0, width, height);
                    const gV = ctx.createLinearGradient(0, 0, 0, height);
                    gV.addColorStop(0, "rgba(0,0,0,0)");
                    gV.addColorStop(1, "rgba(0,0,0,1)");
                    ctx.fillStyle = gV;
                    ctx.fillRect(0, 0, width, height);
                }
            }

            Rectangle {
                x: pickerContainer.s * parent.width - width / 2
                y: (1 - pickerContainer.v) * parent.height - height / 2
                width: 12; height: 12
                radius: 6
                color: "transparent"
                border.color: pickerContainer.v > 0.4 ? "black" : "white"
                border.width: 2
            }

            MouseArea {
                anchors.fill: parent
                function pick(mx, my) {
                    pickerContainer.s = Math.max(0, Math.min(1, mx / width));
                    pickerContainer.v = Math.max(0, Math.min(1, 1 - my / height));
                    colourWheel.updateCol();
                }
                onPressed:         m => pick(m.x, m.y)
                onPositionChanged: m => pick(m.x, m.y)
            }
        }

        Rectangle {
            id: hueSlider
            height: 14
            radius: 7
            clip: true
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                margins: 15; bottomMargin: 43
            }
            Canvas {
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const g = ctx.createLinearGradient(0, 0, width, 0);
                    for (let i = 0; i <= 12; i++)
                        g.addColorStop(i / 12, Qt.hsva(i / 12, 1, 1, 1));
                    ctx.fillStyle = g;
                    ctx.fillRect(0, 0, width, height);
                }
            }
            Rectangle {
                x: pickerContainer.h * (hueSlider.width - width)
                y: (parent.height - height) / 2
                width: 10; height: 18
                radius: 3
                color: "transparent"
                border.color: "white"
                border.width: 2
            }
            MouseArea {
                anchors.fill: parent
                function pick(mx) {
                    pickerContainer.h = Math.max(0, Math.min(1, mx / width));
                    svBox.requestPaint();
                    colourWheel.updateCol();
                }
                onPressed:         m => pick(m.x)
                onPositionChanged: m => pick(m.x)
            }
        }

        Rectangle {
            anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
            width: 48; height: 22
            color: dock.drawColor
            border.color: "white"
            radius: 4
        }

        function updateCol() {
            dock.drawColor = Qt.hsva(pickerContainer.h, pickerContainer.s, pickerContainer.v, 1.0);
        }
    }

    component ColorDot: Rectangle {
        anchors { bottom: parent.bottom; right: parent.right; margins: 4 }
        width: 8; height: 8
        radius: 4
        color: dock.drawColor
        border.color: "black"
    }

    component DockButton: Item {
        id: btn
        property string toolTip: ""
        property bool active: false
        signal clicked
        signal rightClicked
        width: 44; height: 44
        Rectangle {
            anchors.fill: parent
            radius: 22
            color: btn.active ? Pal.accentAlt : (ma.containsMouse ? Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.2) : "transparent")
            border.color: Pal.accentAlt
            border.width: 1.5
        }
        default property alias content: iconSlot.children
        Item {
            id: iconSlot
            anchors.fill: parent
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? btn.rightClicked() : btn.clicked()
            onContainsMouseChanged: {
                if (containsMouse) {
                    dock._tipText = btn.toolTip;
                    dock._tipSource = btn;
                } else if (dock._tipSource === btn) {
                    dock._tipSource = null;
                }
            }
        }
    }
}
