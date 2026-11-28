import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.WindowManager
import Quickshell.Services.SystemTray
import "../"
import "fmt.js" as F

// The bar on one screen: tags, the focused window, CPU, memory, disk, volume, network, battery, date and time, the
// VPN lock and the tray. Hover one for details; a click opens more (CPU: cpu-info, Mem: btop, Disk: ncdu,
// volume: wiremix, network: the wifi panel, date: the calendar).
PanelWindow {
    id: win

    required property var modelData
    required property var bar

    readonly property int barH: Math.max(Sys.barPx(22), sepL.need, ws.need, win_.need, cpu.need, mem.need, disk.need, pulse.need, net.need, bat.need, date.need, time.need, pomo.need, vpn.need, tray.need)
    readonly property var sets: F.sortSets(WindowManager.screenProjection(modelData).windowsets)
    readonly property var netLabel: F.net(bar.sys.net || "disconnected", bar.sys.essid || "")
    readonly property var batLabel: F.battery(bar.sys)
    readonly property string home: bar.home

    function term(...args) {
        Quickshell.execDetached([Sys.terminal, ...args]);
    }
    function showTip(item, x) {
        tip.show(item, x);
    }
    function hideTip(item) {
        tip.hide(item);
    }

    onBarHChanged: Sys.barH = barH
    Component.onCompleted: Sys.barH = barH

    screen: modelData
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: barH
    color: Pal.bg
    WlrLayershell.layer: WlrLayer.Top

    Tip {
        id: tip
        anchor.window: win
    }

    TrayMenu {
        id: menu
    }

    Row {
        spacing: 3

        Item {
            id: ws
            readonly property int need: Sys.barPx(18)
            width: wsRow.width + 4
            height: win.barH

            Row {
                id: wsRow
                x: 2

                Repeater {
                    model: win.sets

                    WsButton {
                        barH: win.barH
                    }
                }
            }
        }

        Sep {
            id: sepL
            barH: win.barH
        }

        Mod {
            id: win_
            text: F.windowInfo(win.bar.monitors, win.modelData.name).text
            fg: Pal.fg
            line: false
            padL: 0
            barH: win.barH
            bar: win
        }

        Item {
            visible: win.bar.recording
            width: Sys.barPx(16)
            height: win.barH

            Rectangle {
                anchors.centerIn: parent
                width: Sys.barPx(9)
                height: width
                radius: width / 2
                color: "#e0453a"
            }
        }
    }

    Row {
        anchors.right: parent.right
        spacing: 3

        Sep { barH: win.barH }

        Mod {
            id: cpu
            text: "CPU: " + win.bar.cpu + "%"
            fg: Pal.color9
            barH: win.barH
            tip: win.bar.cpuTip
            bar: win
            onPressed: b => {
                if (b === Qt.LeftButton)
                    win.term("--class=cpu-info", "-e", Quickshell.shellPath("bar/cpu-info"));
            }
        }

        Sep { barH: win.barH }

        Mod {
            id: mem
            text: win.bar.mem === "" ? "" : "Mem: " + win.bar.mem + "GiB"
            fg: Pal.color11
            barH: win.barH
            tip: win.bar.memTip
            bar: win
            onPressed: b => {
                if (b === Qt.LeftButton)
                    win.term("-e", "btop");
            }
        }

        Sep { barH: win.barH }

        Mod {
            id: disk
            text: win.bar.sys.disk ? "Disk: " + win.bar.sys.disk : ""
            fg: Pal.color13
            barH: win.barH
            tip: win.bar.sys.diskTip || ""
            bar: win
            onPressed: b => {
                if (b === Qt.LeftButton)
                    win.term("-e", "ncdu");
            }
        }

        Sep { barH: win.barH }

        Mod {
            id: pulse
            icon: win.bar.muted ? "\u{f0581}" : F.volIcon(win.bar.vol)
            iconPx: F.pango(13000) * Sys.barScale
            tightIcon: true
            text: win.bar.muted ? "Muted" : F.volume(win.bar.vol)
            fg: win.bar.muted ? Pal.color8 : Pal.color12
            opacity: win.bar.muted ? 0.5 : 1
            barH: win.barH
            wheel: true
            tip: win.bar.sink ? F.esc(win.bar.sink.description) : ""
            bar: win
            onPressed: b => {
                if (b === Qt.LeftButton)
                    win.term("-e", "wiremix");
                else if (b === Qt.MiddleButton)
                    Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
            }
            onScrolled: d => win.bar.stepVolume(d)
        }

        Sep { barH: win.barH }

        Mod {
            id: net
            icon: win.netLabel.icon
            iconPx: F.pango(9200) * Sys.barScale
            tightIcon: true
            text: win.netLabel.text
            fg: Pal.color14
            barH: win.barH
            tip: win.netLabel.tip || ""
            bar: win
            onPressed: b => {
                if (b === Qt.LeftButton)
                    Quickshell.execDetached(["qs", "ipc", "call", "wifi", "toggle"]);
            }
        }

        Sep {
            barH: win.barH
            visible: bat.visible
        }

        Mod {
            id: bat
            icon: win.batLabel.icon
            iconPx: F.pango(11000) * Sys.barScale
            tightIcon: true
            text: win.batLabel.text
            fg: win.batLabel.cls === "charging" || win.batLabel.cls === "plugged" ? Pal.themedGood : win.batLabel.cls === "critical" ? Pal.themedBad : win.batLabel.cls === "warning" ? Pal.themedWarn : Pal.color11
            barH: win.barH
            tip: win.batLabel.tip
            bar: win
            SequentialAnimation on opacity {
                running: win.batLabel.cls === "critical"
                loops: Animation.Infinite
                alwaysRunToEnd: true
                NumberAnimation { to: 0.35; duration: 500 }
                NumberAnimation { to: 1; duration: 500 }
            }
        }

        Sep { barH: win.barH }

        Mod {
            id: date
            icon: " "
            iconPx: F.pango(11000) * Sys.barScale
            text: Qt.locale().toString(win.bar.now, "ddd dd MMM")
            fg: Pal.color5
            padL: Sys.barPx(8)
            barH: win.barH
            onPressed: b => {
                if (b === Qt.LeftButton)
                    Quickshell.execDetached(["qs", "ipc", "call", "calendar", "toggle"]);
            }
        }

        Sep { barH: win.barH }

        Mod {
            id: time
            icon: "󰥔"
            iconPx: F.pango(11000) * Sys.barScale
            tightIcon: true
            text: Qt.formatTime(win.bar.now, "HH:mm")
            fg: Pal.color5
            padL: Sys.barPx(14)
            barH: win.barH
            onPressed: b => {
                if (b === Qt.LeftButton)
                    win.bar.powermenu();
            }
        }

        Sep {
            barH: win.barH
            visible: win.bar.pomo.text !== ""
        }

        Mod {
            id: pomo
            text: win.bar.pomo.text
            fg: win.bar.pomo.cls === "paused" ? Pal.color8 : win.bar.pomo.cls === "break" ? Pal.positive : Pal.color10
            padL: Sys.barPx(8)
            barH: win.barH
            tip: F.esc(win.bar.pomo.tip)
            bar: win
            onPressed: b => {
                const p = win.home + "/.local/bin/pomo";
                if (b === Qt.LeftButton)
                    Quickshell.execDetached([p]);
                else if (b === Qt.RightButton)
                    Quickshell.execDetached([p, "skip"]);
                else if (b === Qt.MiddleButton)
                    Quickshell.execDetached([p, "reset"]);
            }
        }

        Sep {
            barH: win.barH
            visible: win.bar.sys.vpn === true
        }

        Mod {
            id: vpn
            text: win.bar.sys.vpn === true ? "\u{1f512}" : ""
            px: 11 * Sys.barScale
            emoji: true
            fg: Pal.color1
            padL: Sys.barPx(8)
            marginR: Sys.barPx(4)
            barH: win.barH
            tip: "VPN active"
            bar: win
            onPressed: b => {
                const p = Quickshell.shellPath("bar/vpn-info");
                if (b === Qt.LeftButton)
                    Quickshell.execDetached([p, "status"]);
                else if (b === Qt.RightButton)
                    Quickshell.execDetached([p, "check"]);
            }
        }

        Item {
            id: tray
            readonly property int need: visible ? Sys.barPx(18) : 0
            visible: SystemTray.items.values.some(i => i.status !== Status.Passive)
            width: trayRow.width + Sys.barPx(8)
            height: win.barH

            Rectangle {
                y: win.barH - 2
                width: parent.width
                height: 2
                color: Pal.color12
            }

            Row {
                id: trayRow
                x: Sys.barPx(4)
                spacing: Sys.barPx(10)

                Repeater {
                    model: SystemTray.items.values

                    Item {
                        id: ti
                        required property var modelData
                        visible: modelData.status !== Status.Passive
                        width: Sys.barPx(16)
                        height: win.barH
                        readonly property string tip: F.trayTip(modelData.tooltipTitle, modelData.tooltipDescription, modelData.title)

                        Image {
                            y: Math.floor((win.barH - 2 - height) / 2)
                            width: Sys.barPx(16)
                            height: width
                            sourceSize.width: width
                            sourceSize.height: width
                            source: ti.modelData.icon
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                            hoverEnabled: true
                            onEntered: win.showTip(ti, mouseX)
                            onExited: win.hideTip(ti)
                            onPressed: e => {
                                win.hideTip(ti);
                                const it = ti.modelData;
                                if ((e.button === Qt.LeftButton && it.onlyMenu) || e.button === Qt.RightButton) {
                                    if (it.hasMenu) {
                                        const p = ti.mapToItem(null, e.x, e.y);
                                        menu.handle = it.menu;
                                        menu.open(win, Math.round(p.x), Math.round(p.y));
                                    }
                                } else if (e.button === Qt.LeftButton) {
                                    it.activate();
                                } else if (e.button === Qt.MiddleButton) {
                                    it.secondaryActivate();
                                }
                            }
                            onWheel: e => {
                                if (e.angleDelta.y !== 0)
                                    ti.modelData.scroll(e.angleDelta.y > 0 ? -1 : 1, false);
                                if (e.angleDelta.x !== 0)
                                    ti.modelData.scroll(e.angleDelta.x > 0 ? -1 : 1, true);
                            }
                        }
                    }
                }
            }
        }
    }
}
