//@ pragma UseQApplication
import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services

// The island's lock screen on its own, for the bar shell. `island lock lock` starts this when the
// island is not running (`qs -p ~/.config/morphing-island/lock.qml`, with ISLAND_LOCK_ENTRY=fade so
// there is no pill: see config/LockScreenConfig.qml) and it quits once the screen is unlocked.
// Nothing else of the island runs here: no notification server, no polkit agent, no windows.
ShellRoot {
    LockScreen {}

    // Same entry points as the island's (shell.qml): `qs -p <this file> ipc call lock lock|unlock`.
    IpcHandler {
        target: "lock"

        function lock(): void {
            Lock.lock();
        }
        function unlock(): void {
            Lock.unlock();
        }
        function isLocked(): bool {
            return Lock.locked;
        }
    }

    // Unlocked (after the exit animation): nothing left to do.
    Connections {
        target: Lock
        function onLockedChanged() {
            if (!Lock.locked)
                Qt.quit();
        }
    }
}
