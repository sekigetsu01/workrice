import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// The screenshotter (qs ipc call screenshotter toggle): freezes the screen to pick a region or the whole screen and
// draw on it, then copies, saves to ~/Pictures/Screenshots or reads its text (tesseract). Also edits a picture from
// swayimg (editFor).
QtObject {
    id: root

    property bool active: false
    onActiveChanged: {
        if (active)
            return;
        _ropesSwapped = false;
        _escClose = false;
        _keyHandover.stop();
        _keyCheck.stop();
        keyScreen = 0;
        _nextKeyScreen = -1;
        if (editing) {
            editing = false;
            editSrc = "";
            editPid = 0;
            Quickshell.execDetached(["rm", "-f", editPreview]);
        }
    }

    readonly property string tmpDir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string watermarkBin: Quickshell.env("HOME") + "/.local/bin/watermark"
    property FileView watermarkFile: FileView {
        path: root.watermarkBin
        printErrors: false
        blockLoading: true
    }
    readonly property bool hasWatermark: watermarkFile.loaded
    readonly property string imSetup: "if command -v magick >/dev/null 2>&1; then IM=(magick); ID=(magick identify)\nelif command -v convert >/dev/null 2>&1; then IM=(convert); ID=(identify)\nelse exit 3; fi\n"
    function notify(title, body, critical) {
        Quickshell.execDetached(["notify-send", "-a", "Screenshot"].concat(critical ? ["--urgency=critical"] : [], [title, body]));
    }

    property bool editing: false
    property string editSrc: ""
    property int editPid: 0
    property int editW: 0
    property int editH: 0
    property string editFont: ""
    property string editFontBold: ""
    readonly property string editPreview: tmpDir + "/qs_edit_preview.png"
    property var _editPrep: Process {
        stdout: StdioCollector {
            id: _editOut
        }
        onExited: code => {
            const out = _editOut.text.split("\n");
            const wh = (out[0] || "").split(" ");
            const w = parseInt(wh[0]), h = parseInt(wh[1]);
            if (root.active || code !== 0 || !(w > 0 && h > 0)) {
                if (!root.active)
                    root.notify("Can't edit the image", code === 3 ? "ImageMagick is not installed (needs magick or convert)" : root.editSrc, true);
                Quickshell.execDetached(["rm", "-f", root.editPreview]);
                return;
            }
            root.editW = w;
            root.editH = h;
            root.editFont = out[1] || "";
            root.editFontBold = out[2] || "";
            root.editing = true;
            root.active = true;
        }
    }
    function edit(path, pid) {
        if (active || _editPrep.running || _preFreeze.running || !Quickshell.screens.length)
            return;
        path = String(path);
        if (path[0] !== "/") {
            notify("Can't edit the image", "Needs the full path: " + path, true);
            return;
        }
        const s = Quickshell.screens[0], dpr = s.devicePixelRatio || 1;
        editSrc = path;
        editPid = pid || 0;
        _editPrep.command = ["bash", "-c", imSetup + "\"${IM[@]}\" \"$1[0]\" -auto-orient +repage -format '%w %h\\n' -write info:- -resize \"$3>\" \"PNG32:$2\" || exit 4\n" + "fc-match -f '%{file}\\n' monospace 2>/dev/null || echo\n" + "fc-match -f '%{file}\\n' monospace:bold 2>/dev/null || echo", "_", path, editPreview, Math.round(s.width * dpr) + "x" + Math.round(s.height * dpr)];
        _editPrep.running = true;
    }

    property int keyScreen: 0
    property int _nextKeyScreen: -1
    signal keyCheck
    function giveKeys(idx) {
        if (idx === keyScreen && _nextKeyScreen < 0) {
            keyCheck();
            return;
        }
        if (idx === _nextKeyScreen)
            return;
        if (_nextKeyScreen >= 0)
            keyScreen = _nextKeyScreen;
        _nextKeyScreen = idx;
        _keyHandover.restart();
    }
    property var _keyHandover: Timer {
        interval: 150
        onTriggered: {
            if (root._nextKeyScreen < 0)
                return;
            root.keyScreen = root._nextKeyScreen;
            root._nextKeyScreen = -1;
            root._keyCheck.restart();
        }
    }
    property var _keyCheck: Timer {
        interval: 150
        onTriggered: root.keyCheck()
    }

    property bool _prefrozen: false
    property var _preFreeze: Process {
        onExited: code => {
            root._prefrozen = code === 0;
            root.active = true;
            Qt.callLater(() => root._prefrozen = false);
        }
    }
    function toggle() {
        if (active) {
            active = false;
            return;
        }
        if (_preFreeze.running || _editPrep.running)
            return;
        const cmds = Quickshell.screens.map((s, i) => "grim " + (s.name ? "-o '" + s.name.replace(/'/g, "") + "' " : "") + "'" + tmpDir + "/qs_frozen_frame_" + i + ".png' & pids=\"$pids $!\"; ");
        _preFreeze.command = ["sh", "-c", "pids=; " + cmds.join("") + "f=0; for p in $pids; do wait $p || f=1; done; exit $f"];
        _preFreeze.running = true;
    }

    property bool _ropesSwapped: false
    // the last Esc closes on its release, so the window underneath doesn't get the Esc as well
    property bool _escClose: false
    readonly property string ropeDesign: /\/night\//i.test(Pal.wallpaper) === _ropesSwapped ? "a" : "b"
    readonly property int ballRadius: 12

    property var _variants: Variants {
        model: Quickshell.screens

        PanelWindow {
            id: geom
            required property var modelData

            screen: modelData
            visible: root.active && (!root.editing || _screenIdx === 0)
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: root.active && !_askAgain && (_screenIdx === root.keyScreen || _screenIdx === root._nextKeyScreen) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            color: "transparent"
            anchors {
                top: true
                left: true
                right: true
                bottom: true
            }

            property bool _askAgain: false
            Item {
                id: keyProbe
                readonly property bool hasKeys: Window.active
            }
            Connections {
                target: root
                function onKeyCheck() {
                    if (root.keyScreen === geom._screenIdx && !keyProbe.hasKeys) {
                        geom._askAgain = true;
                        askAgainTimer.restart();
                    }
                }
            }
            Timer {
                id: askAgainTimer
                interval: 100
                onTriggered: geom._askAgain = false
            }

            readonly property string saveDir: Quickshell.env("HOME") + "/Pictures/Screenshots"
            property bool uiVisible: true
            property string pendingCmd: ""
            property int delaySeconds: 0
            property int delayRemaining: 0
            property string _savePath: ""
            readonly property bool delayActive: delayTimer.running

            readonly property int _screenIdx: Quickshell.screens.indexOf(modelData)
            readonly property string frozenFrame: `${root.tmpDir}/qs_frozen_frame_${_screenIdx}.png`
            readonly property string _drawPath: `${root.tmpDir}/qs_drawing_${_screenIdx}.png`
            property bool frameReady: false
            property bool _hideAll: false
            property bool _refreeze: false
            property bool _busy: false
            property bool _hasDrawing: false
            readonly property var _grimCmd: ["grim"].concat(modelData && modelData.name ? ["-o", modelData.name] : [], [frozenFrame])

            property Region passThroughRegion: Region {}
            mask: delayActive ? passThroughRegion : null

            property real _ex: 0
            property real _ey: 0
            property real _ew: 1
            property real _eh: 1

            onVisibleChanged: {
                if (visible) {
                    const ready = root.editing || root._prefrozen;
                    if (root.editing) {
                        const sw = modelData.width, sh = modelData.height;
                        const s = Math.max(0.55, Math.min(1.8, Math.min(sw, sh) / 1080));
                        const k = Math.min((sw - 56 * s) / root.editW, (sh - 228 * s) / root.editH);
                        _ew = root.editW * k;
                        _eh = root.editH * k;
                        _ex = Math.round((sw - _ew) / 2);
                        _ey = Math.round((sh - _eh) / 2);
                    }
                    frameReady = ready;
                    uiVisible = ready;
                    if (!ready)
                        freezeDelay.start();
                    geomRect.ballX = width / 2;
                    geomRect.ballY = height / 2;
                    Qt.callLater(() => {
                        geomRect.ballX = geom.width / 2 + 40;
                        geomRect.ballY = geom.height / 2 - 40;
                    });
                    return;
                }
                freezeDelay.stop();
                delayTimer.stop();
                refreezeTimer.stop();
                captureTimer.stop();
                _busy = false;
                _refreeze = false;
                _hideAll = false;
                uiVisible = true;
                frameReady = false;
                delaySeconds = 0;
                delayRemaining = 0;
                geomRect.selecting = false;
                drawingCanvas.clear();
                textCursor.close(false);
                dock.reset();
                _dropFrame();
            }

            function _dropFrame() {
                if (!visible && !freezeProcess.running && !refreezeProcess.running && !captureProcess.running)
                    Quickshell.execDetached(["rm", "-f", frozenFrame]);
            }

            Timer {
                id: freezeDelay
                interval: 150
                onTriggered: freezeProcess.running = true
            }

            Process {
                id: freezeProcess
                command: geom._grimCmd
                onExited: code => {
                    if (!geom.visible) {
                        geom._dropFrame();
                    } else if (code === 0) {
                        geom.frameReady = true;
                        geom.uiVisible = true;
                    } else {
                        geom._captureFailed("grim could not capture the screen");
                        root.active = false;
                    }
                }
            }

            Image {
                x: root.editing ? geom._ex : 0
                y: root.editing ? geom._ey : 0
                width: root.editing ? geom._ew : parent.width
                height: root.editing ? geom._eh : parent.height
                source: geom.frameReady ? "file://" + (root.editing ? root.editPreview : geom.frozenFrame) : ""
                visible: geom.frameReady && !geom.delayActive && !geom._hideAll && !geom._refreeze
                cache: false
                z: -10
            }

            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: 0.45
                z: -9
                visible: geom.uiVisible && !geom.delayActive && !geom._refreeze && !root.editing
            }

            function clamp(v, lo, hi) {
                return Math.max(lo, Math.min(hi, v));
            }

            function edgePoint(cx, cy, fx, fy, r) {
                const dx = fx - cx, dy = fy - cy, d = Math.hypot(dx, dy);
                return d < 1 ? { x: cx, y: cy } : { x: cx + dx / d * r, y: cy + dy / d * r };
            }

            function kbEnsureSelecting() {
                if (geomRect.selecting)
                    return;
                const qx = Math.round(width / 4), qy = Math.round(height / 4);
                geomRect.anchor1X = qx;
                geomRect.anchor1Y = qy;
                geomRect.anchor2X = width - qx;
                geomRect.anchor2Y = height - qy;
                geomRect.selecting = true;
            }

            function kbMove(ax, dir, mods) {
                kbEnsureSelecting();
                const g = geomRect, a = "anchor1" + ax, b = "anchor2" + ax, max = ax === "X" ? width : height;
                const step = mods & Qt.ControlModifier ? 50 : 10;
                if (mods & Qt.AltModifier) {
                    const size = g[b] - g[a], n = clamp(g[a] + dir * step, 0, max - size);
                    g[a] = n;
                    g[b] = n + size;
                    return;
                }
                const d = (mods & Qt.ShiftModifier ? -dir : dir) * step;
                if (dir < 0)
                    g[a] = clamp(g[a] + d, 0, g[b] - 1);
                else
                    g[b] = clamp(g[b] + d, g[a] + 1, max);
            }

            readonly property bool fullSelected: geomRect.selecting && geomRect.anchor1X <= 0 && geomRect.anchor1Y <= 0 && geomRect.anchor2X >= Math.floor(width) && geomRect.anchor2Y >= Math.floor(height)
            function toggleFullSelection() {
                if (root.editing || delayTimer.running)
                    return;
                if (fullSelected) {
                    geomRect.selecting = false;
                    return;
                }
                geomRect.anchor1X = 0;
                geomRect.anchor1Y = 0;
                geomRect.anchor2X = Math.floor(width);
                geomRect.anchor2Y = Math.floor(height);
                geomRect.selecting = true;
            }

            function cycleDelay() {
                if (!delayTimer.running)
                    delaySeconds = delaySeconds === 0 ? 3 : delaySeconds === 3 ? 5 : 0;
            }

            function _q(s) {
                return "'" + String(s).replace(/'/g, "'\\''") + "'";
            }

            function editDraws() {
                const f = root.editW / _ew;
                const X = x => +((x - _ex) * f).toFixed(1), Y = y => +((y - _ey) * f).toFixed(1), N = v => +(v * f).toFixed(2);
                const P = p => X(p.x) + "," + Y(p.y);
                const str = t => "'" + String(t).replace(/[\\']/g, "\\$&") + "'";
                const font = file => file ? "font " + str(file) + " " : "";
                const out = [];
                for (const s of drawingCanvas.strokes) {
                    const pts = s.pts, sw = s.width || 3, t = s.tool;
                    const c = String(s.color), col = "'" + (c.length === 9 ? "#" + c.slice(3) + c.slice(1, 3) : c) + "'";
                    const line = `stroke ${col} stroke-width ${N(sw)} stroke-linecap round stroke-linejoin round fill none `;
                    if (!pts || !pts.length || (pts.length < 2 && t !== "text" && t !== "number"))
                        continue;
                    const a = pts[0], b = pts[pts.length - 1];
                    const x0 = Math.min(a.x, b.x), y0 = Math.min(a.y, b.y), x1 = Math.max(a.x, b.x), y1 = Math.max(a.y, b.y);
                    if (t === "pen") {
                        out.push(line + "polyline " + pts.map(P).join(" "));
                    } else if (t === "highlighter") {
                        if (x1 - x0 >= 2 && y1 - y0 >= 2)
                            out.push(`fill ${col} fill-opacity 0.35 stroke none rectangle ${X(x0)},${Y(y0)} ${X(x1)},${Y(y1)}`);
                    } else if (t === "line") {
                        out.push(line + "line " + P(a) + " " + P(b));
                    } else if (t === "rect") {
                        out.push((s.fill ? `fill ${col} stroke none ` : line) + `rectangle ${X(x0)},${Y(y0)} ${X(x1)},${Y(y1)}`);
                    } else if (t === "circle") {
                        if (x1 - x0 >= 4 && y1 - y0 >= 4)
                            out.push((s.fill ? `fill ${col} stroke none ` : line) + `ellipse ${X((x0 + x1) / 2)},${Y((y0 + y1) / 2)} ${N((x1 - x0) / 2)},${N((y1 - y0) / 2)} 0,360`);
                    } else if (t === "arrow") {
                        const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy);
                        if (len < 8)
                            continue;
                        const ux = dx / len, uy = dy / len, hl = Math.min(30, len * 0.4);
                        const bx = b.x - ux * hl, by = b.y - uy * hl, px = -uy * hl * 0.4, py = ux * hl * 0.4;
                        out.push(line + "line " + P(a) + " " + P({ x: bx, y: by }) + ` fill ${col} stroke none polygon ` + P(b) + " " + P({ x: bx + px, y: by + py }) + " " + P({ x: bx - px, y: by - py }));
                    } else if (t === "text") {
                        if (s.text)
                            out.push(font(root.editFont) + `font-size ${N(drawingCanvas.fontSize(s))} fill ${col} stroke none text ${P(a)} ` + str(s.text));
                    } else if (t === "number") {
                        const r = sw * 6 + 14, label = String(s.num ?? 1), fs = label.length > 1 ? Math.max(10, r * 1.1) : r * 1.3;
                        out.push(`fill ${col} stroke '#00000073' stroke-width ${N(2.5)} circle ${P(a)} ${X(a.x + r)},${Y(a.y)} ` + font(root.editFontBold) + `stroke none fill black font-size ${N(fs)} text-anchor middle text ${X(a.x)},${Y(a.y + fs * 0.36)} ` + str(label));
                    }
                }
                return out;
            }

            function buildEditScript(copy) {
                const L = [
                    "set -e",
                    "S=" + _q(root.editSrc),
                    root.imSetup,
                    'D=(); for a; do D+=(-draw "$a"); done',
                    'if [ "${IM[0]}" = magick ]; then D=("${D[@]//\\\\/\\\\\\\\}"); D=("${D[@]//%/%%}"); D=("${D[@]//&/\\&amp;}"); fi',
                    'dir=${S%/*}; n=${S##*/}',
                    'case $n in ?*.*) stem=${n%.*}; ext=${n##*.} ;; *) stem=$n; ext=png ;; esac',
                    'case ${ext,,} in png|jpg|jpeg|jpe|jfif|webp|gif|bmp|tif|tiff|avif|heic|heif|jxl|qoi|tga|ppm|pgm|pnm) ;; *) ext=png ;; esac',
                    'pick() { OUT=$dir/$stem-drawn.$ext; i=2; while [ -e "$OUT" ]; do OUT=$dir/$stem-drawn-$i.$ext; i=$((i + 1)); done; }',
                    'draw() { "${IM[@]}" "$S[0]" -auto-orient +repage "${D[@]}" "$OUT"; }',
                    'pick',
                    'if ! draw 2>/dev/null; then rm -f "$OUT"; ext=png; pick; draw; fi'
                ];
                if (copy)
                    L.push('if [ "${ext,,}" = png ]; then wl-copy -t image/png < "$OUT"; else "${IM[@]}" "$OUT" png:- | wl-copy -t image/png; fi >/dev/null 2>&1');
                if (root.editPid > 0)
                    L.push(`P=${root.editPid}; if [ "$(cat /proc/$P/comm 2>/dev/null)" = swayimg ]; then printf '%s\\n' "$OUT" > "\${XDG_RUNTIME_DIR:-/tmp}/qs_edit_$P"; kill -USR1 $P; fi`);
                L.push("printf '%s' \"$OUT\"");
                return L.join("\n");
            }

            function buildComposeScript(mode, hasDrawing) {
                const region = mode.indexOf("region") === 0;
                const copy = mode === "full_copy" || mode === "region_copy" || mode === "region_copy_save";
                const save = mode === "full_save" || mode === "region_save" || mode === "region_copy_save" || mode.endsWith("_watermark");
                const ocr = mode === "region_ocr";
                const out = save ? `${saveDir}/screenshot_${Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss")}.png` : `${root.tmpDir}/qs_shot_${_screenIdx}.png`;
                _savePath = out;
                const L = [
                    "set -e",
                    "F=" + _q(frozenFrame) + "; D=" + _q(_drawPath) + "; OUT=" + _q(out),
                    "LW=" + Math.round(width) + "; LH=" + Math.round(height),
                    root.imSetup,
                    "read -r FW FH < <(\"${ID[@]}\" -format '%w %h\\n' \"$F\")",
                    "crop=()"
                ];
                if (ocr)
                    L.push("command -v tesseract >/dev/null 2>&1 || exit 4");
                if (region) {
                    const x = geomRect.anchor1X, y = geomRect.anchor1Y;
                    const w = geomRect.anchor2X - x, h = geomRect.anchor2Y - y;
                    L.push(`read -r CX CY CW CH < <(awk -v fw="$FW" -v fh="$FH" -v lw="$LW" -v lh="$LH" 'BEGIN { sx = fw / lw; sy = fh / lh; printf "%d %d %d %d\\n", ${x} * sx + 0.5, ${y} * sy + 0.5, ${w} * sx + 0.5, ${h} * sy + 0.5 }')`);
                    L.push('crop=(-crop "${CW}x${CH}+${CX}+${CY}" +repage)');
                }
                L.push('mkdir -p "$(dirname "$OUT")"');
                if (hasDrawing)
                    L.push('"${IM[@]}" "$F" \\( "$D" -resize "${FW}x${FH}!" \\) -composite "${crop[@]}" -strip "$OUT"', 'rm -f "$D"');
                else
                    L.push('"${IM[@]}" "$F" "${crop[@]}" -strip "$OUT"');
                if (ocr) {
                    L.push('"${IM[@]}" "$OUT" -resize 200% -colorspace Gray "$OUT"');
                    L.push('TXT=$(tesseract "$OUT" - 2>/dev/null | tr -d \'\\f\' | sed -e \'s/[[:space:]]*$//\')');
                    L.push('rm -f "$OUT"');
                    L.push('[ -n "$(printf \'%s\' "$TXT" | tr -d \'[:space:]\')" ] || exit 5');
                    L.push('printf \'%s\' "$TXT" | wl-copy');
                    L.push('notify-send -a Screenshot "Copied text" "$(printf \'%s\' "$TXT" | head -c 200)"');
                    return L.join("\n");
                }
                if (copy)
                    L.push('wl-copy -t image/png < "$OUT"');
                if (!save)
                    L.push('rm -f "$OUT"');
                return L.join("\n");
            }

            function triggerCapture(mode) {
                if (_busy || delayTimer.running || captureProcess.running || refreezeProcess.running)
                    return;
                if (mode.indexOf("region") === 0 && (!geomRect.selecting || geomRect.anchor2X <= geomRect.anchor1X || geomRect.anchor2Y <= geomRect.anchor1Y))
                    return;
                textCursor.close(true);
                if (root.editing && !editDraws().length) {
                    root.notify("Nothing drawn", "Draw something first");
                    return;
                }
                _busy = true;
                pendingCmd = mode;
                drawingCanvas.selectedIndex = -1;
                if (delaySeconds > 0) {
                    delayRemaining = delaySeconds;
                    delayTimer.start();
                    return;
                }
                _refreeze = false;
                startCapture();
            }

            function removeWatermark() {
                if (root.editing && !editDraws().length) {
                    if (_busy)
                        return;
                    runWatermark(root.editSrc);
                    root.active = false;
                    return;
                }
                triggerCapture(root.editing ? "edit_watermark" : geomRect.selecting ? "region_watermark" : "full_watermark");
            }

            function runWatermark(path) {
                Quickshell.execDetached([root.watermarkBin, path].concat(root.editPid > 0 ? [String(root.editPid)] : []));
            }

            function startCapture() {
                if (root.editing) {
                    _afterDrawingSaved(true);
                } else if (pendingCmd !== "region_ocr" && drawingCanvas.strokes.length > 0) {
                    drawingCanvas.grabToImage(result => {
                        geom._afterDrawingSaved(result.saveToFile(geom._drawPath));
                    });
                } else {
                    _afterDrawingSaved(false);
                }
            }

            function _afterDrawingSaved(has) {
                _hasDrawing = has;
                uiVisible = false;
                if (_refreeze) {
                    _hideAll = true;
                    refreezeTimer.start();
                } else {
                    captureTimer.start();
                }
            }

            function _captureFailed(msg) {
                _busy = false;
                _hideAll = false;
                _refreeze = false;
                uiVisible = true;
                root.notify("Screenshot failed", msg, true);
            }

            Timer {
                id: delayTimer
                interval: 1000
                repeat: true
                onTriggered: {
                    if (--geom.delayRemaining > 0)
                        return;
                    geom._refreeze = true;
                    stop();
                    geom.startCapture();
                }
            }

            Timer {
                id: refreezeTimer
                interval: 150
                onTriggered: refreezeProcess.running = true
            }

            Process {
                id: refreezeProcess
                command: geom._grimCmd
                onExited: code => {
                    if (!geom.visible) {
                        geom._dropFrame();
                        return;
                    }
                    geom._hideAll = false;
                    if (code !== 0) {
                        geom._captureFailed("grim could not capture the screen");
                        return;
                    }
                    geom.frameReady = false;
                    geom.frameReady = true;
                    geom._refreeze = false;
                    captureTimer.start();
                }
            }

            Timer {
                id: captureTimer
                interval: 80
                onTriggered: {
                    captureProcess.mode = geom.pendingCmd;
                    if (root.editing)
                        captureProcess.command = ["bash", "-c", geom.buildEditScript(geom.pendingCmd === "edit_copy_save"), "bash"].concat(geom.editDraws());
                    else
                        captureProcess.command = ["bash", "-c", geom.buildComposeScript(geom.pendingCmd, geom._hasDrawing)];
                    captureProcess.running = true;
                }
            }

            Process {
                id: captureProcess
                property string mode: ""
                stdout: StdioCollector {
                    id: captureOut
                }
                onExited: code => {
                    geom._dropFrame();
                    const err = {
                        3: "ImageMagick is not installed (needs magick or convert)",
                        4: "tesseract is not installed (pacman -S tesseract tesseract-data-eng)",
                        5: "No text found in the selection"
                    }[code];
                    if (code !== 0) {
                        geom._captureFailed(err || "Could not create the image (exit " + code + ")");
                        return;
                    }
                    const m = mode;
                    if (m.endsWith("_watermark"))
                        geom.runWatermark(m === "edit_watermark" ? captureOut.text : geom._savePath);
                    else if (m === "edit_save" || m === "edit_copy_save")
                        root.notify(m === "edit_save" ? "Saved" : "Copied & Saved", captureOut.text);
                    else if (m === "full_copy" || m === "region_copy")
                        root.notify("Copied", m === "region_copy" && !geom.fullSelected ? "Region" : "Full screen");
                    else if (m === "region_copy_save")
                        root.notify("Copied & Saved", geom._savePath);
                    else if (m !== "region_ocr")
                        root.notify("Saved", geom._savePath);
                    root.active = false;
                }
            }

            function keyAction(k, m) {
                const ctrl = m & Qt.ControlModifier, dc = drawingCanvas;
                const is = (...ks) => ks.indexOf(k) !== -1;
                const step = ctrl ? 50 : 10;
                if (dock.activeTool === "move" && dc.selectedIndex !== -1) {
                    if (is(Qt.Key_Delete, Qt.Key_Backspace))
                        return () => dc.deleteSelected();
                    if (ctrl && is(Qt.Key_Equal, Qt.Key_Plus, Qt.Key_Minus, Qt.Key_Underscore))
                        return () => dc.resizeSelectedText(is(Qt.Key_Minus, Qt.Key_Underscore) ? -2 : 2);
                    if (is(Qt.Key_BracketLeft, Qt.Key_BracketRight))
                        return () => dock.changeSize(k === Qt.Key_BracketLeft ? -1 : 1);
                    if (k === Qt.Key_B && !ctrl && ["rect", "circle"].indexOf(dc.strokes[dc.selectedIndex].tool) !== -1)
                        return () => dc._change(dc.selectedIndex, s => s.fill = !s.fill);
                    const d = ({ [Qt.Key_Left]: [-step, 0], [Qt.Key_Right]: [step, 0], [Qt.Key_Up]: [0, -step], [Qt.Key_Down]: [0, step] })[k];
                    if (d)
                        return () => dc.moveStroke(dc.selectedIndex, d[0], d[1]);
                }
                if (ctrl && !(m & Qt.AltModifier) && is(Qt.Key_H, Qt.Key_Left, Qt.Key_L, Qt.Key_Right))
                    return () => dock.cycleTool(is(Qt.Key_H, Qt.Key_Left) ? -1 : 1);
                if (textCursor.visible && is(Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down))
                    return null;
                if (!textCursor.visible && !(m & Qt.AltModifier)) {
                    const shift = m & Qt.ShiftModifier;
                    if (ctrl && !shift && k === Qt.Key_F)
                        return () => toggleFullSelection();
                    if (!ctrl && !shift && k >= Qt.Key_1 && k <= Qt.Key_9 && k - Qt.Key_1 < dock.toolList.length)
                        return () => {
                            dock.activeTool = dock.toolList[k - Qt.Key_1];
                        };
                    if (!ctrl && !shift && k === Qt.Key_O)
                        return () => {
                            dock.colourWheelVisible = !dock.colourWheelVisible;
                        };
                    if (!ctrl && !shift && k === Qt.Key_B)
                        return () => dock.toggleFill();
                    if (!ctrl && !shift && k === Qt.Key_Z)
                        return () => dock.toggleSizePopup();
                    if (!ctrl && shift && k === Qt.Key_W && root.hasWatermark)
                        return () => removeWatermark();
                }
                if (root.editing && is(Qt.Key_H, Qt.Key_J, Qt.Key_K, Qt.Key_L, Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down, Qt.Key_D, Qt.Key_F, Qt.Key_T, Qt.Key_G, Qt.Key_A))
                    return null;
                const dir = ({ [Qt.Key_H]: ["X", -1], [Qt.Key_Left]: ["X", -1], [Qt.Key_L]: ["X", 1], [Qt.Key_Right]: ["X", 1], [Qt.Key_K]: ["Y", -1], [Qt.Key_Up]: ["Y", -1], [Qt.Key_J]: ["Y", 1], [Qt.Key_Down]: ["Y", 1] })[k];
                if (dir)
                    return () => kbMove(dir[0], dir[1], m);
                if (is(Qt.Key_BracketLeft, Qt.Key_BracketRight))
                    return () => dock.changeSize(k === Qt.Key_BracketLeft ? -1 : 1);
                if (ctrl)
                    return k === Qt.Key_Z ? () => dc.undo() : k === Qt.Key_Y ? () => dc.redo() : null;
                const sel = geomRect.selecting;
                return ({
                    [Qt.Key_D]: () => cycleDelay(),
                    [Qt.Key_A]: () => toggleFullSelection(),
                    [Qt.Key_F]: () => triggerCapture("full_copy"),
                    [Qt.Key_S]: () => triggerCapture(root.editing ? "edit_save" : sel ? "region_save" : "full_save"),
                    [Qt.Key_C]: root.editing || sel ? () => triggerCapture(root.editing ? "edit_copy_save" : "region_copy_save") : null,
                    [Qt.Key_T]: sel ? () => triggerCapture("region_ocr") : null,
                    [Qt.Key_W]: () => dock.cycleTool(1),
                    [Qt.Key_X]: () => dock.cycleTool(-1),
                    [Qt.Key_U]: () => dc.undo(),
                    [Qt.Key_R]: () => dc.redo(),
                    [Qt.Key_P]: () => dock.vertical = !dock.vertical,
                    [Qt.Key_G]: () => root._ropesSwapped = !root._ropesSwapped
                })[k] || null;
            }

            contentItem {
                focus: root.active

                Keys.onEscapePressed: {
                    root._escClose = false;
                    if (delayTimer.running) {
                        delayTimer.stop();
                        geom._busy = false;
                        geom.delayRemaining = 0;
                        geom.uiVisible = true;
                    } else if (dock.colourWheelVisible) {
                        dock.colourWheelVisible = false;
                    } else if (dock.sizePopupVisible) {
                        dock.sizePopupVisible = false;
                    } else if (dock.activeTool !== "none") {
                        dock.activeTool = "none";
                    } else if (geomRect.selecting) {
                        geomRect.selecting = false;
                    } else {
                        root._escClose = true;
                    }
                }
                Keys.onReleased: event => {
                    if (event.key === Qt.Key_Escape && root._escClose && !event.isAutoRepeat) {
                        event.accepted = true;
                        root.active = false;
                    }
                }
                Keys.onReturnPressed: geom.triggerCapture(root.editing ? "edit_copy_save" : geomRect.selecting ? "region_copy" : "full_copy")
                Keys.onPressed: event => {
                    const f = geom.keyAction(event.key, event.modifiers);
                    if (f) {
                        f();
                        event.accepted = true;
                    }
                }
            }

            Item {
                id: geomRect
                anchors.fill: parent

                property int anchor1X: 0
                property int anchor1Y: 0
                property int anchor2X: 0
                property int anchor2Y: 0
                property bool selecting: false
                property real ballX: width / 2
                property real ballY: height / 2
                readonly property real ballTargetX: selecting ? (anchor1X + anchor2X) / 2 : width / 2
                readonly property real ballTargetY: selecting ? (anchor1Y + anchor2Y) / 2 : height / 2

                FrameAnimation {
                    running: root.active && !root.editing && (Math.abs(geomRect.ballTargetX - geomRect.ballX) > 0.5 || Math.abs(geomRect.ballTargetY - geomRect.ballY) > 0.5)
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
                readonly property string _design: root.ropeDesign
                on_DesignChanged: selCanvas.requestPaint()

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
                        ctx.fillStyle = "black";
                        ctx.globalAlpha = 0.55;
                        ctx.fillRect(0, 0, width, height);
                        ctx.clearRect(x1, y1, w, h);
                        ctx.globalAlpha = 1;
                        const b = root.ropeDesign === "b", T = b ? 7 : 4;
                        const ox = Math.max(x1 - T, 0), oy = Math.max(y1 - T, 0);
                        const ow = Math.min(x1 + w + T, width) - ox, oh = Math.min(y1 + h + T, height) - oy;
                        const ring = (from, to, colour) => {
                            const d = T - (from + to) / 2;
                            ctx.strokeStyle = colour;
                            ctx.lineWidth = to - from;
                            ctx.strokeRect(ox + d, oy + d, ow - d * 2, oh - d * 2);
                        };
                        if (b) {
                            ring(0, 7, Qt.lighter(Pal.accentAlt, 1.15));
                            ring(1.4, 5.6, Qt.darker(Pal.color0, 1.6));
                        } else {
                            ring(0, 4, Pal.accentAlt);
                        }
                    }
                }

                Canvas {
                    id: drawingCanvas
                    anchors.fill: parent
                    visible: !geom._hideAll

                    property var strokes: []
                    onStrokesChanged: requestPaint()
                    property var redoStack: []
                    property var currentPts: []
                    property bool drawing: false
                    property int selectedIndex: -1
                    // the drawing just made: the size controls change it as you go, until the next one or another tool
                    property int liveIndex: -1
                    // the drawing picked up with the move tool, for the dock's size controls
                    readonly property var picked: dock.activeTool === "move" && selectedIndex >= 0 ? strokes[selectedIndex] || null : null

                    function clear() {
                        strokes = [];
                        redoStack = [];
                        currentPts = [];
                        drawing = false;
                        selectedIndex = -1;
                        liveIndex = -1;
                    }
                    function fontSize(s) {
                        return s.fontSize > 0 ? s.fontSize : s.width * 4 + 8;
                    }
                    function renumberNext() {
                        dock.nextNumber = strokes.reduce((m, st) => st.tool === "number" ? Math.max(m, st.num || 0) : m, 0) + 1;
                    }
                    function add(s) {
                        redoStack = [];
                        strokes = strokes.concat([s]);
                        liveIndex = strokes.length - 1;
                    }
                    function _remove(i) {
                        const copy = strokes.slice(), s = copy.splice(i, 1)[0];
                        strokes = copy;
                        redoStack = redoStack.concat([s]);
                        selectedIndex = -1;
                        liveIndex = -1;
                        if (s.tool === "number")
                            renumberNext();
                    }
                    function _change(i, fn) {
                        if (i < 0 || i >= strokes.length)
                            return;
                        const copy = strokes.slice(), s = Object.assign({}, copy[i]);
                        fn(s);
                        copy[i] = s;
                        strokes = copy;
                    }
                    function moveStroke(i, dx, dy) {
                        _change(i, s => s.pts = s.pts.map(p => ({ x: p.x + dx, y: p.y + dy })));
                    }
                    // a size from the dock: onto the picked-up drawing, or the one just made with the tool in use
                    function applySize(v) {
                        const i = dock.picking ? selectedIndex : liveIndex, s = strokes[i];
                        if (!s || (!dock.picking && s.tool !== dock.activeTool))
                            return;
                        _change(i, st => {
                            if (st.tool === "text")
                                st.fontSize = v;
                            else
                                st.width = v;
                        });
                    }
                    function resizeSelectedText(d) {
                        const s = strokes[selectedIndex];
                        if (s && s.tool === "text")
                            _change(selectedIndex, s => s.fontSize = Math.max(8, Math.min(200, fontSize(s) + d)));
                    }
                    function deleteSelected() {
                        if (selectedIndex < 0 || selectedIndex >= strokes.length)
                            return;
                        _remove(selectedIndex);
                    }
                    function undo() {
                        if (strokes.length)
                            _remove(strokes.length - 1);
                    }
                    function redo() {
                        if (!redoStack.length)
                            return;
                        const r = redoStack.slice(), s = r.pop();
                        redoStack = r;
                        strokes = strokes.concat([s]);
                        if (s.tool === "number")
                            renumberNext();
                    }

                    function beginStroke(x, y) {
                        currentPts = [{ x, y }];
                        drawing = true;
                    }
                    function addPoint(x, y) {
                        if (!drawing)
                            return;
                        currentPts = dock.activeTool === "pen" ? currentPts.concat([{ x, y }]) : [currentPts[0], { x, y }];
                        requestPaint();
                    }
                    function endStroke() {
                        if (!drawing)
                            return;
                        drawing = false;
                        if (currentPts.length > 1)
                            add({ tool: dock.activeTool, color: dock.drawColor.toString(), width: dock.strokeWidth, pts: currentPts, fill: dock.fill && dock.fillable });
                        currentPts = [];
                        requestPaint();
                    }
                    function commitText(x, y, text) {
                        if (text.trim())
                            add({ tool: "text", color: dock.drawColor.toString(), width: dock.strokeWidth, pts: [{ x, y }], text, fontSize: dock.textFontSize });
                    }
                    function placeNumber(x, y) {
                        add({ tool: "number", color: dock.drawColor.toString(), width: dock.strokeWidth, pts: [{ x, y }], num: dock.nextNumber++ });
                    }

                    function _segDist(px, py, a, b) {
                        const dx = b.x - a.x, dy = b.y - a.y, len = dx * dx + dy * dy;
                        const t = len < 1e-6 ? 0 : Math.max(0, Math.min(1, ((px - a.x) * dx + (py - a.y) * dy) / len));
                        return Math.hypot(px - a.x - t * dx, py - a.y - t * dy);
                    }
                    function bbox(s) {
                        const p = s.pts;
                        if (s.tool === "number") {
                            const r = (s.width || 3) * 6 + 14;
                            return { x0: p[0].x - r, y0: p[0].y - r, x1: p[0].x + r, y1: p[0].y + r };
                        }
                        if (s.tool === "text") {
                            const fs = fontSize(s);
                            return { x0: p[0].x, y0: p[0].y - fs, x1: p[0].x + Math.max(20, s.text.length * fs * 0.62), y1: p[0].y + fs * 0.25 };
                        }
                        const xs = p.map(q => q.x), ys = p.map(q => q.y);
                        return { x0: Math.min(...xs), y0: Math.min(...ys), x1: Math.max(...xs), y1: Math.max(...ys) };
                    }
                    function _hit(s, mx, my) {
                        const p = s.pts, tol = Math.max(10, (s.width || 3) + 6);
                        if (s.tool === "number" || s.tool === "text" || s.tool === "rect" || s.tool === "highlighter") {
                            const b = bbox(s), e = s.tool === "number" || s.tool === "text" ? 4 : tol;
                            return mx >= b.x0 - e && mx <= b.x1 + e && my >= b.y0 - e && my <= b.y1 + e;
                        }
                        if (s.tool === "circle") {
                            const nx = (mx - (p[0].x + p[1].x) / 2) / (Math.abs(p[1].x - p[0].x) / 2 + tol);
                            const ny = (my - (p[0].y + p[1].y) / 2) / (Math.abs(p[1].y - p[0].y) / 2 + tol);
                            return nx * nx + ny * ny <= 1;
                        }
                        for (let i = 1; i < p.length; i++)
                            if (_segDist(mx, my, p[i - 1], p[i]) <= tol)
                                return true;
                        return false;
                    }
                    function hitTestStroke(mx, my) {
                        for (let i = strokes.length - 1; i >= 0; i--)
                            if (_hit(strokes[i], mx, my))
                                return i;
                        return -1;
                    }

                    function paintShape(ctx, s) {
                        const p = s.pts, t = s.tool;
                        ctx.strokeStyle = s.color;
                        ctx.fillStyle = s.color;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        ctx.lineWidth = s.width;
                        ctx.globalAlpha = t === "highlighter" ? 0.35 : 1;
                        if (t === "text") {
                            if (s.text) {
                                ctx.font = fontSize(s) + "px monospace";
                                ctx.fillText(s.text, p[0].x, p[0].y);
                            }
                            return;
                        }
                        if (t === "number") {
                            const cx = p[0].x, cy = p[0].y, r = s.width * 6 + 14;
                            ctx.beginPath();
                            ctx.arc(cx, cy, r, 0, 2 * Math.PI, false);
                            ctx.fill();
                            ctx.lineWidth = 2.5;
                            ctx.strokeStyle = "rgba(0,0,0,0.45)";
                            ctx.stroke();
                            const label = String(s.num ?? 1), fs = label.length > 1 ? Math.max(10, r * 1.1) : r * 1.3;
                            ctx.save();
                            ctx.font = `bold ${fs}px monospace`;
                            ctx.fillStyle = "black";
                            ctx.textAlign = "center";
                            ctx.textBaseline = "middle";
                            ctx.fillText(label, cx, cy);
                            ctx.restore();
                            return;
                        }
                        if (p.length < 2)
                            return;
                        const a = p[0], b = p[p.length - 1];
                        const x = Math.min(a.x, b.x), y = Math.min(a.y, b.y), w = Math.abs(b.x - a.x), h = Math.abs(b.y - a.y);
                        ctx.beginPath();
                        if (t === "pen") {
                            ctx.moveTo(a.x, a.y);
                            for (let i = 1; i < p.length; i++)
                                ctx.lineTo(p[i].x, p[i].y);
                            ctx.stroke();
                        } else if (t === "highlighter") {
                            if (w >= 2 && h >= 2)
                                ctx.fillRect(x, y, w, h);
                        } else if (t === "line") {
                            ctx.moveTo(a.x, a.y);
                            ctx.lineTo(b.x, b.y);
                            ctx.stroke();
                        } else if (t === "rect") {
                            if (s.fill)
                                ctx.fillRect(x, y, w, h);
                            else
                                ctx.strokeRect(x, y, w, h);
                        } else if (t === "circle") {
                            if (w < 4 || h < 4)
                                return;
                            ctx.save();
                            ctx.translate(x + w / 2, y + h / 2);
                            ctx.scale(w / 2, h / 2);
                            ctx.arc(0, 0, 1, 0, 2 * Math.PI, false);
                            ctx.restore();
                            if (s.fill)
                                ctx.fill();
                            else
                                ctx.stroke();
                        } else if (t === "arrow") {
                            const dx = b.x - a.x, dy = b.y - a.y, len = Math.hypot(dx, dy);
                            if (len < 8)
                                return;
                            const ux = dx / len, uy = dy / len, hl = Math.min(30, len * 0.4);
                            const bx = b.x - ux * hl, by = b.y - uy * hl, px = -uy * hl * 0.4, py = ux * hl * 0.4;
                            ctx.moveTo(a.x, a.y);
                            ctx.lineTo(bx, by);
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(b.x, b.y);
                            ctx.lineTo(bx + px, by + py);
                            ctx.lineTo(bx - px, by - py);
                            ctx.closePath();
                            ctx.fill();
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        for (const s of strokes)
                            paintShape(ctx, s);
                        if (drawing && currentPts.length)
                            paintShape(ctx, { tool: dock.activeTool, color: dock.drawColor.toString(), width: dock.strokeWidth, pts: currentPts, fill: dock.fill && dock.fillable });
                    }
                }

                Rectangle {
                    readonly property var b: drawingCanvas.selectedIndex >= 0 && drawingCanvas.selectedIndex < drawingCanvas.strokes.length ? drawingCanvas.bbox(drawingCanvas.strokes[drawingCanvas.selectedIndex]) : null
                    visible: b !== null && geom.uiVisible
                    x: b ? b.x0 - 4 : 0
                    y: b ? b.y0 - 4 : 0
                    width: b ? b.x1 - b.x0 + 8 : 0
                    height: b ? b.y1 - b.y0 + 8 : 0
                    color: "transparent"
                    border.width: 1.5
                    border.color: "#00e5ff"
                    opacity: 0.9
                }

                Repeater {
                    model: 4
                    Ropes {
                        required property int index
                        readonly property bool atRight: index % 2 === 1
                        readonly property bool atBottom: index > 1
                        readonly property var idle: geom.edgePoint(geomRect.ballX, geomRect.ballY, startX, startY, root.ballRadius)
                        anchors.fill: parent
                        design: root.ropeDesign
                        visible: geom.uiVisible && root.active && !root.editing
                        startX: atRight ? geomRect.width : 0
                        startY: atBottom ? geomRect.height : 0
                        endX: geomRect.selecting ? (atRight ? geomRect.anchor2X : geomRect.anchor1X) : idle.x
                        endY: geomRect.selecting ? (atBottom ? geomRect.anchor2Y : geomRect.anchor1Y) : idle.y
                    }
                }
            }

            Rectangle {
                visible: root.editing
                readonly property real b: Math.max(geom.width, geom.height)
                x: geom._ex - b
                y: geom._ey - b
                width: geom._ew + 2 * b
                height: geom._eh + 2 * b
                color: "transparent"
                border.width: b
                border.color: Pal.color0
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
                visible: geom.uiVisible && !geomRect.selecting && !root.editing
                cx: geomRect.ballX
                cy: geomRect.ballY
            }

            Dock {
                id: dock
                visible: geom.uiVisible
                captureTools: !root.editing
                watermark: root.hasWatermark
                fullSelected: geom.fullSelected
                delaySeconds: geom.delaySeconds
                onFullRequested: geom.toggleFullSelection()
                onDelayRequested: geom.cycleDelay()
                onWatermarkRequested: geom.removeWatermark()
                onUndoRequested: drawingCanvas.undo()
                onRedoRequested: drawingCanvas.redo()
                pickedTool: drawingCanvas.picked ? drawingCanvas.picked.tool : ""
                pickedSize: !drawingCanvas.picked ? 0 : drawingCanvas.picked.tool === "text" ? drawingCanvas.fontSize(drawingCanvas.picked) : drawingCanvas.picked.width || 3
                pickedColor: drawingCanvas.picked ? drawingCanvas.picked.color : drawColor
                pickedFill: !!(drawingCanvas.picked && drawingCanvas.picked.fill)
                pickedNum: drawingCanvas.picked ? drawingCanvas.picked.num || 1 : 1
                onSizePicked: v => drawingCanvas.applySize(v)
                onActiveToolChanged: {
                    if (activeTool !== "move")
                        drawingCanvas.selectedIndex = -1;
                    if (activeTool !== "text")
                        textCursor.close(true);
                    drawingCanvas.liveIndex = -1;
                }
            }

            TextInput {
                id: textCursor
                visible: false
                color: dock.drawColor
                font.pixelSize: dock.textFontSize
                font.family: "monospace"
                property real px: 0
                property real py: 0
                x: px
                y: py - font.pixelSize

                function open(x, y) {
                    close(true);
                    px = x;
                    py = y;
                    visible = true;
                    focus = true;
                }
                function close(commit) {
                    if (!visible)
                        return;
                    if (commit)
                        drawingCanvas.commitText(px, py, text);
                    text = "";
                    visible = false;
                    focus = false;
                    geom.contentItem.focus = true;
                }

                Rectangle {
                    anchors {
                        fill: parent
                        margins: -4
                    }
                    color: Qt.rgba(0, 0, 0, 0.45)
                    radius: 4
                    z: -1
                }

                Keys.onPressed: event => {
                    if (!(event.modifiers & Qt.ControlModifier))
                        return;
                    if (event.key === Qt.Key_Equal || event.key === Qt.Key_Plus)
                        dock.changeSize(1);
                    else if (event.key === Qt.Key_Minus || event.key === Qt.Key_Underscore)
                        dock.changeSize(-1);
                    else
                        return;
                    event.accepted = true;
                }
                Keys.onReturnPressed: close(true)
                Keys.onEscapePressed: close(false)
            }

            MouseArea {
                anchors.fill: parent
                z: -1
                hoverEnabled: true
                readonly property bool drawTool: ["pen", "highlighter", "circle", "arrow", "rect", "line"].indexOf(dock.activeTool) !== -1
                cursorShape: {
                    if (dock.activeTool === "move")
                        return movingShape || drawingCanvas.hitTestStroke(mouseX, mouseY) !== -1 ? Qt.SizeAllCursor : Qt.ArrowCursor;
                    if (dock.activeTool !== "none")
                        return Qt.CrossCursor;
                    return ({ tl: Qt.SizeFDiagCursor, br: Qt.SizeFDiagCursor, tr: Qt.SizeBDiagCursor, bl: Qt.SizeBDiagCursor, l: Qt.SizeHorCursor, r: Qt.SizeHorCursor, t: Qt.SizeVerCursor, b: Qt.SizeVerCursor, inside: Qt.SizeAllCursor })[_hitTest(mouseX, mouseY)] ?? Qt.CrossCursor;
                }

                property real originX: 0
                property real originY: 0
                property real anchorDx: 0
                property real anchorDy: 0
                property string dragMode: "none"
                property real lastX: 0
                property real lastY: 0
                property bool movingShape: false

                function _hitTest(mx, my) {
                    if (!geomRect.selecting)
                        return "none";
                    const x1 = geomRect.anchor1X, y1 = geomRect.anchor1Y, x2 = geomRect.anchor2X, y2 = geomRect.anchor2Y, e = root.ballRadius;
                    const inX = mx >= x1 - e && mx <= x2 + e, inY = my >= y1 - e && my <= y2 + e;
                    const v = Math.abs(my - y1) <= e && inX ? "t" : Math.abs(my - y2) <= e && inX ? "b" : "";
                    const h = Math.abs(mx - x1) <= e && inY ? "l" : Math.abs(mx - x2) <= e && inY ? "r" : "";
                    if (v || h)
                        return v + h;
                    return mx >= x1 && mx <= x2 && my >= y1 && my <= y2 ? "inside" : "none";
                }

                onPressed: m => {
                    root.giveKeys(geom._screenIdx);
                    const tool = dock.activeTool;
                    if (drawTool) {
                        drawingCanvas.liveIndex = -1;
                        drawingCanvas.beginStroke(m.x, m.y);
                    } else if (tool === "number") {
                        drawingCanvas.placeNumber(m.x, m.y);
                    } else if (tool === "text") {
                        textCursor.open(m.x, m.y);
                        // (after open: it puts down the label being typed, which would become the one just made)
                        drawingCanvas.liveIndex = -1;
                    } else if (tool === "move") {
                        drawingCanvas.selectedIndex = drawingCanvas.hitTestStroke(m.x, m.y);
                        movingShape = drawingCanvas.selectedIndex !== -1;
                        lastX = m.x;
                        lastY = m.y;
                    } else if (!root.editing) {
                        dragMode = _hitTest(m.x, m.y);
                        if (dragMode !== "none") {
                            anchorDx = m.x - geomRect.anchor1X;
                            anchorDy = m.y - geomRect.anchor1Y;
                        } else {
                            dragMode = "new";
                            originX = m.x;
                            originY = m.y;
                            geomRect.selecting = true;
                            geomRect.anchor1X = geomRect.anchor2X = m.x;
                            geomRect.anchor1Y = geomRect.anchor2Y = m.y;
                        }
                    }
                }

                onPositionChanged: m => {
                    const tool = dock.activeTool, g = geomRect, mx = m.x, my = m.y;
                    if (drawTool) {
                        drawingCanvas.addPoint(mx, my);
                    } else if (tool === "move") {
                        if (movingShape) {
                            drawingCanvas.moveStroke(drawingCanvas.selectedIndex, mx - lastX, my - lastY);
                            lastX = mx;
                            lastY = my;
                        }
                    } else if (tool !== "none" || dragMode === "none") {
                        return;
                    } else if (dragMode === "inside") {
                        const bw = g.anchor2X - g.anchor1X, bh = g.anchor2Y - g.anchor1Y;
                        g.anchor1X = geom.clamp(mx - anchorDx, 0, geom.width - bw);
                        g.anchor1Y = geom.clamp(my - anchorDy, 0, geom.height - bh);
                        g.anchor2X = g.anchor1X + bw;
                        g.anchor2Y = g.anchor1Y + bh;
                    } else if (dragMode === "new") {
                        g.anchor1X = Math.min(originX, mx);
                        g.anchor1Y = Math.min(originY, my);
                        g.anchor2X = Math.max(originX, mx);
                        g.anchor2Y = Math.max(originY, my);
                    } else {
                        if (dragMode.includes("l"))
                            g.anchor1X = geom.clamp(mx, 0, g.anchor2X - 1);
                        if (dragMode.includes("r"))
                            g.anchor2X = geom.clamp(mx, g.anchor1X + 1, geom.width);
                        if (dragMode.includes("t"))
                            g.anchor1Y = geom.clamp(my, 0, g.anchor2Y - 1);
                        if (dragMode.includes("b"))
                            g.anchor2Y = geom.clamp(my, g.anchor1Y + 1, geom.height);
                    }
                }

                onReleased: {
                    if (drawTool) {
                        drawingCanvas.endStroke();
                        return;
                    }
                    movingShape = false;
                    if (dragMode === "new" && (geomRect.anchor2X - geomRect.anchor1X < 2 || geomRect.anchor2Y - geomRect.anchor1Y < 2))
                        geomRect.selecting = false;
                    dragMode = "none";
                }

                onWheel: wheel => {
                    wheel.accepted = false;
                    if (!(wheel.modifiers & Qt.ControlModifier))
                        return;
                    const step = wheel.angleDelta.y > 0 ? 2 : -2;
                    if (textCursor.visible)
                        dock.changeSize(step / 2);
                    else if (dock.activeTool === "move" && drawingCanvas.selectedIndex !== -1)
                        drawingCanvas.resizeSelectedText(step);
                    else
                        return;
                    wheel.accepted = true;
                }
            }
        }
    }

    component CornerBall: Item {
        property real cx: 0
        property real cy: 0
        readonly property int r: root.ballRadius
        readonly property bool shadowArms: root.ropeDesign === "b"
        x: cx - r
        y: cy - r
        width: r * 2
        height: r * 2
        Rectangle {
            visible: parent.shadowArms
            anchors.centerIn: parent
            width: parent.width + 16
            height: width
            radius: width / 2
            color: Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.09)
        }
        Rectangle {
            visible: parent.shadowArms
            anchors.centerIn: parent
            width: parent.width + 7
            height: width
            radius: width / 2
            color: Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.22)
        }
        Rectangle {
            anchors.fill: parent
            radius: parent.r
            color: parent.shadowArms ? Qt.darker(Pal.color0, 1.6) : Pal.accentAlt
            border.width: parent.shadowArms ? 1.5 : 0
            border.color: Qt.lighter(Pal.accentAlt, 1.15)
            antialiasing: true
        }
    }
}
