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

        property var    allDrives:    []
    property string focusSource:  "keyboard"
    property bool   busy:         false
    property string view:         "list"   
    property var    pendingDrive: null
    property string pendingDev:   ""
    property string pendingMp:    ""
    property string sudoError:    ""
    property bool   needsLuks:    false  
    property bool   isLoading:    false
    property bool   pendingUmount: false 
    property var    aliases:      ({})   

        function aliasKey(drive) {
                return drive.pkname !== "" ? drive.pkname : drive.devname
    }
    function displayLabel(drive) {
        var key = aliasKey(drive)
        return (aliases[key] && aliases[key] !== "") ? aliases[key] : drive.label
    }
    function saveAlias(drive, name) {
        var key = aliasKey(drive)
        var a = Object.assign({}, aliases)
        if (name === "" || name === drive.label) delete a[key]
        else a[key] = name
        aliases = a
        saveAliasProc.command = ["sh", "-c",
            "mkdir -p ~/.config && printf '%s' " + shellEscape(JSON.stringify(a)) +
            " > ~/.config/quickshell-drive-aliases.json"]
        saveAliasProc.running = true
    }

    Process {
        id: loadAliasProc
        running: true
        command: ["sh", "-c", "cat ~/.config/quickshell-drive-aliases.json 2>/dev/null || echo '{}'"]
        stdout: SplitParser {
            property string buf: ""
            onRead: function(line) { buf += line }
        }
        onExited: function() {
            try { root.aliases = JSON.parse(loadAliasProc.stdout.buf) } catch(e) { root.aliases = ({}) }
            loadAliasProc.stdout.buf = ""
        }
    }
    Process { id: saveAliasProc; running: false; command: ["sh", "-c", "true"] }

            property var usageMap: ({})

    Process {
        id: dfProc
        running: false
        command: ["sh", "-c", "df -h --output=target,used,avail,pcent 2>/dev/null | tail -n +2"]
        stdout: SplitParser {
            property string buf: ""
            onRead: function(line) { buf += line + "\n" }
        }
        onExited: function() {
            var lines = dfProc.stdout.buf.trim().split("\n")
            dfProc.stdout.buf = ""
            var map = {}
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].trim().split(/\s+/)
                if (parts.length < 4) continue
                var mp   = parts[0]
                var used = parts[1]
                var avail = parts[2]
                var pctStr = parts[3].replace("%", "")
                var pct = parseInt(pctStr, 10)
                if (isNaN(pct)) pct = 0
                map[mp] = { used: used, avail: avail, pct: pct }
            }
            root.usageMap = map
        }
    }

            property bool udevReady: false
    Process {
        id: udevProc
        running: true
        command: ["sh", "-c",
            "stdbuf -oL udevadm monitor --udev --subsystem-match=block 2>/dev/null | " +
            "grep --line-buffered 'add\\|remove\\|change'"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                if (!root.udevReady) { root.udevReady = true; return }
                udevDebounce.restart()
            }
        }
    }
    Timer {
        id: udevDebounce
        interval: 800   
        onTriggered: {
            if (root.view === "list") root.activate()
        }
    }

        Process {
        id: openFmProc
        running: false
        command: ["sh", "-c", "true"]
    }
    function openInFileManager(drive) {
        var mp = drive.mountpoint !== "" ? drive.mountpoint : "/mnt/" + drive.label
        openFmProc.command = ["sh", "-c",
            "xdg-open " + shellEscape(mp) + " 2>/dev/null &"
        ]
        openFmProc.running = true
    }

        property string busyError: ""
    Process {
        id: busyProc
        running: false
        command: ["sh", "-c", "true"]
        stdout: SplitParser {
            property string buf: ""
            onRead: function(line) { buf += line + "\n" }
        }
        onExited: function() {
            var out = busyProc.stdout.buf.trim()
            busyProc.stdout.buf = ""
            if (out !== "") {
                root.busyError = "Busy — held by: " + out.replace(/\n/g, ", ")
            } else {
                root.busyError = "Unmount failed (device may be busy)"
            }
        }
    }
    function checkBusy(drive) {
        root.busyError = ""
        var mp = drive.mountpoint !== "" ? drive.mountpoint : drive.devname
        busyProc.command = ["sh", "-c",
            "fuser -m " + shellEscape(mp) + " 2>/dev/null | xargs -r ps -p --no-headers -o comm= 2>/dev/null | sort -u | head -5; " +
            "lsof +D " + shellEscape(mp) + " 2>/dev/null | awk 'NR>1{print $1}' | sort -u | head -5"
        ]
        busyProc.running = true
    }

    focus: true
    Keys.onPressed: function(ev) {
        if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ControlModifier)) {
            root.activate(); ev.accepted = true; return
        }
        if (root.view === "detail") {
            if (ev.key === Qt.Key_Backspace || ev.key === Qt.Key_Escape) {
                root.view = "list"; root.pendingDrive = null; focusTimer.restart(); ev.accepted = true
            } else if (ev.key === Qt.Key_U) {
                if (root.pendingDrive && root.pendingDrive.mounted && !root.busy) {
                    root.busyError = ""
                    if (root.pendingDrive.luks) {
                        root.pendingUmount = true; root.needsLuks = false; root.sudoError = ""
                        overlayCol.luksVisible = false; overlayCol.sudoVisible = false
                        sudoField.text = ""; root.view = "sudo"; focusTimer.restart()
                    } else {
                        root.doUmount(root.pendingDrive); root.view = "list"; focusTimer.restart()
                    }
                }
                ev.accepted = true
            }
            return
        }
        if (root.view !== "list") return
        if (ev.key === Qt.Key_Escape) { root.requestClose(); ev.accepted = true }
        else if (ev.key === Qt.Key_Space) {
            var si = listView.currentIndex >= 0 ? listView.currentIndex : 0
            if (si < root.allDrives.length) {
                root.openDetail(root.allDrives[si])
            }
            ev.accepted = true
        } else if (ev.key === Qt.Key_Return || ev.key === Qt.Key_Enter) {
            if (!root.busy) {
                var idx = listView.currentIndex >= 0 ? listView.currentIndex : 0
                if (idx < root.allDrives.length) {
                    var d = root.allDrives[idx]
                    if (d.mounted) root.doUmount(d)
                    else           root.openDetail(d)
                }
            }
            ev.accepted = true
        } else if (ev.key === Qt.Key_J) {
            listView.currentIndex = Math.min(Math.max(listView.currentIndex, 0) + 1, root.allDrives.length - 1)
            root.focusSource = "keyboard"; ev.accepted = true
        } else if (ev.key === Qt.Key_K) {
            listView.currentIndex = Math.max(listView.currentIndex - 1, 0)
            root.focusSource = "keyboard"; ev.accepted = true
        }
    }

        function activate() {
        view         = "list"
        pendingDrive = null
        pendingDev   = ""
        pendingMp    = ""
        busy         = false
        isLoading    = true
        pendingUmount = false
        busyError    = ""
        listView.currentIndex = -1
        listProc.running = false
        listProc.running = true
        focusTimer.restart()
    }

    Timer {
        id: focusTimer; interval: 40
        onTriggered: {
            if      (root.view === "list")   root.forceActiveFocus()
            else if (root.view === "detail") {
                if (root.pendingDrive && !root.pendingDrive.mounted) mountInput.forceActiveFocus()
                else root.forceActiveFocus()
            }
            else if (root.view === "sudo")   { if (root.needsLuks) luksField.forceActiveFocus(); else sudoField.forceActiveFocus() }
        }
    }

        function driveIcon(d) {
        if (d.isPhone)  return "󰄜"
        if (d.luks)     return d.mounted ? "󰓐" : "󰌾"
        if (d.type === "rom") return "󰗮"
        return d.mounted ? "󰋊" : "󰋈"
    }
    function driveColor(d) {
        if (d.mounted) return Pal.positive
        if (d.luks)    return Pal.warning
        return Pal.fgSub
    }
    function shellEscape(s) {
        return "'" + s.replace(/'/g, "'\\''") + "'"
    }

        Process {
        id: listProc
        running: false
        command: ["sh", "-c",
            "lsblk -Ppo 'UUID,NAME,TYPE,SIZE,LABEL,MOUNTPOINT,FSTYPE,PKNAME' 2>/dev/null; " +
            "echo '---PHONES---'; " +
            "simple-mtpfs -l 2>/dev/null || true; " +
            "echo '---MTAB---'; " +
            "grep simple-mtpfs /etc/mtab 2>/dev/null || true"
        ]
        stdout: SplitParser {
            property string buf: ""
            onRead: function(line) { buf += line + "\n" }
        }
        onExited: function() {
            var raw = listProc.stdout.buf
            listProc.stdout.buf = ""
            var drives = []

            function field(text, key) {
                var i = text.indexOf(key + "=\"")
                if (i < 0) return ""
                var s = i + key.length + 2
                var e = text.indexOf("\"", s)
                return e >= 0 ? text.substring(s, e) : ""
            }

            var secs      = raw.split("---PHONES---")
            var lsblkPart = secs[0].trim().split("\n")

            for (var i = 0; i < lsblkPart.length; i++) {
                var ln = lsblkPart[i].trim()
                if (!ln || ln.indexOf("UUID=") < 0) continue
                var devname = field(ln, "NAME")
                var type    = field(ln, "TYPE")
                var size    = field(ln, "SIZE")
                var label   = field(ln, "LABEL")
                var mpoint  = field(ln, "MOUNTPOINT")
                var fstype  = field(ln, "FSTYPE")
                var pkname  = field(ln, "PKNAME")
                if (type !== "part" && type !== "crypt" && type !== "rom") continue
                var mpl = mpoint.toLowerCase()
                if (mpl === "/" || mpl.startsWith("/boot") || mpl === "[swap]") continue
                if (fstype.toLowerCase() === "swap") continue
                var isLuks   = devname.indexOf("/dev/mapper/") === 0
                var isMounted = mpoint !== "" && mpoint !== " "
                                                var lbl
                if (label !== "") {
                    lbl = label
                } else if (type === "crypt" && pkname !== "") {
                    lbl = pkname.replace(/^\/dev\//, "")
                } else {
                    lbl = devname.replace("/dev/mapper/","").replace("/dev/","")
                }
                drives.push({ label:lbl, devname:devname, pkname:pkname, size:size,
                    type:type, mounted:isMounted, mountpoint:mpoint,
                    luks:isLuks, fstype:fstype, isPhone:false })
            }

            var phoneSecs  = secs.length > 1 ? secs[1].split("---MTAB---") : ["",""]
            var phoneLines = phoneSecs[0].trim().split("\n")
            var mtab       = phoneSecs.length > 1 ? phoneSecs[1] : ""
            for (var j = 0; j < phoneLines.length; j++) {
                var pl = phoneLines[j].trim()
                if (!pl) continue
                var ci = pl.indexOf(":")
                if (ci < 0) continue
                var num  = pl.substring(0, ci).trim()
                var name = pl.substring(ci+1).trim()
                var safe = name.toLowerCase().replace(/[^a-z0-9]/g, "-")
                var alreadyMounted = mtab.indexOf("simple-mtpfs-" + safe) >= 0
                drives.push({ label:name, devname:num, pkname:"", size:"",
                    type:"phone", mounted:alreadyMounted,
                    mountpoint: alreadyMounted ? "/media/"+safe : "",
                    luks:false, fstype:"mtp", isPhone:true })
            }

                                    var unlocked = {}
            for (var k = 0; k < drives.length; k++) {
                var dk = drives[k]
                if (dk.type === "crypt") {
                                        if (dk.pkname && dk.pkname !== "") {
                        var pkBare = dk.pkname.replace(/^\/dev\//, "")
                        unlocked[pkBare] = true
                    }
                                        var mapBare = dk.devname.replace(/^\/dev\/mapper\//, "").replace(/^\/dev\//, "")
                    unlocked[mapBare] = true
                }
            }
            drives = drives.filter(function(d) {
                if (d.fstype === "crypto_LUKS") {
                    var bare = d.devname.replace(/^\/dev\//, "")  
                    if (unlocked[bare]) return false
                }
                return true
            })

            root.allDrives = drives
            root.isLoading = false
            if (drives.length > 0 && listView.currentIndex < 0)
                listView.currentIndex = 0
                        dfProc.running = false
            dfProc.running = true
        }
    }

        Process {
        id: mountProc
        running: false
        property string targetLabel: ""
        command: ["sh", "-c", "exit 1"]
        stdout: SplitParser {
            property string buf: ""
            onRead: function(line) { buf += line + "\n" }
        }
        stderr: SplitParser {
            onRead: function(line) { mountProc.stdout.buf += line + "\n" }
        }
        onExited: function(code) {
            root.busy = false
            var out = mountProc.stdout.buf.trim()
            mountProc.stdout.buf = ""
            if (code === 0) {
                root.notify("Mounted " + mountProc.targetLabel, "", true)
                root.sudoError = ""
                sudoField.text = ""
                luksField.text = ""
                root.view = "list"
                root.isLoading = true
                listProc.running = false
                listProc.running = true
                focusTimer.restart()
            } else if (root.view === "sudo") {
                if (code === 1)      root.sudoError = "Incorrect sudo password — try again"
                else if (code === 2) root.sudoError = "Incorrect LUKS passphrase — try again"
                else                 root.sudoError = "Mount failed (exit " + code + ")"
                if (code === 1) { sudoField.text = ""; sudoField.forceActiveFocus() }
                else            { luksField.text = ""; if (root.needsLuks) luksField.forceActiveFocus() }
            } else {
                                root.sudoError = ""
                root.needsLuks = (root.pendingDrive !== null && root.pendingDrive.fstype === "crypto_LUKS")
                overlayCol.luksVisible = false
                overlayCol.sudoVisible = false
                root.view = "sudo"
                focusTimer.restart()
            }
        }
    }

        Process {
        id: umountProc
        running: false
        property string targetLabel: ""
        command: ["sh", "-c", "exit 1"]
        stdout: SplitParser {
            property string buf: ""
            onRead: function(line) { buf += line + "\n" }
        }
        onExited: function(code) {
            root.busy = false
            umountProc.stdout.buf = ""
            if (code === 0) {
                root.busyError = ""
                root.notify("Unmounted " + umountProc.targetLabel, "", true)
            } else {
                root.checkBusy(root.pendingDrive)
                root.notify("Failed to unmount " + umountProc.targetLabel, "", false)
            }
            root.isLoading = true
            listProc.running = false
            listProc.running = true
            focusTimer.restart()
        }
    }

    Process {
        id: notifyProc; running: false; command: ["sh", "-c", "true"]
    }
    function notify(summary, body, isOk) {
        notifyProc.command = ["sh", "-c",
            "notify-send -u " + (isOk ? "normal" : "critical") +
            " -i " + (isOk ? "drive-harddisk" : "dialog-error") +
            " " + shellEscape(summary) +
            (body !== "" ? " " + shellEscape(body) : "")
        ]
        notifyProc.running = true
    }

        function openDetail(drive) {
        root.pendingDrive = drive
        root.sudoError    = ""
        root.busyError    = ""
        root.view = "detail"
        if (!drive.mounted) {
            var defaultMp = "/mnt/" + drive.label.replace(/[^a-zA-Z0-9]/g, "_")
            mountInput.text = defaultMp
            var key = aliasKey(drive)
            nicknameInput.text = (aliases[key] && aliases[key] !== "") ? aliases[key] : ""
            root.pendingDev = drive.devname
            root.pendingMp  = defaultMp
        }
        focusTimer.stop()
        focusTimer.restart()
    }

    function confirmMount() {
        var mp = mountInput.text.trim()
        if (!root.pendingDrive || mp === "") return
        root.pendingMp = mp
        root.pendingDev = root.pendingDrive.devname
        var nick = nicknameInput.text.trim()
        root.saveAlias(root.pendingDrive, nick)
        focusTimer.stop()
        doMount(root.pendingDrive, mp)
    }

    function doMount(drive, mp) {
        if (root.busy) return
        root.busy = true
        root.pendingDrive = drive
        root.pendingDev   = drive.devname
        root.pendingMp    = mp
        mountProc.targetLabel = drive.label
        var cmd
        if (drive.isPhone) {
            root.view = "list"
            var safe = drive.label.toLowerCase().replace(/[^a-z0-9]/g, "-")
            cmd = "MP=/media/" + safe + "; mkdir -p \"$MP\"; " +
                  "sudo simple-mtpfs -o allow_other -o fsname='simple-mtpfs-" + safe + "' " +
                  "--device " + drive.devname + " \"$MP\""
        } else if (drive.fstype === "crypto_LUKS") {
                        root.busy = false
            root.sudoError = ""
            root.needsLuks = true
            overlayCol.luksVisible = false
            overlayCol.sudoVisible = false
            luksField.text = ""
            sudoField.text = ""
            focusTimer.stop()
            root.view = "sudo"
            focusTimer.restart()
            return
        } else if (drive.type === "crypt") {
                        root.busy = false
            root.sudoError = ""
            root.needsLuks = false
            overlayCol.luksVisible = false
            overlayCol.sudoVisible = false
            sudoField.text = ""
            root.view = "sudo"
            focusTimer.restart()
            return
        } else {
                        root.busy = false
            root.sudoError = ""
            root.needsLuks = false
            overlayCol.luksVisible = false
            overlayCol.sudoVisible = false
            sudoField.text = ""
            root.view = "sudo"
            focusTimer.restart()
            return
        }
        mountProc.command = ["sh", "-c", cmd]
        mountProc.running = true
    }

    function doSudoMount() {
        var pw     = sudoField.text
        var luksPw = luksField.text
        if (!root.pendingDrive) return
        if (root.needsLuks && luksPw === "") return
        if (!root.needsLuks && pw === "") return
        if (root.busy) return
        root.busy = true
        var drive = root.pendingDrive
        var mp    = root.pendingMp
        var cmd
        if (drive.fstype === "crypto_LUKS") {
            var mapName = "luks_qs_" + drive.devname.replace(/^\/dev\//, "").replace(/\//g, "_")
                                    cmd = "printf '%s\\n' " + shellEscape(pw) + " | sudo -S true 2>&1 || exit 1; " +
                  "printf '%s\\n' " + shellEscape(pw) + " | sudo -S cryptsetup close " + shellEscape(mapName) + " 2>/dev/null; " +
                  "printf '%s' "    + shellEscape(luksPw) + " | sudo -S cryptsetup open " + shellEscape(drive.devname) + " --key-file=- " + shellEscape(mapName) + " 2>&1 || exit 2; " +
                  "mkdir -p "       + shellEscape(mp) + " 2>/dev/null || printf '%s\\n' " + shellEscape(pw) + " | sudo -S mkdir -p " + shellEscape(mp) + "; " +
                  "printf '%s\\n' " + shellEscape(pw) + " | sudo -S mount \"/dev/mapper/" + mapName + "\" " + shellEscape(mp) + " 2>&1 || exit 4"
        } else {
                        cmd = "printf '%s\\n' " + shellEscape(pw) + " | sudo -S true 2>&1 || exit 1; " +
                  "mkdir -p "       + shellEscape(mp) + " 2>/dev/null || printf '%s\\n' " + shellEscape(pw) + " | sudo -S mkdir -p " + shellEscape(mp) + "; " +
                  "printf '%s\\n' " + shellEscape(pw) + " | sudo -S mount " + shellEscape(drive.devname) + " " + shellEscape(mp) + " 2>&1 || exit 4"
        }
        mountProc.targetLabel = drive.label
        mountProc.command = ["sh", "-c", cmd]
        mountProc.running = true
    }

    function doSudoUmount() {
        var pw = sudoField.text
        if (!root.pendingDrive || pw === "") return
        if (root.busy) return
        root.busy = true
        root.pendingUmount = false
        var drive = root.pendingDrive
        var mp2   = drive.mountpoint !== "" ? drive.mountpoint : drive.devname
        var pkBare  = drive.pkname !== "" ? drive.pkname.replace(/^\/dev\//, "") : ""
        var mapName = pkBare !== "" ? "luks_qs_" + pkBare : drive.devname.replace(/^\/dev\/mapper\//, "")
        var cmd = "printf '%s\\n' " + shellEscape(pw) + " | sudo -S true 2>&1 || exit 1; " +
                  "printf '%s\\n' " + shellEscape(pw) + " | sudo -S umount " + shellEscape(mp2) + " 2>/dev/null || " +
                  "printf '%s\\n' " + shellEscape(pw) + " | sudo -S umount -l " + shellEscape(mp2) + " 2>/dev/null; " +
                  "printf '%s\\n' " + shellEscape(pw) + " | sudo -S cryptsetup close " + shellEscape(mapName) + " 2>&1; exit 0"
        umountProc.targetLabel = drive.label
        umountProc.command = ["sh", "-c", cmd]
        umountProc.running = true
        sudoField.text = ""
        root.view = "list"
    }

    function doUmount(drive) {
        if (root.busy) return
        root.busy = true
        umountProc.targetLabel = drive.label
        var cmd
        if (drive.isPhone) {
            var safe = drive.label.toLowerCase().replace(/[^a-z0-9]/g, "-")
            var mp = drive.mountpoint !== "" ? drive.mountpoint : "/media/" + safe
            cmd = "fusermount -u " + shellEscape(mp) + " 2>/dev/null || sudo umount -l " + shellEscape(mp)
        } else if (drive.luks) {
            var mp2 = drive.mountpoint !== "" ? drive.mountpoint : drive.devname
                                    var pkBare = drive.pkname !== "" ? drive.pkname.replace(/^\/dev\//, "") : ""
            var mapName = pkBare !== "" ? "luks_qs_" + pkBare : drive.devname.replace(/^\/dev\/mapper\//, "")
            cmd = "sudo umount " + shellEscape(mp2) + " 2>/dev/null || sudo umount -l " + shellEscape(mp2) + " 2>/dev/null; " +
                  "sudo cryptsetup close " + shellEscape(mapName) + " 2>/dev/null; exit 0"
        } else {
            var mp3 = drive.mountpoint !== "" ? drive.mountpoint : drive.devname
                        cmd = "udisksctl unmount -b " + shellEscape(drive.devname) + " 2>/dev/null || " +
                  "sudo umount " + shellEscape(mp3) + " 2>/dev/null || " +
                  "sudo umount -l " + shellEscape(mp3) + "; " +
                  "udisksctl power-off -b " + shellEscape(drive.devname) + " 2>/dev/null; exit 0"
        }
        umountProc.command = ["sh", "-c", cmd]
        umountProc.running = true
    }

        ColumnLayout {
        anchors.fill: parent
        spacing: 0

                Item {
            Layout.fillWidth: true
            height: theme.searchBarH
            Item {
                anchors.fill: parent
                anchors.margins: 10; anchors.bottomMargin: 0
                Rectangle { anchors.fill: parent; radius: 6; color: "transparent"; border.color: theme.clrBorder; border.width: 1 }
                RowLayout {
                    anchors.fill: parent; anchors.leftMargin: 12; anchors.rightMargin: 12; spacing: 8

                                        Rectangle {
                        visible: root.view === "detail"
                        width: 24; height: 24; radius: 4
                        color: backMa.containsMouse ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4) : "transparent"
                        Layout.alignment: Qt.AlignVCenter
                        Text { anchors.centerIn: parent; text: "󰁍"; font.pixelSize: 14; color: theme.clrTextSecond }
                        MouseArea { id: backMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.view = "list"; root.pendingDrive = null; focusTimer.restart() } }
                    }

                    Text { visible: root.view === "list"; text: "󰋊"; font.pixelSize: 14; color: theme.clrSearchIcon; Layout.alignment: Qt.AlignVCenter }

                    
                    Text {
                        text: root.view === "detail" && root.pendingDrive ? root.displayLabel(root.pendingDrive) : "Drive Manager"
                        color: theme.clrTextPrim; font.pixelSize: 13; font.family: "monospace"
                        Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter; elide: Text.ElideRight
                    }

                    Rectangle {
                        visible: root.view === "list" && root.allDrives.filter(function(d){return d.mounted}).length > 0
                        height: 22; width: badge.implicitWidth + 16; radius: 11
                        color: Qt.rgba(Pal.positive.r, Pal.positive.g, Pal.positive.b, 0.15)
                        border.color: Qt.rgba(Pal.positive.r, Pal.positive.g, Pal.positive.b, 0.4); border.width: 1
                        Layout.alignment: Qt.AlignVCenter
                        Text { id: badge; anchors.centerIn: parent; color: Pal.positive; font.pixelSize: 10; font.family: "monospace"
                            text: root.allDrives.filter(function(d){return d.mounted}).length + " mounted" }
                    }

                    Rectangle {
                        visible: root.view === "list"
                        width: 28; height: 28; radius: 5
                        color: refreshMa.containsMouse ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4) : "transparent"
                        Layout.alignment: Qt.AlignVCenter
                        Text {
                            id: refreshIcon
                            anchors.centerIn: parent; text: "󰑓"; font.pixelSize: 13
                            color: root.isLoading ? Pal.accent : theme.clrTextSecond
                            RotationAnimation on rotation {
                                running: root.isLoading
                                from: 0; to: 360; duration: 900; loops: Animation.Infinite
                            }
                            RotationAnimation on rotation {
                                running: !root.isLoading
                                to: 0; duration: 150; easing.type: Easing.OutCubic
                            }
                        }
                        MouseArea { id: refreshMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.activate() }
                    }

                    Text {
                        visible: root.view === "detail" && root.pendingDrive && root.pendingDrive.size !== ""
                        text: root.pendingDrive ? root.pendingDrive.size : ""
                        color: theme.clrTextMuted; font.pixelSize: 10; font.family: "monospace"; Layout.alignment: Qt.AlignVCenter
                    }
                }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: theme.clrDivider }

                Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.view === "list"

            Text { anchors.centerIn: parent; visible: root.allDrives.length === 0 && !listProc.running
                text: "No mountable drives found"; color: theme.clrTextMuted; font.pixelSize: 12; font.family: "monospace" }
            Text { anchors.centerIn: parent; visible: listProc.running && root.allDrives.length === 0
                text: "Scanning drives…"; color: theme.clrTextMuted; font.pixelSize: 12; font.family: "monospace" }

            ListView {
                id: listView
                anchors.fill: parent; model: root.allDrives; clip: true; keyNavigationEnabled: false
                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle { implicitWidth: 3; radius: 2; color: theme.clrScrollbar }
                    background: Item {}
                }
                delegate: Item {
                    required property var modelData
                    required property int index
                    width: listView.width
                    height: modelData.mounted && root.usageMap[modelData.mountpoint] ? theme.rowHeight + 14 : theme.rowHeight

                    property var usage: modelData.mounted && modelData.mountpoint !== ""
                        ? root.usageMap[modelData.mountpoint] || null : null

                    Rectangle {
                        anchors.fill: parent
                        color: (root.focusSource === "keyboard" && listView.currentIndex === index) ? theme.clrSelRow
                             : rowMa.containsMouse ? theme.clrHovRow : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 14; anchors.rightMargin: 14
                        anchors.topMargin: 4; anchors.bottomMargin: 4
                        spacing: 4

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            Text { text: root.driveIcon(modelData); font.pixelSize: 16; color: root.driveColor(modelData); Layout.alignment: Qt.AlignVCenter }

                            Column {
                                Layout.fillWidth: true; spacing: 1
                                Text { width: parent.width; text: root.displayLabel(modelData)
                                    color: modelData.mounted ? Pal.positive : theme.clrTextPrim
                                    font.pixelSize: 12; font.family: "monospace"; elide: Text.ElideRight }
                                Text { width: parent.width
                                    text: (modelData.fstype ? modelData.fstype + "  ·  " : "") +
                                          (modelData.mounted && modelData.mountpoint ? modelData.mountpoint : modelData.devname)
                                    color: theme.clrTextMuted; font.pixelSize: 10; font.family: "monospace"; elide: Text.ElideRight }
                            }

                                                        Text {
                                visible: modelData.size !== ""
                                text: {
                                    if (usage) return usage.used + " / " + modelData.size
                                    return modelData.size
                                }
                                color: theme.clrTextMuted; font.pixelSize: 10; font.family: "monospace"; Layout.alignment: Qt.AlignVCenter
                            }

                            Rectangle {
                                width: 68; height: 22; radius: 4; Layout.alignment: Qt.AlignVCenter
                                color: btnMa.containsMouse
                                    ? Qt.rgba(modelData.mounted ? Pal.negative.r : Pal.accent.r,
                                              modelData.mounted ? Pal.negative.g : Pal.accent.g,
                                              modelData.mounted ? Pal.negative.b : Pal.accent.b, 0.28)
                                    : Qt.rgba(modelData.mounted ? Pal.negative.r : Pal.accent.r,
                                              modelData.mounted ? Pal.negative.g : Pal.accent.g,
                                              modelData.mounted ? Pal.negative.b : Pal.accent.b, 0.12)
                                border.color: Qt.rgba(modelData.mounted ? Pal.negative.r : Pal.accent.r,
                                                      modelData.mounted ? Pal.negative.g : Pal.accent.g,
                                                      modelData.mounted ? Pal.negative.b : Pal.accent.b, 0.4)
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 80 } }
                                Text { anchors.centerIn: parent; text: modelData.mounted ? "unmount" : "mount"
                                    color: modelData.mounted ? Pal.negative : Pal.accent; font.pixelSize: 9; font.family: "monospace" }
                                MouseArea {
                                    id: btnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.busy) return
                                        root.busyError = ""
                                        if (modelData.mounted) {
                                            if (modelData.luks) {
                                                root.pendingDrive = modelData
                                                root.pendingUmount = true
                                                root.needsLuks = false
                                                root.sudoError = ""
                                                overlayCol.luksVisible = false
                                                overlayCol.sudoVisible = false
                                                sudoField.text = ""
                                                root.view = "sudo"
                                                focusTimer.restart()
                                            } else {
                                                root.pendingDrive = modelData
                                                root.doUmount(modelData)
                                            }
                                        } else {
                                            root.openDetail(modelData)
                                        }
                                    }
                                }
                            }
                        }

                                                Item {
                            Layout.fillWidth: true
                            height: 5
                            visible: usage !== null

                            Rectangle {
                                anchors.fill: parent; radius: 3
                                color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.25)
                            }
                            Rectangle {
                                width: usage ? parent.width * Math.min(usage.pct / 100, 1.0) : 0
                                height: parent.height; radius: 3
                                color: {
                                    if (!usage) return Pal.accent
                                    if (usage.pct >= 90) return Pal.negative
                                    if (usage.pct >= 75) return Pal.warning
                                    return Pal.positive
                                }
                                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                            }
                        }
                    }

                    MouseArea {
                        id: rowMa; anchors.fill: parent; hoverEnabled: true; z: -1
                        cursorShape: Qt.PointingHandCursor
                        onEntered: root.focusSource = "mouse"
                        onClicked: { root.focusSource = "mouse"; listView.currentIndex = index; root.openDetail(modelData) }
                    }
                }
            }
        }

                Item {
            Layout.fillWidth: true; Layout.fillHeight: true
            visible: root.view === "detail"

            ColumnLayout {
                anchors.fill: parent; anchors.margins: 16; spacing: 10

                                RowLayout {
                    Layout.fillWidth: true; spacing: 12
                    Text {
                        text: root.pendingDrive ? root.driveIcon(root.pendingDrive) : ""
                        font.pixelSize: 24
                        color: root.pendingDrive ? root.driveColor(root.pendingDrive) : theme.clrTextMuted
                        Layout.alignment: Qt.AlignVCenter
                    }
                    Column {
                        Layout.fillWidth: true; spacing: 3
                        Text {
                            text: root.pendingDrive ? root.displayLabel(root.pendingDrive) : ""
                            color: theme.clrTextPrim; font.pixelSize: 14; font.family: "monospace"
                            elide: Text.ElideRight; width: parent.width
                        }
                        Text {
                            text: root.pendingDrive ? root.pendingDrive.devname : ""
                            color: theme.clrTextMuted; font.pixelSize: 10; font.family: "monospace"
                        }
                    }
                    Text {
                        visible: root.pendingDrive && root.pendingDrive.size !== ""
                        text: root.pendingDrive ? root.pendingDrive.size : ""
                        color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace"
                        Layout.alignment: Qt.AlignVCenter
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: theme.clrDivider }

                                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8
                    visible: root.pendingDrive !== null && root.pendingDrive.mounted

                                        Repeater {
                        model: {
                            if (!root.pendingDrive || !root.pendingDrive.mounted) return []
                            var u = root.usageMap[root.pendingDrive.mountpoint] || null
                            var rows = [
                                { icon: "󰉋", label: "Mountpoint", value: root.pendingDrive.mountpoint || "—" },
                                { icon: "󰋊", label: "Filesystem", value: root.pendingDrive.fstype || "—" },
                            ]
                            if (u) {
                                rows.push({ icon: "󰆼", label: "Used", value: u.used + " of " + root.pendingDrive.size + "  (" + u.pct + "%)" })
                                rows.push({ icon: "󰆼", label: "Free",  value: u.avail })
                            }
                            return rows
                        }

                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true; height: 36; radius: 5
                            color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.15)
                            border.color: theme.clrBorder; border.width: 1
                            RowLayout {
                                anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10; spacing: 8
                                Text { text: modelData.icon; font.pixelSize: 13; color: theme.clrSearchIcon; Layout.alignment: Qt.AlignVCenter }
                                Text { text: modelData.label; color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace"; Layout.preferredWidth: 80; Layout.alignment: Qt.AlignVCenter }
                                Text { text: modelData.value; color: theme.clrTextPrim; font.pixelSize: 11; font.family: "monospace"; Layout.fillWidth: true; elide: Text.ElideRight; Layout.alignment: Qt.AlignVCenter }
                            }
                        }
                    }

                                        Item {
                        Layout.fillWidth: true; height: 6
                        visible: root.pendingDrive !== null && root.pendingDrive.mounted &&
                                 root.usageMap[root.pendingDrive.mountpoint] !== undefined
                        property var u: root.pendingDrive && root.pendingDrive.mounted
                            ? root.usageMap[root.pendingDrive.mountpoint] || null : null
                        Rectangle { anchors.fill: parent; radius: 3; color: Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.25) }
                        Rectangle {
                            property var u2: root.pendingDrive && root.pendingDrive.mounted
                                ? root.usageMap[root.pendingDrive.mountpoint] || null : null
                            width: u2 ? parent.width * Math.min(u2.pct / 100, 1.0) : 0
                            height: parent.height; radius: 3
                            color: !u2 ? Pal.accent : u2.pct >= 90 ? Pal.negative : u2.pct >= 75 ? Pal.warning : Pal.positive
                            Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutCubic } }
                        }
                    }
                }

                                ColumnLayout {
                    Layout.fillWidth: true; spacing: 8
                    visible: root.pendingDrive !== null && !root.pendingDrive.mounted

                    Text { text: "Nickname (optional)"; color: theme.clrTextMuted; font.pixelSize: 10; font.family: "monospace" }
                    Rectangle {
                        Layout.fillWidth: true; height: 32; radius: 5
                        color: Qt.rgba(0,0,0,0.3)
                        border.color: nicknameInput.activeFocus ? Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.8) : theme.clrBorder
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 80 } }
                        TextInput {
                            id: nicknameInput
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.clrTextPrim; font.pixelSize: 12; font.family: "monospace"; selectByMouse: true
                            Keys.onReturnPressed: function(ev) { mountInput.forceActiveFocus(); ev.accepted = true }
                            Keys.onEscapePressed: function(ev) { root.view="list"; root.pendingDrive=null; focusTimer.restart(); ev.accepted = true }
                            Keys.onPressed: function(ev) {
                                if (ev.key === Qt.Key_J && (ev.modifiers & Qt.ControlModifier)) {
                                    mountInput.forceActiveFocus(); ev.accepted = true
                                }
                            }
                            Text {
                                anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                                text: root.pendingDrive ? root.pendingDrive.label : ""
                                color: theme.clrTextMuted; font.pixelSize: 12; font.family: "monospace"
                                elide: Text.ElideRight; visible: nicknameInput.text === ""
                            }
                        }
                    }

                    Text { text: "Mount point"; color: theme.clrTextMuted; font.pixelSize: 10; font.family: "monospace" }
                    Rectangle {
                        Layout.fillWidth: true; height: 32; radius: 5
                        color: Qt.rgba(0,0,0,0.3)
                        border.color: mountInput.activeFocus ? Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.8) : theme.clrBorder
                        border.width: 1
                        Behavior on border.color { ColorAnimation { duration: 80 } }
                        TextInput {
                            id: mountInput
                            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 10
                            verticalAlignment: TextInput.AlignVCenter
                            color: theme.clrTextPrim; font.pixelSize: 12; font.family: "monospace"; selectByMouse: true
                            Keys.onReturnPressed: function(ev) { root.confirmMount(); ev.accepted = true }
                            Keys.onEscapePressed: function(ev) { root.view="list"; root.pendingDrive=null; focusTimer.restart(); ev.accepted = true }
                            Keys.onPressed: function(ev) {
                                if (ev.key === Qt.Key_K && (ev.modifiers & Qt.ControlModifier)) {
                                    nicknameInput.forceActiveFocus(); ev.accepted = true
                                }
                            }
                        }
                    }
                    Text { text: "Directory will be created if it doesn't exist."; color: theme.clrTextMuted; font.pixelSize: 9; font.family: "monospace" }
                }

                                Rectangle {
                    Layout.fillWidth: true; height: 28; radius: 5
                    visible: root.busyError !== "" && root.pendingDrive !== null && root.pendingDrive.mounted
                    color: Qt.rgba(Pal.negative.r, Pal.negative.g, Pal.negative.b, 0.10)
                    border.color: Qt.rgba(Pal.negative.r, Pal.negative.g, Pal.negative.b, 0.35); border.width: 1
                    Text {
                        anchors.centerIn: parent; text: root.busyError
                        color: Pal.negative; font.pixelSize: 10; font.family: "monospace"
                        elide: Text.ElideRight; width: parent.width - 16
                        horizontalAlignment: Text.AlignHCenter
                    }
                }

                Item { Layout.fillHeight: true }

                                RowLayout {
                    Layout.fillWidth: true; spacing: 8

                                        Rectangle {
                        Layout.fillWidth: true; height: 34; radius: 5
                        color: detBackMa.containsMouse ? theme.clrHovRow : "transparent"
                        border.color: theme.clrBorder; border.width: 1
                        Text { anchors.centerIn: parent; text: "Back"; color: theme.clrTextMuted; font.pixelSize: 12; font.family: "monospace" }
                        MouseArea { id: detBackMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: { root.view = "list"; root.pendingDrive = null; focusTimer.restart() } }
                    }

                                        Rectangle {
                        Layout.fillWidth: true; height: 34; radius: 5
                        visible: root.pendingDrive !== null && !root.pendingDrive.mounted
                        color: mountBtnMa.containsMouse ? Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.35) : Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.18)
                        border.color: Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.55); border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "Mount here"; color: Pal.accent; font.pixelSize: 12; font.family: "monospace" }
                        MouseArea { id: mountBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.confirmMount() }
                    }

                                        Rectangle {
                        Layout.fillWidth: true; height: 34; radius: 5
                        visible: root.pendingDrive !== null && root.pendingDrive.mounted
                        color: detUmountMa.containsMouse ? Qt.rgba(Pal.negative.r,Pal.negative.g,Pal.negative.b,0.35) : Qt.rgba(Pal.negative.r,Pal.negative.g,Pal.negative.b,0.18)
                        border.color: Qt.rgba(Pal.negative.r,Pal.negative.g,Pal.negative.b,0.55); border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }
                        Text { anchors.centerIn: parent; text: "Unmount"; color: Pal.negative; font.pixelSize: 12; font.family: "monospace" }
                        MouseArea {
                            id: detUmountMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (!root.pendingDrive || root.busy) return
                                root.busyError = ""
                                if (root.pendingDrive.luks) {
                                    root.pendingUmount = true
                                    root.needsLuks = false
                                    root.sudoError = ""
                                    overlayCol.luksVisible = false
                                    overlayCol.sudoVisible = false
                                    sudoField.text = ""
                                    root.view = "sudo"
                                    focusTimer.restart()
                                } else {
                                    root.doUmount(root.pendingDrive)
                                    root.view = "list"
                                    focusTimer.restart()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

        Rectangle {
        anchors.fill: parent
        color: theme.clrBg; radius: 4
        visible: root.view === "sudo"
        opacity: visible ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 120 } }

        ColumnLayout {
            id: overlayCol
            anchors.centerIn: parent
            width: Math.min(parent.width - 60, 320); spacing: 14

                        property bool luksVisible: false
            property bool sudoVisible: false

            Text { Layout.alignment: Qt.AlignHCenter; text: "🔒"; font.pixelSize: 28 }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.pendingUmount ? "sudo password required" : (root.needsLuks ? "LUKS passphrase required" : "sudo password required")
                color: theme.clrTextPrim; font.pixelSize: 13; font.family: "monospace"; font.bold: true
            }
            Text { Layout.alignment: Qt.AlignHCenter
                text: root.pendingDrive ? (root.pendingUmount ? "Unmounting: " : "Mounting: ") + root.displayLabel(root.pendingDrive) : ""
                color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace"
                horizontalAlignment: Text.AlignHCenter; Layout.fillWidth: true; wrapMode: Text.WordWrap }

                        ColumnLayout {
                id: luksFieldCol
                Layout.fillWidth: true; spacing: 4
                visible: root.needsLuks
                Text { text: "LUKS passphrase"; color: theme.clrTextMuted; font.pixelSize: 9; font.family: "monospace" }
                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 6; color: "transparent"
                    border.color: luksField.activeFocus ? theme.clrSearchFocus : theme.clrBorder; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 4; spacing: 8
                        Text { text: "🔑"; font.pixelSize: 11; Layout.alignment: Qt.AlignVCenter; color: theme.clrSearchIcon }
                        TextInput {
                            id: luksField
                            Layout.fillWidth: true; Layout.fillHeight: true
                            echoMode: overlayCol.luksVisible ? TextInput.Normal : TextInput.Password
                            color: theme.clrInputText; font.pixelSize: 12; font.family: "monospace"
                            verticalAlignment: TextInput.AlignVCenter; clip: true
                            enabled: root.view === "sudo" && !root.busy
                            Keys.onReturnPressed: function(ev) {
                                if (sudoField.text === "") sudoField.forceActiveFocus()
                                else root.doSudoMount()
                                ev.accepted = true
                            }
                            Keys.onEscapePressed: function(ev) {
                                luksField.text = ""; sudoField.text = ""; root.sudoError = ""
                                root.view = "list"; focusTimer.restart(); ev.accepted = true
                            }
                            Keys.onPressed: function(ev) {
                                if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ControlModifier)) {
                                    root.activate(); ev.accepted = true
                                } else if (ev.key === Qt.Key_J && (ev.modifiers & Qt.ControlModifier)) {
                                    sudoField.forceActiveFocus(); ev.accepted = true
                                } else if (ev.key === Qt.Key_V && (ev.modifiers & Qt.ControlModifier)) {
                                    overlayCol.luksVisible = !overlayCol.luksVisible; ev.accepted = true
                                }
                            }
                        }
                                                Rectangle {
                            width: 28; height: 28; radius: 4; Layout.alignment: Qt.AlignVCenter
                            color: luksEyeHov.containsMouse ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent
                                text: overlayCol.luksVisible ? "󰈈" : "󰈉"
                                font.pixelSize: 14
                                color: overlayCol.luksVisible ? theme.clrSearchFocus : theme.clrSearchIcon
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea { id: luksEyeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: overlayCol.luksVisible = !overlayCol.luksVisible }
                        }
                    }
                }
            }

                        ColumnLayout {
                Layout.fillWidth: true; spacing: 4
                Text {
                    text: root.needsLuks ? "sudo password (for mount)" : "sudo password"
                    color: theme.clrTextMuted; font.pixelSize: 9; font.family: "monospace"
                }
                Rectangle {
                    Layout.fillWidth: true; height: 36; radius: 6; color: "transparent"
                    border.color: sudoField.activeFocus ? theme.clrSearchFocus : theme.clrBorder; border.width: 1
                    Behavior on border.color { ColorAnimation { duration: 120 } }
                    RowLayout {
                        anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 4; spacing: 8
                        Text { text: "🔐"; font.pixelSize: 11; Layout.alignment: Qt.AlignVCenter; color: theme.clrSearchIcon }
                        TextInput {
                            id: sudoField
                            Layout.fillWidth: true; Layout.fillHeight: true
                            echoMode: overlayCol.sudoVisible ? TextInput.Normal : TextInput.Password
                            color: theme.clrInputText; font.pixelSize: 12; font.family: "monospace"
                            verticalAlignment: TextInput.AlignVCenter; clip: true
                            enabled: root.view === "sudo" && !root.busy
                            Keys.onReturnPressed: function(ev) {
                                if (root.pendingUmount) root.doSudoUmount()
                                else root.doSudoMount()
                                ev.accepted = true
                            }
                            Keys.onEscapePressed: function(ev) {
                                sudoField.text = ""; luksField.text = ""; root.sudoError = ""
                                root.view = "list"; focusTimer.restart(); ev.accepted = true
                            }
                            Keys.onPressed: function(ev) {
                                if (ev.key === Qt.Key_R && (ev.modifiers & Qt.ControlModifier)) {
                                    root.activate(); ev.accepted = true
                                } else if (ev.key === Qt.Key_K && (ev.modifiers & Qt.ControlModifier)) {
                                    if (root.needsLuks) luksField.forceActiveFocus(); ev.accepted = true
                                } else if (ev.key === Qt.Key_V && (ev.modifiers & Qt.ControlModifier)) {
                                    overlayCol.sudoVisible = !overlayCol.sudoVisible; ev.accepted = true
                                }
                            }
                        }
                                                Rectangle {
                            width: 28; height: 28; radius: 4; Layout.alignment: Qt.AlignVCenter
                            color: sudoEyeHov.containsMouse ? Qt.rgba(Pal.color8.r, Pal.color8.g, Pal.color8.b, 0.4) : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }
                            Text {
                                anchors.centerIn: parent
                                text: overlayCol.sudoVisible ? "󰈈" : "󰈉"
                                font.pixelSize: 14
                                color: overlayCol.sudoVisible ? theme.clrSearchFocus : theme.clrSearchIcon
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }
                            MouseArea { id: sudoEyeHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: overlayCol.sudoVisible = !overlayCol.sudoVisible }
                        }
                    }
                }
            }

            Text { Layout.alignment: Qt.AlignHCenter; text: root.sudoError; color: Pal.negative
                font.pixelSize: 11; font.family: "monospace"; visible: root.sudoError !== "" }

            RowLayout {
                Layout.fillWidth: true; spacing: 8
                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 6
                    color: cancelMa.containsMouse ? theme.clrHovRow : "transparent"
                    border.color: theme.clrBorder; border.width: 1
                    Text { anchors.centerIn: parent; text: "Cancel"; color: theme.clrTextMuted; font.pixelSize: 11; font.family: "monospace" }
                    MouseArea { id: cancelMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { sudoField.text = ""; luksField.text = ""; root.sudoError = ""; root.view = "list"; focusTimer.restart() } }
                }
                Rectangle {
                    Layout.fillWidth: true; height: 32; radius: 6
                    color: sudoBtnMa.containsMouse ? Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.35) : Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.18)
                    border.color: Qt.rgba(Pal.accent.r,Pal.accent.g,Pal.accent.b,0.55); border.width: 1
                    Text { anchors.centerIn: parent; text: root.pendingUmount ? "Unmount" : "Mount"; color: Pal.accent; font.pixelSize: 11; font.family: "monospace" }
                    MouseArea { id: sudoBtnMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.pendingUmount ? root.doSudoUmount() : root.doSudoMount() }
                }
            }
        }
    }
}
