import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

// The wallpaper picker (SUPER+SHIFT+S): the wallpapers folder as pictures; Enter sets one (~/.local/bin/wallpaper),
// / searches, r picks one at random, m switches to the night ones, o opens another folder; Esc closes.
PanelWindow {
    id: root
    property bool escClose: false

    readonly property string home: Quickshell.env("HOME")
    // the folder comes from ~/.local/bin/wallpaper dir (click the path to change it)
    readonly property string wallpaper: home + "/.local/bin/wallpaper"
    readonly property var exts: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]

    property string layoutMode: "center"
    readonly property bool isLeft: layoutMode === "left"
    readonly property bool isBottom: layoutMode === "bottom"

    property string basePath: home + "/wallpapers"
    property string currentPath: home + "/wallpapers"
    property var pathHistory: []
    property string pendingDir: ""
    property int pendingChoice: 0
    property string searchText: ""
    property var searchMatches: []
    property int searchMatchIndex: -1
    property bool gPending: false
    property int deleting: -1
    property bool nightMode: false
    readonly property bool folderMissing: folderModel.status === FolderListModel.Null
    readonly property bool folderEmpty: folderModel.status === FolderListModel.Ready && folderModel.count === 0
    readonly property bool inNight: nightMode && currentPath !== basePath && currentPath.endsWith("/night")
    onFolderMissingChanged: Qt.callLater(dayIfNoNight)
    onFolderEmptyChanged: Qt.callLater(dayIfNoNight)

    visible: false
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    anchors.top: isLeft
    anchors.bottom: isLeft || isBottom
    anchors.left: isLeft
    margins.top: isLeft ? Sys.barH : 0
    implicitWidth: isLeft ? 380 : isBottom ? Math.round(screen.width * 0.60) : 800
    implicitHeight: isLeft ? screen.height - Sys.barH : isBottom ? Math.round(screen.height * 0.62) : 600

    FileView {
        id: timesFile
        path: root.home + "/.config/times.conf"
        blockAllReads: true
        watchChanges: true
        onFileChanged: reload()
    }

    function isNightTime() {
        Date.timeZoneUpdated()
        const t = {}
        for (const l of timesFile.text().split("\n")) {
            const m = /^\s*(night_start|night_end)\s+(\d{1,2}):(\d{2})\s*$/.exec(l)
            if (m) t[m[1]] = m[2] * 60 + +m[3]
        }
        const s = t.night_start ?? 1260, e = t.night_end ?? 300
        const d = new Date(), n = d.getHours() * 60 + d.getMinutes()
        return s > e ? (n >= s || n < e) : (n >= s && n < e)
    }

    onVisibleChanged: {
        if (!visible) return
        Quickshell.execDetached([wallpaper, "warm"])
        nightMode = isNightTime()
        focusRetryTimer.restart()
        if (pendingDir === "") dirProc.running = true
        if (folderMissing) rebindFolder()
    }

    onNightModeChanged: {
        if (currentPath === basePath) return
        if (nightMode && !currentPath.endsWith("/night")) currentPath += "/night"
        else if (!nightMode && currentPath.endsWith("/night")) currentPath = currentPath.slice(0, -6)
        pathHistory = []
    }

    onCurrentPathChanged: {
        search.text = ""
        deleting = -1
        grid.currentIndex = 0
    }

    function useBase(dir) {
        basePath = dir
        currentPath = dir
        pathHistory = []
    }

    function pickDir() {
        hideAndReset()
        pickProc.running = true
    }

    function choose(mode) {
        setProc.dir = pendingDir
        setProc.command = [wallpaper, "dir", "set", pendingDir, mode]
        setProc.running = true
        pendingDir = ""
    }

    function goBack() {
        if (pathHistory.length > 0) {
            const h = pathHistory.slice()
            currentPath = h.pop()
            pathHistory = h
        } else if (currentPath !== basePath) {
            currentPath = basePath
        } else {
            return false
        }
        return true
    }

    function hideAndReset() {
        search.text = ""
        currentPath = basePath
        pathHistory = []
        pendingDir = ""
        grid.currentIndex = 0
        visible = false
    }

    function toggle() {
        if (visible) hideAndReset()
        else visible = true
    }

    function setWallpaper(path) {
        Quickshell.execDetached([wallpaper, path])
        hideAndReset()
    }

    function tilde(path) {
        return path.replace(home, "~").replace(/\/+$/, "")
    }

    function rebindFolder() {
        folderModel.folder = ""
        folderModel.folder = Qt.binding(() => fileUrl(currentPath))
    }

    function dayIfNoNight() {
        if (inNight && (folderMissing || folderEmpty)) currentPath = currentPath.slice(0, -6)
    }

    function fileUrl(path) {
        return "file://" + path.split("/").map(encodeURIComponent).join("/")
    }

    function randomFrom(dir, top) {
        const names = exts.map(e => "-iname '" + e + "'").join(" -o ")
        const find = where => "find " + where + " -type f \\( " + names + " \\) 2>/dev/null"
        const script = top ? (nightMode ? find('"$1"/*/night -maxdepth 1') : find('"$1" -maxdepth 3') + " | grep -v /night/")
                     : nightMode && !dir.endsWith("/night") ? 'p=$(' + find('"$1"/night -maxdepth 1') + '); [ -n "$p" ] && printf "%s\\n" "$p" || ' + find('"$1" -maxdepth 1')
                     : find('"$1" -maxdepth 1')
        findProc.command = ["sh", "-c", script, "sh", dir]
        findProc.running = true
    }

    function rebuildMatches() {
        const needle = searchText.toLowerCase()
        const matches = []
        if (needle)
            for (let i = 0; i < folderModel.count; i++)
                if (folderModel.get(i, "fileName").toLowerCase().includes(needle)) matches.push(i)
        searchMatches = matches
        searchMatchIndex = matches.length ? 0 : -1
        if (matches.length) {
            grid.currentIndex = matches[0]
            grid.positionViewAtIndex(matches[0], GridView.Contain)
        }
    }

    function stepMatch(d) {
        const n = searchMatches.length
        if (!n) return
        searchMatchIndex = (searchMatchIndex + d + n) % n
        grid.currentIndex = searchMatches[searchMatchIndex]
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
    }

    Rectangle {
        id: keyRect
        anchors.fill: parent
        color: Pal.bgPanel
        radius: 4
        focus: true

        Keys.onReleased: event => {
            if (event.key === Qt.Key_Escape && root.escClose && !event.isAutoRepeat) {
                root.escClose = false
                root.hideAndReset()
                event.accepted = true
            }
        }
        Keys.onPressed: event => {
            const k = event.key, shift = event.modifiers & Qt.ShiftModifier
            event.accepted = true

            if (root.pendingDir !== "") {
                if (k === Qt.Key_Escape) root.pendingDir = ""
                else if (k === Qt.Key_F) root.choose("session")
                else if (k === Qt.Key_J) root.choose("always")
                else if ([Qt.Key_H, Qt.Key_Left, Qt.Key_K, Qt.Key_Up].includes(k)) root.pendingChoice = 0
                else if ([Qt.Key_L, Qt.Key_Right, Qt.Key_Down].includes(k)) root.pendingChoice = 1
                else if (k === Qt.Key_1) root.choose("session")
                else if (k === Qt.Key_2) root.choose("always")
                else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(k)) root.choose(root.pendingChoice === 0 ? "session" : "always")
                return
            }
            if (k === Qt.Key_Escape) {
                if (!root.goBack()) root.escClose = true
                return
            }
            if (search.activeFocus) {
                event.accepted = false
                return
            }

            const cols = Math.max(1, Math.floor(grid.width / grid.cellWidth))
            const i = grid.currentIndex, n = grid.count
            const g = root.gPending
            root.gPending = false

            if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(k)) {
                if (root.folderMissing || root.folderEmpty) root.pickDir()
                else grid.activateCurrent()
            }
            else if ([Qt.Key_F, Qt.Key_Slash, Qt.Key_I, Qt.Key_A].includes(k)) search.forceActiveFocus()
            else if (k === Qt.Key_M || k === Qt.Key_S) root.nightMode = !root.nightMode
            else if (k === Qt.Key_O && !shift) root.pickDir()
            else if (shift && k === Qt.Key_C) root.layoutMode = "center"
            else if (shift && k === Qt.Key_B) root.layoutMode = "bottom"
            else if (shift && k === Qt.Key_L) root.layoutMode = "left"
            else if (k === Qt.Key_B) {
                if (i >= 0 && i < folderModel.count && folderModel.get(i, "fileIsDir"))
                    root.randomFrom(folderModel.get(i, "filePath"), false)
            } else if (k === Qt.Key_R) root.randomFrom(root.currentPath, root.currentPath === root.basePath)
            else if (k === Qt.Key_C) {
                if (i >= 0 && i < folderModel.count) {
                    root.visible = false
                    Quickshell.execDetached([Sys.terminal, "-e", "sh", "-c",
                        "id=$$; (sleep 0.4; ya emit-to \"$id\" rename --cursor=before_ext) >/dev/null 2>&1 & exec yazi --client-id \"$id\" \"$1\"",
                        "sh", folderModel.get(i, "filePath")])
                }
            } else if (k === Qt.Key_T && !shift) {
                if (i >= 0 && i < folderModel.count && !folderModel.get(i, "fileIsDir")) {
                    const dir = root.currentPath.replace(/\/+$/, "")
                    root.deleting = i
                    deleteProc.command = ["sh", "-c", [
                        'f=${XDG_STATE_HOME:-$HOME/.local/state}/setwp/last_wallpaper',
                        'was=$(readlink -f -- "$1")',
                        'mkdir -p -- "$2" && mv -f -- "$1" "$2/" || exit 1',
                        '[ "$(cat -- "$f" 2>/dev/null)" = "$was" ] && readlink -f -- "$2/${1##*/}" > "$f"',
                        'exit 0'].join("\n"),
                        "sh", folderModel.get(i, "filePath"), dir.endsWith("/night") ? dir.slice(0, -6) : dir + "/night"]
                    deleteProc.running = true
                }
            } else if (k === Qt.Key_N) root.stepMatch(shift ? -1 : 1)
            else if (shift && k === Qt.Key_G) {
                grid.currentIndex = n - 1
                grid.positionViewAtEnd()
            } else if (shift && k === Qt.Key_D) {
                if (i >= 0 && i < folderModel.count && !folderModel.get(i, "fileIsDir")) {
                    root.deleting = i
                    deleteProc.command = ["rm", "-f", "--", folderModel.get(i, "filePath")]
                    deleteProc.running = true
                }
            } else if (k === Qt.Key_G) {
                if (g) {
                    grid.currentIndex = 0
                    grid.positionViewAtBeginning()
                } else {
                    root.gPending = true
                    gPendingTimer.restart()
                }
            } else if (k === Qt.Key_H || k === Qt.Key_Left) { if (i % cols !== 0) grid.currentIndex-- }
            else if (k === Qt.Key_L || k === Qt.Key_Right) { if ((i + 1) % cols !== 0 && i < n - 1) grid.currentIndex++ }
            else if (k === Qt.Key_K || k === Qt.Key_Up) { if (i - cols >= 0) grid.currentIndex -= cols }
            else if (k === Qt.Key_J || k === Qt.Key_Down) { if (i + cols < n) grid.currentIndex += cols }
            else if (k === Qt.Key_Backspace) root.goBack()
            else event.accepted = false
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.isLeft ? 8 : root.isBottom ? 10 : 16
            spacing: root.layoutMode === "center" ? 10 : 6

            Item {
                Layout.fillWidth: true
                implicitHeight: root.isLeft ? 28 : 36
                readonly property int fs: root.isLeft ? 13 : 15

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: ""; font.pixelSize: parent.parent.fs; color: Pal.color7 }
                    Text { text: "Wallpapers"; font.pixelSize: parent.parent.fs; font.weight: Font.Medium; color: Pal.color7 }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Repeater {
                        model: root.isBottom ? ["shuffle", "night"] : ["night"]
                        Rectangle {
                            required property string modelData
                            readonly property bool night: modelData === "night"
                            readonly property bool on: night && root.nightMode
                            width: root.isLeft ? 26 : 32
                            height: width
                            radius: width / 2
                            color: btn.containsMouse ? (on ? Pal.borderSurface : Pal.bgInput) : (on ? Pal.bgInput : "transparent")
                            border.color: on ? Pal.accent : Pal.borderSurface
                            border.width: 1
                            Text {
                                anchors.centerIn: parent
                                text: !parent.night ? "⇄" : root.nightMode ? "" : ""
                                font.pixelSize: root.isLeft ? 13 : 15
                                color: !parent.night ? Pal.fgSub : root.nightMode ? Pal.accent : Pal.accentWarm
                            }
                            MouseArea {
                                id: btn
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    if (parent.night) root.nightMode = !root.nightMode
                                    else root.randomFrom(root.currentPath, root.currentPath === root.basePath)
                                    keyRect.forceActiveFocus()
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: root.isLeft ? 28 : root.isBottom ? 26 : 36
                color: Pal.bgInput
                radius: 6
                border.color: search.activeFocus ? Pal.accent : Pal.borderSurface
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6
                    Text { text: "⌕"; color: Pal.accent; font.pixelSize: root.isLeft ? 12 : 14 }
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 22
                        Text {
                            anchors.fill: parent
                            text: "Search wallpapers..."
                            color: Pal.fgFaint
                            font.pixelSize: search.font.pixelSize
                            verticalAlignment: Text.AlignVCenter
                            visible: search.text.length === 0 && !search.activeFocus
                        }
                        TextInput {
                            id: search
                            anchors.fill: parent
                            color: Pal.fgPrimary
                            font.pixelSize: root.isLeft ? 11 : 12
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: {
                                root.searchText = text
                                root.rebuildMatches()
                            }
                            Keys.onReturnPressed: e => {
                                keyRect.forceActiveFocus()
                                grid.activateCurrent()
                            }
                            Keys.onEscapePressed: e => {
                                text = ""
                                keyRect.forceActiveFocus()
                            }
                            Keys.onTabPressed: root.stepMatch(1)
                            Keys.onBacktabPressed: root.stepMatch(-1)
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_N && (e.modifiers & Qt.ControlModifier)) {
                                    root.stepMatch(e.modifiers & Qt.ShiftModifier ? -1 : 1)
                                    e.accepted = true
                                }
                            }
                        }
                    }
                    Text {
                        visible: root.searchText.length > 0
                        text: root.searchMatches.length > 0 ? (root.searchMatchIndex + 1) + "/" + root.searchMatches.length : "0"
                        color: root.searchMatches.length > 0 ? Pal.matchFound : Pal.matchNone
                        font.pixelSize: 10
                    }
                    Text {
                        visible: search.text.length > 0
                        text: "✕"
                        color: Pal.fgMuted
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                search.text = ""
                                keyRect.forceActiveFocus()
                            }
                        }
                    }
                }
            }

            FolderListModel {
                id: folderModel
                folder: root.fileUrl(root.currentPath)
                nameFilters: root.exts
                caseSensitive: false
                showDirsFirst: true
                showDotAndDotDot: false
                property bool settled: false
                onStatusChanged: {
                    if (settled || status !== FolderListModel.Ready) return
                    settled = true
                    if (count > 0 && !get(0, "filePath").startsWith(root.currentPath.replace(/\/+$/, "") + "/"))
                        Qt.callLater(root.rebindFolder)
                }
                onCountChanged: {
                    if (root.deleting < 0) return
                    grid.currentIndex = Math.max(0, Math.min(root.deleting, count - 1))
                    grid.positionViewAtIndex(grid.currentIndex, GridView.Contain)
                    root.deleting = -1
                    if (root.searchText) root.rebuildMatches()
                }
            }

            GridView {
                id: grid
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                cellWidth: root.isLeft ? Math.floor(width / 3) : root.isBottom ? Math.floor(width / 4) : Math.floor(width / Math.max(1, Math.floor(width / 160)))
                cellHeight: root.isLeft ? 110 : root.isBottom ? Math.floor(width / 4 / 1.15) : 175
                cacheBuffer: 600
                model: folderModel
                highlight: Item {}
                highlightMoveDuration: 80

                ScrollBar.vertical: ScrollBar {
                    id: gridScrollBar
                    width: 6
                    contentItem: Rectangle {
                        implicitWidth: 6
                        implicitHeight: 100
                        radius: 3
                        color: gridScrollBar.pressed ? Pal.accent : Pal.borderSurface
                        opacity: gridScrollBar.active ? 1.0 : 0.4
                    }
                    background: Item {}
                }

                Column {
                    visible: root.folderMissing || root.folderEmpty
                    x: Math.max(0, (grid.width - width) / 2)
                    y: Math.max(0, (grid.height - height) / 2)
                    width: Math.min(grid.width - 24, Math.max(emptyMsg.implicitWidth, emptyBtn.width))
                    spacing: 14
                    Text {
                        id: emptyMsg
                        width: parent.width
                        text: root.folderMissing ? "No wallpapers folder at " + root.tilde(root.currentPath)
                            : "No wallpapers in " + root.tilde(root.currentPath)
                        color: Pal.color7
                        font.pixelSize: root.isLeft ? 11 : 13
                        wrapMode: Text.Wrap
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Rectangle {
                        id: emptyBtn
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: 150
                        height: 34
                        radius: 6
                        color: emptyBtnMa.containsMouse ? Pal.bgInput : "transparent"
                        border.color: Pal.accent
                        border.width: 2
                        Text {
                            anchors.centerIn: parent
                            text: "Choose folder"
                            color: Pal.fgPrimary
                            font.pixelSize: 12
                        }
                        MouseArea {
                            id: emptyBtnMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.pickDir(); keyRect.forceActiveFocus() }
                        }
                    }
                }

                function activateCurrent() {
                    if (currentIndex < 0 || currentIndex >= folderModel.count) return
                    const fp = folderModel.get(currentIndex, "filePath")
                    if (!folderModel.get(currentIndex, "fileIsDir")) {
                        root.setWallpaper(fp)
                        return
                    }
                    const h = root.pathHistory.slice()
                    h.push(root.currentPath)
                    root.pathHistory = h
                    root.currentPath = root.nightMode && !root.currentPath.endsWith("/night") ? fp + "/night" : fp
                }

                delegate: Item {
                    id: cell
                    required property int index
                    required property string fileName
                    required property string filePath
                    required property bool fileIsDir
                    readonly property bool isCur: GridView.isCurrentItem
                    readonly property bool isSearchMatch: root.searchText.length > 0 && root.searchMatches.includes(index)
                    width: grid.cellWidth
                    height: grid.cellHeight

                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: root.layoutMode === "center" ? 6 : 3
                        color: ma.containsMouse ? Pal.borderSurface : Pal.bgInput
                        radius: 6
                        border.color: cell.isCur ? Pal.accent : cell.isSearchMatch ? Pal.warning : "transparent"
                        border.width: cell.isCur ? 3 : cell.isSearchMatch ? 1 : 0

                        Rectangle {
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: root.layoutMode === "center" ? 8 : 4
                            height: parent.height - label.height - (root.isLeft ? 6 : 12)
                            radius: 6
                            color: Pal.bgSubtle
                            clip: true

                            Text {
                                anchors.centerIn: parent
                                text: cell.fileIsDir ? "📁" : thumb.status === Image.Error ? "?" : thumb.status === Image.Ready ? "" : "…"
                                color: thumb.status === Image.Error ? Pal.matchNone : Pal.fgFaint
                                font.pixelSize: cell.fileIsDir ? (root.isLeft ? 28 : 42) : 18
                            }
                            Image {
                                id: thumb
                                anchors.fill: parent
                                source: cell.fileIsDir ? "" : root.fileUrl(cell.filePath)
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                sourceSize.width: 320
                                sourceSize.height: 320
                            }
                        }

                        Text {
                            id: label
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 4
                            anchors.bottomMargin: root.isLeft ? 3 : 6
                            height: root.isLeft ? 20 : 28
                            text: cell.fileName
                            color: Pal.fgPrimary
                            font.pixelSize: root.isLeft ? 9 : 11
                            elide: Text.ElideMiddle
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                grid.currentIndex = cell.index
                                keyRect.forceActiveFocus()
                                grid.activateCurrent()
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { visible: !root.isLeft; text: folderModel.count + " items  ·"; color: Pal.color7; font.pixelSize: 11 }
                Item {
                    Layout.fillWidth: true
                    implicitHeight: root.isLeft ? 14 : 16
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(implicitWidth, parent.width)
                        text: root.currentPath.replace(root.home, "~").replace(/\/+$/, "")
                        color: pathMa.containsMouse ? Pal.accent : Pal.color7
                        font.pixelSize: root.isLeft ? 9 : 11
                        font.underline: pathMa.containsMouse
                        elide: Text.ElideLeft
                        MouseArea { id: pathMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.pickDir() }
                    }
                }
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            color: Qt.rgba(0, 0, 0, 0.55)
            visible: root.pendingDir !== ""
            MouseArea { anchors.fill: parent; onClicked: { root.pendingDir = ""; keyRect.forceActiveFocus() } }

            Rectangle {
                anchors.centerIn: parent
                width: Math.min(parent.width - 32, Math.max(300, choiceCol.implicitWidth + 40))
                height: choiceCol.implicitHeight + 36
                radius: 8
                color: Pal.bgPanel
                border.color: Pal.borderSurface
                border.width: 1
                MouseArea { anchors.fill: parent }

                Column {
                    id: choiceCol
                    anchors.centerIn: parent
                    spacing: 14
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: Math.min(implicitWidth, 520)
                        text: root.pendingDir.replace(root.home, "~")
                        color: Pal.fgPrimary
                        font.pixelSize: 13
                        font.weight: Font.Medium
                        elide: Text.ElideLeft
                    }
                    Row {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 10
                        Repeater {
                            model: [{ label: "Until restart", mode: "session" }, { label: "Always", mode: "always" }]
                            Rectangle {
                                required property var modelData
                                required property int index
                                readonly property bool cur: root.pendingChoice === index
                                width: 130
                                height: 34
                                radius: 6
                                color: choiceMa.containsMouse || cur ? Pal.bgInput : "transparent"
                                border.color: cur ? Pal.accent : Pal.borderSurface
                                border.width: cur ? 2 : 1
                                Text { anchors.centerIn: parent; text: modelData.label; color: parent.cur ? Pal.fgPrimary : Pal.color7; font.pixelSize: 12 }
                                MouseArea {
                                    id: choiceMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: root.pendingChoice = index
                                    onClicked: { root.choose(modelData.mode); keyRect.forceActiveFocus() }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Process {
        id: dirProc
        command: [root.wallpaper, "dir"]
        stdout: StdioCollector { id: dirOut }
        onExited: code => {
            const d = dirOut.text.trim()
            if (code !== 0 || d === "" || d === root.basePath) return
            if (root.currentPath === root.basePath) root.useBase(d)
            else root.basePath = d
        }
    }

    Process {
        id: pickProc
        command: [root.wallpaper, "dir", "pick"]
        stdout: StdioCollector { id: pickOut }
        onExited: code => {
            const d = pickOut.text.trim()
            if (code === 0 && d !== "") {
                root.pendingChoice = 0
                root.pendingDir = d
            }
            root.visible = true
        }
    }

    Process {
        id: setProc
        property string dir: ""
        onExited: code => { if (code === 0) root.useBase(dir) }
    }

    Process {
        id: deleteProc
        onExited: code => { if (code !== 0) root.deleting = -1 }
    }

    Process {
        id: findProc
        stdout: StdioCollector { id: findOut }
        onExited: {
            const lines = findOut.text.split("\n").filter(l => l.length > 0)
            if (lines.length > 0) root.setWallpaper(lines[Math.floor(Math.random() * lines.length)])
        }
    }

    Timer { id: gPendingTimer; interval: 500; onTriggered: root.gPending = false }
    Timer { id: focusRetryTimer; interval: 50; onTriggered: keyRect.forceActiveFocus() }
}
