import QtQuick
import QtQuick.Shapes
import "../"

// The ropes swinging from the screen's corners to the selection while you pick a region, in two looks (G swaps them).
Item {
    id: root

    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property string design: "a"

    readonly property int segments: 10
    readonly property real segmentLength: 5
    readonly property real gravity: 8.8
    readonly property real armWidth: 8
    readonly property real rimWidth: 1.5
    readonly property color shadow: Qt.darker(Pal.color0, 1.6)
    readonly property color rim: Qt.lighter(Pal.accentAlt, 1.15)
    readonly property color glow: Pal.accentAlt

    property var _px: []
    property var _py: []
    property var _vx: []
    property var _vy: []
    property bool _still: false
    property int _calm: 0

    function _reset() {
        const px = [], py = [], vx = [], vy = [];
        for (let i = 0; i <= segments; i++) {
            px.push(startX + (endX - startX) * i / segments);
            py.push(startY + (endY - startY) * i / segments);
            vx.push(0);
            vy.push(0);
        }
        _px = px; _py = py; _vx = vx; _vy = vy;
        _wake();
        _draw();
    }
    function _draw() {
        if (_px.length !== segments + 1)
            return;
        for (const path of design === "b" ? [hazePath, glowPath, rimPath, bodyPath] : [plainPath]) {
            if (path.pathElements.length !== segments)
                return;
            path.startX = _px[0];
            path.startY = _py[0];
            for (let i = 0; i < segments; i++) {
                path.pathElements[i].x = _px[i + 1];
                path.pathElements[i].y = _py[i + 1];
            }
        }
    }

    Component {
        id: curve
        PathCurve {}
    }
    Component.onCompleted: {
        for (const path of [plainPath, hazePath, glowPath, rimPath, bodyPath])
            for (let i = 0; i < segments; i++)
                path.pathElements.push(curve.createObject(path));
        _reset();
    }
    onVisibleChanged: if (visible) _reset()
    onWidthChanged: _reset()
    onHeightChanged: _reset()
    onDesignChanged: _draw()
    function _wake() {
        _still = false;
        _calm = 0;
    }
    onStartXChanged: _wake()
    onStartYChanged: _wake()
    onEndXChanged: _wake()
    onEndYChanged: _wake()
    readonly property bool _short: Math.hypot(endX - startX, endY - startY) <= 1
    on_ShortChanged: if (_short) _reset()

    FrameAnimation {
        running: root.visible && !root._still && !root._short
        onTriggered: {
            const n = root.segments;
            const px = root._px, py = root._py, vx = root._vx, vy = root._vy;
            if (px.length !== n + 1) {
                root._reset();
                return;
            }
            px[0] = root.startX; py[0] = root.startY;
            px[n] = root.endX; py[n] = root.endY;
            vx[n] = 0; vy[n] = 0;
            let fastest = 0;
            for (let i = n - 1; i >= 1; i--) {
                const pdx = px[i - 1] - px[i], pdy = py[i - 1] - py[i];
                const ndx = px[i + 1] - px[i], ndy = py[i + 1] - py[i];
                const pd = Math.hypot(pdx, pdy), nd = Math.hypot(ndx, ndy);
                if (pd < 0.01 || nd < 0.01)
                    continue;
                const pe = pd - root.segmentLength, ne = nd - root.segmentLength;
                const fx = (pdx / pd) * pe + (ndx / nd) * ne;
                const fy = (pdy / pd) * pe + (ndy / nd) * ne + root.gravity;
                vx[i] = vx[i] * 0.55 + (isNaN(fx) ? 0 : fx) * 0.45;
                vy[i] = vy[i] * 0.55 + (isNaN(fy) ? 0 : fy) * 0.45;
                px[i] += vx[i];
                py[i] += vy[i];
                fastest = Math.max(fastest, Math.abs(vx[i]), Math.abs(vy[i]));
            }
            root._draw();
            root._calm = fastest < 0.1 ? root._calm + 1 : 0;
            if (root._calm >= 10)
                root._still = true;
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.design !== "b"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: plainPath
            strokeColor: Pal.accentAlt
            strokeWidth: root.armWidth
            fillColor: "transparent"
        }
    }

    Shape {
        anchors.fill: parent
        visible: root.design === "b"
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            id: hazePath
            strokeColor: Qt.rgba(root.glow.r, root.glow.g, root.glow.b, 0.09)
            strokeWidth: root.armWidth + 16
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
        }
        ShapePath {
            id: glowPath
            strokeColor: Qt.rgba(root.glow.r, root.glow.g, root.glow.b, 0.22)
            strokeWidth: root.armWidth + 7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
        }
        ShapePath {
            id: rimPath
            strokeColor: root.rim
            strokeWidth: root.armWidth + root.rimWidth * 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
        }
        ShapePath {
            id: bodyPath
            strokeColor: root.shadow
            strokeWidth: root.armWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
        }
    }
}
