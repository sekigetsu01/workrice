import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import "../"
import "fmt.js" as F

// The bar's data, shared by every screen: CPU, memory, volume, the clock, mango's tags and windows, and sysmon's
// disk, network, battery and VPN. Draws a BarWindow on each screen.
Scope {
    id: root

    signal powermenu

    readonly property string home: Quickshell.env("HOME")
    property int cpu: 0
    property string mem: ""
    property string memTip: ""
    property var sys: ({})
    property var monitors: null
    property bool recording: false
    property var pomo: ({ text: "", cls: "", tip: "" })
    property var _cpuPrev: null

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool muted: !!(sink && sink.audio && sink.audio.muted)
    readonly property int vol: sink && sink.audio ? Math.round(sink.audio.volume * 100) : 0

    function stepVolume(dir) {
        Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.5", "@DEFAULT_AUDIO_SINK@", dir > 0 ? "1%+" : "1%-"]);
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }
    readonly property date now: clock.date

    FileView {
        id: stat
        path: "/proc/stat"
        printErrors: false
        onLoaded: {
            const t = F.times(text());
            if (!t)
                return;
            if (root._cpuPrev === null) {
                root._cpuPrev = t;
                first.start();
                return;
            }
            root.cpu = F.usage(root._cpuPrev, t);
            root._cpuPrev = t;
        }
    }

    Timer {
        id: first
        interval: 100
        onTriggered: stat.reload()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: stat.reload()
    }

    FileView {
        id: cpuinfo
        path: "/proc/cpuinfo"
        printErrors: false
        blockLoading: true
    }
    readonly property string cpuTip: F.cpuTip(cpuinfo.text())

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const m = F.memory(text());
            root.mem = m ? m.text : "";
            root.memTip = m ? m.tip : "";
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: meminfo.reload()
    }

    Process {
        id: sysmon
        command: [Quickshell.shellPath("bar/sysmon")]
        running: true
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.sys = JSON.parse(line);
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }

    property bool batWarned: false
    onSysChanged: {
        const p = sys.bat, low = typeof p === "number" && p <= 15 && sys.batStatus === "Discharging";
        if (low && !batWarned)
            Quickshell.execDetached(["notify-send", "-u", "critical", "-a", "Battery", "Battery low", p + "% left" + (sys.batLeft ? " (" + sys.batLeft + ")" : "")]);
        if (low)
            batWarned = true;
        else if (typeof p !== "number" || p > 15 || sys.batStatus !== "Discharging")
            batWarned = false;
    }

    FileView {
        id: pomoBin
        path: root.home + "/.local/bin/pomo"
        printErrors: false
        blockLoading: true
    }
    readonly property bool hasPomo: pomoBin.loaded

    Process {
        id: pomoWatch
        command: [root.home + "/.local/bin/pomo", "watch"]
        running: root.hasPomo
        stdout: SplitParser {
            onRead: line => {
                const p = F.pomo(line);
                if (p)
                    root.pomo = p;
            }
        }
        onExited: {
            root.pomo = { text: "", cls: "", tip: "" };
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: {
            if (!sysmon.running)
                sysmon.running = true;
            if (!pomoWatch.running && root.hasPomo)
                pomoWatch.running = true;
        }
    }

    readonly property string mangoPath: Quickshell.env("MANGO_INSTANCE_SIGNATURE") || ""
    readonly property bool mangoOn: mangoLoader.item ? mangoLoader.item.connected : false

    LazyLoader {
        id: mangoLoader
        active: root.mangoPath !== ""

        Socket {
            id: mango
            path: root.mangoPath
            connected: true
            onConnectedChanged: {
                if (connected) {
                    mango.write("watch all-monitors\n");
                    mango.flush();
                } else {
                    root.monitors = null;
                }
            }
            parser: SplitParser {
                onRead: line => {
                    let o;
                    try {
                        o = JSON.parse(line);
                    } catch (e) {
                        return;
                    }
                    if (!o || !Array.isArray(o.monitors))
                        return;
                    root.monitors = o;
                }
            }
        }
    }

    Timer {
        interval: 2000
        repeat: true
        running: !root.mangoOn && root.mangoPath !== ""
        onTriggered: {
            mangoLoader.active = false;
            mangoLoader.active = true;
        }
    }

    IpcHandler {
        target: "bar"
        function vpn(): void {
            sysmon.write("\n");
        }
    }

    Variants {
        model: Quickshell.screens

        BarWindow {
            bar: root
        }
    }
}
