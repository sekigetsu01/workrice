import QtQuick
import "../"

// The screenshotter's toolbar: move, pen, highlighter, rectangle, circle, arrow, text, line and numbered badges,
// with the colour, the size and solid fill (to hide things).
Item {
    id: dock

    property string activeTool: "none"
    property color drawColor: Pal.accentAlt
    property int strokeWidth: 3
    property var toolSizes: _sizes()
    property int textFontSize: 28
    property int nextNumber: 1
    property bool userMoved: false
    property bool vertical: false
    property bool colourWheelVisible: false
    property bool sizePopupVisible: false
    // rectangles and circles drawn solid, in the colour (b): to hide things
    property bool fill: false
    readonly property bool fillable: activeTool === "rect" || activeTool === "circle"
    property bool _resetting: false
    property bool _syncingSize: false
    // a drawing picked up with the move tool (the screenshotter sets these): the size controls show and change it
    property string pickedTool: ""
    property int pickedSize: 0
    property color pickedColor: drawColor
    property bool pickedFill: false
    property int pickedNum: 1
    readonly property bool picking: activeTool === "move" && pickedTool !== ""
    // what the size controls are about: the tool in use, or the picked-up drawing
    readonly property string sizeTool: picking ? pickedTool : activeTool
    readonly property color sizeColor: picking ? pickedColor : drawColor
    // a size picked (slider, [ ], scroll): the screenshotter resizes the drawing just made, or the picked-up one, as you go
    signal sizePicked(int v)

    property bool captureTools: true
    property bool fullSelected: false
    property int delaySeconds: 0
    property bool watermark: true
    signal undoRequested
    signal redoRequested
    signal fullRequested
    signal delayRequested
    signal watermarkRequested

    readonly property var toolList: ["move", "pen", "highlighter", "rect", "circle", "arrow", "text", "line", "number"]

    // (not the highlighter: it fills the box you drag, whatever the size)
    function _sizes() {
        return { pen: 3, rect: 3, circle: 3, arrow: 3, line: 3, number: 3 };
    }
    readonly property bool hasSize: sizeTool === "text" || toolSizes[sizeTool] !== undefined
    readonly property int sizeMin: sizeTool === "text" ? 8 : 1
    readonly property int sizeMax: sizeTool === "text" ? 200 : 40
    readonly property int sizeValue: picking ? pickedSize : activeTool === "text" ? textFontSize : strokeWidth
    onHasSizeChanged: if (!hasSize) sizePopupVisible = false
    readonly property string sizeName: ({ pen: "Pen thickness", rect: "Rectangle thickness", circle: "Circle thickness",
        arrow: "Arrow thickness", line: "Line thickness", number: "Number badge size", text: "Text size" })[sizeTool] || "Size"
    function reset() {
        activeTool = "none";
        colourWheelVisible = false;
        sizePopupVisible = false;
        fill = false;
        _tipSource = null;
        toolSizes = _sizes();
        strokeWidth = 3;
        textFontSize = 28;
        drawColor = Qt.binding(() => Pal.accentAlt);
        nextNumber = 1;
        xAnim.stop();
        yAnim.stop();
        _resetting = true;
        vertical = false;
        _resetting = false;
        userMoved = false;
    }
    function _sizeFromTool() {
        if (toolSizes[activeTool] === undefined)
            return;
        _syncingSize = true;
        strokeWidth = toolSizes[activeTool];
        _syncingSize = false;
    }
    onStrokeWidthChanged: {
        if (_syncingSize || toolSizes[activeTool] === undefined)
            return;
        const t = Object.assign({}, toolSizes);
        t[activeTool] = strokeWidth;
        toolSizes = t;
    }
    onActiveToolChanged: {
        colourWheelVisible = false;
        _sizeFromTool();
        // (worked out here: hasSize may not have caught up with the new tool yet)
        if (activeTool !== "text" && toolSizes[activeTool] === undefined)
            sizePopupVisible = false;
    }
    // one popup at a time
    onColourWheelVisibleChanged: if (colourWheelVisible) sizePopupVisible = false
    onSizePopupVisibleChanged: if (sizePopupVisible) colourWheelVisible = false
    function changeSize(dir) {
        setSize(sizeValue + (sizeTool === "text" ? 2 : 1) * dir);
    }
    // scrolling: a step a wheel notch (120); a touchpad's small scrolls added up to that; sideways does nothing
    property real _wheelAcc: 0
    function wheelSize(dy) {
        if (!dy)
            return;
        if ((dy > 0) !== (_wheelAcc > 0))
            _wheelAcc = 0;
        _wheelAcc += dy;
        while (Math.abs(_wheelAcc) >= 120) {
            const s = _wheelAcc > 0 ? 1 : -1;
            _wheelAcc -= 120 * s;
            changeSize(s);
        }
    }
    function setSize(v) {
        if (!hasSize)
            return;
        v = Math.max(sizeMin, Math.min(sizeMax, Math.round(v)));
        if (!picking) {
            if (activeTool === "text")
                textFontSize = v;
            else
                strokeWidth = v;
        }
        sizePicked(v);
    }
    function toggleSizePopup() {
        sizePopupVisible = hasSize && !sizePopupVisible;
    }
    // b: solid rectangles and circles on / off; with another tool, it picks the rectangle, solid
    function toggleFill() {
        if (fillable) {
            fill = !fill;
        } else {
            activeTool = "rect";
            fill = true;
        }
    }
    function cycleTool(dir) {
        const idx = toolList.indexOf(activeTool);
        if (idx === -1)
            activeTool = dir > 0 ? toolList[0] : toolList[toolList.length - 1];
        else
            activeTool = toolList[(idx + dir + toolList.length) % toolList.length];
    }

    readonly property real pw: parent ? parent.width : 0
    readonly property real ph: parent ? parent.height : 0
    readonly property real uiScale: parent ? Math.max(0.55, Math.min(1.8, Math.min(pw, ph) / 1080)) : 1
    readonly property real buttonSize: 44 * uiScale
    readonly property real iconSizeSmall: 18 * uiScale
    readonly property real iconSizeMed: 20 * uiScale
    readonly property real dividerThickness: Math.max(1, uiScale)
    readonly property real outerPadShort: 28 * uiScale
    readonly property real popupDistance: 5 * uiScale

    readonly property real keySize: Math.max(10, 12 * uiScale)
    readonly property real keyGap: 3 * uiScale
    readonly property real keyRoom: keySize + keyGap
    readonly property real longSide: buttonRow.width + 48 * uiScale
    readonly property real shortSide: buttonRow.height + keyRoom + outerPadShort
    width: vertical ? shortSide : longSide
    height: vertical ? longSide : shortSide

    Binding on x {
        when: !dock.userMoved
        value: Math.round((dock.pw - dock.width) / 2)
        restoreMode: Binding.RestoreNone
    }
    Binding on y {
        when: !dock.userMoved
        value: Math.round(dock.ph - dock.height - dock.outerPadShort)
        restoreMode: Binding.RestoreNone
    }
    NumberAnimation on x {
        id: xAnim
        duration: 180
        easing.type: Easing.OutCubic
        running: false
    }
    NumberAnimation on y {
        id: yAnim
        duration: 180
        easing.type: Easing.OutCubic
        running: false
    }
    function snapToDefault() {
        userMoved = true;
        if (vertical) {
            xAnim.to = Math.round(outerPadShort);
            yAnim.to = Math.round((ph - longSide) / 2);
        } else {
            xAnim.to = Math.round((pw - longSide) / 2);
            yAnim.to = Math.round(ph - shortSide - outerPadShort);
        }
        xAnim.restart();
        yAnim.restart();
    }
    onVerticalChanged: if (!_resetting) Qt.callLater(snapToDefault)

    property var _tipSource: null
    function _hover(item, on) {
        if (on)
            _tipSource = item;
        else if (_tipSource === item)
            _tipSource = null;
    }
    readonly property bool _isLeft: x + width / 2 < pw / 2
    readonly property bool _isTop: y + height / 2 < ph / 2

    Rectangle {
        anchors.fill: parent
        radius: 6 * dock.uiScale
        color: Pal.color0
        border.color: Pal.accentAlt
        border.width: 1.5 * dock.uiScale
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.SizeAllCursor
        drag.target: dock
        drag.threshold: 2
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: dock.pw - dock.width
        drag.maximumY: dock.ph - dock.height
        onPressed: dock.userMoved = true
    }

    Item {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: dock.vertical ? 0 : -dock.keyRoom / 2
        anchors.horizontalCenterOffset: dock.vertical ? dock.keyRoom / 2 : 0
        width: buttonRow.width
        height: buttonRow.height
        rotation: dock.vertical ? 90 : 0

        Row {
            id: buttonRow
            spacing: 10 * dock.uiScale

            DockButton {
                key: "p"
                tip: dock.vertical ? "Horizontal" : "Vertical"
                onClicked: dock.vertical = !dock.vertical
                Glyph {
                    text: "⇅"
                    font.pixelSize: dock.iconSizeSmall
                    color: Pal.accentAlt
                    Behavior on rotation {
                        NumberAnimation {
                            duration: 180
                        }
                    }
                }
            }
            Divider {}
            DockButton {
                key: "1"
                tip: "Move / Select"
                active: dock.activeTool === "move"
                onClicked: dock.activeTool = active ? "none" : "move"
                Glyph {
                    text: "✋"
                    font.pixelSize: dock.iconSizeSmall
                }
            }
            Divider {}
            ToolButton {
                tool: "pen"
                tip: "Pen"
                glyph: "✏️"
            }
            ToolButton {
                tool: "highlighter"
                tip: "Highlighter"
                glyph: "🖊️"
            }
            ToolButton {
                tool: "rect"
                tip: "Rectangle"
                glyph: "⬜"
            }
            ToolButton {
                tool: "circle"
                tip: "Circle"
                glyph: "⭕"
            }
            ToolButton {
                tool: "arrow"
                tip: "Arrow"
                glyph: "⬆️"
            }
            ToolButton {
                tool: "text"
                tip: "Text"
                glyph: "T"
            }
            ToolButton {
                id: lineBtn
                tool: "line"
                tip: "Line"
                Canvas {
                    anchors.centerIn: parent
                    width: dock.iconSizeMed + 4 * dock.uiScale
                    height: width
                    rotation: dock.vertical ? -90 : 0
                    property color c: lineBtn.active ? "black" : Pal.accentAlt
                    onCChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = c;
                        ctx.lineWidth = 2.5 * dock.uiScale;
                        ctx.lineCap = "round";
                        const m = width * 0.125;
                        ctx.beginPath();
                        ctx.moveTo(m, height - m);
                        ctx.lineTo(width - m, m);
                        ctx.stroke();
                    }
                }
            }
            ToolButton {
                id: numberBtn
                tool: "number"
                tip: "Number Badge"
                Rectangle {
                    anchors.centerIn: parent
                    width: 22 * dock.uiScale
                    height: width
                    radius: width / 2
                    color: "transparent"
                    border.color: numberBtn.active ? "black" : Pal.accentAlt
                    border.width: 2 * dock.uiScale
                    Text {
                        anchors.centerIn: parent
                        text: dock.nextNumber
                        color: parent.border.color
                        font.pixelSize: 11 * dock.uiScale
                        font.bold: true
                        rotation: dock.vertical ? -90 : 0
                    }
                }
            }
            DockButton {
                key: "b"
                tip: dock.fill ? "Solid rectangles and circles (to hide things): on" : "Solid rectangles and circles (to hide things)"
                active: dock.fill
                opacity: dock.fillable || dock.fill ? 1 : 0.55
                onClicked: dock.toggleFill()
                Rectangle {
                    anchors.centerIn: parent
                    width: 18 * dock.uiScale
                    height: 14 * dock.uiScale
                    radius: 2 * dock.uiScale
                    border.width: 2 * dock.uiScale
                    border.color: dock.fill ? "black" : Pal.accentAlt
                    color: dock.fill ? "black" : "transparent"
                }
            }
            Divider {}

            Item {
                id: strokeItem
                width: dock.buttonSize * 1.3
                height: dock.buttonSize
                anchors.verticalCenter: parent.verticalCenter
                readonly property bool isText: dock.sizeTool === "text"
                readonly property bool hasSize: dock.hasSize
                readonly property string tip: (hasSize ? dock.sizeName + " " + dock.sizeValue : "Size (pick a tool first)") + "  ·  click or z: slider  ·  [ ] or scroll: smaller / bigger"
                opacity: hasSize ? 1 : 0.4
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: sizeMa.containsMouse ? Pal.over(Pal.accentAlt, 0.2) : "transparent"
                    border.color: Pal.accentAlt
                    border.width: 1.5 * dock.uiScale
                }
                Item {
                    anchors.fill: parent
                    rotation: dock.vertical ? -90 : 0
                    Rectangle {
                        visible: !strokeItem.isText
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height * 0.62 - height / 2
                        width: parent.width * 0.55
                        height: Math.max(1, Math.min(dock.sizeValue, 12) * dock.uiScale)
                        radius: height / 2
                        color: dock.sizeColor
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: strokeItem.isText ? (parent.height - height) / 2 : parent.height * 0.12
                        text: strokeItem.isText ? "Aa " + dock.sizeValue : dock.sizeValue
                        color: Pal.accentAlt
                        font.pixelSize: (strokeItem.isText ? 12 : 11) * dock.uiScale
                        font.bold: true
                    }
                }
                KeyLabel {
                    text: "z [ ]"
                }
                MouseArea {
                    id: sizeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: m => m.button === Qt.RightButton ? dock.changeSize(-1) : dock.toggleSizePopup()
                    onWheel: w => dock.wheelSize(w.angleDelta.y)
                    onContainsMouseChanged: dock._hover(strokeItem, containsMouse)
                }
            }
            Divider {}
            DockButton {
                key: "u"
                tip: "Undo (also Ctrl+z)"
                onClicked: dock.undoRequested()
                Glyph {
                    text: "↩️"
                }
            }
            DockButton {
                key: "r"
                tip: "Redo (also Ctrl+y)"
                onClicked: dock.redoRequested()
                Glyph {
                    text: "↪️"
                }
            }
            Divider {
                visible: dock.watermark
            }
            DockButton {
                visible: dock.watermark
                key: "⇧w"
                tip: "Remove a watermark"
                onClicked: dock.watermarkRequested()
                Glyph {
                    text: "🪄"
                }
            }
            Divider {
                visible: dock.captureTools
            }
            DockButton {
                visible: dock.captureTools
                key: "a"
                tip: dock.fullSelected ? "Unselect" : "Select the full screen"
                active: dock.fullSelected
                onClicked: dock.fullRequested()
                Canvas {
                    anchors.centerIn: parent
                    width: dock.iconSizeMed
                    height: width
                    property color c: dock.fullSelected ? "black" : Pal.accentAlt
                    onCChanged: requestPaint()
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        ctx.strokeStyle = c;
                        ctx.lineWidth = 2 * dock.uiScale;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        const a = ctx.lineWidth, b = width - a, k = width * 0.32;
                        ctx.beginPath();
                        ctx.moveTo(a, a + k); ctx.lineTo(a, a); ctx.lineTo(a + k, a);
                        ctx.moveTo(b - k, a); ctx.lineTo(b, a); ctx.lineTo(b, a + k);
                        ctx.moveTo(b, b - k); ctx.lineTo(b, b); ctx.lineTo(b - k, b);
                        ctx.moveTo(a + k, b); ctx.lineTo(a, b); ctx.lineTo(a, b - k);
                        ctx.stroke();
                    }
                }
            }
            DockButton {
                visible: dock.captureTools
                key: "d"
                tip: "Delay " + (dock.delaySeconds ? dock.delaySeconds + "s" : "off")
                active: dock.delaySeconds > 0
                onClicked: dock.delayRequested()
                Glyph {
                    text: dock.delaySeconds + "s"
                    font.pixelSize: dock.iconSizeSmall * 0.8
                    font.bold: true
                    color: dock.delaySeconds > 0 ? "black" : Pal.accentAlt
                }
            }
        }
    }

    Rectangle {
        visible: dock._tipSource !== null && !dock.colourWheelVisible && !dock.sizePopupVisible
        color: Pal.color0
        border.color: Pal.accentAlt
        border.width: dock.dividerThickness
        radius: 4 * dock.uiScale
        width: tipText.width + 16 * dock.uiScale
        height: tipText.height + 10 * dock.uiScale
        z: 1000
        x: {
            const s = dock._tipSource;
            if (!s)
                return 0;
            if (dock.vertical)
                return dock._isLeft ? dock.width + dock.popupDistance : -width - dock.popupDistance;
            return dock.mapFromItem(s, s.width / 2, 0).x - width / 2;
        }
        y: {
            const s = dock._tipSource;
            if (!s)
                return 0;
            if (dock.vertical)
                return dock.mapFromItem(s, 0, s.height / 2).y - height / 2;
            return dock._isTop ? dock.height + dock.popupDistance : -height - dock.popupDistance;
        }
        Text {
            id: tipText
            anchors.centerIn: parent
            text: dock._tipSource ? (dock._tipSource.fullTip !== undefined ? dock._tipSource.fullTip : dock._tipSource.tip) : ""
            color: Pal.accentAlt
            font.pixelSize: 12 * dock.uiScale
            font.family: "monospace"
        }
    }

    Rectangle {
        id: colourWheel
        visible: dock.colourWheelVisible
        width: 220 * dock.uiScale
        height: 270 * dock.uiScale
        radius: 6 * dock.uiScale
        color: Pal.color0
        border.color: Pal.accentAlt
        border.width: 1.5 * dock.uiScale
        z: 1001
        x: dock.vertical ? (dock._isLeft ? dock.width + dock.popupDistance : -width - dock.popupDistance) : Math.max(-dock.x, Math.min(dock.pw - dock.x - width, (dock.width - width) / 2))
        y: dock.vertical ? Math.max(-dock.y, Math.min(dock.ph - dock.y - height, (dock.height - height) / 2)) : dock._isTop ? dock.height + dock.popupDistance : -height - dock.popupDistance

        function updateCol() {
            dock.drawColor = Qt.hsva(picker.h, picker.s, picker.v, 1);
        }

        MouseArea {
            anchors.fill: parent
        }

        Item {
            id: picker
            anchors {
                fill: parent
                margins: 15 * dock.uiScale
                bottomMargin: 70 * dock.uiScale
            }
            property real h: 0.5
            property real s: 1
            property real v: 1

            Canvas {
                id: svBox
                anchors.fill: parent
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const gH = ctx.createLinearGradient(0, 0, width, 0);
                    gH.addColorStop(0, "white");
                    gH.addColorStop(1, Qt.hsva(picker.h, 1, 1, 1));
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
                x: picker.s * parent.width - width / 2
                y: (1 - picker.v) * parent.height - height / 2
                width: 12 * dock.uiScale
                height: width
                radius: width / 2
                color: "transparent"
                border.color: picker.v > 0.4 ? "black" : "white"
                border.width: 2 * dock.uiScale
            }
            MouseArea {
                anchors.fill: parent
                function pick(m) {
                    picker.s = Math.max(0, Math.min(1, m.x / width));
                    picker.v = Math.max(0, Math.min(1, 1 - m.y / height));
                    colourWheel.updateCol();
                }
                onPressed: m => pick(m)
                onPositionChanged: m => pick(m)
            }
        }

        Rectangle {
            id: hueSlider
            height: 14 * dock.uiScale
            radius: height / 2
            clip: true
            anchors {
                left: parent.left
                right: parent.right
                bottom: parent.bottom
                margins: 15 * dock.uiScale
                bottomMargin: 43 * dock.uiScale
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
                x: picker.h * (hueSlider.width - width)
                y: (parent.height - height) / 2
                width: 10 * dock.uiScale
                height: 18 * dock.uiScale
                radius: 3 * dock.uiScale
                color: "transparent"
                border.color: "white"
                border.width: 2 * dock.uiScale
            }
            MouseArea {
                anchors.fill: parent
                function pick(m) {
                    picker.h = Math.max(0, Math.min(1, m.x / width));
                    svBox.requestPaint();
                    colourWheel.updateCol();
                }
                onPressed: m => pick(m)
                onPositionChanged: m => pick(m)
            }
        }

        Rectangle {
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 10 * dock.uiScale
            }
            width: 48 * dock.uiScale
            height: 22 * dock.uiScale
            color: dock.drawColor
            border.color: "white"
            radius: 4 * dock.uiScale
        }
    }

    // the size slider (click the size button, or z): the tool drawn at that size, in its colour
    Rectangle {
        id: sizePopup
        visible: dock.sizePopupVisible
        width: 260 * dock.uiScale
        height: 196 * dock.uiScale
        radius: 6 * dock.uiScale
        color: Pal.color0
        border.color: Pal.accentAlt
        border.width: 1.5 * dock.uiScale
        z: 1001
        x: dock.vertical ? (dock._isLeft ? dock.width + dock.popupDistance : -width - dock.popupDistance) : Math.max(-dock.x, Math.min(dock.pw - dock.x - width, (dock.width - width) / 2))
        y: dock.vertical ? Math.max(-dock.y, Math.min(dock.ph - dock.y - height, (dock.height - height) / 2)) : dock._isTop ? dock.height + dock.popupDistance : -height - dock.popupDistance

        MouseArea {
            anchors.fill: parent
            onWheel: w => dock.wheelSize(w.angleDelta.y)
        }

        Text {
            id: sizeTitle
            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: 12 * dock.uiScale
            }
            text: dock.sizeName + "  " + dock.sizeValue
            color: Pal.accentAlt
            font.pixelSize: 13 * dock.uiScale
            font.family: "monospace"
            font.bold: true
        }

        Canvas {
            id: sizePreview
            anchors {
                top: sizeTitle.bottom
                left: parent.left
                right: parent.right
                margins: 12 * dock.uiScale
                topMargin: 6 * dock.uiScale
            }
            height: 100 * dock.uiScale
            property real shrink: 1
            readonly property var deps: [dock.sizeTool, dock.sizeValue, dock.sizeColor, dock.fill, dock.pickedFill, dock.picking, dock.nextNumber, dock.pickedNum, width, height]
            onDepsChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const t = dock.sizeTool, w = dock.sizeValue, W = width, H = height, cx = W / 2, cy = H / 2;
                ctx.strokeStyle = dock.sizeColor;
                ctx.fillStyle = dock.sizeColor;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                // drawn at its real size; something bigger than the box is drawn smaller, and says so
                let k = 1;
                if (t === "number")
                    k = Math.min(1, (H / 2 - 4) / (w * 6 + 14));
                else if (t === "text")
                    k = Math.min(1, (H - 8) / dock.sizeValue);
                else
                    k = Math.min(1, (H / 3) / w);
                shrink = k;
                ctx.lineWidth = w * k;
                ctx.beginPath();
                if (t === "pen") {
                    ctx.moveTo(W * 0.12, cy);
                    ctx.bezierCurveTo(W * 0.35, cy - H * 0.35, W * 0.55, cy + H * 0.35, W * 0.88, cy);
                    ctx.stroke();
                } else if (t === "line") {
                    ctx.moveTo(W * 0.12, cy);
                    ctx.lineTo(W * 0.88, cy);
                    ctx.stroke();
                } else if (t === "arrow") {
                    const a = { x: W * 0.12, y: cy }, b = { x: W * 0.88, y: cy }, hl = Math.min(30, (b.x - a.x) * 0.4) * k;
                    ctx.moveTo(a.x, a.y);
                    ctx.lineTo(b.x - hl, b.y);
                    ctx.stroke();
                    ctx.beginPath();
                    ctx.moveTo(b.x, b.y);
                    ctx.lineTo(b.x - hl, b.y + hl * 0.4);
                    ctx.lineTo(b.x - hl, b.y - hl * 0.4);
                    ctx.closePath();
                    ctx.fill();
                } else if (t === "rect" || t === "circle") {
                    const bw = W * 0.6, bh = H * 0.62, x = cx - bw / 2, y = cy - bh / 2;
                    if (t === "rect") {
                        if (dock.picking ? dock.pickedFill : dock.fill)
                            ctx.fillRect(x, y, bw, bh);
                        else
                            ctx.strokeRect(x, y, bw, bh);
                    } else {
                        ctx.save();
                        ctx.translate(cx, cy);
                        ctx.scale(bw / 2, bh / 2);
                        ctx.arc(0, 0, 1, 0, 2 * Math.PI, false);
                        ctx.restore();
                        if (dock.picking ? dock.pickedFill : dock.fill)
                            ctx.fill();
                        else
                            ctx.stroke();
                    }
                } else if (t === "number") {
                    const r = (w * 6 + 14) * k, label = String(dock.picking ? dock.pickedNum : dock.nextNumber), fs = label.length > 1 ? Math.max(10 * k, r * 1.1) : r * 1.3;
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI, false);
                    ctx.fill();
                    ctx.lineWidth = 2.5 * k;
                    ctx.strokeStyle = "rgba(0,0,0,0.45)";
                    ctx.stroke();
                    ctx.font = "bold " + fs + "px monospace";
                    ctx.fillStyle = "black";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillText(label, cx, cy);
                } else if (t === "text") {
                    ctx.font = (dock.sizeValue * k) + "px monospace";
                    ctx.textAlign = "center";
                    ctx.textBaseline = "middle";
                    ctx.fillText("Aa", cx, cy);
                }
            }
        }
        Text {
            visible: sizePreview.shrink < 1
            anchors.right: sizePreview.right
            anchors.bottom: sizePreview.bottom
            text: "shown at " + Math.round(sizePreview.shrink * 100) + "%"
            color: Pal.color8
            font.pixelSize: 10 * dock.uiScale
            font.family: "monospace"
        }

        Item {
            id: sizeSlider
            anchors {
                left: parent.left
                right: parent.right
                top: sizePreview.bottom
                margins: 14 * dock.uiScale
                topMargin: 10 * dock.uiScale
            }
            height: 18 * dock.uiScale
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4 * dock.uiScale
                radius: height / 2
                color: Pal.color8
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: knob.x + knob.width / 2
                height: 4 * dock.uiScale
                radius: height / 2
                color: Pal.accentAlt
            }
            Rectangle {
                id: knob
                anchors.verticalCenter: parent.verticalCenter
                width: 16 * dock.uiScale
                height: width
                radius: width / 2
                x: (dock.sizeValue - dock.sizeMin) / Math.max(1, dock.sizeMax - dock.sizeMin) * (sizeSlider.width - width)
                color: Pal.accentAlt
                border.color: "black"
            }
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6 * dock.uiScale
                function pick(m) {
                    const f = Math.max(0, Math.min(1, (m.x - 6 * dock.uiScale - knob.width / 2) / (sizeSlider.width - knob.width)));
                    dock.setSize(dock.sizeMin + f * (dock.sizeMax - dock.sizeMin));
                }
                onPressed: m => pick(m)
                onPositionChanged: m => pick(m)
                onWheel: w => dock.wheelSize(w.angleDelta.y)
            }
        }

        Text {
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 9 * dock.uiScale
            }
            text: "[ ] or scroll · z or Esc closes"
            color: Pal.color8
            font.pixelSize: 10 * dock.uiScale
            font.family: "monospace"
        }
    }

    component Divider: Rectangle {
        width: dock.dividerThickness
        height: 26 * dock.uiScale
        anchors.verticalCenter: parent.verticalCenter
        color: Pal.color8
    }

    component Glyph: Text {
        anchors.centerIn: parent
        font.pixelSize: dock.iconSizeMed
        rotation: dock.vertical ? -90 : 0
    }

    component KeyLabel: Text {
        anchors.top: parent.bottom
        anchors.topMargin: dock.keyGap
        anchors.horizontalCenter: parent.horizontalCenter
        rotation: dock.vertical ? -90 : 0
        color: Pal.accentAlt
        opacity: 0.85
        font.pixelSize: dock.keySize
        font.family: "monospace"
        font.bold: true
    }

    component DockButton: Item {
        id: btn
        property string key: ""
        property string tip: ""
        property string fullTip: key ? tip + "  ·  " + key : tip
        property bool active: false
        default property alias content: iconSlot.children
        signal clicked
        signal rightClicked
        width: dock.buttonSize
        height: dock.buttonSize
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btn.active ? Pal.accentAlt : ma.containsMouse ? Pal.over(Pal.accentAlt, 0.2) : "transparent"
            border.color: Pal.accentAlt
            border.width: 1.5 * dock.uiScale
        }
        Item {
            id: iconSlot
            anchors.fill: parent
        }
        KeyLabel {
            visible: btn.key !== ""
            text: btn.key
        }
        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: m => m.button === Qt.RightButton ? btn.rightClicked() : btn.clicked()
            onContainsMouseChanged: dock._hover(btn, containsMouse)
        }
    }

    component ToolButton: DockButton {
        id: tb
        property string tool
        property string glyph
        key: String(dock.toolList.indexOf(tool) + 1)
        fullTip: tip + "  ·  " + key + "   (o or right-click: colour)"
        active: dock.activeTool === tool
        onClicked: dock.activeTool = active ? "none" : tool
        onRightClicked: {
            if (active)
                dock.colourWheelVisible = !dock.colourWheelVisible;
            else
                dock.activeTool = tool;
        }
        Glyph {
            text: tb.glyph
            font.bold: true
            color: tb.active ? "black" : Pal.accentAlt
        }
        Rectangle {
            anchors {
                bottom: parent.bottom
                right: parent.right
                margins: 4 * dock.uiScale
            }
            z: 1
            width: 8 * dock.uiScale
            height: width
            radius: width / 2
            color: dock.drawColor
            border.color: "black"
        }
    }
}
