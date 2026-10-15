import QtQuick
import qs.config
import qs.services
import qs.theme

// PC statistics (services/SysStats.qml), shown by the control center's System page and by the
// detached window (core/StatsWindow.qml): CPU (per core), memory (apps, cache, free, swap), GPU,
// temperatures, storage, network and disk speed, battery draw, and the ten busiest processes,
// sorted by CPU or by memory.
Column {
    id: root

    // "cpu" or "memory": how the process list is sorted.
    property string sortBy: "cpu"
    // Only the essentials (CPU, memory, GPU, temperatures): the small detached window.
    property bool compact: false
    readonly property var d: SysStats.data
    readonly property var procs: (sortBy === "memory" ? d?.processesByMemory : d?.processes) ?? []

    function pct(used, total) {
        return total > 0 ? used / total : 0;
    }
    function tempColor(c) {
        return c >= 85 ? Theme.danger : c >= 70 ? Theme.accent : Theme.foreground;
    }

    spacing: 14

    // ——— CPU: total, one bar per core, model, frequency, load, processes and threads ———
    Column {
        width: parent.width
        spacing: 6

        TitleRow {
            title: "CPU"
            value: `${Math.round(root.d?.cpu.percent ?? 0)}%`
            strong: true
        }
        Meter {
            value: (root.d?.cpu.percent ?? 0) / 100
        }
        // Logical processors: two rows of bars, each with its number and load.
        Grid {
            id: coreGrid
            visible: !root.compact
            readonly property int n: root.d?.cpu.cores.length ?? 0
            width: parent.width
            columns: Math.max(1, Math.ceil(n / 2))
            spacing: 4
            Repeater {
                model: root.d?.cpu.cores ?? []
                Rectangle {
                    required property var modelData
                    required property int index
                    width: (coreGrid.width - coreGrid.spacing * (coreGrid.columns - 1)) / coreGrid.columns
                    height: 44
                    radius: 6
                    color: Qt.alpha(Theme.foreground, 0.07)
                    clip: true
                    Rectangle {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        height: Math.max(3, parent.height * modelData / 100)
                        color: modelData > 90 ? Theme.danger : Qt.alpha(Theme.accent, 0.85)
                        Behavior on height {
                            NumberAnimation {
                                duration: Animations.duration(300)
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                    Label {
                        anchors.top: parent.top
                        anchors.topMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: String(index)
                        color: Theme.faint
                        font.pixelSize: Appearance.fontSize - 4
                    }
                    Label {
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: `${Math.round(modelData)}`
                        color: modelData > 45 ? Theme.accentContent : Theme.foreground
                        font.pixelSize: Appearance.fontSize - 3
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
        Small {
            text: [root.d?.cpu.model ?? "", root.d ? `${(root.d.cpu.freq / 1000).toFixed(2)} GHz` : ""].filter(x => x).join("  ·  ")
        }
        Small {
            text: root.d ? `Load ${root.d.cpu.load.map(x => x.toFixed(2)).join(" / ")}  ·  ${root.d.counts.processes} processes, ${root.d.counts.threads} threads` : ""
        }
    }

    // ——— Memory: apps / cache / free in one bar, then swap ———
    Column {
        width: parent.width
        spacing: 6

        TitleRow {
            title: "Memory"
            value: root.d ? `${SysStats.bytes(root.d.memory.used)} / ${SysStats.bytes(root.d.memory.total)}` : ""
        }
        Rectangle {
            width: parent.width
            height: 8
            radius: 4
            color: Qt.alpha(Theme.foreground, 0.08)
            clip: true
            Row {
                anchors.fill: parent
                Rectangle {
                    width: parent.width * root.pct(root.d?.memory.apps ?? 0, root.d?.memory.total ?? 0)
                    height: parent.height
                    color: Theme.accent
                }
                Rectangle {
                    width: parent.width * root.pct(root.d?.memory.cache ?? 0, root.d?.memory.total ?? 0)
                    height: parent.height
                    color: Qt.alpha(Theme.accent, 0.4)
                }
            }
        }
        Flow {
            width: parent.width
            spacing: 12
            Repeater {
                model: root.d ? [
                    {
                        k: "Apps",
                        v: root.d.memory.apps,
                        c: Theme.accent
                    },
                    {
                        k: "Cache",
                        v: root.d.memory.cache,
                        c: Qt.alpha(Theme.accent, 0.4)
                    },
                    {
                        k: "Free",
                        v: root.d.memory.free,
                        c: Qt.alpha(Theme.foreground, 0.12)
                    },
                    {
                        k: "Available",
                        v: root.d.memory.available,
                        c: "transparent"
                    }
                ] : []
                Row {
                    required property var modelData
                    spacing: 5
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 4
                        color: modelData.c
                        border.width: modelData.c === "transparent" ? 1 : 0
                        border.color: Theme.faint
                    }
                    Small {
                        text: `${modelData.k} ${SysStats.bytes(modelData.v)}`
                    }
                }
            }
        }
        Small {
            visible: (root.d?.memory.swapTotal ?? 0) > 0
            text: root.d ? `Swap ${SysStats.bytes(root.d.memory.swapUsed)} / ${SysStats.bytes(root.d.memory.swapTotal)}  ·  Shared ${SysStats.bytes(root.d.memory.shared)}` : ""
        }
    }

    // ——— GPU ———
    Column {
        visible: !!root.d?.gpu
        width: parent.width
        spacing: 6
        TitleRow {
            title: "GPU"
            value: root.d?.gpu ? `${root.d.gpu.percent}%` + (root.d.gpu.vramTotal > 0 ? `  ·  VRAM ${SysStats.bytes(root.d.gpu.vramUsed)} / ${SysStats.bytes(root.d.gpu.vramTotal)}` : "") : ""
        }
        Meter {
            value: (root.d?.gpu?.percent ?? 0) / 100
        }
    }

    // ——— Temperatures: a chip per sensor ———
    Column {
        visible: (root.d?.temps ?? []).length > 0
        width: parent.width
        spacing: 6
        TitleRow {
            title: "Temperatures"
        }
        Flow {
            width: parent.width
            spacing: 6
            Repeater {
                model: root.d?.temps ?? []
                Rectangle {
                    required property var modelData
                    width: tempRow.implicitWidth + 20
                    height: 30
                    radius: 15
                    color: Qt.alpha(Theme.foreground, 0.05)
                    border.width: 1
                    border.color: Theme.border
                    Row {
                        id: tempRow
                        anchors.centerIn: parent
                        spacing: 6
                        Label {
                            text: modelData.name
                            color: Theme.dim
                            font.pixelSize: Appearance.fontSize - 1
                        }
                        Label {
                            text: `${Math.round(modelData.celsius)}°C`
                            color: root.tempColor(modelData.celsius)
                            font.weight: Font.DemiBold
                            font.pixelSize: Appearance.fontSize - 1
                        }
                    }
                }
            }
        }
    }

    // ——— Storage ———
    Column {
        visible: !root.compact && (root.d?.disks ?? []).length > 0
        width: parent.width
        spacing: 6
        TitleRow {
            title: "Storage"
        }
        Repeater {
            model: root.d?.disks ?? []
            Column {
                required property var modelData
                width: parent.width
                spacing: 4
                TitleRow {
                    title: modelData.mount
                    value: `${SysStats.bytes(modelData.used)} / ${SysStats.bytes(modelData.total)}  ·  ${SysStats.bytes(modelData.total - modelData.used)} free`
                    small: true
                }
                Meter {
                    value: root.pct(modelData.used, modelData.total)
                }
            }
        }
    }

    // ——— Network, disk activity, power, uptime ———
    Flow {
        visible: !root.compact
        width: parent.width
        spacing: 6
        Repeater {
            model: root.d ? [
                {
                    k: "Download",
                    v: `${SysStats.bytes(root.d.net.rx)}/s`
                },
                {
                    k: "Upload",
                    v: `${SysStats.bytes(root.d.net.tx)}/s`
                },
                {
                    k: "Disk read",
                    v: `${SysStats.bytes(root.d.diskio.read)}/s`
                },
                {
                    k: "Disk write",
                    v: `${SysStats.bytes(root.d.diskio.write)}/s`
                }
            ].concat(root.d.power ? [
                    {
                        k: "Battery draw",
                        v: `${root.d.power} W`
                    }
                ] : []).concat([
                {
                    k: "Up",
                    v: SysInfo.uptime
                }
            ]) : []
            Rectangle {
                required property var modelData
                width: (parent.width - 6) / 2
                height: 44
                radius: 14
                color: Qt.alpha(Theme.foreground, 0.05)
                border.width: 1
                border.color: Theme.border
                Column {
                    anchors.left: parent.left
                    anchors.leftMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    Small {
                        text: modelData.k
                    }
                    Label {
                        text: modelData.v
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }

    // ——— Processes: the ten busiest, by CPU or by memory ———
    Column {
        visible: !root.compact && root.procs.length > 0
        width: parent.width
        spacing: 4

        Item {
            width: parent.width
            height: 28
            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: "Processes"
                font.weight: Font.DemiBold
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Repeater {
                    model: [
                        {
                            v: "cpu",
                            l: "CPU"
                        },
                        {
                            v: "memory",
                            l: "Memory"
                        }
                    ]
                    Rectangle {
                        id: sortChip
                        required property var modelData
                        readonly property bool chosen: root.sortBy === modelData.v
                        width: sortLabel.implicitWidth + 18
                        height: 24
                        radius: 12
                        color: chosen ? Theme.accent : sortMouse.containsMouse ? Theme.hover : "transparent"
                        border.width: chosen ? 0 : 1
                        border.color: Theme.border
                        Label {
                            id: sortLabel
                            anchors.centerIn: parent
                            text: sortChip.modelData.l
                            color: sortChip.chosen ? Theme.accentContent : Theme.foreground
                            font.pixelSize: Appearance.fontSize - 2
                        }
                        MouseArea {
                            id: sortMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.sortBy = sortChip.modelData.v
                        }
                    }
                }
            }
        }

        // Column titles.
        Row {
            width: parent.width
            Small {
                width: parent.width - 196
                text: "Name"
            }
            Small {
                width: 56
                horizontalAlignment: Text.AlignRight
                text: "PID"
            }
            Small {
                width: 60
                horizontalAlignment: Text.AlignRight
                text: "CPU"
            }
            Small {
                width: 80
                horizontalAlignment: Text.AlignRight
                text: "Memory"
            }
        }

        Repeater {
            model: root.procs
            Row {
                required property var modelData
                width: parent.width
                Label {
                    width: parent.width - 196
                    text: modelData.threads > 1 ? `${modelData.name}  ·  ${modelData.threads}` : modelData.name
                    font.pixelSize: Appearance.fontSize - 1
                }
                Label {
                    width: 56
                    horizontalAlignment: Text.AlignRight
                    text: String(modelData.pid)
                    color: Theme.faint
                    font.pixelSize: Appearance.fontSize - 2
                }
                Label {
                    width: 60
                    horizontalAlignment: Text.AlignRight
                    text: `${modelData.cpu.toFixed(1)}%`
                    font.weight: root.sortBy === "cpu" ? Font.DemiBold : Font.Normal
                    font.pixelSize: Appearance.fontSize - 1
                }
                Label {
                    width: 80
                    horizontalAlignment: Text.AlignRight
                    text: SysStats.bytes(modelData.memory)
                    color: root.sortBy === "memory" ? Theme.foreground : Theme.dim
                    font.weight: root.sortBy === "memory" ? Font.DemiBold : Font.Normal
                    font.pixelSize: Appearance.fontSize - 1
                }
            }
        }
        Small {
            text: "Name  ·  threads"
            color: Theme.faint
        }
    }

    // Title on the left, value on the right.
    component TitleRow: Item {
        property string title: ""
        property string value: ""
        property bool strong: false
        property bool small: false
        width: parent ? parent.width : 0
        height: Math.max(titleLabel.implicitHeight, valueLabel.implicitHeight)
        Label {
            id: titleLabel
            anchors.left: parent.left
            anchors.right: valueLabel.left
            anchors.rightMargin: 8
            text: parent.title
            font.weight: parent.small ? Font.Normal : Font.DemiBold
            font.pixelSize: parent.small ? Appearance.fontSize - 1 : Appearance.fontSize
        }
        Label {
            id: valueLabel
            anchors.right: parent.right
            text: parent.value
            color: parent.strong ? Theme.foreground : Theme.dim
            font.weight: parent.strong ? Font.DemiBold : Font.Normal
            font.pixelSize: parent.small ? Appearance.fontSize - 1 : Appearance.fontSize
        }
    }

    // Secondary line.
    component Small: Label {
        color: Theme.dim
        font.pixelSize: Appearance.fontSize - 2
    }

    // A thin rounded level bar.
    component Meter: Rectangle {
        property real value: 0
        width: parent ? parent.width : 0
        height: 8
        radius: 4
        color: Qt.alpha(Theme.foreground, 0.08)
        Rectangle {
            width: Math.max(parent.height, parent.width * Math.max(0, Math.min(1, parent.value)))
            height: parent.height
            radius: 4
            color: parent.value > 0.9 ? Theme.danger : Theme.accent
            Behavior on width {
                NumberAnimation {
                    duration: Animations.duration(300)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
