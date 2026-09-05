import QtQuick
import QtQuick.Shapes
import "../"

Item {
    id: root

    property double startX: 0
    property double startY: 0
    property double endX: 0
    property double endY: 0

    property int segments: 10
    property int segment_length: 5
    property double gravity: 8.8

    property alias color: pathCurves.strokeColor
    property alias strokeWidth: pathCurves.strokeWidth

    readonly property double _dist: Math.sqrt((endX - startX) * (endX - startX) + (endY - startY) * (endY - startY))

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        Instantiator {
            model: root.segments
            onObjectAdded: (index, obj) => pathCurves.pathElements.push(obj)
            delegate: PathCurve {
                property int index: model.index
                x: root.startX
                y: root.startY
            }
        }

        ShapePath {
            id: pathCurves
            strokeColor: Pal.accentAlt
            fillColor: "transparent"
            strokeWidth: 8
            startX: root.startX
            startY: root.startY
        }

        ShapePath {
            id: dotPath
            strokeColor: "transparent"
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.startX
                centerY: root.startY
                radiusX: 1
                radiusY: 1
                startAngle: 0
                sweepAngle: 360
            }
        }

        Instantiator {
            model: root.segments
            onObjectAdded: (index, obj) => dotPath.pathElements.push(obj)
            delegate: PathAngleArc {
                property int index: model.index
                property double vx: 0
                property double vy: 0

                readonly property double _initX: root.startX + (root.endX - root.startX) * (index + 1) / root.segments
                readonly property double _initY: root.startY + (root.endY - root.startY) * (index + 1) / root.segments

                onCenterXChanged: {
                    if (pathCurves.pathElements[index])
                        pathCurves.pathElements[index].x = centerX;
                }
                onCenterYChanged: {
                    if (pathCurves.pathElements[index])
                        pathCurves.pathElements[index].y = centerY;
                }

                centerX: _initX
                centerY: _initY
                radiusX: 1
                radiusY: 1
                startAngle: 0
                sweepAngle: 360
            }
        }

        FrameAnimation {
            running: root._dist > 1

            onTriggered: {
                if (dotPath.pathElements.length < root.segments + 1)
                    return;
                if (pathCurves.pathElements.length < root.segments)
                    return;

                dotPath.pathElements[0].centerX = root.startX;
                dotPath.pathElements[0].centerY = root.startY;

                const endPt = dotPath.pathElements[root.segments];
                endPt.centerX = root.endX;
                endPt.centerY = root.endY;
                endPt.vx = 0;
                endPt.vy = 0;

                for (let i = root.segments - 1; i >= 1; i--) {
                    const point = dotPath.pathElements[i];
                    const prev = dotPath.pathElements[i - 1];
                    const next = dotPath.pathElements[i + 1];

                    if (!point || !prev || !next)
                        continue;

                    const prevDx = prev.centerX - point.centerX;
                    const prevDy = prev.centerY - point.centerY;
                    const prevDist = Math.sqrt(prevDx * prevDx + prevDy * prevDy);

                    const nextDx = next.centerX - point.centerX;
                    const nextDy = next.centerY - point.centerY;
                    const nextDist = Math.sqrt(nextDx * nextDx + nextDy * nextDy);

                    if (prevDist < 0.01 || nextDist < 0.01)
                        continue;

                    const prevExtend = prevDist - root.segment_length;
                    const nextExtend = nextDist - root.segment_length;

                    let vx = (prevDx / prevDist) * prevExtend + (nextDx / nextDist) * nextExtend;
                    let vy = (prevDy / prevDist) * prevExtend + (nextDy / nextDist) * nextExtend + root.gravity;

                    if (isNaN(vx)) vx = 0;
                    if (isNaN(vy)) vy = 0;

                    point.vx = point.vx * 0.55 + vx * 0.45;
                    point.vy = point.vy * 0.55 + vy * 0.45;
                    point.centerX += point.vx;
                    point.centerY += point.vy;
                }
            }
        }
    }
}
