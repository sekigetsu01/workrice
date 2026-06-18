import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Io
import "../../"

Item {
    id: root

    Theme { id: theme }

    required property var panelRef

    signal requestClose()

        property string activeConnName: ""
    property string activeConnType: ""   
    property string activeConnSsid: ""

    property var    wifiList:  []        
    property var    ethList:   []        

        property string view: "list"
    property var    pendingNet: null     
    property var    detailNet: null      

    property bool   passwordVisible: false

        property string detailPassword: ""
    property bool   detailPasswordVisible: false
    property string detailBssid: ""
    property string detailIpAddr: ""

        property string pingMs: ""
    property string ethSpeed: ""         

        property string searchQuery: ""
    property bool   isLoading: false

        property string focusSource: "keyboard"

        property var favs: ({})   
    property int favVersion: 0  

    function isFav(ssid) { return !!root.favs[ssid] }
    function toggleFav(ssid) {
        var f = root.favs
        if (f[ssid]) delete f[ssid]
        else f[ssid] = true
        root.favs = f
        root.favVersion++
        saveFavs()
    }

        Process {
        id: saveFavsProc
        command: ["sh", "-c", "true"]
    }
    function saveFavs() {
                var escaped = JSON.stringify(root.favs).replace(/'/g, "'\\''")
        saveFavsProc.command = ["sh", "-c",
            "mkdir -p ~/.cache && " +
            "printf '%s' '" + escaped + "' > ~/.cache/quickshell-network-favs.json"
        ]
        saveFavsProc.running = true
    }
    Process {
        id: loadFavsProc
        running: true
        command: ["sh", "-c", "cat ~/.cache/quickshell-network-favs.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            onRead: function(line) {
                if (line.trim() === "") return
                try { root.favs = JSON.parse(line) } catch(e) { root.favs = {} }
            }
        }
    }

        function activate() {
        view = "list"
        pendingNet = null
        detailNet = null
        detailPassword = ""
        detailBssid = ""
        detailIpAddr = ""
        detailPasswordVisible = false
        passwordField.text = ""
        passwordVisible = false
        searchField.text = ""
        searchQuery = ""
        pingMs = ""
        ethSpeed = ""   
        isLoading = true
        scanProc.running = true
        activeProc.running = true
        autoRefreshTimer.restart()
        listFocusTimer.restart()
    }

    Timer {
        id: listFocusTimer
        interval: 30
        onTriggered: {
            if (root.view === "list") searchField.forceActiveFocus()
            else passwordField.forceActiveFocus()
        }
    }

        Timer {
        id: autoRefreshTimer
        interval: 30000
        repeat: true
        running: false
        onTriggered: {
            if (root.view === "connect") return   
            root.isLoading = true
            scanProc.running = true
            activeProc.running = true
        }
    }

    
                Process {
        id: scanProc
        running: false
        command: ["sh", "-c",
            "nmcli --mode multiline -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null"]
        stdout: SplitParser {
            property string buffer: ""
            onRead: function(line) { buffer += line + "\n" }
        }
        onExited: function() {
            var lines = scanProc.stdout.buffer.trim().split("\n")
            scanProc.stdout.buffer = ""
            var nets = []
            var seen = {}
            var i = 0
            while (i < lines.length) {
                                var inuseLine    = lines[i]   || ""
                var ssidLine     = lines[i+1] || ""
                var signalLine   = lines[i+2] || ""
                var securityLine = lines[i+3] || ""
                i += 4

                                var inuse    = inuseLine.indexOf(":") !== -1    ? inuseLine.substring(inuseLine.indexOf(":")+1).trim()    : ""
                var ssid     = ssidLine.indexOf(":") !== -1     ? ssidLine.substring(ssidLine.indexOf(":")+1).trim()     : ""
                var signal   = signalLine.indexOf(":") !== -1   ? parseInt(signalLine.substring(signalLine.indexOf(":")+1).trim()) || 0 : 0
                var security = securityLine.indexOf(":") !== -1 ? securityLine.substring(securityLine.indexOf(":")+1).trim() : ""

                if (ssid === "" || ssid === "--") continue
                if (seen[ssid]) continue
                seen[ssid] = true
                nets.push({
                    type:     "wifi",
                    ssid:     ssid,
                    signal:   signal,
                    security: security,
                    known:    false,
                    inuse:    inuse === "*"
                })
            }
                        nets.sort(function(a,b){ return b.signal - a.signal })
            knownProc.pendingNets = nets
            knownProc.running = true
        }
    }

    Process {
        id: knownProc
        running: false
        property var pendingNets: []
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE connection show 2>/dev/null"]
        stdout: SplitParser {
            property string buffer: ""
            onRead: function(line) { buffer += line + "\n" }
        }
        onExited: function() {
            var lines = knownProc.stdout.buffer.trim().split("\n")
            knownProc.stdout.buffer = ""
            var knownSsids = {}
            for (var i = 0; i < lines.length; i++) {
                var colonIdx = lines[i].indexOf(":")
                if (colonIdx === -1) continue
                var name  = lines[i].substring(0, colonIdx).trim()
                var ctype = lines[i].substring(colonIdx+1).trim()
                if (ctype.indexOf("wireless") !== -1)
                    knownSsids[name] = true
            }
            var nets = knownProc.pendingNets
            for (var j = 0; j < nets.length; j++)
                nets[j].known = !!knownSsids[nets[j].ssid]
            root.wifiList = nets
            root.isLoading = false
        }
    }

        Process {
        id: ethProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null | grep ':ethernet:'"]
        stdout: SplitParser {
            property string buffer: ""
            onRead: function(line) { buffer += line + "\n" }
        }
        onExited: function() {
            var lines = ethProc.stdout.buffer.trim().split("\n")
            ethProc.stdout.buffer = ""
            var eths = []
            for (var i = 0; i < lines.length; i++) {
                var p = lines[i].split(":")
                if (p.length < 3) continue
                eths.push({ type: "ethernet", name: p[0].trim(), state: p[2].trim() })
            }
            root.ethList = eths
        }
    }

            Process {
        id: activeProc
        running: false
        command: ["sh", "-c",
            "nmcli -t -f NAME,TYPE,DEVICE connection show --active 2>/dev/null"]
        stdout: SplitParser {
            property string buffer: ""
            onRead: function(line) { buffer += line + "\n" }
        }
        onExited: function() {
            var lines = activeProc.stdout.buffer.trim().split("\n")
            activeProc.stdout.buffer = ""
            root.activeConnName = ""
            root.activeConnType = ""
            root.activeConnSsid = ""
                        root.ethSpeed = ""
            var foundWifi = false
            var foundEth  = false
            for (var i = 0; i < lines.length; i++) {
                var p = lines[i].split(":")
                if (p.length < 3) continue
                var ctype = p[1].trim()
                if (!foundWifi && ctype.indexOf("wireless") !== -1) {
                    root.activeConnName = p[0].trim()
                    root.activeConnSsid = p[0].trim()
                    root.activeConnType = "wifi"
                    foundWifi = true
                } else if (!foundEth && ctype.indexOf("ethernet") !== -1) {
                                        if (!foundWifi) {
                        root.activeConnName = p[0].trim()
                        root.activeConnType = "ethernet"
                    }
                    var dev = p.length > 2 ? p[2].trim() : ""
                    if (dev !== "") {
                        ethSpeedProc.command = ["sh", "-c", "ethtool " + dev + " 2>/dev/null | grep Speed"]
                        ethSpeedProc.running = true
                    }
                    foundEth = true
                }
                if (foundWifi && foundEth) break
            }
            ethProc.running = true
            if (root.activeConnName !== "") pingProc.running = true
            else root.pingMs = ""
        }
    }

                Process {
        id: connectProc
        running: false
        property string targetSsid: ""
        property bool   isEth: false
        property string ethDev: ""

        command: ["true"]

        onExited: function(code) {
            if (code === 0) {
                var name = connectProc.isEth ? connectProc.ethDev : connectProc.targetSsid
                root.notify("Connected", name, true)
                activeProc.running = true
                scanProc.running = true
            } else {
                root.notify("Connection failed", connectProc.isEth ? connectProc.ethDev : connectProc.targetSsid, false)
            }
            root.view = "list"
        }
    }

            Process {
        id: pingProc
        running: false
        command: ["sh", "-c", "ping -c 3 -W 1 -q 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print int($5)}'"]
        stdout: SplitParser {
            onRead: function(line) {
                var v = line.trim()
                root.pingMs = (v !== "" && !isNaN(parseInt(v))) ? v + " ms" : ""
            }
        }
    }

        Process {
        id: ethSpeedProc
        running: false
        property string dev: ""
        command: ["sh", "-c", "true"]
        stdout: SplitParser {
            onRead: function(line) {
                var m = line.match(/Speed:\s*(\S+)/)
                if (m) root.ethSpeed = m[1]
            }
        }
    }

    Process {
        id: notifyProc
        running: false
        command: ["sh", "-c", "true"]
    }
    function notify(summary, body, isOk) {
        var urgency = isOk ? "normal" : "critical"
        var icon    = isOk ? "network-wireless" : "network-error"
        notifyProc.command = ["sh", "-c",
            "notify-send -u " + urgency + " -i " + icon +
            " '" + summary.replace(/'/g, "'\\''") + "'" +
            (body !== "" ? " '" + body.replace(/'/g, "'\\''") + "'" : "")
        ]
        notifyProc.running = true
    }

    Process {
        id: disconnectProc
        running: false
        command: ["sh", "-c", "exit 1"]
        onExited: function(code) {
            if (code === 0)
                root.notify("Disconnected", "", true)
            else
                root.notify("Network", "Failed to disconnect", false)
            activeProc.running = true
            scanProc.running = true
        }
    }

                function connectWifi(ssid, password) {
        connectProc.isEth      = false
        connectProc.targetSsid = ssid
        if (password !== "") {
            connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "password", password]
        } else {
                        connectProc.command = ["nmcli", "connection", "up", "id", ssid]
        }
        connectProc.running = true
    }

        function connectEth(devName) {
        connectProc.isEth  = true
        connectProc.ethDev = devName
        connectProc.command = ["nmcli", "device", "connect", devName]
        connectProc.running = true
    }

    Process {
        id: forgetProc
        running: false
        command: ["sh", "-c", "true"]
        onExited: function(code) {
            if (code === 0) root.notify("Network forgotten", "", true)
            else            root.notify("Failed to forget network", "", false)
            scanProc.running = false
            scanProc.running = true
        }
    }
    function forgetNetwork(name) {
        forgetProc.command = ["nmcli", "connection", "delete", "id", name]
        forgetProc.running = true
    }

    function disconnect() {
        disconnectProc.command = ["nmcli", "connection", "down", "id", root.activeConnName]
        disconnectProc.running = true
    }

        property bool detailCopied: false
    Timer {
        id: copiedResetTimer
        interval: 1800
        onTriggered: root.detailCopied = false
    }
    Process {
        id: clipProc
        running: false
        command: ["sh", "-c", "true"]
    }
    function copyPassword() {
        if (root.detailPassword === "") return
        var escaped = root.detailPassword.replace(/'/g, "'\\''")
        clipProc.command = ["sh", "-c",
            "printf '%s' '" + escaped + "' | wl-copy 2>/dev/null || " +
            "printf '%s' '" + escaped + "' | xclip -selection clipboard 2>/dev/null || " +
            "printf '%s' '" + escaped + "' | xsel --clipboard --input 2>/dev/null"
        ]
        clipProc.running = true
        root.detailCopied = true
        copiedResetTimer.restart()
    }

                Process {
        id: detailPassProc
        running: false
        command: ["sh", "-c", "true"]
        stdout: SplitParser {
            property string buffer: ""
            onRead: function(line) { buffer += line + "\n" }
        }
        onExited: function() {
            var lines = detailPassProc.stdout.buffer.trim().split("\n")
            detailPassProc.stdout.buffer = ""
            root.detailPassword = ""
            root.detailBssid    = ""
            root.detailIpAddr   = ""
            for (var i = 0; i < lines.length; i++) {
                var colonIdx = lines[i].indexOf(":")
                if (colonIdx === -1) continue
                var key = lines[i].substring(0, colonIdx).trim()
                var val = lines[i].substring(colonIdx + 1).trim()
                if (key === "802-11-wireless-security.psk")   root.detailPassword = val
                if (key === "GENERAL.HWADDR")                 root.detailBssid    = val
                if (key === "IP4.ADDRESS[1]")                 root.detailIpAddr   = val
            }
        }
    }

    function openDetails(net) {
        root.detailNet = net
        root.detailPassword = ""
        root.detailBssid    = ""
        root.detailIpAddr   = ""
        root.detailPasswordVisible = false
        root.view = "details"

        var name = net.ssid || net.name || ""
                detailPassProc.command = ["sh", "-c",
            "nmcli --show-secrets -f 802-11-wireless-security.psk,GENERAL.HWADDR,IP4.ADDRESS connection show id '" +
            name.replace(/'/g, "'\\''") + "' 2>/dev/null ; " +
            "nmcli -f IP4.ADDRESS device show 2>/dev/null | head -2"
        ]
        detailPassProc.running = true
    }

    function openConnect(net) {
        root.pendingNet = net
        root.view = "connect"
        passwordField.text = ""
        passwordVisible = false
        passFocusTimer.restart()
    }

    Timer {
        id: passFocusTimer
        interval: 30
        onTriggered: {
            if (net_needs_password(root.pendingNet))
                passwordField.forceActiveFocus()
            else
                connectBtn.forceActiveFocus()
        }
    }

    function net_needs_password(net) {
        if (!net) return false
        if (net.type === "ethernet") return false
        return net.security !== "" && net.security !== "--" && !net.known
    }

        function signalIcon(sig) {
        if (sig >= 75) return "󰤨"   
        if (sig >= 50) return "󰤥"
        if (sig >= 25) return "󰤢"
        return "󰤟"
    }
    function signalColor(sig) {
        if (sig >= 60) return Pal.positive
        if (sig >= 30) return Pal.warning
        return Pal.negative
    }

        property var combinedList: {
        var result = []
        for (var i = 0; i < root.ethList.length; i++)
            result.push(root.ethList[i])
        for (var j = 0; j < root.wifiList.length; j++)
            result.push(root.wifiList[j])
        return result
    }

    property var filteredList: {
        var q = root.searchQuery.toLowerCase().trim()
        var src = root.combinedList
        var list = q === ""
            ? src.slice()
            : src.filter(function(n) {
                var name = (n.type === "ethernet" ? n.name : n.ssid) || ""
                return name.toLowerCase().indexOf(q) !== -1
              })
                list.sort(function(a, b) {
            var fa = root.isFav(a.ssid || a.name) ? 1 : 0
            var fb = root.isFav(b.ssid || b.name) ? 1 : 0
            if (fb !== fa) return fb - fa
            var ia = a.inuse || a.state === "connected" ? 1 : 0
            var ib = b.inuse || b.state === "connected" ? 1 : 0
            if (ib !== ia) return ib - ia
            return (b.signal || 0) - (a.signal || 0)
        })
        return list
    }

        ColumnLayout {
        anchors.fill: parent
        spacing: 0

                Item {
            Layout.fillWidth: true
            height: theme.searchBarH

            Item {
                anchors.fill: parent
                anchors.topMargin:    10
                anchors.bottomMargin: 0
                anchors.leftMargin:   10
                anchors.rightMargin:  10

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: "transparent"
                    border.color: searchField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                    border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin:  12
                    anchors.rightMargin: 12
                    spacing: 8

                                        Text {
                        text: root.view === "connect" ? "󰌾" : (root.view === "details" ? "󰋼" : "󰖩")
                        font.pixelSize: 14
                        color: theme.clrSearchIcon
                        Layout.alignment: Qt.AlignVCenter
                    }

                                        Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.view === "connect"
                        Text {
                            anchors.fill: parent
                            text: root.pendingNet ? root.pendingNet.ssid || root.pendingNet.name : ""
                            color: theme.clrTextPrim
                            font.pixelSize: 13
                            font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.view === "details"
                        Text {
                            anchors.fill: parent
                            text: root.detailNet ? (root.detailNet.ssid || root.detailNet.name || "") : ""
                            color: theme.clrTextPrim
                            font.pixelSize: 13
                            font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        visible: root.view === "list"

                                                Text {
                            anchors.fill: parent
                            text: "Search networks..."
                            color: theme.clrTextMuted
                            font.pixelSize: 13
                            font.family: "monospace"
                            verticalAlignment: Text.AlignVCenter
                            visible: searchField.text.length === 0
                            opacity: 0.5
                        }
                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            color: theme.clrInputText
                            font.pixelSize: 13
                            font.family: "monospace"
                            verticalAlignment: TextInput.AlignVCenter
                            clip: true
                            selectByMouse: true
                            onTextChanged: root.searchQuery = text

                            Keys.onEscapePressed: function(ev) {
                                if (text !== "") {
                                    text = ""
                                    root.searchQuery = ""
                                } else {
                                    root.requestClose()
                                }
                                ev.accepted = true
                            }
                            Keys.onPressed: function(ev) {
                                                                if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ControlModifier)) {
                                    root.isLoading = true
                                    root.activate()
                                    ev.accepted = true
                                    return
                                }
                                                                if (ev.key === Qt.Key_D && (ev.modifiers & Qt.ControlModifier)) {
                                    if (root.activeConnName !== "") root.disconnect()
                                    ev.accepted = true
                                    return
                                }
                                                                if (ev.key === Qt.Key_F && (ev.modifiers & Qt.ControlModifier)) {
                                    var fidx = listView.currentIndex
                                                                        for (var fi = 0; fi < root.filteredList.length; fi++) {
                                        var fitem = listView.itemAtIndex(fi)
                                        if (fitem && fitem.mouseOver) { fidx = fi; break }
                                    }
                                    if (fidx >= 0 && fidx < root.filteredList.length) {
                                        var fnet = root.filteredList[fidx]
                                        if (fnet.known) root.forgetNetwork(fnet.ssid || fnet.name)
                                    }
                                    ev.accepted = true
                                    return
                                }
                                                                if (ev.key === Qt.Key_S && (ev.modifiers & Qt.ControlModifier)) {
                                    if (listView.currentIndex >= 0 && listView.currentIndex < root.filteredList.length) {
                                        var net = root.filteredList[listView.currentIndex]
                                        root.toggleFav(net.ssid || net.name)
                                    }
                                    ev.accepted = true
                                    return
                                }
                                                                if (ev.key === Qt.Key_J && (ev.modifiers & Qt.ControlModifier)) {
                                    if (listView.currentIndex < root.filteredList.length - 1) {
                                        root.focusSource = "keyboard"
                                        listView.currentIndex++
                                        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                                    }
                                    ev.accepted = true
                                    return
                                }
                                                                if (ev.key === Qt.Key_K && (ev.modifiers & Qt.ControlModifier)) {
                                    if (listView.currentIndex > 0) {
                                        root.focusSource = "keyboard"
                                        listView.currentIndex--
                                        listView.positionViewAtIndex(listView.currentIndex, ListView.Contain)
                                    }
                                    ev.accepted = true
                                    return
                                }
                                                                if (ev.key === Qt.Key_Space) {
                                    if (listView.currentIndex >= 0 && listView.currentIndex < root.filteredList.length) {
                                        root.openDetails(root.filteredList[listView.currentIndex])
                                    }
                                    ev.accepted = true
                                    return
                                }

                                                        if (root.view === "details") {
                                if (ev.key === Qt.Key_V && (ev.modifiers & Qt.ControlModifier)) {
                                    root.detailPasswordVisible = !root.detailPasswordVisible
                                    ev.accepted = true
                                    return
                                }
                                if (ev.key === Qt.Key_C && (ev.modifiers & Qt.ControlModifier)) {
                                    root.copyPassword()
                                    ev.accepted = true
                                    return
                                }
                                if (ev.key === Qt.Key_Escape) {
                                    root.view = "list"
                                    listFocusTimer.restart()
                                    ev.accepted = true
                                    return
                                }
                            }

                            if (root.view === "list") {
                                if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
                                    if (listView.currentIndex >= 0 && listView.currentIndex < root.filteredList.length) {
                                        var selNet = root.filteredList[listView.currentIndex]
                                        if (selNet.type === "ethernet") {
                                            root.connectEth(selNet.name)
                                        } else if (selNet.inuse) {
                                            root.disconnect()
                                        } else if (selNet.known) {
                                            root.connectWifi(selNet.ssid, "")
                                        } else {
                                            root.openConnect(selNet)
                                        }
                                    }
                                    ev.accepted = true
                                    return
                                }
                            }
                            }  
                        }
                    }

                                        Rectangle {
                        visible: root.activeConnName !== "" && root.view === "list"
                        height: 22
                        width: activeLabel.implicitWidth + 16
                        radius: 11
                        color: Qt.rgba(Pal.positive.r, Pal.positive.g, Pal.positive.b, 0.15)
                        border.color: Qt.rgba(Pal.positive.r, Pal.positive.g, Pal.positive.b, 0.4)
                        border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            id: activeLabel
                            anchors.centerIn: parent
                            text: root.activeConnSsid !== ""
                                ? root.activeConnSsid
                                : root.activeConnName
                            color: Pal.positive
                            font.pixelSize: 10
                            font.family: "monospace"
                        }
                    }

                                        Rectangle {
                        width: 28; height: 28; radius: 5
                        color: refreshHov.containsMouse
                            ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4)
                            : "transparent"
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            id: refreshIcon
                            anchors.centerIn: parent
                            text: root.view === "connect" || root.view === "details" ? "󰁮" : "󰑓"
                            font.pixelSize: 13
                                                        color: root.isLoading ? Pal.accent : theme.clrTextSecond

                                                                                                                RotationAnimation on rotation {
                                running: root.isLoading
                                from: 0
                                to: 360
                                duration: 900
                                loops: Animation.Infinite
                            }
                            RotationAnimation on rotation {
                                running: !root.isLoading
                                to: 0
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                        MouseArea {
                            id: refreshHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.view === "connect" || root.view === "details") {
                                    root.view = "list"
                                    listFocusTimer.restart()
                                } else {
                                    root.isLoading = true
                                    root.activate()
                                }
                            }
                        }
                    }
                }
            }
        }

                Rectangle {
            Layout.fillWidth: true
            height: 1
            color: theme.clrDivider
        }

                Rectangle {
            Layout.fillWidth: true
            height: 30
            visible: root.view === "list" && root.activeConnName !== ""
            color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.15)

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 16
                anchors.rightMargin: 12
                spacing: 0

                                Text {
                    visible: root.pingMs !== ""
                    text: "󰓅  " + root.pingMs
                    color: {
                        var ms = parseInt(root.pingMs)
                        if (ms < 30)  return Pal.positive
                        if (ms < 80)  return Pal.warning
                        return Pal.negative
                    }
                    font.pixelSize: 10
                    font.family: "monospace"
                    Layout.alignment: Qt.AlignVCenter
                }

                                Text {
                    visible: root.pingMs !== "" && root.ethSpeed !== ""
                    text: "  ·  "
                    color: theme.clrTextMuted
                    font.pixelSize: 10
                    font.family: "monospace"
                    Layout.alignment: Qt.AlignVCenter
                }

                                Text {
                    visible: root.ethSpeed !== ""
                    text: "󰈀  " + root.ethSpeed
                    color: theme.clrTextSecond
                    font.pixelSize: 10
                    font.family: "monospace"
                    Layout.alignment: Qt.AlignVCenter
                }

                Item { Layout.fillWidth: true }
            }
        }

                Rectangle {
            Layout.fillWidth: true
            height: root.view === "list" && root.activeConnName !== "" ? 1 : 0
            color: theme.clrDivider
        }

                                Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.view === "list"

                        Text {
                anchors.centerIn: parent
                visible: !root.isLoading && root.filteredList.length === 0
                text: root.searchQuery !== "" ? "No networks match \"" + root.searchQuery + "\"" : "No networks found"
                color: theme.clrTextMuted
                font.pixelSize: 12
                font.family: "monospace"
            }

            ListView {
                id: listView
                anchors.fill: parent
                anchors.margins: 0
                model: root.filteredList
                clip: true
                currentIndex: 0
                keyNavigationEnabled: false   
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 3
                        radius: 2
                        color: theme.clrScrollbar
                    }
                    background: Item {}
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: listView.width
                    height: theme.rowHeight
                    property bool mouseOver: false
                    color: (root.focusSource === "keyboard" && listView.currentIndex === index)
                        ? theme.clrSelRow
                        : (root.focusSource === "mouse" && mouseOver)
                            ? theme.clrHovRow : "transparent"
                    Behavior on color { ColorAnimation { duration: 80 } }

                    property bool isActive: modelData.type === "wifi"
                        ? modelData.inuse
                        : (modelData.state === "connected")
                    property bool starred: { root.favVersion; return !!root.favs[modelData.ssid || modelData.name] }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 14
                        spacing: 12

                                                Text {
                            text: {
                                if (modelData.type === "ethernet")
                                    return "󰈀"
                                return root.signalIcon(modelData.signal)
                            }
                            font.pixelSize: 15
                            color: isActive ? Pal.positive : Pal.color4
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 24
                        }

                                                Column {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                width: parent.width
                                text: modelData.type === "ethernet"
                                    ? modelData.name
                                    : modelData.ssid
                                color: isActive ? Pal.positive : theme.clrTextPrim
                                font.pixelSize: 13
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: text !== ""
                                width: parent.width
                                text: {
                                    if (modelData.type === "ethernet")
                                        return modelData.state
                                    var parts = []
                                    if (modelData.security && modelData.security !== "--")
                                        parts.push("🔒 " + modelData.security)
                                    if (isActive) parts.push("connected")
                                    else if (modelData.known) parts.push("saved")
                                    return parts.join("  ·  ")
                                }
                                color: theme.clrTextMuted
                                font.pixelSize: 10
                                font.family: "monospace"
                                elide: Text.ElideRight
                            }
                        }

                                                Text {
                            visible: modelData.type === "wifi"
                            text: modelData.type === "wifi" ? modelData.signal + "%" : ""
                            color: Pal.color4
                            font.pixelSize: 11
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                        }

                                                Text {
                            text: "★"
                            font.pixelSize: 14
                            color: starred
                                ? theme.clrStar
                                : ((root.focusSource === "mouse" && mouseOver) || (root.focusSource === "keyboard" && listView.currentIndex === index)
                                    ? theme.clrStarOff
                                    : "transparent")
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 100 } }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function(mouse) {
                                    root.toggleFav(modelData.ssid || modelData.name)
                                    mouse.accepted = true
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: { root.focusSource = "mouse"; mouseOver = true; }
                        onExited:  mouseOver = false
                        onClicked: {
                            root.focusSource = "mouse"
                            listView.currentIndex = index
                            var net = modelData
                            if (net.type === "ethernet") {
                                root.connectEth(net.name)
                            } else if (net.inuse) {
                                root.disconnect()
                            } else if (net.known) {
                                root.connectWifi(net.ssid, "")
                            } else {
                                root.openConnect(net)
                            }
                        }
                    }
                }
            }
        }

                                Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.view === "connect"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 14

                                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    radius: 6
                    color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.25)
                    border.color: theme.clrBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: root.pendingNet
                                ? (root.pendingNet.type === "ethernet" ? "󰈀" : root.signalIcon(root.pendingNet.signal || 0))
                                : ""
                            font.pixelSize: 22
                            color: root.pendingNet && root.pendingNet.type === "wifi"
                                ? root.signalColor(root.pendingNet ? root.pendingNet.signal || 0 : 0)
                                : theme.clrTextSecond
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: root.pendingNet
                                    ? (root.pendingNet.ssid || root.pendingNet.name || "")
                                    : ""
                                color: theme.clrTextPrim
                                font.pixelSize: 14
                                font.family: "monospace"
                            }
                            Text {
                                visible: root.pendingNet && root.pendingNet.type === "wifi"
                                text: root.pendingNet && root.pendingNet.security && root.pendingNet.security !== "--"
                                    ? "🔒 " + root.pendingNet.security + (root.pendingNet.signal ? "  ·  " + root.pendingNet.signal + "%" : "")
                                    : (root.pendingNet ? "Open network" + (root.pendingNet.signal ? "  ·  " + root.pendingNet.signal + "%" : "") : "")
                                color: theme.clrTextMuted
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }
                    }
                }

                                Item {
                    Layout.fillWidth: true
                    height: 42
                    visible: root.net_needs_password(root.pendingNet)

                    Rectangle {
                        anchors.fill: parent
                        radius: 6
                        color: "transparent"
                        border.color: passwordField.activeFocus ? theme.clrSearchFocus : theme.clrBorder
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 120 } }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 8

                        Text {
                            text: "󰌾"
                            font.pixelSize: 13
                            color: passwordField.activeFocus ? theme.clrSearchFocus : theme.clrSearchIcon
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 120 } }
                        }

                                                Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            Text {
                                anchors.fill: parent
                                text: "Passphrase..."
                                color: theme.clrTextMuted
                                font.pixelSize: 12
                                font.family: "monospace"
                                verticalAlignment: Text.AlignVCenter
                                visible: passwordField.text.length === 0
                                opacity: 0.5
                            }
                            TextInput {
                                id: passwordField
                                anchors.fill: parent
                                color: theme.clrInputText
                                font.pixelSize: 12
                                font.family: "monospace"
                                verticalAlignment: TextInput.AlignVCenter
                                clip: true
                                selectByMouse: true
                                echoMode: root.passwordVisible
                                    ? TextInput.Normal
                                    : TextInput.Password
                                Keys.onEscapePressed: function(ev) {
                                    root.view = "list"
                                    listFocusTimer.restart()
                                    ev.accepted = true
                                }
                                Keys.onReturnPressed: function(ev) {
                                    doConnect()
                                    ev.accepted = true
                                }
                                Keys.onPressed: function(ev) {
                                    if (ev.key === Qt.Key_H && (ev.modifiers & Qt.ControlModifier)) {
                                        root.passwordVisible = !root.passwordVisible
                                        ev.accepted = true
                                    }
                                }
                            }
                        }

                                                Rectangle {
                            width: 28; height: 28; radius: 4
                            color: eyeHov.containsMouse
                                ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4)
                                : "transparent"
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.passwordVisible ? "󰈈" : "󰈉"
                                font.pixelSize: 14
                                color: root.passwordVisible
                                    ? theme.clrSearchFocus
                                    : theme.clrSearchIcon
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: eyeHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.passwordVisible = !root.passwordVisible
                            }
                        }
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 5
                    visible: root.pendingNet && root.pendingNet.known && root.pendingNet.type === "wifi"
                    color: Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.10)
                    border.color: Qt.rgba(Pal.accentAlt.r, Pal.accentAlt.g, Pal.accentAlt.b, 0.25)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "󰒓  Saved network — will connect automatically"
                        color: Pal.accentAlt
                        font.pixelSize: 10
                        font.family: "monospace"
                    }
                }

                                Item { Layout.fillHeight: true }

                                Rectangle {
                    id: connectBtn
                    Layout.fillWidth: true
                    height: 40
                    radius: 6
                    focus: !root.net_needs_password(root.pendingNet)
                    color: connectBtnHov.containsMouse || activeFocus
                        ? Qt.rgba(Pal.accent.r, Pal.accent.g, Pal.accent.b, 0.25)
                        : Qt.rgba(Pal.accent.r, Pal.accent.g, Pal.accent.b, 0.12)
                    border.color: Qt.rgba(Pal.accent.r, Pal.accent.g, Pal.accent.b,
                                          connectBtnHov.containsMouse || activeFocus ? 0.7 : 0.35)
                    border.width: 1
                    Behavior on color { ColorAnimation { duration: 80 } }
                    Behavior on border.color { ColorAnimation { duration: 80 } }

                    Keys.onReturnPressed: function(ev) { doConnect(); ev.accepted = true }
                    Keys.onEscapePressed: function(ev) { root.view = "list"; ev.accepted = true }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: connectProc.running ? "󰑓" : "󰖩"
                            font.pixelSize: 14
                            color: Pal.accent
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: connectProc.running ? "Connecting..." : "Connect"
                            color: Pal.accent
                            font.pixelSize: 13
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }

                    MouseArea {
                        id: connectBtnHov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: doConnect()
                    }
                }

                                Item { height: 4 }
            }
        }
                                Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.view === "details"

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12

                                Rectangle {
                    Layout.fillWidth: true
                    height: 60
                    radius: 6
                    color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.25)
                    border.color: theme.clrBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 12

                        Text {
                            text: root.detailNet
                                ? (root.detailNet.type === "ethernet" ? "󰈀" : root.signalIcon(root.detailNet.signal || 0))
                                : ""
                            font.pixelSize: 22
                            color: root.detailNet && root.detailNet.type === "wifi"
                                ? root.signalColor(root.detailNet ? root.detailNet.signal || 0 : 0)
                                : theme.clrTextSecond
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Column {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                text: root.detailNet ? (root.detailNet.ssid || root.detailNet.name || "") : ""
                                color: theme.clrTextPrim
                                font.pixelSize: 14
                                font.family: "monospace"
                            }
                            Text {
                                visible: root.detailNet !== null
                                text: {
                                    if (!root.detailNet) return ""
                                    if (root.detailNet.type === "ethernet") return root.detailNet.state
                                    var parts = []
                                    if (root.detailNet.security && root.detailNet.security !== "--")
                                        parts.push("🔒 " + root.detailNet.security)
                                    if (root.detailNet.inuse) parts.push("connected")
                                    else if (root.detailNet.known) parts.push("saved")
                                    if (root.detailNet.signal) parts.push(root.detailNet.signal + "%")
                                    return parts.join("  ·  ")
                                }
                                color: theme.clrTextMuted
                                font.pixelSize: 10
                                font.family: "monospace"
                            }
                        }
                    }
                }

                                                                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 5
                    visible: root.detailNet && root.detailNet.type === "wifi"
                    color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.15)
                    border.color: theme.clrBorder
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10

                        Text {
                            text: "󰌾"
                            font.pixelSize: 13
                            color: theme.clrSearchIcon
                            Layout.alignment: Qt.AlignVCenter
                        }
                        Text {
                            text: "Password"
                            color: theme.clrTextMuted
                            font.pixelSize: 11
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                            Layout.preferredWidth: 80
                        }
                        Text {
                            Layout.fillWidth: true
                            text: {
                                if (!root.detailNet || !root.detailNet.known) return "—"
                                if (root.detailPassword === "") return "(fetching…)"
                                return root.detailPasswordVisible
                                    ? root.detailPassword
                                    : "•".repeat(Math.min(root.detailPassword.length, 20))
                            }
                            color: root.detailPassword !== "" ? theme.clrTextPrim : theme.clrTextMuted
                            font.pixelSize: 12
                            font.family: "monospace"
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                                                Rectangle {
                            width: 28; height: 28; radius: 4
                            visible: root.detailPassword !== "" && root.detailNet && root.detailNet.known
                            color: detailEyeHov.containsMouse
                                ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4)
                                : "transparent"
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.detailPasswordVisible ? "󰈈" : "󰈉"
                                font.pixelSize: 14
                                color: root.detailPasswordVisible
                                    ? theme.clrSearchFocus
                                    : theme.clrSearchIcon
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: detailEyeHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.detailPasswordVisible = !root.detailPasswordVisible
                            }
                        }

                                                Rectangle {
                            width: 28; height: 28; radius: 4
                            visible: root.detailPassword !== "" && root.detailNet && root.detailNet.known
                            color: root.detailCopied
                                ? Qt.rgba(Pal.positive.r, Pal.positive.g, Pal.positive.b, 0.25)
                                : detailCopyHov.containsMouse
                                    ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4)
                                    : "transparent"
                            Layout.alignment: Qt.AlignVCenter
                            Behavior on color { ColorAnimation { duration: 120 } }
                            Text {
                                anchors.centerIn: parent
                                text: root.detailCopied ? "󰄬" : "󰆏"
                                font.pixelSize: 13
                                color: root.detailCopied ? Pal.positive : theme.clrSearchIcon
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea {
                                id: detailCopyHov
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.copyPassword()
                            }
                        }
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 5
                    visible: root.detailNet && root.detailNet.type === "wifi"
                    color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.15)
                    border.color: theme.clrBorder
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10
                        Text { text: "󰒍"; font.pixelSize: 13; color: theme.clrSearchIcon; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "Security"; color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 80; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            Layout.fillWidth: true
                            text: root.detailNet
                                ? (root.detailNet.security && root.detailNet.security !== "--"
                                    ? root.detailNet.security : "Open")
                                : "—"
                            color: theme.clrTextPrim
                            font.pixelSize: 12
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 5
                    visible: root.detailNet && root.detailNet.type === "wifi"
                    color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.15)
                    border.color: theme.clrBorder
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10
                        Text { text: "󰤨"; font.pixelSize: 13; color: theme.clrSearchIcon; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "Signal"; color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 80; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            Layout.fillWidth: true
                            text: root.detailNet ? root.detailNet.signal + "%" : "—"
                            color: root.detailNet ? root.signalColor(root.detailNet.signal || 0) : theme.clrTextMuted
                            font.pixelSize: 12
                            font.family: "monospace"
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 40
                    radius: 5
                    visible: root.detailIpAddr !== ""
                    color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.15)
                    border.color: theme.clrBorder
                    border.width: 1
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 8
                        spacing: 10
                        Text { text: "󰩟"; font.pixelSize: 13; color: theme.clrSearchIcon; Layout.alignment: Qt.AlignVCenter }
                        Text { text: "IP Address"; color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 80; Layout.alignment: Qt.AlignVCenter }
                        Text {
                            Layout.fillWidth: true
                            text: root.detailIpAddr
                            color: theme.clrTextPrim
                            font.pixelSize: 12
                            font.family: "monospace"
                            elide: Text.ElideRight
                            Layout.alignment: Qt.AlignVCenter
                        }
                    }
                }

                                Rectangle {
                    Layout.fillWidth: true
                    height: 32
                    radius: 5
                    visible: root.detailNet && !root.detailNet.known && root.detailNet.type === "wifi"
                    color: Qt.rgba(Pal.warning.r, Pal.warning.g, Pal.warning.b, 0.08)
                    border.color: Qt.rgba(Pal.warning.r, Pal.warning.g, Pal.warning.b, 0.25)
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "  Not a saved network — no stored password"
                        color: Pal.warning
                        font.pixelSize: 10
                        font.family: "monospace"
                    }
                }

                Item { Layout.fillHeight: true }

                                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10

                                        Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 6
                        color: backHov.containsMouse
                            ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4)
                            : Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.2)
                        border.color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.5)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "󰁮"; font.pixelSize: 13; color: theme.clrTextSecond }
                            Text { text: "Back"; color: theme.clrTextSecond; font.pixelSize: 13; font.family: "monospace" }
                        }
                        MouseArea {
                            id: backHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { root.view = "list"; listFocusTimer.restart() }
                        }
                        Keys.onReturnPressed: function(ev) { root.view = "list"; listFocusTimer.restart(); ev.accepted = true }
                        Keys.onEscapePressed: function(ev) { root.view = "list"; listFocusTimer.restart(); ev.accepted = true }
                    }

                                        Rectangle {
                        Layout.fillWidth: true
                        height: 40
                        radius: 6
                        visible: root.detailNet && !root.detailNet.inuse && root.detailNet.type === "wifi"
                        color: detailConnHov.containsMouse
                            ? Qt.rgba(Pal.accent.r, Pal.accent.g, Pal.accent.b, 0.30)
                            : Qt.rgba(Pal.accent.r, Pal.accent.g, Pal.accent.b, 0.15)
                        border.color: Qt.rgba(Pal.accent.r, Pal.accent.g, Pal.accent.b, 0.5)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        RowLayout {
                            anchors.centerIn: parent
                            spacing: 6
                            Text { text: "󰖩"; font.pixelSize: 13; color: Pal.accent }
                            Text { text: "Connect"; color: Pal.accent; font.pixelSize: 13; font.family: "monospace" }
                        }
                        MouseArea {
                            id: detailConnHov
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.detailNet) return
                                if (root.detailNet.known) {
                                    root.connectWifi(root.detailNet.ssid, "")
                                    root.view = "list"
                                    listFocusTimer.restart()
                                } else {
                                    root.openConnect(root.detailNet)
                                }
                            }
                        }
                    }
                }

                Item { height: 4 }
            }
        }
    }

    function doConnect() {
        if (!root.pendingNet) return
        if (root.pendingNet.type === "ethernet") {
            root.connectEth(root.pendingNet.name)
        } else {
            root.connectWifi(root.pendingNet.ssid, passwordField.text)
        }
        root.view = "list"
        listFocusTimer.restart()
    }
}
