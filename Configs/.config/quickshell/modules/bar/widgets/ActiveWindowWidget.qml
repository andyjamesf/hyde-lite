import qs.components
import qs.services

// Icon and title of the active window, only on the bar of the screen it is on.
BarItem {
    id: root

    readonly property var toplevel: Hypr.activeToplevel
    readonly property string appId: Hypr.appIdOf(toplevel)

    shown: !!toplevel && toplevel.title !== "" && (!bar?.monitor || toplevel.monitor === bar.monitor)
    image: appId ? Apps.iconFor(appId) : ""
    text: toplevel?.title ?? ""
    textColor: Theme.textDim
    maxTextWidth: Config.widgets.activeWindow.maxWidth
    tooltip: appId ? `<b>${Apps.nameFor(appId)}</b>\n${text}` : text
}
