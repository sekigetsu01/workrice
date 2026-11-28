import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "./lockscreen"

// The lock screen: CTRL+ALT+L (or Lock in the power menu), and after 45 minutes idle. If quickshell restarts while
// locked, it locks again. LockContext does the work; LockSurface is what's on screen.
Scope {
    id: lockscreen

    function lock() {
        _checkLost();
        ctx.lock();
        _checkLost();
    }
    function _checkLost() {
        if (ctx.locked && !sessionLock.locked)
            ctx.lockLost();
    }

    LockContext {
        id: ctx
    }

    // locked when the last instance died (mango keeps the session locked): lock again
    Process {
        running: true
        command: ["test", "-e", ctx.lockedFile]
        onExited: code => {
            if (code === 0 && !ctx.locked)
                lockscreen.lock();
        }
    }

    // locks after 45 minutes idle
    IdleMonitor {
        timeout: 45 * 60
        respectInhibitors: true
        onIsIdleChanged: if (isIdle && !ctx.locked) lockscreen.lock()
    }

    WlSessionLock {
        id: sessionLock
        locked: ctx.locked
        onSecureChanged: if (!sessionLock.secure) Qt.callLater(lockscreen._checkLost)
        onLockedChanged: Qt.callLater(lockscreen._checkLost)

        WlSessionLockSurface {
            LockSurface {
                anchors.fill: parent
                context: ctx
            }
        }
    }
}
