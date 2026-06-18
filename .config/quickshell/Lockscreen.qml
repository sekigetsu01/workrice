import QtQuick
import Quickshell
import Quickshell.Wayland
import "./lockscreen"

Scope {
    id: lockscreen
    property bool active: false

    onActiveChanged: {
        if (active)
            ctx.lock();
    }

    LockContext {
        id: ctx
        onUnlocked: lockscreen.active = false
    }

    WlSessionLock {
        locked: lockscreen.active

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: ctx
            }
        }
    }
}
