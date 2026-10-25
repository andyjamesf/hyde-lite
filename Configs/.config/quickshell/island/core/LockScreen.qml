import QtQuick
import Quickshell.Wayland
import qs.island.theme
import qs.shared.services

// Session lock: while Lock.locked, the compositor shows only these surfaces (one per monitor) and
// nothing else receives keyboard or mouse. If the shell is reloaded with the screen locked, this
// WlSessionLock (with the same reloadableId) takes over the previous lock without releasing it.
WlSessionLock {
    id: sessionLock

    reloadableId: "islandSessionLock"
    locked: Lock.locked

    WlSessionLockSurface {
        id: surface

        color: Theme.background

        LockSurface {
            screenName: surface.screen?.name ?? ""
        }
    }
}
