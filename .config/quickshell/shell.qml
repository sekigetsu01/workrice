import QtQuick
import Quickshell
import Quickshell.Io
import "./screenshotter"
import "./powermenu"
import "./lockscreen"
import "./wallpaper-selector"
import "./launcher/apps"
import "./launcher/emoji"
import "./launcher/calc"
import "./launcher/timezone"
import "./launcher/network"
import "./launcher/drives"
import "./notifications"

ShellRoot {

    Screenshotter {
        id: screenshotter
    }

    LazyLoader {
        id: powerMenuLoader
        loading: false

        Launcher {
            MenuButton {
                text: "  Lock"
                keybind: Qt.Key_L
                command: "qs ipc call lockscreen lock"
            }
            MenuButton {
                text: "  Reboot"
                keybind: Qt.Key_R
                command: "systemctl reboot"
            }
            MenuButton {
                text: "  Shutdown"
                keybind: Qt.Key_S
                command: "systemctl poweroff"
            }
        }

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(powerMenuLoader.onItemChanged);
            }
        }
    }

    LazyLoader {
        id: lockscreenLoader
        loading: false

        Lockscreen {}
    }

    LazyLoader {
        id: wallpaperSelectorLoader
        loading: false

        WallpaperSelector {}

        onItemChanged: {
            if (item) {
                item.visible = true;
                itemChanged.disconnect(wallpaperSelectorLoader.onItemChanged);
            }
        }
    }

    LazyLoader {
        id: appLauncherLoader
        loading: false

        AppLauncherPanel {}

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(appLauncherLoader.onItemChanged);
            }
        }
    }

    LazyLoader {
        id: emojiLoader
        loading: false

        EmojiPanel {}

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(emojiLoader.onItemChanged);
            }
        }
    }

    LazyLoader {
        id: calcLoader
        loading: false

        CalcPanel {}

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(calcLoader.onItemChanged);
            }
        }
    }

    LazyLoader {
        id: timezoneLoader
        loading: false

        TimezonePanel {}

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(timezoneLoader.onItemChanged);
            }
        }
    }

    LazyLoader {
        id: networkManagerLoader
        loading: false

        NetworkManagerPanel {}

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(networkManagerLoader.onItemChanged);
            }
        }
    }

                LazyLoader {
        id: notificationCenterLoader
        loading: true

        NotificationCenter {}
    }

    NotificationPopup {
        id: notificationPopup
        centerRef: notificationCenterLoader.item
    }

    IpcHandler {
        target: "screenshotter"
        function toggle(): void {
            screenshotter.toggle();
        }
    }

    IpcHandler {
        target: "powermenu"
        function toggle(): void {
            if (powerMenuLoader.item) {
                powerMenuLoader.item.toggle();
            } else {
                powerMenuLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "lockscreen"
        function lock(): void {
            if (lockscreenLoader.item) {
                lockscreenLoader.item.active = true;
            } else {
                lockscreenLoader.loading = true;
                var _lockConn = function() {
                    lockscreenLoader.onItemChanged.disconnect(_lockConn);
                    lockscreenLoader.item.active = true;
                };
                lockscreenLoader.onItemChanged.connect(_lockConn);
            }
        }
    }

    IpcHandler {
        target: "wallpaperSelector"
        function toggle(): void {
            if (wallpaperSelectorLoader.item) {
                var w = wallpaperSelectorLoader.item;
                if (w.visible)
                    w.hideAndReset();
                else
                    w.visible = true;
            } else {
                wallpaperSelectorLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "applauncher"
        function toggle(): void {
            if (appLauncherLoader.item) {
                appLauncherLoader.item.toggle();
            } else {
                appLauncherLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "emojipicker"
        function toggle(): void {
            if (emojiLoader.item) {
                emojiLoader.item.toggle();
            } else {
                emojiLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "calc"
        function toggle(): void {
            if (calcLoader.item) {
                calcLoader.item.toggle();
            } else {
                calcLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "timezone"
        function toggle(): void {
            if (timezoneLoader.item) {
                timezoneLoader.item.toggle();
            } else {
                timezoneLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "network"
        function toggle(): void {
            if (networkManagerLoader.item) {
                networkManagerLoader.item.toggle();
            } else {
                networkManagerLoader.loading = true;
            }
        }
    }

    LazyLoader {
        id: driveManagerLoader
        loading: false

        DriveManagerPanel {}

        onItemChanged: {
            if (item) {
                item.toggle();
                itemChanged.disconnect(driveManagerLoader.onItemChanged);
            }
        }
    }

    IpcHandler {
        target: "drives"
        function toggle(): void {
            if (driveManagerLoader.item) {
                driveManagerLoader.item.toggle();
            } else {
                driveManagerLoader.loading = true;
            }
        }
    }

    IpcHandler {
        target: "notifications"
        function toggle(): void {
            if (notificationCenterLoader.item) notificationCenterLoader.item.toggle();
        }
        function notify(appName: string, summary: string, body: string, icon: string): void {
            notificationPopup.showNotif(appName, summary, body, icon);
        }
    }
}
