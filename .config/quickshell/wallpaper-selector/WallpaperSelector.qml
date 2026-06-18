import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
    id: root

    exclusionMode: ExclusionMode.Ignore

    visible: false

    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    onVisibleChanged: {
        if (visible)
            focusRetryTimer.restart();
    }

    property string layoutMode: "center"

    anchors.top: layoutMode === "left" ? true : false
    anchors.bottom: layoutMode === "left" ? true : layoutMode === "bottom" ? true : false
    anchors.left: layoutMode === "left" ? true : false
    anchors.right: false

    implicitWidth: layoutMode === "left" ? 580 : layoutMode === "bottom" ? Math.round(screen.width * 0.60) : 800
    implicitHeight: layoutMode === "left" ? screen.height - 22 : layoutMode === "bottom" ? Math.round(screen.height * 0.62) : 600

    margins.top: layoutMode === "center" ? (screen.height - implicitHeight) / 2 : layoutMode === "left" ? 22 : 0
    margins.left: layoutMode === "center" ? (screen.width - implicitWidth) / 2 : layoutMode === "bottom" ? (screen.width - implicitWidth) / 2 : 0
    margins.bottom: 0

    property string currentPath: Quickshell.env("HOME") + "/wallpapers"
    property string basePath: Quickshell.env("HOME") + "/wallpapers"
    property var pathHistory: []

    property string searchText: ""
    property int searchMatchIndex: -1
    property var searchMatches: []

    property bool gPending: false

    property bool nightMode: false

    onNightModeChanged: {
        var atRoot = (currentPath === basePath);
        if (atRoot)
            return;
        if (nightMode) {
            if (!currentPath.endsWith("/night"))
                currentPath = currentPath + "/night";
        } else {
            if (currentPath.endsWith("/night"))
                currentPath = currentPath.slice(0, -6);
        }
                    }

    property string filenameDisplay: "full"

    function hideAndReset() {
        searchInput.text = "";
        searchInputBottom.text = "";
        root.searchText = "";
        root.searchMatches = [];
        root.searchMatchIndex = -1;
        root.currentPath = root.basePath;
        root.pathHistory = [];
        grid.currentIndex = 0;
        root.visible = false;
    }

    function setWallpaper(path) {
        setwpProc.command = [Quickshell.env("HOME") + "/.local/bin/setwp", path];
        setwpProc.running = true;
        root.hideAndReset();
    }

    function randomFromDir(dirPath) {
        var m = Qt.createQmlObject('import Qt.labs.folderlistmodel; FolderListModel { ' + 'showDirs: false; showFiles: true; ' + 'nameFilters: ["*.jpg","*.jpeg","*.png","*.webp","*.gif"]; ' + 'folder: "file://' + dirPath + '" }', root, "tmpModel");

        pickTimer.targetModel = m;
        pickTimer.retryCount = 0;
        pickTimer.restart();
    }

    function randomFromBase() {
        var atRoot = (root.currentPath === root.basePath);

        var cmd;
        if (root.nightMode && atRoot) {
            cmd = "find " + root.basePath + "/*/night -maxdepth 1 -type f " + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " + "-o -iname '*.webp' -o -iname '*.gif' \\)";
        } else if (!root.nightMode && atRoot) {
            cmd = "find " + root.basePath + " -maxdepth 3 -type f " + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " + "-o -iname '*.webp' -o -iname '*.gif' \\) " + "| grep -v '/night/'";
        } else if (root.nightMode && !atRoot && !root.currentPath.endsWith("/night")) {
            cmd = "find " + root.currentPath + "/night -maxdepth 1 -type f " + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " + "-o -iname '*.webp' -o -iname '*.gif' \\)";
        } else {
            cmd = "find " + root.currentPath + " -maxdepth 1 -type f " + "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " + "-o -iname '*.webp' -o -iname '*.gif' \\)";
        }

        findProc.command = ["bash", "-c", cmd];
        findProc.running = true;
    }

    function rebuildMatches() {
        if (searchText.length === 0) {
            searchMatches = [];
            searchMatchIndex = -1;
            return;
        }
        var needle = searchText.toLowerCase();
        var matches = [];
        for (var i = 0; i < folderModel.count; i++) {
            if (folderModel.get(i, "fileName").toLowerCase().indexOf(needle) !== -1)
                matches.push(i);
        }
        searchMatches = matches;
        searchMatchIndex = matches.length > 0 ? 0 : -1;
        if (matches.length > 0) {
            grid.currentIndex = matches[0];
            grid.positionViewAtIndex(matches[0], GridView.Contain);
        }
    }

    function nextMatch() {
        if (searchMatches.length === 0)
            return;
        searchMatchIndex = (searchMatchIndex + 1) % searchMatches.length;
        grid.currentIndex = searchMatches[searchMatchIndex];
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }

    function prevMatch() {
        if (searchMatches.length === 0)
            return;
        searchMatchIndex = (searchMatchIndex - 1 + searchMatches.length) % searchMatches.length;
        grid.currentIndex = searchMatches[searchMatchIndex];
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
    }

    color: "transparent"

    Rectangle {
        id: keyRect
        anchors.fill: parent
        color: Pal.bgPanel
        radius: layoutMode === "left" ? 4 : 12
        focus: true
        activeFocusOnTab: false

        Keys.onPressed: function (event) {
            var inSearch = searchInput.activeFocus || searchInputBottom.activeFocus;

            if (event.key === Qt.Key_Escape) {
                if (root.pathHistory.length > 0) {
                    var h = root.pathHistory.slice();
                    root.currentPath = h.pop();
                    root.pathHistory = h;
                    grid.currentIndex = 0;
                } else if (root.currentPath !== root.basePath) {
                    root.currentPath = root.basePath;
                    grid.currentIndex = 0;
                } else {
                    searchInput.text = "";
                    searchInputBottom.text = "";
                    root.searchText = "";
                    root.searchMatches = [];
                    root.searchMatchIndex = -1;
                    root.currentPath = root.basePath;
                    grid.currentIndex = 0;
                    root.visible = false;
                }
                event.accepted = true;
                return;
            }

            if (inSearch)
                return;
            var cols = Math.max(1, Math.floor(grid.width / grid.cellWidth));

            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
                grid.activateCurrent();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_F || event.key === Qt.Key_Slash || event.key === Qt.Key_I || event.key === Qt.Key_A) {
                if (layoutMode === "bottom")
                    searchInputBottom.forceActiveFocus();
                else
                    searchInput.forceActiveFocus();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_M || event.key === Qt.Key_S) {
                root.nightMode = !root.nightMode;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_C && (event.modifiers & Qt.ShiftModifier)) {
                root.layoutMode = "center";
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_B && (event.modifiers & Qt.ShiftModifier)) {
                root.layoutMode = "bottom";
                event.accepted = true;
                return;
            }
            if (event.key === Qt.Key_L && (event.modifiers & Qt.ShiftModifier)) {
                root.layoutMode = "left";
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_B && !(event.modifiers & Qt.ShiftModifier)) {
                if (grid.currentIndex >= 0) {
                    var isDir2 = folderModel.get(grid.currentIndex, "fileIsDir");
                    var dp = folderModel.get(grid.currentIndex, "filePath");
                    if (isDir2) {
                        if (root.nightMode && !dp.endsWith("/night"))
                            root.randomFromDir(dp + "/night");
                        else if (!root.nightMode && !dp.endsWith("/night"))
                            root.randomFromDir(dp);
                    }
                }
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_R) {
                root.randomFromBase();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_N) {
                if (event.modifiers & Qt.ShiftModifier)
                    root.prevMatch();
                else
                    root.nextMatch();
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_G && (event.modifiers & Qt.ShiftModifier)) {
                grid.currentIndex = grid.count - 1;
                grid.positionViewAtEnd();
                root.gPending = false;
                event.accepted = true;
                return;
            }

            if (event.key === Qt.Key_G) {
                if (root.gPending) {
                    grid.currentIndex = 0;
                    grid.positionViewAtBeginning();
                    root.gPending = false;
                } else {
                    root.gPending = true;
                    gPendingTimer.restart();
                }
                event.accepted = true;
                return;
            }

            if (!(event.modifiers & Qt.ControlModifier)) {
                if (event.key === Qt.Key_H) {
                    if (grid.currentIndex % cols !== 0)
                        grid.currentIndex -= 1;
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_L) {
                    if ((grid.currentIndex + 1) % cols !== 0 && grid.currentIndex < grid.count - 1)
                        grid.currentIndex += 1;
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_K) {
                    if (grid.currentIndex - cols >= 0)
                        grid.currentIndex -= cols;
                    event.accepted = true;
                    return;
                }
                if (event.key === Qt.Key_J) {
                    if (grid.currentIndex + cols < grid.count)
                        grid.currentIndex += cols;
                    event.accepted = true;
                    return;
                }
            }

            if (event.key === Qt.Key_Backspace) {
                if (root.pathHistory.length > 0) {
                    var h2 = root.pathHistory.slice();
                    root.currentPath = h2.pop();
                    root.pathHistory = h2;
                    grid.currentIndex = 0;
                }
                event.accepted = true;
                return;
            }

            root.gPending = false;
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: layoutMode === "left" ? 8 : layoutMode === "bottom" ? 10 : 16
            spacing: layoutMode === "left" ? 6 : layoutMode === "bottom" ? 6 : 10

            Item {
                visible: layoutMode === "left" || layoutMode === "center"
                Layout.fillWidth: true
                height: layoutMode === "center" ? 36 : 28

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uF03E"
                        font.pixelSize: layoutMode === "center" ? 15 : 13
                        color: Pal.color7
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wallpapers"
                        font.pixelSize: layoutMode === "center" ? 15 : 13
                        font.weight: Font.Medium
                        color: Pal.color7
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                        property int sz: layoutMode === "center" ? 32 : 26
                        width: sz
                        height: sz
                        radius: width / 2
                        color: leftNightBtn.containsMouse ? (root.nightMode ? Pal.borderSurface : Pal.bgInput) : (root.nightMode ? Pal.bgInput : Pal.bgPanel)
                        border.color: root.nightMode ? Pal.accent : Pal.borderSurface
                        border.width: 1
                        Behavior on color {
                            ColorAnimation {
                                duration: 100
                            }
                        }
                        Text {
                            anchors.centerIn: parent
                            text: root.nightMode ? "\uF186" : "\uF185"
                            font.pixelSize: layoutMode === "center" ? 15 : 13
                            color: root.nightMode ? Pal.accent : Pal.accentWarm
                        }
                        MouseArea {
                            id: leftNightBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.nightMode = !root.nightMode;
                                keyRect.forceActiveFocus();
                            }
                        }
                        ToolTip {
                            visible: leftNightBtn.containsMouse
                            text: root.nightMode ? "Show all" : "Night mode"
                            delay: 500
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                height: layoutMode === "left" ? 28 : layoutMode === "bottom" ? 28 : 36
                spacing: layoutMode === "left" ? 4 : 8

                Item {
                    visible: layoutMode === "bottom"
                    Layout.fillWidth: layoutMode === "bottom"
                    Layout.preferredWidth: layoutMode === "bottom" ? -1 : 0
                    height: parent.height
                    Row {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\uF03E"
                            font.pixelSize: 14
                            color: Pal.color7
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Wallpapers"
                            font.pixelSize: 14
                            font.weight: Font.Medium
                            color: Pal.color7
                        }
                    }
                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: shuffleBtn.containsMouse ? Pal.bgInput : "transparent"
                            border.color: Pal.borderSurface
                            border.width: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: "\u21C4"
                                font.pixelSize: 16
                                color: Pal.fgSecondary
                            }
                            MouseArea {
                                id: shuffleBtn
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var cnt = folderModel.count;
                                    if (cnt > 0) {
                                        var r = Math.floor(Math.random() * cnt);
                                        if (!folderModel.get(r, "fileIsDir"))
                                            root.setWallpaper(folderModel.get(r, "filePath"));
                                    }
                                    keyRect.forceActiveFocus();
                                }
                            }
                            ToolTip {
                                visible: shuffleBtn.containsMouse
                                text: "Random wallpaper"
                                delay: 500
                            }
                        }
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: nightBtn2.containsMouse ? (root.nightMode ? Pal.borderSurface : Pal.bgInput) : "transparent"
                            border.color: root.nightMode ? Pal.accent : Pal.borderSurface
                            border.width: 1
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                            Text {
                                anchors.centerIn: parent
                                text: root.nightMode ? "\uF186" : "\uF185"
                                font.pixelSize: 15
                                color: root.nightMode ? Pal.accent : Pal.accentWarm
                            }
                            MouseArea {
                                id: nightBtn2
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    root.nightMode = !root.nightMode;
                                    keyRect.forceActiveFocus();
                                }
                            }
                            ToolTip {
                                visible: nightBtn2.containsMouse
                                text: root.nightMode ? "Show all" : "Night mode"
                                delay: 500
                            }
                        }
                    }
                }

                Rectangle {
                    visible: layoutMode !== "bottom"
                    Layout.fillWidth: layoutMode !== "bottom"
                    Layout.preferredWidth: layoutMode === "bottom" ? 0 : -1
                    height: parent.height
                    color: Pal.bgInput
                    radius: 6
                    border.color: searchInput.activeFocus ? Pal.accent : Pal.borderSurface
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 6
                        Text {
                            text: "⌕"
                            color: Pal.accent
                            font.pixelSize: layoutMode === "left" ? 12 : 14
                        }
                        Item {
                            Layout.fillWidth: true
                            height: 22
                            Text {
                                anchors.fill: parent
                                text: "Search wallpapers..."
                                color: Pal.fgFaint
                                font.pixelSize: layoutMode === "left" ? 11 : 12
                                verticalAlignment: Text.AlignVCenter
                                visible: searchInput.text.length === 0 && !searchInput.activeFocus
                            }
                            TextInput {
                                id: searchInput
                                anchors.fill: parent
                                color: Pal.fgPrimary
                                font.pixelSize: layoutMode === "left" ? 11 : 12
                                verticalAlignment: TextInput.AlignVCenter

                                onTextChanged: {
                                    if (searchInputBottom.text !== text)
                                        searchInputBottom.text = text;
                                    root.searchText = text;
                                    root.rebuildMatches();
                                }
                                Keys.onReturnPressed: function (e) {
                                    keyRect.forceActiveFocus();
                                    grid.activateCurrent();
                                    e.accepted = true;
                                }
                                Keys.onEscapePressed: function (e) {
                                    text = "";
                                    searchInputBottom.text = "";
                                    root.searchText = "";
                                    root.searchMatches = [];
                                    root.searchMatchIndex = -1;
                                    keyRect.forceActiveFocus();
                                    e.accepted = true;
                                }
                                Keys.onTabPressed: root.nextMatch()
                                Keys.onBacktabPressed: root.prevMatch()
                                Keys.onPressed: function (e) {
                                    if (e.key === Qt.Key_N) {
                                        if (e.modifiers & Qt.ShiftModifier)
                                            root.prevMatch();
                                        else
                                            root.nextMatch();
                                        e.accepted = true;
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
                            visible: searchInput.text.length > 0
                            text: "✕"
                            color: Pal.fgDim
                            font.pixelSize: 11
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    searchInput.text = "";
                                    searchInputBottom.text = "";
                                    root.searchText = "";
                                    root.searchMatches = [];
                                    root.searchMatchIndex = -1;
                                    keyRect.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                visible: layoutMode === "bottom"
                Layout.fillWidth: true
                height: 26
                color: Pal.bgInput
                radius: 6
                border.color: searchInputBottom.activeFocus ? Pal.accent : Pal.borderSurface
                border.width: 1
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 6
                    Text {
                        text: "⌕"
                        color: Pal.accent
                        font.pixelSize: 14
                    }
                    Item {
                        Layout.fillWidth: true
                        height: 22
                        Text {
                            anchors.fill: parent
                            text: "Search wallpapers..."
                            color: Pal.fgFaint
                            font.pixelSize: 12
                            verticalAlignment: Text.AlignVCenter
                            visible: searchInputBottom.text.length === 0 && !searchInputBottom.activeFocus
                        }
                        TextInput {
                            id: searchInputBottom
                            anchors.fill: parent
                            color: Pal.fgPrimary
                            font.pixelSize: 12
                            verticalAlignment: TextInput.AlignVCenter

                            onTextChanged: {
                                if (searchInput.text !== text)
                                    searchInput.text = text;
                                root.searchText = text;
                                root.rebuildMatches();
                            }
                            Keys.onReturnPressed: function (e) {
                                keyRect.forceActiveFocus();
                                grid.activateCurrent();
                                e.accepted = true;
                            }
                            Keys.onEscapePressed: function (e) {
                                text = "";
                                searchInput.text = "";
                                root.searchText = "";
                                root.searchMatches = [];
                                root.searchMatchIndex = -1;
                                keyRect.forceActiveFocus();
                                e.accepted = true;
                            }
                            Keys.onTabPressed: root.nextMatch()
                            Keys.onBacktabPressed: root.prevMatch()
                            Keys.onPressed: function (e) {
                                if (e.key === Qt.Key_N) {
                                    if (e.modifiers & Qt.ShiftModifier)
                                        root.prevMatch();
                                    else
                                        root.nextMatch();
                                    e.accepted = true;
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
                        visible: searchInputBottom.text.length > 0
                        text: "✕"
                        color: Pal.fgDim
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                searchInputBottom.text = "";
                                searchInput.text = "";
                                root.searchText = "";
                                root.searchMatches = [];
                                root.searchMatchIndex = -1;
                                keyRect.forceActiveFocus();
                            }
                        }
                    }
                }
            }

            FolderListModel {
                id: folderModel
                folder: "file://" + root.currentPath
                showDirs: true
                showFiles: true
                nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif"]
                showDirsFirst: true
                showDotAndDotDot: false
                sortField: FolderListModel.Name
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: grid
                    anchors.fill: parent
                    clip: true

                    cellWidth: layoutMode === "left" ? Math.floor(grid.width / 3) : layoutMode === "bottom" ? Math.floor(grid.width / 5) : Math.floor(grid.width / Math.max(1, Math.floor(grid.width / 160)))
                    cellHeight: layoutMode === "left" ? 150 : layoutMode === "bottom" ? Math.floor(grid.width / 4 / 1.5) : 175

                    cacheBuffer: 600
                    flow: GridView.FlowLeftToRight
                    model: folderModel
                    currentIndex: 0

                    highlight: Rectangle {
                        color: "transparent"
                        border.color: Pal.accent
                        border.width: 2
                        radius: 8
                        z: 2
                    }
                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 80

                    ScrollBar.vertical: ScrollBar {
                        id: gridScrollBar
                        policy: ScrollBar.AsNeeded
                        width: 6
                        contentItem: Rectangle {
                            implicitWidth: 6
                            implicitHeight: 100
                            radius: 3
                            color: gridScrollBar.pressed ? Pal.accent : Pal.borderSurface
                            opacity: gridScrollBar.active ? 1.0 : 0.4
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }
                        }
                        background: Rectangle {
                            color: "transparent"
                        }
                    }

                    function activateCurrent() {
                        if (currentIndex < 0)
                            return;
                        var isDir = folderModel.get(currentIndex, "fileIsDir");
                        var fp = folderModel.get(currentIndex, "filePath");
                        if (isDir) {
                            var alreadyNight = root.currentPath.endsWith("/night");
                            var target = (root.nightMode && !alreadyNight) ? fp + "/night" : fp;
                            var h = root.pathHistory.slice();
                            h.push(root.currentPath);
                            root.pathHistory = h;
                            root.currentPath = target;
                            grid.currentIndex = 0;
                        } else {
                            root.setWallpaper(fp);
                        }
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: grid.cellWidth
                        height: grid.cellHeight

                        readonly property string dFileName: model.fileName ?? ""
                        readonly property string dFilePath: model.filePath ?? ""
                        readonly property string dFileURL: dIsDir ? "" : ("file://" + dFilePath)
                        readonly property bool dIsDir: model.fileIsDir ?? false
                        readonly property bool isSearchMatch: root.searchText.length > 0 && root.searchMatches.indexOf(index) !== -1

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: layoutMode === "left" ? 3 : layoutMode === "bottom" ? 3 : 6
                            color: ma.containsMouse ? Pal.borderSurface : Pal.bgInput
                            radius: 6
                            border.color: isSearchMatch ? Pal.warning : "transparent"
                            border.width: isSearchMatch ? 1 : 0
                            Behavior on color {
                                ColorAnimation {
                                    duration: 100
                                }
                            }

                            Item {
                                id: thumbArea
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: layoutMode === "left" ? 4 : layoutMode === "bottom" ? 4 : 8
                                height: parent.height - labelRow.height - (layoutMode === "left" ? 6 : 12)

                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Pal.bgSubtle
                                    visible: dIsDir
                                    Text {
                                        anchors.centerIn: parent
                                        text: "📁"
                                        font.pixelSize: layoutMode === "left" ? 28 : 42
                                    }
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    radius: 6
                                    color: Pal.bgSubtle
                                    clip: true
                                    visible: !dIsDir
                                    Image {
                                        anchors.fill: parent
                                        source: dIsDir ? "" : dFileURL
                                        fillMode: Image.PreserveAspectCrop
                                        asynchronous: true
                                        cache: true
                                        sourceSize.width: 320
                                        sourceSize.height: 320
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Pal.bgInput
                                            radius: 6
                                            visible: parent.status === Image.Loading || parent.status === Image.Null
                                            Text {
                                                anchors.centerIn: parent
                                                text: "…"
                                                color: Pal.fgFaint
                                                font.pixelSize: 18
                                            }
                                        }
                                        Rectangle {
                                            anchors.fill: parent
                                            color: Pal.bgInput
                                            radius: 6
                                            visible: parent.status === Image.Error
                                            Text {
                                                anchors.centerIn: parent
                                                text: "?"
                                                color: Pal.matchNone
                                                font.pixelSize: 18
                                            }
                                        }
                                    }
                                }
                            }

                            Item {
                                id: labelRow
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottomMargin: layoutMode === "left" ? 3 : 6
                                height: root.filenameDisplay === "none" ? 0 : (layoutMode === "left" ? 20 : 28)
                                Text {
                                    anchors.fill: parent
                                    anchors.leftMargin: 4
                                    anchors.rightMargin: 4
                                    text: root.filenameDisplay === "none" ? "" : root.filenameDisplay === "noext" ? dFileName.replace(/\.[^.]+$/, "") : dFileName
                                    color: Pal.fgPrimary
                                    font.pixelSize: layoutMode === "left" ? 9 : 11
                                    elide: Text.ElideMiddle
                                    horizontalAlignment: Text.AlignHCenter
                                    verticalAlignment: Text.AlignVCenter
                                    wrapMode: Text.NoWrap
                                }
                            }

                            MouseArea {
                                id: ma
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    grid.currentIndex = index;
                                    keyRect.forceActiveFocus();
                                    grid.activateCurrent();
                                }
                            }
                        }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text {
                    visible: layoutMode !== "left"
                    text: folderModel.count + " items"
                    color: Pal.color7
                    font.pixelSize: 11
                    Layout.preferredWidth: implicitWidth
                }
                Text {
                    visible: layoutMode !== "left"
                    text: "·"
                    color: Pal.color7
                    font.pixelSize: 11
                }
                Item {
                    visible: layoutMode !== "left"
                    Layout.fillWidth: true
                    height: 16
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentPath.replace(Quickshell.env("HOME"), "~").replace(/\/+$/, "")
                        color: Pal.color7
                        font.pixelSize: 11
                        elide: Text.ElideLeft
                    }
                }
                Item {
                    visible: layoutMode === "left"
                    Layout.fillWidth: true
                    height: 14
                    clip: true
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.currentPath.replace(Quickshell.env("HOME"), "~").replace(/\/+$/, "")
                        color: Pal.color7
                        font.pixelSize: 9
                        elide: Text.ElideLeft
                    }
                }
            }
        }
    }

    Timer {
        id: gPendingTimer
        interval: 500
        onTriggered: root.gPending = false
    }
    Timer {
        id: focusRetryTimer
        interval: 50
        onTriggered: keyRect.forceActiveFocus()
    }

    Timer {
        id: pickTimer
        interval: 80
        property var targetModel: null
        property int retryCount: 0

        onTriggered: {
            if (!targetModel)
                return;
            if (targetModel.count === 0 && retryCount < 10) {
                retryCount++;
                restart();
                return;
            }
            if (targetModel.count > 0) {
                var idx = Math.floor(Math.random() * targetModel.count);
                root.setWallpaper(targetModel.get(idx, "filePath"));
            }
            targetModel.destroy();
            targetModel = null;
            retryCount = 0;
        }
    }

    Process {
        id: setwpProc
    }

    Process {
        id: findProc
        property string accumulated: ""
        onRunningChanged: {
            if (running)
                findProc.accumulated = "";
        }
        stdout: SplitParser {
            onRead: function (line) {
                if (line.trim() !== "")
                    findProc.accumulated += line.trim() + "\n";
            }
        }
        onExited: function (code) {
            var lines = findProc.accumulated.trim().split("\n").filter(function (l) {
                return l.length > 0;
            });
            findProc.accumulated = "";
            if (lines.length > 0)
                root.setWallpaper(lines[Math.floor(Math.random() * lines.length)]);
            keyRect.forceActiveFocus();
        }
    }
}
