import QtQuick
import Quickshell
import Quickshell.Io
import "./screenshotter"
import "./powermenu"
import "./lockscreen"
import "./wallpaper"
import "./launcher/apps"
import "./launcher/emoji"
import "./launcher/calc"
import "./launcher/timezone"
import "./launcher/wifi"
import "./notifications"
import "./bar"
import "./calendar"

// The whole desktop shell (quickshell, started by mango's config.conf): the bar, lock screen, screenshotter, notifications
// and every panel, each opened by its key through qs ipc call NAME toggle; opening one puts the others away.
ShellRoot {
    id: shellRoot

    function closeOthers(keep) {
        for (const l of [powerMenu, wallpaperSelector, appLauncher, emoji, calc, timezone, wifi, calendar, notificationCenter]) {
            const w = l.item;
            if (l !== keep && w && (l === powerMenu ? w.active : l === notificationCenter ? w.panelOpen : w.visible || w.parked === true)) {
                if (typeof w.setAside === "function")
                    w.setAside();
                else
                    w.toggle();
            }
        }
        if (keep !== linkChoice)
            linkChoice.active = false;
    }

    Lockscreen {
        id: lockscreen
    }

    Bar {
        recording: notificationPopup.recording
        onPowermenu: powerMenu.toggle()
    }

    Screenshotter {
        id: screenshotter
    }

    LazyPanel {
        id: powerMenu
        ipc: "powermenu"
        onOpening: shellRoot.closeOthers(powerMenu)

        Launcher {
            MenuButton {
                text: "Lock"
                keybind: Qt.Key_L
                command: "qs ipc call lockscreen lock"
            }
            MenuButton {
                text: "Reboot"
                keybind: Qt.Key_R
                command: "systemctl reboot"
            }
            MenuButton {
                text: "Shutdown"
                keybind: Qt.Key_S
                command: "systemctl poweroff"
            }
        }
    }

    Launcher {
        id: linkChoice
        property string url: ""

        MenuButton {
            text: "FreeTube"
            icon: "\u{f04b}"
            keybind: Qt.Key_F
            args: [linkChoice.url]
            command: 'exec ~/.local/bin/open-link --freetube "$1"'
        }
        MenuButton {
            text: "YouTube"
            icon: "\u{f16a}"
            iconScale: 1.15   // the logo is wide and short: this makes it as tall as the FreeTube triangle
            keybind: Qt.Key_J
            args: [linkChoice.url]
            command: 'exec ~/.local/bin/open-link --browser "$1"'
        }
    }

    IpcHandler {
        target: "link"
        function youtube(url: string): void {
            shellRoot.closeOthers(null);
            linkChoice.url = url;
            linkChoice.active = true;
        }
    }

    LazyPanel {
        id: wallpaperSelector
        ipc: "wallpaperSelector"
        onOpening: shellRoot.closeOthers(wallpaperSelector)
        WallpaperSelector {}
    }

    LazyPanel {
        id: appLauncher
        ipc: "applauncher"
        onOpening: shellRoot.closeOthers(appLauncher)
        AppLauncherPanel {}
    }

    LazyPanel {
        id: emoji
        ipc: "emojipicker"
        onOpening: shellRoot.closeOthers(emoji)
        EmojiPanel {}
    }

    LazyPanel {
        id: calc
        ipc: "calc"
        onOpening: shellRoot.closeOthers(calc)
        CalcPanel {}
    }

    IpcHandler {
        target: "calcKeys"
        Component.onCompleted: Quickshell.execDetached(["rm", "-f", (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/qs-calc-side"])
        function side(key: string): bool {
            return !!calc.item && calc.item.sideKey(key);
        }
        function window(key: string): bool {
            return !!calc.item && calc.item.windowKey(key);
        }
        function typing(): bool {
            return !!calc.item && calc.item.typing;
        }
        function focus(): bool {
            if (!calc.item || !calc.item.visible)
                return false;
            calc.item.refocus();
            return true;
        }
        function release(): bool {
            if (!calc.item || !calc.item.visible || !calc.item.hasWindow)
                return false;
            calc.item.release();
            return true;
        }
    }

    LazyPanel {
        id: timezone
        ipc: "timezone"
        onOpening: shellRoot.closeOthers(timezone)
        TimezonePanel {}
    }

    LazyPanel {
        id: wifi
        ipc: "wifi"
        onOpening: shellRoot.closeOthers(wifi)
        WifiPanel {}
    }

    LazyPanel {
        id: calendar
        onOpening: shellRoot.closeOthers(calendar)
        CalendarPanel {}
    }

    CalendarDesk {
        panel: calendar
    }

    LazyLoader {
        id: notificationCenter
        loading: true
        NotificationCenter {
            onOpenPanel: name => {
                if (name === "calendar" && !(calendar.item && calendar.item.visible))
                    calendar.toggle();
            }
        }
    }

    NotificationPopup {
        id: notificationPopup
        centerRef: notificationCenter.item
        onOpenCenter: notifIpc.open()
    }

    IpcHandler {
        target: "screenshotter"
        function toggle(): void {
            screenshotter.toggle();
        }
        function editFor(path: string, pid: int): void {
            screenshotter.edit(path, pid);
        }
    }

    IpcHandler {
        target: "capture"
        function toggle(): void {
            Quickshell.execDetached([Quickshell.shellPath("scripts/qs-capture"), "popup"]);
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            lockscreen.lock();
        }
    }

    IpcHandler {
        id: notifIpc
        target: "notifications"
        function toggle(): void {
            shellRoot.closeOthers(notificationCenter);
            if (notificationCenter.item)
                notificationCenter.item.toggle();
        }
        function open(): void {
            shellRoot.closeOthers(notificationCenter);
            if (notificationCenter.item && !notificationCenter.item.panelOpen)
                notificationCenter.item.toggle();
        }
        function recording(pid: int): void {
            notificationPopup.setRecorder(pid, false);
        }
        // a recording that shows pop-ups as usual (record-screen -s)
        function recordingShown(pid: int): void {
            notificationPopup.setRecorder(pid, true);
        }
        function dismiss(): void {
            notificationPopup.dismissTop();
        }
    }
}
