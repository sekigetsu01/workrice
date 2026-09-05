import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

QtObject {
    id: root

    property bool active: false

    function toggle() {
        active = !active;
    }

    property var _variants: Variants {
        model: Quickshell.screens

        PanelWindow {
            id: geom
            property var modelData

            screen: modelData
            visible: root.active
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay

            WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            property string homeDir: Quickshell.env("HOME")
            property string saveDir: homeDir + "/Pictures/Screenshots"
            property bool uiVisible: true
            property bool hintVisible: true
            property string pendingCmd: ""
            property int delaySeconds: 0
            property int delayRemaining: 0
            property string _savePath: ""
            readonly property bool delayActive: delayTimer.running

            readonly property int _screenIdx: Quickshell.screens.indexOf(modelData)
            property string frozenFrame: `/tmp/qs_frozen_frame_${_screenIdx}.png`
            property bool frameReady: false

            onVisibleChanged: {
                if (visible) {
                    frameReady = false;
                    uiVisible = false;
                    hintVisible = true;
                    geomRect.selecting = false;
                    drawingCanvas.strokes = [];
                    drawingCanvas.redoStack = [];
                    dock.nextNumber = 1;
                    freezeDelay.start();

                    geomRect.ballX = geom.width / 2;
                    geomRect.ballY = geom.height / 2;
                    Qt.callLater(() => {
                        geomRect.ballX = geom.width / 2 + 40;
                        geomRect.ballY = geom.height / 2 - 40;
                    });
                }
            }

            Timer {
                id: freezeDelay
                interval: 150
                repeat: false
                onTriggered: freezeProcess.running = true
            }

            Process {
                id: freezeProcess
                command: ["sh", "-c", `grim "${geom.frozenFrame}"`]
                onExited: code => {
                    if (code === 0) {
                        geom.frameReady = true;
                        geom.uiVisible = true;
                    }
                }
            }

            Image {
                anchors.fill: parent
                source: geom.frameReady ? ("file://" + geom.frozenFrame) : ""
                visible: geom.frameReady
                cache: false
                z: -10
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
                z: -9
                visible: geom.uiVisible
            }

            function freshTimestamp() {
                const n = new Date();
                return n.getFullYear() + "-" + String(n.getMonth() + 1).padStart(2, "0") + "-" + String(n.getDate()).padStart(2, "0") + "_" + String(n.getHours()).padStart(2, "0") + "-" + String(n.getMinutes()).padStart(2, "0") + "-" + String(n.getSeconds()).padStart(2, "0");
            }

            function edgePoint(cx, cy, fx, fy, r) {
                const dx = fx - cx, dy = fy - cy;
                const d = Math.sqrt(dx * dx + dy * dy);
                if (d < 1)
                    return {
                        x: cx,
                        y: cy
                    };
                return {
                    x: cx + (dx / d) * r,
                    y: cy + (dy / d) * r
                };
            }

            function clamp(v, lo, hi) {
                return Math.max(lo, Math.min(hi, v));
            }

            function kbStep(mods) {
                return (mods & Qt.ControlModifier) ? 50 : 10;
            }

            function kbEnsureSelecting() {
                if (geomRect.selecting)
                    return;
                const qx = Math.round(geom.width / 4);
                const qy = Math.round(geom.height / 4);
                geomRect.anchor1X = qx;
                geomRect.anchor1Y = qy;
                geomRect.anchor2X = geom.width - qx;
                geomRect.anchor2Y = geom.height - qy;
                geomRect.selecting = true;
            }

            function buildCaptureCommands() {
                const capPath = `${saveDir}/screenshot_${freshTimestamp()}.png`;
                _savePath = capPath;
                const mkdirSave = `mkdir -p "${saveDir}" && `;
                const drawPath = `${homeDir}/.cache/qs_drawing.png`;
                const basePath = `/tmp/qs_base_${_screenIdx}.png`;
                grimFullCopyProcess.command = ["sh", "-c", `wl-copy < "${geom.frozenFrame}"`];
                grimFullSaveProcess.command = ["sh", "-c", `${mkdirSave}cp "${geom.frozenFrame}" "${capPath}"`];
                if (geomRect.selecting) {
                    const x = geomRect.anchor1X, y = geomRect.anchor1Y;
                    const w = geomRect.anchor2X - x, h = geomRect.anchor2Y - y;
                    if (w > 0 && h > 0) {
                        const gArg = `"${x},${y} ${w}x${h}"`;
                        grimRegionCopyProcess.command = ["sh", "-c", `grim -g ${gArg} - | wl-copy`];
                        grimRegionCopySaveProcess.command = ["sh", "-c", `${mkdirSave}grim -g ${gArg} - | tee "${capPath}" | wl-copy`];
                        const cropAndComposite = `convert "${geom.frozenFrame}" -crop ${w}x${h}+${x}+${y} +repage "${basePath}" && ` + `if [ -f "${drawPath}" ]; then convert "${basePath}" "${drawPath}" -geometry -${x}-${y} +repage -flatten "${capPath}" && rm -f "${drawPath}" || rm -f "${drawPath}"; else cp "${basePath}" "${capPath}"; fi`;
                        grimAnnotatedProcess.command = ["sh", "-c", `${mkdirSave}${cropAndComposite}`];
                    }
                }
            }

            function triggerCapture(mode) {
                if (delayTimer.running)
                    return;
                if ((mode === "region_copy" || mode === "region_copy_save" || mode === "region_annotated") && geomRect.selecting && (geomRect.anchor2X <= geomRect.anchor1X || geomRect.anchor2Y <= geomRect.anchor1Y))
                    return;
                if (delaySeconds > 0) {
                    delayRemaining = delaySeconds;
                    pendingCmd = mode;
                    delayTimer.start();
                    return;
                }
                pendingCmd = mode;
                uiVisible = false;
                captureTimer.start();
            }

            function closeScreenshotter() {
                geomRect.selecting = false;
                drawingCanvas.strokes = [];
                drawingCanvas.redoStack = [];
                dock.nextNumber = 1;
                dock.activeTool = "none";
                dock.strokeWidth = 3;
                dock.drawColor = Pal.accentAlt;
                delaySeconds = 0;
                uiVisible = true;
                xAnim.stop();
                yAnim.stop();
                dock._resetting = true;
                dock.vertical = false;
                dock.userMoved = false;
                dock._resetting = false;
                root.active = false;
            }

            Timer {
                id: delayTimer
                interval: 1000
                repeat: true
                onTriggered: {
                    delayRemaining -= 1;
                    if (delayRemaining <= 0) {
                        stop();
                        uiVisible = false;
                        captureTimer.start();
                    }
                }
            }

            Timer {
                id: captureTimer
                interval: 80
                repeat: false
                onTriggered: {
                    buildCaptureCommands();
                    if (pendingCmd === "full_copy")
                        grimFullCopyProcess.running = true;
                    else if (pendingCmd === "full_save")
                        grimFullSaveProcess.running = true;
                    else if (pendingCmd === "region_copy")
                        grimRegionCopyProcess.running = true;
                    else if (pendingCmd === "region_copy_save")
                        grimRegionCopySaveProcess.running = true;
                    else if (pendingCmd === "region_annotated")
                        grimAnnotatedProcess.running = true;
                }
            }

            Process {
                id: grimFullCopyProcess
                onExited: code => {
                    if (code !== 0) {
                        uiVisible = true;
                        return;
                    }
                    notifyProcess.command = ["notify-send", "Copied", "Full screen"];
                    notifyProcess.running = true;
                }
            }
            Process {
                id: grimFullSaveProcess
                onExited: code => {
                    if (code !== 0) {
                        uiVisible = true;
                        return;
                    }
                    notifyProcess.command = ["notify-send", "Saved", geom._savePath];
                    notifyProcess.running = true;
                }
            }
            Process {
                id: grimRegionCopyProcess
                onExited: code => {
                    if (code !== 0) {
                        uiVisible = true;
                        return;
                    }
                    notifyProcess.command = ["notify-send", "Copied", "Region"];
                    notifyProcess.running = true;
                }
            }
            Process {
                id: grimRegionCopySaveProcess
                onExited: code => {
                    if (code !== 0) {
                        uiVisible = true;
                        return;
                    }
                    notifyProcess.command = ["notify-send", "Copied & Saved", geom._savePath];
                    notifyProcess.running = true;
                }
            }
            Process {
                id: grimAnnotatedProcess
                onExited: code => {
                    if (code !== 0) {
                        uiVisible = true;
                        return;
                    }
                    notifyProcess.command = ["notify-send", "Saved", geom._savePath];
                    notifyProcess.running = true;
                }
            }

            Process {
                id: notifyProcess
                onExited: {
                    cleanupProcess.command = ["rm", "-f", geom.frozenFrame];
                    cleanupProcess.running = true;
                    geom.closeScreenshotter();
                }
            }

            Process {
                id: cleanupProcess
                onExited: geom.closeScreenshotter()
            }

            contentItem {
                focus: root.active

                Keys.onEscapePressed: {
                    if (delayTimer.running) {
                        delayTimer.stop();
                        delayRemaining = 0;
                        uiVisible = true;
                        return;
                    }
                    if (dock.colourWheelVisible) {
                        dock.colourWheelVisible = false;
                        return;
                    }
                    if (dock.activeTool !== "none") {
                        dock.activeTool = "none";
                        return;
                    }
                    if (geomRect.selecting) {
                        geomRect.selecting = false;
                        return;
                    }
                    geom.closeScreenshotter();
                }

                Keys.onReturnPressed: {
                    if (!geomRect.selecting)
                        return;
                    triggerCapture("region_copy");
                }

                Keys.onPressed: event => {
                    const ctrl = event.modifiers & Qt.ControlModifier;
                    const shift = event.modifiers & Qt.ShiftModifier;
                    const alt = event.modifiers & Qt.AltModifier;
                    const step = kbStep(event.modifiers);

                    if (!alt && ctrl && (event.key === Qt.Key_H || event.key === Qt.Key_Left)) {
                        dock.cycleTool(-1);
                        event.accepted = true;
                        return;
                    }
                    if (!alt && ctrl && (event.key === Qt.Key_L || event.key === Qt.Key_Right)) {
                        dock.cycleTool(1);
                        event.accepted = true;
                        return;
                    }

                    switch (event.key) {
                    case Qt.Key_H:
                    case Qt.Key_Left:
                        {
                            kbEnsureSelecting();
                            if (alt) {
                                const bw = geomRect.anchor2X - geomRect.anchor1X;
                                const nx = clamp(geomRect.anchor1X - step, 0, geom.width - bw);
                                geomRect.anchor1X = nx;
                                geomRect.anchor2X = nx + bw;
                            } else {
                                geomRect.anchor1X = clamp(geomRect.anchor1X + (shift ? step : -step), 0, geomRect.anchor2X - 1);
                            }
                            event.accepted = true;
                            return;
                        }
                    case Qt.Key_L:
                    case Qt.Key_Right:
                        {
                            kbEnsureSelecting();
                            if (alt) {
                                const bw = geomRect.anchor2X - geomRect.anchor1X;
                                const nx = clamp(geomRect.anchor1X + step, 0, geom.width - bw);
                                geomRect.anchor1X = nx;
                                geomRect.anchor2X = nx + bw;
                            } else {
                                geomRect.anchor2X = clamp(geomRect.anchor2X + (shift ? -step : step), geomRect.anchor1X + 1, geom.width);
                            }
                            event.accepted = true;
                            return;
                        }
                    case Qt.Key_K:
                    case Qt.Key_Up:
                        {
                            kbEnsureSelecting();
                            if (alt) {
                                const bh = geomRect.anchor2Y - geomRect.anchor1Y;
                                const ny = clamp(geomRect.anchor1Y - step, 0, geom.height - bh);
                                geomRect.anchor1Y = ny;
                                geomRect.anchor2Y = ny + bh;
                            } else {
                                geomRect.anchor1Y = clamp(geomRect.anchor1Y + (shift ? step : -step), 0, geomRect.anchor2Y - 1);
                            }
                            event.accepted = true;
                            return;
                        }
                    case Qt.Key_J:
                    case Qt.Key_Down:
                        {
                            kbEnsureSelecting();
                            if (alt) {
                                const bh = geomRect.anchor2Y - geomRect.anchor1Y;
                                const ny = clamp(geomRect.anchor1Y + step, 0, geom.height - bh);
                                geomRect.anchor1Y = ny;
                                geomRect.anchor2Y = ny + bh;
                            } else {
                                geomRect.anchor2Y = clamp(geomRect.anchor2Y + (shift ? -step : step), geomRect.anchor1Y + 1, geom.height);
                            }
                            event.accepted = true;
                            return;
                        }
                    case Qt.Key_Tab:
                        hintVisible = !hintVisible;
                        event.accepted = true;
                        return;
                    case Qt.Key_BracketLeft:
                        dock.strokeWidth = clamp(dock.strokeWidth - 1, 1, 40);
                        event.accepted = true;
                        return;
                    case Qt.Key_BracketRight:
                        dock.strokeWidth = clamp(dock.strokeWidth + 1, 1, 40);
                        event.accepted = true;
                        return;
                    }

                    if (event.key === Qt.Key_D && !ctrl) {
                        delaySeconds = delaySeconds === 0 ? 3 : delaySeconds === 3 ? 5 : 0;
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_F && !ctrl) {
                        triggerCapture("full_copy");
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_S && !ctrl) {
                        if (geomRect.selecting) {
                            drawingCanvas.grabToImage(result => {
                                result.saveToFile(`${homeDir}/.cache/qs_drawing.png`);
                                triggerCapture("region_annotated");
                            });
                        } else {
                            triggerCapture("full_save");
                        }
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_C && !ctrl) {
                        if (geomRect.selecting) {
                            triggerCapture("region_copy_save");
                            event.accepted = true;
                        }
                        return;
                    }
                    if (event.key === Qt.Key_W && !ctrl) {
                        dock.cycleTool(1);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_X && !ctrl) {
                        dock.cycleTool(-1);
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_U && !ctrl) {
                        drawingCanvas.undo();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_R && !ctrl) {
                        drawingCanvas.redo();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Z && ctrl) {
                        drawingCanvas.undo();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_Y && ctrl) {
                        drawingCanvas.redo();
                        event.accepted = true;
                        return;
                    }
                    if (event.key === Qt.Key_P && !ctrl) {
                        dock.vertical = !dock.vertical;
                        event.accepted = true;
                        return;
                    }
                }
            }

            Rectangle {
                id: geomRect
                anchors.fill: parent
                color: "transparent"

                property int anchor1X: 0
                property int anchor1Y: 0
                property int anchor2X: 0
                property int anchor2Y: 0
                property int borderWidth: 4
                readonly property int ballRadius: borderWidth * 3
                property bool selecting: false
                property real ballX: width / 2
                property real ballY: height / 2
                readonly property real ballTargetX: selecting ? (anchor1X + anchor2X) / 2 : width / 2
                readonly property real ballTargetY: selecting ? (anchor1Y + anchor2Y) / 2 : height / 2

                FrameAnimation {
                    running: Math.abs(geomRect.ballTargetX - geomRect.ballX) > 0.5 || Math.abs(geomRect.ballTargetY - geomRect.ballY) > 0.5
                    onTriggered: {
                        geomRect.ballX += (geomRect.ballTargetX - geomRect.ballX) * 0.10;
                        geomRect.ballY += (geomRect.ballTargetY - geomRect.ballY) * 0.10;
                    }
                }

                onAnchor1XChanged: selCanvas.requestPaint()
                onAnchor1YChanged: selCanvas.requestPaint()
                onAnchor2XChanged: selCanvas.requestPaint()
                onAnchor2YChanged: selCanvas.requestPaint()
                onSelectingChanged: selCanvas.requestPaint()

                Canvas {
                    id: selCanvas
                    anchors.fill: parent
                    visible: geom.uiVisible
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (!geomRect.selecting)
                            return;
                        const x1 = geomRect.anchor1X, y1 = geomRect.anchor1Y;
                        const w = geomRect.anchor2X - x1, h = geomRect.anchor2Y - y1;
                        const bw = geomRect.borderWidth;
                        ctx.fillStyle = "black";
                        ctx.globalAlpha = 0.55;
                        ctx.fillRect(0, 0, width, height);
                        ctx.clearRect(x1, y1, w, h);
                        ctx.globalAlpha = 1;
                        ctx.strokeStyle = Pal.accentAlt;
                        ctx.lineWidth = bw;
                        ctx.strokeRect(x1 - bw / 2, y1 - bw / 2, w + bw, h + bw);
                    }
                }

                Canvas {
                    id: drawingCanvas
                    anchors.fill: parent

                    property var strokes: []
                    property var redoStack: []
                    property var currentPts: []
                    property bool drawing: false

                    function undo() {
                        if (strokes.length === 0)
                            return;
                        var copy = strokes.slice();
                        var s = copy.pop();
                        strokes = copy;
                        redoStack = redoStack.concat([s]);
                        if (s.tool === "number" && dock.nextNumber > 1)
                            dock.nextNumber -= 1;
                        requestPaint();
                    }
                    function redo() {
                        if (redoStack.length === 0)
                            return;
                        var rCopy = redoStack.slice();
                        var s = rCopy.pop();
                        redoStack = rCopy;
                        strokes = strokes.concat([s]);
                        if (s.tool === "number")
                            dock.nextNumber += 1;
                        requestPaint();
                    }

                    function beginStroke(x, y) {
                        redoStack = [];
                        currentPts = [
                            {
                                x,
                                y
                            }
                        ];
                        drawing = true;
                    }
                    function addPoint(x, y) {
                        if (!drawing)
                            return;
                        const t = dock.activeTool;
                        if (t === "circle" || t === "arrow" || t === "rect" || t === "line" || t === "highlighter")
                            currentPts = [currentPts[0],
                                {
                                    x,
                                    y
                                }
                            ];
                        else
                            currentPts = currentPts.concat([
                                {
                                    x,
                                    y
                                }
                            ]);
                        requestPaint();
                    }
                    function endStroke() {
                        if (!drawing)
                            return;
                        drawing = false;
                        if (currentPts.length >= 1)
                            strokes = strokes.concat([
                                {
                                    tool: dock.activeTool,
                                    color: dock.drawColor.toString(),
                                    width: dock.strokeWidth,
                                    pts: currentPts.slice()
                                }
                            ]);
                        currentPts = [];
                        requestPaint();
                    }
                    function commitText(x, y, text) {
                        if (!text.trim())
                            return;
                        redoStack = [];
                        strokes = strokes.concat([
                            {
                                tool: "text",
                                color: dock.drawColor.toString(),
                                width: dock.strokeWidth,
                                pts: [
                                    {
                                        x,
                                        y
                                    }
                                ],
                                text
                            }
                        ]);
                        requestPaint();
                    }

                    function placeNumber(x, y, num, color, sw) {
                        redoStack = [];
                        strokes = strokes.concat([
                            {
                                tool: "number",
                                color: color,
                                width: sw,
                                pts: [
                                    {
                                        x,
                                        y
                                    }
                                ],
                                num
                            }
                        ]);
                        requestPaint();
                    }

                    function paintShape(ctx, tool, color, pts, sw, text, num) {
                        ctx.strokeStyle = color;
                        ctx.fillStyle = color;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.globalAlpha = tool === "highlighter" ? 0.4 : 1.0;
                        ctx.lineWidth = tool === "highlighter" ? sw * 4 : sw;
                        if (tool === "pen") {
                            if (pts.length < 2)
                                return;
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, pts[0].y);
                            for (let i = 1; i < pts.length; i++)
                                ctx.lineTo(pts[i].x, pts[i].y);
                            ctx.stroke();
                        } else if (tool === "highlighter") {
                            if (pts.length < 2)
                                return;
                            const hx = Math.min(pts[0].x, pts[1].x);
                            const hy = Math.min(pts[0].y, pts[1].y);
                            const hw = Math.abs(pts[1].x - pts[0].x);
                            const hh = Math.abs(pts[1].y - pts[0].y);
                            if (hw < 2 || hh < 2)
                                return;
                            ctx.globalAlpha = 0.35;
                            ctx.fillRect(hx, hy, hw, hh);
                        } else if (tool === "line") {
                            if (pts.length < 2)
                                return;
                            ctx.globalAlpha = 1.0;
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, pts[0].y);
                            ctx.lineTo(pts[1].x, pts[1].y);
                            ctx.stroke();
                        } else if (tool === "rect") {
                            if (pts.length < 2)
                                return;
                            ctx.globalAlpha = 1.0;
                            ctx.strokeRect(Math.min(pts[0].x, pts[1].x), Math.min(pts[0].y, pts[1].y), Math.abs(pts[1].x - pts[0].x), Math.abs(pts[1].y - pts[0].y));
                        } else if (tool === "circle") {
                            if (pts.length < 2)
                                return;
                            const cx = (pts[0].x + pts[1].x) / 2, cy = (pts[0].y + pts[1].y) / 2;
                            const rx = Math.abs(pts[1].x - pts[0].x) / 2, ry = Math.abs(pts[1].y - pts[0].y) / 2;
                            if (rx < 2 || ry < 2)
                                return;
                            ctx.save();
                            ctx.translate(cx, cy);
                            ctx.scale(rx, ry);
                            ctx.beginPath();
                            ctx.arc(0, 0, 1, 0, 2 * Math.PI, false);
                            ctx.restore();
                            ctx.lineWidth = sw;
                            ctx.stroke();
                        } else if (tool === "arrow") {
                            if (pts.length < 2)
                                return;
                            const dx = pts[1].x - pts[0].x, dy = pts[1].y - pts[0].y;
                            const len = Math.sqrt(dx * dx + dy * dy);
                            if (len < 8)
                                return;
                            const ux = dx / len, uy = dy / len;
                            const hl = Math.min(30, len * 0.4);
                            const bx = pts[1].x - ux * hl, by = pts[1].y - uy * hl;
                            const px = -uy * hl * 0.4, py = ux * hl * 0.4;
                            ctx.beginPath();
                            ctx.moveTo(pts[0].x, pts[0].y);
                            ctx.lineTo(bx, by);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(pts[1].x, pts[1].y);
                            ctx.lineTo(bx + px, by + py);
                            ctx.lineTo(bx - px, by - py);
                            ctx.closePath();
                            ctx.fill();
                        } else if (tool === "text") {
                            if (!pts.length || !text)
                                return;
                            ctx.globalAlpha = 1.0;
                            ctx.font = `${sw * 4 + 8}px monospace`;
                            ctx.fillText(text, pts[0].x, pts[0].y);
                        } else if (tool === "number") {
                            if (!pts.length)
                                return;
                            ctx.globalAlpha = 1.0;
                            const cx = pts[0].x, cy = pts[0].y;
                            const r = sw * 6 + 14;

                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI, false);
                            ctx.fillStyle = color;
                            ctx.fill();

                            ctx.lineWidth = 2.5;
                            ctx.strokeStyle = "rgba(0,0,0,0.45)";
                            ctx.stroke();

                            const label = String(num ?? 1);
                            const fs = label.length > 1 ? Math.max(10, r * 1.1) : r * 1.3;
                            ctx.font = `bold ${fs}px monospace`;
                            ctx.fillStyle = "black";
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.fillText(label, cx, cy);
                            ctx.textAlign = "start";
                            ctx.textBaseline = "alphabetic";
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        for (const s of strokes)
                            paintShape(ctx, s.tool, s.color, s.pts, s.width, s.text ?? "", s.num ?? 1);
                        if (drawing && currentPts.length > 0)
                            paintShape(ctx, dock.activeTool, dock.drawColor.toString(), currentPts, dock.strokeWidth, "", 0);
                    }
                }

                readonly property var _idleTL: geom.edgePoint(ballX, ballY, 0, 0, ballRadius)
                readonly property var _idleTR: geom.edgePoint(ballX, ballY, width, 0, ballRadius)
                readonly property var _idleBL: geom.edgePoint(ballX, ballY, 0, height, ballRadius)
                readonly property var _idleBR: geom.edgePoint(ballX, ballY, width, height, ballRadius)

                Ropes {
                    anchors.fill: parent
                    visible: geom.uiVisible
                    startX: 0
                    startY: 0
                    endX: geomRect.selecting ? geomRect.anchor1X : geomRect._idleTL.x
                    endY: geomRect.selecting ? geomRect.anchor1Y : geomRect._idleTL.y
                }
                Ropes {
                    anchors.fill: parent
                    visible: geom.uiVisible
                    startX: geomRect.width
                    startY: 0
                    endX: geomRect.selecting ? geomRect.anchor2X : geomRect._idleTR.x
                    endY: geomRect.selecting ? geomRect.anchor1Y : geomRect._idleTR.y
                }
                Ropes {
                    anchors.fill: parent
                    visible: geom.uiVisible
                    startX: 0
                    startY: geomRect.height
                    endX: geomRect.selecting ? geomRect.anchor1X : geomRect._idleBL.x
                    endY: geomRect.selecting ? geomRect.anchor2Y : geomRect._idleBL.y
                }
                Ropes {
                    anchors.fill: parent
                    visible: geom.uiVisible
                    startX: geomRect.width
                    startY: geomRect.height
                    endX: geomRect.selecting ? geomRect.anchor2X : geomRect._idleBR.x
                    endY: geomRect.selecting ? geomRect.anchor2Y : geomRect._idleBR.y
                }
            }

            Text {
                visible: geom.uiVisible && geom.hintVisible
                anchors.horizontalCenter: parent.horizontalCenter
                y: 24
                text: geom.delayActive ? `Capturing in ${geom.delayRemaining}s  —  Esc cancel` : geomRect.selecting ? `H/L left/right  K/J top/bottom  Shift=inward  Alt=move  ↵/C copy+save  S annotate+save  F full-screen  U undo  R redo  W/X tool  D delay(${geom.delaySeconds}s)  Tab hide` : `drag or hjkl to select  F copy-full  S save-full  U undo  R redo  W/X tool  D delay(${geom.delaySeconds}s)  Tab hide  Esc exit`
                color: Pal.accentAlt
                font.pixelSize: 14
                font.family: "monospace"
                style: Text.Outline
                styleColor: "black"
            }

            Text {
                visible: geom.uiVisible && geomRect.selecting && (geomRect.anchor2X - geomRect.anchor1X) > 60 && (geomRect.anchor2Y - geomRect.anchor1Y) > 24
                x: geomRect.anchor1X + 6
                y: geomRect.anchor1Y + 6
                text: (geomRect.anchor2X - geomRect.anchor1X) + " × " + (geomRect.anchor2Y - geomRect.anchor1Y)
                color: Pal.accentAlt
                font.pixelSize: 12
                font.family: "monospace"
                style: Text.Outline
                styleColor: "black"
            }

            Text {
                visible: geom.uiVisible && geom.delayActive && geom.delayRemaining > 0
                anchors.centerIn: parent
                text: geom.delayRemaining
                color: Pal.accentAlt
                font.pixelSize: 96
                font.family: "monospace"
                style: Text.Outline
                styleColor: "black"
                opacity: 0.85
            }

            CornerBall {
                visible: geom.uiVisible && geomRect.selecting
                cx: geomRect.anchor1X
                cy: geomRect.anchor1Y
            }
            CornerBall {
                visible: geom.uiVisible && geomRect.selecting
                cx: geomRect.anchor2X
                cy: geomRect.anchor1Y
            }
            CornerBall {
                visible: geom.uiVisible && geomRect.selecting
                cx: geomRect.anchor1X
                cy: geomRect.anchor2Y
            }
            CornerBall {
                visible: geom.uiVisible && geomRect.selecting
                cx: geomRect.anchor2X
                cy: geomRect.anchor2Y
            }
            CornerBall {
                visible: geom.uiVisible && !geomRect.selecting
                cx: geomRect.ballX
                cy: geomRect.ballY
            }

            Dock {
                id: dock
                visible: uiVisible

                function snapToDefault() {
                    dock.userMoved = true;
                    if (vertical) {
                        xAnim.to = 28;
                        yAnim.to = (geom.height - height) / 2;
                    } else {
                        xAnim.to = (geom.width - width) / 2;
                        yAnim.to = geom.height - height - 28;
                    }
                    xAnim.restart();
                    yAnim.restart();
                }

                Binding on x {
                    when: !dock.userMoved
                    value: (geom.width - dock.width) / 2
                }
                Binding on y {
                    when: !dock.userMoved
                    value: geom.height - dock.height - 28
                }
                onVerticalChanged: { if (!dock._resetting) Qt.callLater(snapToDefault) }

                property bool _resetting: false

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

                onUndoRequested: drawingCanvas.undo()
                onRedoRequested: drawingCanvas.redo()
            }

            TextInput {
                id: textCursor
                visible: false
                color: dock.drawColor
                font.pixelSize: dock.strokeWidth * 4 + 8
                font.family: "monospace"
                property real px: 0
                property real py: 0
                x: px
                y: py - font.pixelSize

                Rectangle {
                    anchors {
                        fill: parent
                        margins: -4
                    }
                    color: Qt.rgba(0, 0, 0, 0.45)
                    radius: 4
                    z: -1
                }

                Keys.onReturnPressed: {
                    drawingCanvas.commitText(textCursor.px, textCursor.py, textCursor.text);
                    textCursor.text = "";
                    textCursor.visible = false;
                    textCursor.focus = false;
                    contentItem.focus = true;
                }
                Keys.onEscapePressed: {
                    textCursor.text = "";
                    textCursor.visible = false;
                    textCursor.focus = false;
                    contentItem.focus = true;
                }
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                cursorShape: {
                    if (!geomRect.selecting || dock.activeTool !== "none") return Qt.CrossCursor;
                    const hit = _hitTest(mouseX, mouseY);
                    if (hit === "tl" || hit === "br") return Qt.SizeFDiagCursor;
                    if (hit === "tr" || hit === "bl") return Qt.SizeBDiagCursor;
                    if (hit === "l"  || hit === "r")  return Qt.SizeHorCursor;
                    if (hit === "t"  || hit === "b")  return Qt.SizeVerCursor;
                    if (hit === "inside")              return Qt.SizeAllCursor;
                    return Qt.CrossCursor;
                }

                property real mouseOriginX: 0
                property real mouseOriginY: 0
                property real mouseAnchorDx: 0
                property real mouseAnchorDy: 0
                property bool mouseDraggingBox: false
                property string dragMode: "none"

                readonly property int _edgeHit: Math.max(geomRect.ballRadius, 12)

                function _hitTest(mx, my) {
                    if (!geomRect.selecting) return "none";
                    const x1 = geomRect.anchor1X, y1 = geomRect.anchor1Y;
                    const x2 = geomRect.anchor2X, y2 = geomRect.anchor2Y;
                    const e = _edgeHit;
                    const nearL = Math.abs(mx - x1) <= e;
                    const nearR = Math.abs(mx - x2) <= e;
                    const nearT = Math.abs(my - y1) <= e;
                    const nearB = Math.abs(my - y2) <= e;
                    const inXSpan = mx >= x1 - e && mx <= x2 + e;
                    const inYSpan = my >= y1 - e && my <= y2 + e;
                    if (nearL && nearT) return "tl";
                    if (nearR && nearT) return "tr";
                    if (nearL && nearB) return "bl";
                    if (nearR && nearB) return "br";
                    if (nearL && inYSpan) return "l";
                    if (nearR && inYSpan) return "r";
                    if (nearT && inXSpan) return "t";
                    if (nearB && inXSpan) return "b";
                    if (mx >= x1 && mx <= x2 && my >= y1 && my <= y2) return "inside";
                    return "none";
                }

                onPressed: mouse => {
                    const tool = dock.activeTool;
                    if (tool === "pen" || tool === "highlighter" || tool === "circle" || tool === "arrow" || tool === "rect" || tool === "line") {
                        drawingCanvas.beginStroke(mouse.x, mouse.y);
                        return;
                    }
                    if (tool === "number") {
                        drawingCanvas.placeNumber(mouse.x, mouse.y, dock.nextNumber, dock.drawColor.toString(), dock.strokeWidth);
                        dock.nextNumber += 1;
                        return;
                    }
                    if (tool === "text") {
                        textCursor.px = mouse.x;
                        textCursor.py = mouse.y;
                        textCursor.text = "";
                        textCursor.visible = true;
                        textCursor.focus = true;
                        return;
                    }
                    const hit = _hitTest(mouse.x, mouse.y);
                    if (hit !== "none") {
                        dragMode = hit;
                        mouseAnchorDx = mouse.x - geomRect.anchor1X;
                        mouseAnchorDy = mouse.y - geomRect.anchor1Y;
                        mouseDraggingBox = (hit === "inside");
                    } else {
                        dragMode = "new";
                        mouseDraggingBox = false;
                        mouseOriginX = mouse.x;
                        mouseOriginY = mouse.y;
                        geomRect.selecting = true;
                        geomRect.anchor1X = mouse.x;
                        geomRect.anchor1Y = mouse.y;
                        geomRect.anchor2X = mouse.x;
                        geomRect.anchor2Y = mouse.y;
                    }
                }

                onPositionChanged: mouse => {
                    const tool = dock.activeTool;
                    if (tool === "pen" || tool === "highlighter" || tool === "circle" || tool === "arrow" || tool === "rect" || tool === "line") {
                        drawingCanvas.addPoint(mouse.x, mouse.y);
                        return;
                    }
                    if (tool === "text" || tool === "number")
                        return;
                    const mx = mouse.x, my = mouse.y;
                    if (dragMode === "inside") {
                        const bw = geomRect.anchor2X - geomRect.anchor1X;
                        const bh = geomRect.anchor2Y - geomRect.anchor1Y;
                        const nx = geom.clamp(mx - mouseAnchorDx, 0, geom.width - bw);
                        const ny = geom.clamp(my - mouseAnchorDy, 0, geom.height - bh);
                        geomRect.anchor1X = nx;
                        geomRect.anchor1Y = ny;
                        geomRect.anchor2X = nx + bw;
                        geomRect.anchor2Y = ny + bh;
                    } else if (dragMode === "tl") {
                        geomRect.anchor1X = geom.clamp(mx, 0, geomRect.anchor2X - 1);
                        geomRect.anchor1Y = geom.clamp(my, 0, geomRect.anchor2Y - 1);
                    } else if (dragMode === "tr") {
                        geomRect.anchor2X = geom.clamp(mx, geomRect.anchor1X + 1, geom.width);
                        geomRect.anchor1Y = geom.clamp(my, 0, geomRect.anchor2Y - 1);
                    } else if (dragMode === "bl") {
                        geomRect.anchor1X = geom.clamp(mx, 0, geomRect.anchor2X - 1);
                        geomRect.anchor2Y = geom.clamp(my, geomRect.anchor1Y + 1, geom.height);
                    } else if (dragMode === "br") {
                        geomRect.anchor2X = geom.clamp(mx, geomRect.anchor1X + 1, geom.width);
                        geomRect.anchor2Y = geom.clamp(my, geomRect.anchor1Y + 1, geom.height);
                    } else if (dragMode === "l") {
                        geomRect.anchor1X = geom.clamp(mx, 0, geomRect.anchor2X - 1);
                    } else if (dragMode === "r") {
                        geomRect.anchor2X = geom.clamp(mx, geomRect.anchor1X + 1, geom.width);
                    } else if (dragMode === "t") {
                        geomRect.anchor1Y = geom.clamp(my, 0, geomRect.anchor2Y - 1);
                    } else if (dragMode === "b") {
                        geomRect.anchor2Y = geom.clamp(my, geomRect.anchor1Y + 1, geom.height);
                    } else if (dragMode === "new") {
                        geomRect.anchor1X = Math.min(mouseOriginX, mx);
                        geomRect.anchor1Y = Math.min(mouseOriginY, my);
                        geomRect.anchor2X = Math.max(mouseOriginX, mx);
                        geomRect.anchor2Y = Math.max(mouseOriginY, my);
                    }
                }

                onReleased: mouse => {
                    const tool = dock.activeTool;
                    if (tool === "pen" || tool === "highlighter" || tool === "circle" || tool === "arrow" || tool === "rect" || tool === "line")
                        drawingCanvas.endStroke();
                    else {
                        dragMode = "none";
                        mouseDraggingBox = false;
                    }
                }
            }
        }
    }

    component CornerBall: Item {
        property real cx: 0
        property real cy: 0
        readonly property int r: geomRect.ballRadius
        x: cx - r
        y: cy - r
        width: r * 2
        height: r * 2
        Rectangle {
            anchors.fill: parent
            radius: parent.r
            color: Pal.accentAlt
        }
    }
}
