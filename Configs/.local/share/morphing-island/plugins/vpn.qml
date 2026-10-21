import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.components
import qs.island.config
import qs.island.services
import qs.island.theme

// VPN: state and switch, for the VPN and WireGuard connections NetworkManager knows about.
//
// The first plugin, and the proof that one file is enough: there is no mention of "vpn" anywhere in
// the shell's own files except its place in StatusPillConfig.icons, which only says where in the
// row it sits. Everything else it is -- whether it shows, its hint, its icon, what a click does --
// is here.
//
// With no VPN configured the icon stays out of the row entirely rather than sitting there greyed
// out: a switch for something that does not exist is not worth the space.
IslandPlugin {
    id: root

    name: "vpn"

    // [{ name, up }] for every VPN and WireGuard connection, in nmcli's order.
    property var connections: []
    readonly property var up: root.connections.find(c => c.up) ?? null
    property bool busy: false

    available: root.connections.length > 0

    hint: {
        if (root.connections.length === 0)
            return "";
        if (root.busy)
            return "VPN\nWorking…";
        if (root.up)
            return `VPN\n${root.up.name}, connected`;
        return root.connections.length === 1 ? `VPN\n${root.connections[0].name}, off` : `VPN\noff, ${root.connections.length} to choose from`;
    }

    // Left click toggles the one that is up, or the first one when none is. With more than one
    // configured and none up, the control centre's network page is the place to choose between
    // them: a status icon is a switch, not a menu.
    onActivate: button => {
        if (root.busy || root.connections.length === 0)
            return;
        const target = root.up ?? root.connections[0];
        root.busy = true;
        switcher.command = ["nmcli", "connection", root.up ? "down" : "up", "id", target.name];
        switcher.running = true;
    }

    onStarted: reader.running = true

    icon: Component {
        Text {
            text: root.up ? "\u{F0582}" : "\u{F0583}"
            color: root.busy ? Theme.dim : root.up ? Theme.accent : Theme.icon
            font.family: Appearance.nerdFont
            font.pixelSize: Math.round(Pill.height * Expanded.statusIconFactor * 0.95)

            Behavior on color {
                ColorAnimation {
                    duration: Animations.duration(160)
                }
            }
        }
    }

    // nmcli's terse output is NAME:TYPE:STATE. A name may contain an escaped colon, while the type
    // and the state never contain one, so the last two fields are taken from the right and whatever
    // is left is the name.
    function parse(text) {
        const out = [];
        for (const line of text.split("\n")) {
            if (line === "")
                continue;
            const parts = line.split(":");
            if (parts.length < 3)
                continue;
            const state = parts.pop();
            const type = parts.pop();
            if (type !== "vpn" && type !== "wireguard")
                continue;
            out.push({
                "name": parts.join(":").replace(/\\:/g, ":"),
                "up": state === "activated"
            });
        }
        root.connections = out;
    }

    property Process reader: Process {
        command: ["nmcli", "-t", "-f", "NAME,TYPE,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
        onExited: code => {
            root.busy = false;
            if (code !== 0)
                Errors.reportExit("vpn", code, "nmcli");
        }
    }

    property Process switcher: Process {
        onExited: code => {
            if (code !== 0)
                Errors.report("vpn", `the connection could not be switched (nmcli exit ${code})`);
            reader.running = true;
        }
    }

    // NetworkManager has no cheap signal to watch from here, so the state is re-read on a slow
    // timer. A VPN going up or down is not something that has to be noticed within a second.
    property Timer poll: Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: if (!root.busy)
            reader.running = true
    }
}
