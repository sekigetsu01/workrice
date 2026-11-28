import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../"
import "units.js" as Units

// The calculator, as a panel down one side of the screen (Shift+l / Shift+j moves it right). Super+' or Esc closes it;
// Super+h / Super+l away from it types in the window, towards it types in it again.
PanelWindow {
    id: root

    readonly property bool closing: false
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property real px: 13

    property string calcInput: ""
    property string calcResult: ""
    property string calcError: ""
    property string calcUnit: ""
    property string calcShown: ""
    property string calcFormula: ""
    property var calcHistory: []
    property int calcHistoryPos: -1
    property bool historyNav: false
    property string calcExpr: ""
    property string notice: ""
    property string selSymbol: ""
    property string selExpr: ""
    property var fxRates: null
    property real fxLoadedAt: 0
    property real fxTriedAt: 0
    property bool fxLoading: false
    property bool fxStale: false
    property string fxDate: ""
    property bool calcIsMoney: false
    readonly property bool ratesWanted: calcIsMoney && (fxStale || fxProc.fetch)
    property bool onRight: false
    property bool overFullscreen: false
    function fullscreenFrom(line) {
        try {
            overFullscreen = JSON.parse(line).clients.some(c => c.is_fullscreen && c.is_visible && (!screen || c.monitor === screen.name));
        } catch (e) {}
    }
    Process {
        running: root.visible
        command: ["mmsg", "watch", "all-clients"]
        stdout: SplitParser {
            onRead: line => root.fullscreenFrom(line)
        }
    }

    property bool held: false
    readonly property bool typing: visible && held

    readonly property int panelW: Math.round(Math.min(420, Math.max(340, (screen ? screen.width : 1280) * 0.3)))
    anchors.top: true
    anchors.bottom: true
    anchors.left: !onRight
    anchors.right: onRight
    margins.top: overFullscreen ? 0 : Sys.barH + 2
    margins.bottom: overFullscreen ? 0 : 2
    margins.left: onRight || overFullscreen ? 0 : 1
    margins.right: onRight && !overFullscreen ? 1 : 0
    implicitWidth: panelW
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-calc"
    WlrLayershell.keyboardFocus: !visible ? WlrKeyboardFocus.None : held && !regrabbing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand
    color: "transparent"
    visible: false

    property bool moving: false
    function setSide(right) {
        if (right === onRight)
            return;
        onRight = right;
        if (!visible)
            return;
        moving = true;
        held = true;
        visible = false;
        Qt.callLater(() => {
            visible = true;
            moving = false;
            sideFile();
            focusTimer.restart();
        });
    }

    readonly property string sidePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-calc-side"
    function sideFile() {
        sideProc.command = visible ? ["sh", "-c", 'printf "%s\\n" "$2" > "$1"', "sh", sidePath, onRight ? "right" : "left"]
                                   : ["rm", "-f", sidePath];
        if (sideProc.running)
            sideProc.again = true;
        else
            sideProc.running = true;
    }
    onVisibleChanged: {
        if (!moving)
            sideFile();
        if (visible)
            windowNow.running = true;
    }
    Process {
        id: sideProc
        property bool again: false
        onExited: {
            if (again) {
                again = false;
                running = true;
            }
        }
    }

    function release() {
        if (hasWindow)
            held = false;
    }

    property bool hasWindow: true
    property var windowId: null
    property var heldOn: null
    onHasWindowChanged: if (!hasWindow && visible) held = true
    function windowFrom(line) {
        try {
            const j = JSON.parse(line);
            windowId = j.id === undefined ? null : j.id;
            hasWindow = windowId !== null;
        } catch (e) {}
    }
    Process {
        id: windowNow
        command: ["mmsg", "get", "focusing-client"]
        stdout: SplitParser {
            onRead: line => {
                root.windowFrom(line);
                root.heldOn = root.windowId;
            }
        }
    }
    Process {
        running: root.visible
        command: ["mmsg", "watch", "focusing-client"]
        stdout: SplitParser {
            onRead: line => root.windowFrom(line)
        }
    }


    function refocus() {
        if (!visible)
            return;
        held = true;
        focusTimer.restart();
    }

    function sideKey(key) {
        if (!visible)
            return false;
        const towards = (key === "h") !== onRight;
        if (towards && !typing) {
            refocus();
            return true;
        }
        if (!towards && typing) {
            release();
            return true;
        }
        return false;
    }

    function windowKey(key) {
        if (!visible || !held)
            return false;
        if (key === "shift-h" || key === "shift-l") {
            setSide(key === "shift-l");
            return true;
        }
        if (key === "space") {
            setSide(!onRight);
            return true;
        }
        release();
        return false;
    }

    onHeldChanged: {
        if (held && visible) {
            heldOn = windowId;
            focusTimer.restart();
        }
    }

    Timer {
        id: lostTimer
        interval: 250
        onTriggered: {
            if (!root.visible || !root.held || root.moving || calcField.activeFocus)
                return;
            if (!root.hasWindow)
                root.regrab();
            else if (root.windowId !== root.heldOn)
                root.held = false;
        }
    }
    property bool regrabbing: false
    function regrab() {
        regrabbing = true;
        regrabTimer.restart();
    }
    Timer {
        id: regrabTimer
        interval: 60
        onTriggered: {
            root.regrabbing = false;
            focusTimer.restart();
        }
    }
    property bool escPending: false
    Shortcut {
        sequence: "Escape"
        context: Qt.WindowShortcut
        onActivated: {
            root.escPending = true;
            escTimer.restart();
        }
    }
    Timer {
        id: escTimer
        interval: 800
        onTriggered: root.finishEsc()
    }
    function finishEsc() {
        if (!escPending)
            return;
        escPending = false;
        escTimer.stop();
        hide();
    }
    contentItem {
        Keys.onReleased: ev => {
            if (ev.key === Qt.Key_Escape && root.escPending && !ev.isAutoRepeat) {
                ev.accepted = true;
                root.finishEsc();
            }
        }
    }

    property bool kept: false
    function setAside() {
        kept = true;
        hide();
    }

    function show() {
        escPending = false;
        fxLoadedAt = 0;
        fxTriedAt = 0;
        ensureRates();
        held = true;
        if (kept) {
            kept = false;
            visible = true;
            focusTimer.restart();
            return;
        }
        calcHistoryPos = -1;
        selExpr = "";
        calcField.text = "";
        notice = "";
        visible = true;
        focusTimer.restart();
    }

    function hide() {
        held = false;
        visible = false;
    }

    function toggle() {
        if (visible)
            hide();
        else
            show();
    }

    function open() {
        if (!visible)
            show();
    }

    function ansValue() {
        const h = calcHistory[0];
        if (!h)
            return "";
        if (h.value !== undefined)
            return String(h.value);
        const m = /-?[\d,]*\.?\d+/.exec(String(h.result));
        return m ? m[0].replace(/,/g, "") : "";
    }
    readonly property bool usesAns: /\bans\b/i.test(calcInput)
    function expandAns(t) {
        const v = usesAns ? ansValue() : "";
        return v === "" ? t : t.replace(/\bans\b/gi, v.charAt(0) === "-" ? "(" + v + ")" : v);
    }

    function updateCalc(t) {
        const e = expandAns(t);
        calcExpr = e.replace(/\s+/g, "");
        evalExpr(e);
    }

    readonly property string countLabel: {
        const e = calcExpr.replace(/,/g, "");
        if (!/^\d+(\.\d+)?([x×*]\d+(\.\d+)?)?(\+\d+(\.\d+)?([x×*]\d+(\.\d+)?)?)+$/.test(e))
            return "";
        const terms = e.split("+");
        const k = terms.filter(x => /[x×*]/.test(x)).length;
        return terms.length + " items" + (k > 0 ? ", " + k + " multiplied" : "");
    }

    readonly property string answerText: calcResult === "" ? ""
        : (calcShown !== "" ? calcShown : (calcUnit === "" && selExpr !== "" && calcInput.startsWith(selExpr) ? selSymbol : "") + formatNumber(calcResult)) + (calcUnit !== "" ? " " + calcUnit : "")

    function wordStep(t, pos, dir) {
        const kind = c => /[\d.,£$€¥₹]/.test(c) ? 1 : /\w/.test(c) ? 2 : /\s/.test(c) ? 0 : 3;
        let i = pos;
        if (dir < 0) {
            while (i > 0 && kind(t[i - 1]) === 0)
                i--;
            const k = i > 0 ? kind(t[i - 1]) : 0;
            while (i > 0 && kind(t[i - 1]) === k)
                i--;
        } else {
            while (i < t.length && kind(t[i]) === 0)
                i++;
            const k = i < t.length ? kind(t[i]) : 0;
            while (i < t.length && kind(t[i]) === k)
                i++;
        }
        return i;
    }

    function setField(t) {
        held = true;
        calcField.text = t;
        calcField.cursorPosition = calcField.text.length;
        calcField.forceActiveFocus();
    }

    function acceptCalcResult() {
        if (calcResult === "")
            return;
        keep();
        calcHistoryPos = -1;
        setField(calcResult);
    }

    function keep() {
        if (calcResult !== "")
            addHistory(expandAns(calcInput).trim().replace(/\s+/g, " ").replace(/\d[\d,]*\.?\d*/g, m => formatNumber(m.replace(/,/g, ""))), answerText, calcResult);
    }

    function finish() {
        keep();
        hide();
    }

    function copyAndClose() {
        if (calcResult === "")
            return;
        Quickshell.execDetached(["wl-copy", "--", answerText]);
        Quickshell.execDetached(["notify-send", "--app-name=Calculator", "-t", "2500", "Copied " + answerText]);
        finish();
    }

    function sumSelection() {
        selProc.buf = "";
        selProc.running = true;
    }
    function sumText(text) {
        const terms = [];
        let sym = "";
        const priced = /[£$€¥₹]\s?\d/.test(text);
        for (const raw of text.split("\n")) {
            const line = raw.trim();
            let amt = "";
            const cur = /([£$€¥₹])\s?(\d[\d,]*(?:\.\d+)?)/.exec(line);
            if (cur) {
                amt = cur[2];
                sym = sym === "" || sym === cur[1] ? cur[1] : "?";
            } else if (!priced) {
                const re = /(^|[^\w.])(\d[\d,]*(?:\.\d+)?)(?!\w)/g;
                let m;
                while ((m = re.exec(line)) !== null)
                    amt = m[2];
            }
            if (amt === "")
                continue;
            const q = /(?:^|\s)(?:[x×]\s?(\d{1,3})(?=$|[\s:,;)\-])|(\d{1,3})\s?[x×](?=\s))/.exec(line);
            const n = q ? parseInt(q[1] || q[2]) : 1;
            amt = amt.replace(/,/g, "").replace(/\.$/, "");
            terms.push(n > 1 ? amt + "x" + n : amt);
        }
        if (terms.length === 0) {
            notice = "Nothing to add up in the selection";
            return;
        }
        selSymbol = sym === "?" ? "" : sym;
        selExpr = terms.join("+");
        calcHistoryPos = -1;
        setField(selExpr);
    }

    function addHistory(expr, result, value) {
        if (expr === "" || result === "")
            return;
        const h = calcHistory.filter(x => x.expr !== expr);
        h.unshift({ expr: expr, result: result, value: value });
        calcHistory = h.slice(0, 50);
        histSave(["sh", "-c", 'd="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell"; mkdir -p "$d" && printf "%s" "$1" > "$d/calc-history.json"', "sh", JSON.stringify(calcHistory)]);
    }

    function clearHistory() {
        calcHistory = [];
        calcHistoryPos = -1;
        histSave(["sh", "-c", 'rm -f "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/calc-history.json"']);
    }

    function historyStep(dir) {
        if (calcHistory.length === 0)
            return;
        pickHistory(Math.max(-1, Math.min(calcHistory.length - 1, calcHistoryPos + dir)));
    }

    function pickHistory(p) {
        calcHistoryPos = p;
        historyNav = true;
        setField(p < 0 ? "" : calcHistory[p].expr);
        historyNav = false;
    }

    function ensureRates() {
        if (fxLoading || Date.now() - fxTriedAt < 60000)
            return;
        if (!fxRates || Date.now() - fxLoadedAt > 12 * 3600000) {
            fxTriedAt = Date.now();
            fxLoading = true;
            fxProc.running = true;
        }
    }

    readonly property var fx: ({
            rates: () => root.fxRates,
            loading: () => root.fxLoading,
            stale: () => root.fxStale,
            ensure: () => {
                root.calcIsMoney = true;
                root.ensureRates();
            }
        })

    function evalExpr(t) {
        calcIsMoney = false;
        calcUnit = "";
        calcShown = "";
        calcFormula = "";
        if (t === "") {
            calcResult = "";
            calcError = "";
            return;
        }
        let cv;
        try {
            cv = Units.convert(t, e => root.calcEvaluate(e), fx);
        } catch (e) {
            cv = { ok: false, msg: "Conversion failed: " + e };
        }
        if (cv) {
            if (cv.pending) {
                calcResult = "";
                calcError = "Getting exchange rates…";
            } else if (cv.ok) {
                calcResult = cv.value;
                calcUnit = cv.unit;
                calcShown = cv.shown;
                calcFormula = cv.formula || "";
                calcError = "";
            } else {
                calcResult = "";
                calcError = cv.msg;
            }
            return;
        }
        const syms = t.match(/[£$€¥₹]/g) || [];
        if (syms.some(x => x !== syms[0])) {
            calcResult = "";
            calcError = "Two currencies: add 'to £' (or another) to say which to show it in";
            return;
        }
        const r = calcEvaluate(syms.length ? t.replace(/[£$€¥₹]/g, "") : t);
        if (r.ok) {
            calcResult = r.value;
            calcError = "";
            if (syms.length) {
                const v = parseFloat(r.value);
                calcShown = (v < 0 ? "-" : "") + syms[0] + formatNumber(Number.isInteger(v) ? String(Math.abs(v)) : Math.abs(v).toFixed(2));
            }
        } else {
            let opens = 0;
            for (const ch of t) {
                if (ch === "(")
                    opens++;
                else if (ch === ")")
                    opens--;
            }
            calcResult = "";
            calcError = opens === 0 && /\d$/.test(t) && r.msg !== "Missing )" ? r.msg : "";
        }
    }

    function addThousandsCommas(intPart) {
        const neg = intPart.charAt(0) === "-";
        return (neg ? "-" : "") + (neg ? intPart.substring(1) : intPart).replace(/\B(?=(\d{3})+(?!\d))/g, ",");
    }

    function formatNumber(numStr) {
        if (!numStr)
            return numStr;
        const dot = numStr.indexOf(".");
        return dot === -1 ? addThousandsCommas(numStr) : addThousandsCommas(numStr.substring(0, dot)) + numStr.substring(dot);
    }

    function calcEvaluate(expr) {
        const s = expr.replace(/[xX×]/g, "*").replace(/\s+/g, "").replace(/,/g, "").toLowerCase();
        let pos = 0;
        const peek = () => s[pos];
        const consume = () => s[pos++];
        function parseAddSub() {
            let left = parseMulDiv();
            while (pos < s.length && (peek() === "+" || peek() === "-")) {
                const op = consume();
                const from = pos;
                let right = parseMulDiv();
                // a plain percentage added or taken off is a share of what's before it, as on a phone: 200+10% = 220
                if (/^\d*\.?\d+(e[+-]?\d+)?%$/.test(s.substring(from, pos)))
                    right = left * right;
                left = op === "+" ? left + right : left - right;
            }
            return left;
        }
        function parseMulDiv() {
            let left = parseUnary();
            while (pos < s.length && (peek() === "*" || peek() === "/")) {
                const op = consume();
                const right = parseUnary();
                if (op === "/" && right === 0)
                    throw "Division by zero";
                left = op === "*" ? left * right : left / right;
            }
            return left;
        }
        function parsePower() {
            const base = parsePrimary();
            if (pos < s.length && peek() === "^") {
                consume();
                return Math.pow(base, parseUnary());
            }
            return base;
        }
        function parseUnary() {
            if (peek() === "-") {
                consume();
                return -parseUnary();
            }
            if (peek() === "+") {
                consume();
                return parseUnary();
            }
            return parsePower();
        }
        function parsePrimary() {
            if (s.substr(pos, 5) === "sqrt(") {
                pos += 5;
                const val = parseAddSub();
                if (peek() !== ")")
                    throw "Missing )";
                consume();
                if (val < 0)
                    throw "sqrt of negative";
                return Math.sqrt(val);
            }
            if (peek() === "(") {
                consume();
                const inner = parseAddSub();
                if (peek() !== ")")
                    throw "Missing )";
                consume();
                return inner;
            }
            const start = pos;
            let seenDot = false;
            while (pos < s.length) {
                if (s[pos] === ".") {
                    if (seenDot)
                        break;
                    seenDot = true;
                } else if (!/\d/.test(s[pos])) {
                    break;
                }
                pos++;
            }
            if (pos === start)
                throw "Expected number";
            const ex = /^e[+-]?\d+/.exec(s.substring(pos));
            if (ex)
                pos += ex[0].length;
            let num = parseFloat(s.substring(start, pos));
            if (pos < s.length && s[pos] === "%") {
                pos++;
                num = num / 100;
            }
            return num;
        }
        try {
            const result = parseAddSub();
            if (pos !== s.length)
                throw "Unexpected: " + s[pos];
            if (!isFinite(result))
                return { ok: false, msg: "Math error" };
            return { ok: true, value: parseFloat(result.toPrecision(10)).toString() };
        } catch (err) {
            return { ok: false, msg: err.toString() };
        }
    }

    Timer {
        id: focusTimer
        interval: 30
        onTriggered: calcField.forceActiveFocus()
    }

    Process {
        id: fxProc
        property string buf: ""
        property bool fetch: false
        command: [Quickshell.shellPath("launcher/calc/fx")].concat(fetch ? ["fetch"] : [])
        onRunningChanged: if (running) buf = ""
        stdout: SplitParser {
            onRead: line => fxProc.buf += line
        }
        onExited: code => {
            root.fxLoading = false;
            fetch = false;
            try {
                const j = JSON.parse(buf);
                const r = j.rates || {};
                r.EUR = 1;
                if (!r.BGN)
                    r.BGN = 1.95583;
                root.fxRates = r;
                root.fxDate = j.date || "";
            } catch (e) {}
            root.fxStale = code !== 0;
            root.fxLoadedAt = Date.now();
            root.updateCalc(root.calcInput.trim());
        }
    }
    function fetchRates() {
        fxProc.running = false;
        fxProc.fetch = true;
        fxLoading = true;
        fxTriedAt = Date.now();
        fxProc.running = true;
    }

    Process {
        id: histLoadProc
        running: true
        property string buf: ""
        command: ["sh", "-c", 'cat "${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/calc-history.json" 2>/dev/null']
        stdout: SplitParser {
            onRead: line => histLoadProc.buf += line
        }
        onExited: {
            try {
                const h = JSON.parse(buf);
                if (Array.isArray(h))
                    root.calcHistory = h;
            } catch (e) {}
        }
    }

    // a save while the last one is still writing runs after it (setting running again would do nothing)
    function histSave(cmd) {
        if (histSaveProc.running) {
            histSaveProc.pending = cmd;
        } else {
            histSaveProc.command = cmd;
            histSaveProc.running = true;
        }
    }
    Process {
        id: histSaveProc
        property var pending: null
        onExited: {
            if (pending) {
                command = pending;
                pending = null;
                running = true;
            }
        }
    }

    Process {
        id: selProc
        property string buf: ""
        command: [Quickshell.shellPath("launcher/calc/selection")]
        stdout: SplitParser {
            onRead: line => selProc.buf += line + "\n"
        }
        onExited: root.sumText(selProc.buf)
    }

    function esc(t) {
        return String(t).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    readonly property color hover: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.55)

    PanelWindow {
        id: room
        visible: root.visible && !root.moving
        anchors.top: true
        anchors.bottom: true
        anchors.left: !root.onRight
        anchors.right: root.onRight
        margins.left: root.onRight ? 0 : 1
        margins.right: root.onRight ? 1 : 0
        implicitWidth: 1
        exclusionMode: ExclusionMode.Normal
        exclusiveZone: root.panelW
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.namespace: "quickshell-calc-room"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        mask: Region {}
    }

    PanelWindow {
        id: shade
        visible: root.visible && root.held && !root.moving
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        margins.top: root.overFullscreen ? 0 : Sys.barH
        margins.left: root.onRight ? 0 : root.panelW + (root.overFullscreen ? 0 : 1)
        margins.right: root.onRight ? root.panelW + (root.overFullscreen ? 0 : 1) : 0
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-calc-shade"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        color: "transparent"
        MouseArea {
            anchors.fill: parent
            onPressed: root.release()
        }
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        color: Pal.bg

        Rectangle {
            x: root.onRight ? 0 : parent.width - 1
            width: 1
            height: parent.height
            color: Pal.color8
        }

        MouseArea {
            anchors.fill: parent
            onPressed: root.held = true
            onClicked: calcField.forceActiveFocus()
        }

        Column {
            id: top
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 14

            Rectangle {
                width: parent.width
                height: 40
                radius: 4
                color: "transparent"
                border.color: calcField.activeFocus ? Pal.borderFocus : Pal.color8
                border.width: 1

                Text {
                    id: prompt
                    anchors.verticalCenter: parent.verticalCenter
                    x: 12
                    text: ">"
                    color: Pal.borderFocus
                    font.family: root.font
                    font.pixelSize: root.px
                    font.bold: true
                }

                TextInput {
                    id: calcField
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: prompt.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    color: Pal.fg
                    selectionColor: Pal.color8
                    font.family: root.font
                    font.pixelSize: root.px
                    clip: true
                    selectByMouse: true
                    onTextChanged: {
                        const cur = text, formatted = cur.replace(/,/g, "").replace(/\d+\.\d*|\.\d+|\d+/g, m => root.formatNumber(m));
                        if (formatted !== cur) {
                            let digits = 0;
                            for (let i = 0; i < cursorPosition && i < cur.length; i++)
                                if (cur.charAt(i) !== ",")
                                    digits++;
                            text = formatted;
                            let pos = digits <= 0 ? 0 : formatted.length;
                            for (let j = 0, n = 0; digits > 0 && j < formatted.length; j++) {
                                if (formatted.charAt(j) !== ",")
                                    n++;
                                if (n === digits) {
                                    pos = j + 1;
                                    break;
                                }
                            }
                            cursorPosition = pos;
                        }
                        root.calcInput = text.replace(/,/g, "");
                        root.notice = "";
                        if (!root.historyNav)
                            root.calcHistoryPos = -1;
                        root.updateCalc(root.calcInput.trim());
                    }
                    onActiveFocusChanged: {
                        if (activeFocus)
                            root.held = true;
                        else
                            lostTimer.restart();
                    }
                    Keys.onEscapePressed: ev => {
                        root.hide();
                        ev.accepted = true;
                    }
                    Keys.onReturnPressed: ev => {
                        if (ev.modifiers & Qt.ShiftModifier)
                            root.copyAndClose();
                        else
                            root.acceptCalcResult();
                        ev.accepted = true;
                    }
                    Keys.onEnterPressed: ev => {
                        if (ev.modifiers & Qt.ShiftModifier)
                            root.copyAndClose();
                        else
                            root.acceptCalcResult();
                        ev.accepted = true;
                    }
                    Keys.onTabPressed: ev => {
                        root.acceptCalcResult();
                        ev.accepted = true;
                    }
                    Keys.onUpPressed: ev => {
                        root.historyStep(1);
                        ev.accepted = true;
                    }
                    Keys.onDownPressed: ev => {
                        root.historyStep(-1);
                        ev.accepted = true;
                    }
                    Keys.onPressed: ev => {
                        root.held = true;
                        const ctrl = ev.modifiers & Qt.ControlModifier, shift = ev.modifiers & Qt.ShiftModifier;
                        if ((ev.key === Qt.Key_Left || ev.key === Qt.Key_Right) && ctrl) {
                            const to = root.wordStep(text, cursorPosition, ev.key === Qt.Key_Left ? -1 : 1);
                            if (shift)
                                moveCursorSelection(to);
                            else {
                                deselect();
                                cursorPosition = to;
                            }
                            ev.accepted = true;
                        } else if ((ev.key === Qt.Key_Backspace || ev.key === Qt.Key_Delete) && ctrl) {
                            if (selectedText !== "")
                                remove(selectionStart, selectionEnd);
                            else {
                                const to = root.wordStep(text, cursorPosition, ev.key === Qt.Key_Backspace ? -1 : 1);
                                remove(Math.min(to, cursorPosition), Math.max(to, cursorPosition));
                            }
                            ev.accepted = true;
                        } else if (ev.key === Qt.Key_D && ctrl) {
                            root.clearHistory();
                            ev.accepted = true;
                        } else if (ev.key === Qt.Key_S && ctrl) {
                            root.sumSelection();
                            ev.accepted = true;
                        } else if (ev.key === Qt.Key_U && ctrl) {
                            if (root.ratesWanted && !root.fxLoading)
                                root.fetchRates();
                            ev.accepted = true;
                        } else if ([Qt.Key_H, Qt.Key_L, Qt.Key_F, Qt.Key_J].includes(ev.key) && shift && !ctrl && text === "") {
                            root.setSide(ev.key === Qt.Key_L || ev.key === Qt.Key_J);
                            ev.accepted = true;
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: 4

                readonly property string label: root.calcError !== "" ? root.calcError
                    : root.notice !== "" ? root.notice
                    : root.usesAns && root.ansValue() !== "" ? "ans = " + root.formatNumber(root.ansValue())
                    : root.countLabel

                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    text: root.answerText !== "" ? root.answerText : root.calcInput.trim() === "" ? "" : "…"
                    color: Pal.accentAlt
                    font.family: root.font
                    font.pixelSize: 32
                    font.bold: true
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: 14
                    height: 44
                    verticalAlignment: Text.AlignVCenter
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    visible: text !== ""
                    text: parent.label
                    color: root.calcError !== "" ? Pal.negative : Pal.fgSub
                    wrapMode: Text.WordWrap
                    font.family: root.font
                    font.pixelSize: root.px - 1
                }
                Text {
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    visible: root.calcFormula !== "" && root.calcError === ""
                    text: root.calcFormula
                    color: Pal.fgMuted
                    wrapMode: Text.WordWrap
                    font.family: root.font
                    font.pixelSize: root.px - 1
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Pal.color8
            }

            Text {
                visible: root.calcHistory.length > 0
                text: "Recent"
                color: Pal.fgMuted
                font.family: root.font
                font.pixelSize: root.px - 1
            }
        }

        ListView {
            id: recents
            anchors.top: top.bottom
            anchors.topMargin: 6
            anchors.bottom: ratesButton.visible ? ratesButton.top : parent.bottom
            anchors.bottomMargin: ratesButton.visible ? 8 : 12
            x: 10
            width: parent.width - 20
            clip: true
            spacing: 2
            boundsBehavior: Flickable.StopAtBounds
            model: root.calcHistory
            currentIndex: root.calcHistoryPos
            onCurrentIndexChanged: if (currentIndex >= 0) positionViewAtIndex(currentIndex, ListView.Contain)
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: recents.width
                height: 30
                radius: 4
                color: pick.containsMouse || index === root.calcHistoryPos ? root.hover : "transparent"
                Text {
                    id: expr
                    anchors.verticalCenter: parent.verticalCenter
                    x: 8
                    width: parent.width - res.width - 28
                    elide: Text.ElideRight
                    text: modelData.expr
                    color: pick.containsMouse || index === root.calcHistoryPos ? Pal.fg : Pal.fgSub
                    font.family: root.font
                    font.pixelSize: root.px
                }
                Text {
                    id: res
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    text: root.formatNumber(String(modelData.result))
                    color: Pal.fgMuted
                    font.family: root.font
                    font.pixelSize: root.px
                }
                MouseArea {
                    id: pick
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.pickHistory(index)
                }
            }
        }
        Rectangle {
            id: ratesButton
            visible: root.ratesWanted
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            width: ratesLabel.implicitWidth + 24
            height: 32
            radius: 4
            color: ratesMouse.containsMouse ? root.hover : "transparent"
            border.color: root.fxLoading ? Pal.color8 : Pal.accentAlt
            border.width: 1

            Text {
                id: ratesLabel
                anchors.centerIn: parent
                textFormat: Text.StyledText
                text: root.fxLoading ? "Updating rates…"
                    : "Update rates" + (root.fxDate !== "" ? " · from " + Qt.formatDate(new Date(root.fxDate + "T12:00:00"), "d MMM") : "")
                color: root.fxLoading ? Pal.fgSub : Pal.accentAlt
                font.family: root.font
                font.pixelSize: root.px - 1
            }
            MouseArea {
                id: ratesMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!root.fxLoading)
                        root.fetchRates();
                    calcField.forceActiveFocus();
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            visible: !root.held
            color: Qt.rgba(Pal.bg.r, Pal.bg.g, Pal.bg.b, 0.6)
        }

        Rectangle {
            anchors.fill: parent
            visible: root.held
            color: "transparent"
            border.color: Pal.borderFocus
            border.width: 3
        }
    }
}
