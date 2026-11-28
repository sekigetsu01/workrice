import QtQuick
import Quickshell
import Quickshell.Io

// The calendar's key (SUPER+C: qs ipc call calendar toggle), and the upcoming events (CalendarWidget) shown top
// right while the calendar is open.
Scope {
    id: root

    required property var panel

    Component.onCompleted: CalStore.rev

    LazyLoader {
        active: !!(root.panel.item && root.panel.item.visible) && Quickshell.screens.length > 0

        CalendarWidget {
            screen: Quickshell.screens[0]
        }
    }

    IpcHandler {
        target: "calendar"
        function toggle(): void {
            root.panel.toggle();
        }
    }
}
