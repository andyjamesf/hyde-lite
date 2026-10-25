import QtQuick
import Quickshell.Wayland
import qs.shared.services

// Session lock: while Lock.locked, the compositor only shows these surfaces (one per
// monitor) and nothing else receives keyboard or mouse input.
WlSessionLock {
    locked: Lock.locked

    WlSessionLockSurface {
        color: "black"

        LockSurface {}
    }
}
