import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Screen brightness and night light.
ColumnLayout {
    width: 300
    spacing: 12

    Component.onCompleted: NightLight.refresh()

    PanelHeader {
        icon: Brightness.icon
        title: "Display"
        subtitle: `Brightness ${Brightness.percent}%`
    }

    StyledSlider {
        Layout.fillWidth: true
        icon: Brightness.icon
        value: Brightness.percent / 100
        onMoved: v => Brightness.set(v * 100)
    }

    ListRow {
        Layout.fillWidth: true
        icon: "nightlight"
        iconFill: NightLight.active ? 1 : 0
        title: "Night light"
        subtitle: NightLight.active ? "On" : "Off"
        onClicked: NightLight.toggle()

        StyledSwitch {
            checked: NightLight.active
            onToggled: NightLight.toggle()
        }
    }
}
