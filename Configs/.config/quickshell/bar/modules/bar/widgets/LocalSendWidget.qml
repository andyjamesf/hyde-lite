import QtQuick
import qs.bar.components
import qs.bar.services
import qs.bar.modules.controls
import qs.shared.services

// LocalSend receiver status. Click opens recent activity; right click restarts the
// background receiver (useful after it was reported not installed).
BarItem {
    icon: "send"
    iconColor: LocalSend.installError ? Theme.textFaint : LocalSend.ready ? Theme.text : Theme.textDim
    tooltip: LocalSend.installError ? "localsend-cli not found in ~/.local/bin" : LocalSend.ready ? `Receiving as "${LocalSend.alias}" on port ${LocalSend.port}` : "Starting…"

    popoutName: "localsend"
    popout: Component {
        LocalSendPanel {}
    }
    onRightClicked: LocalSend.restart()
}
