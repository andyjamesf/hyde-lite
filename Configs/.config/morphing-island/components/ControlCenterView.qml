import QtQuick
import qs.config
import qs.core
import qs.services

// Control center: a single island content for the "controlcenter", "wifi", "bluetooth", "audio"
// and "media" modes. Inside it is a stack of pages: when the page changes, the new one slides in
// (from the right when entering a subview, from the left when going back to the main page) while
// the old one leaves to the opposite side; at the same time the view's natural size becomes the
// new page's and the island follows it with its spring (slide + resize). Both pages exist only
// during the transition; otherwise only the current one is loaded.
Item {
    id: root

    // Current island mode (other values, e.g. "clock" when closing, are ignored).
    property string page: IslandState.controlCenter
    // True while this is the island's current content.
    property bool open: false

    readonly property real islandRadius: ControlCenter.radius
    readonly property var pages: [IslandState.controlCenter].concat(IslandState.subviews)

    // Page on screen and the one leaving (only relevant while `sliding`).
    // (No binding: set at creation, then only changed by navigate().)
    property string current: ""
    property string previous: ""
    // +1: the new page enters from the right; −1: from the left.
    property int direction: 1
    // 0 → start of the transition; 1 → done.
    property real progress: 1
    readonly property bool sliding: progress < 1

    readonly property Item currentItem: {
        const loaders = [mainPage, wifiPage, bluetoothPage, audioPage, mediaPage, batteryPage, systemPage];
        return loaders.find(l => l.name === current)?.item ?? null;
    }

    // Summary for IPC (island-debug ccState).
    readonly property string status: {
        const nets = (Network.networks ?? []).length;
        const devs = (Bluetooth.devices ?? []).length;
        const sinks = (Audio.sinks ?? []).length;
        const sources = (Audio.sources ?? []).length;
        return `page=${current} sliding=${sliding ? 1 : 0} height=${Math.round(implicitHeight)} ` + `wifi=${Network.wifiEnabled ? 1 : 0} networks=${nets} bluetooth=${Bluetooth.enabled ? 1 : 0} devices=${devs} ` + `sinks=${sinks} sources=${sources} media=${Media.active ? 1 : 0} notifications=${Notifications.count}`;
    }

    // A text field released the focus: the island takes it back (so Esc reaches it).
    signal releaseFocus

    implicitWidth: ControlCenter.width
    implicitHeight: currentItem ? currentItem.implicitHeight : 0

    onPageChanged: navigate(page)
    Component.onCompleted: current = pages.includes(page) ? page : IslandState.controlCenter

    function navigate(p) {
        if (!pages.includes(p) || p === current)
            return;
        direction = p === IslandState.controlCenter ? -1 : 1;
        previous = current;
        current = p;
        slide.stop();
        if (Animations.enabled) {
            progress = 0;
            slide.start();
        } else {
            progress = 1;
        }
    }

    // Horizontal offset of a page: the new one comes from `direction` and the old one leaves to the
    // other side, both at the same speed (they stay side by side).
    function offsetFor(name) {
        if (name === current)
            return direction * (1 - progress) * width;
        if (name === previous && sliding)
            return -direction * progress * width;
        return 0;
    }

    function opacityFor(name) {
        if (name === current)
            return 0.35 + 0.65 * progress;
        if (name === previous && sliding)
            return 1 - 0.65 * progress;
        return 0;
    }

    function live(name) {
        return name === current || (name === previous && sliding);
    }

    NumberAnimation {
        id: slide
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: Animations.duration(ControlCenter.slideMs)
        easing.type: Easing.OutCubic
    }

    Binding {
        target: ControlCenterState
        property: "status"
        value: root.status
        when: root.open
    }

    // Under the pages: takes clicks on empty space and removes the focus from any field.
    MouseArea {
        anchors.fill: parent
        onPressed: root.releaseFocus()
    }

    Loader {
        id: mainPage
        readonly property string name: IslandState.controlCenter
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: CcMainPage {
            shown: root.open && root.current === mainPage.name
        }
    }

    Loader {
        id: wifiPage
        readonly property string name: IslandState.wifi
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: CcWifiPage {
            shown: root.open && root.current === wifiPage.name
            onReleaseFocus: root.releaseFocus()
        }
    }

    Loader {
        id: bluetoothPage
        readonly property string name: IslandState.bluetooth
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: CcBluetoothPage {
            shown: root.open && root.current === bluetoothPage.name
        }
    }

    Loader {
        id: audioPage
        readonly property string name: IslandState.audio
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: CcAudioPage {
            shown: root.open && root.current === audioPage.name
        }
    }

    Loader {
        id: mediaPage
        readonly property string name: IslandState.media
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: MediaCard {
            shown: root.open && root.current === mediaPage.name
        }
    }

    Loader {
        id: batteryPage
        readonly property string name: IslandState.battery
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: CcBatteryPage {
            shown: root.open && root.current === batteryPage.name
        }
    }

    Loader {
        id: systemPage
        readonly property string name: IslandState.system
        active: root.live(name)
        visible: active
        width: root.width
        x: root.offsetFor(name)
        opacity: root.opacityFor(name)
        sourceComponent: CcSystemPage {
            shown: root.open && root.current === systemPage.name
        }
    }
}
