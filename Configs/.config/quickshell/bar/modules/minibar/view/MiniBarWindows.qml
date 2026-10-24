import QtQuick
import Quickshell
import qs.bar.modules.minibar.model

// One minimal bar per screen, created only while the bar is switched on and only on the screens
// MiniBarConfig.screens names ([] = all of them). bar/Shell.qml instantiates this once; the
// windows themselves come and go with the state, so the bar costs nothing while it is off.
Scope {
    Variants {
        model: Quickshell.screens

        LazyLoader {
            id: loader
            required property ShellScreen modelData
            active: MiniBarState.active && (MiniBarConfig.screens.length === 0 || MiniBarConfig.screens.includes(modelData.name))

            MiniBar {
                modelData: loader.modelData
            }
        }
    }
}
