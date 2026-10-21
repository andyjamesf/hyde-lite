import QtQuick
import Quickshell.Io

// Reads a command that speaks the JSON protocol of Waybar "custom" modules ({text, tooltip, class, alt}),
// one line at a time. Used to reuse HyDE's scripts and the user's own (AI usage, cava).
// With interval 0 the command is a continuous stream and is restarted if it exits; otherwise it runs every interval ms.
Item {
    id: root

    property string exec
    property int interval: 0
    property bool running: true

    property string text
    property string tooltip
    property string cls
    property string alt

    function refresh() {
        proc.running = true;
    }

    function parse(line) {
        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            d = {
                text: line
            };
        }
        text = d.text ?? "";
        tooltip = d.tooltip ?? "";
        cls = Array.isArray(d.class) ? d.class.join(" ") : (d.class ?? "");
        alt = d.alt ?? "";
    }

    Process {
        id: proc
        command: ["sh", "-c", root.exec]
        running: root.running && root.exec !== ""
        stdout: SplitParser {
            onRead: line => root.parse(line)
        }
        onExited: if (root.interval === 0 && root.running)
            restart.start()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: proc.running = true
    }

    Timer {
        interval: root.interval
        running: root.running && root.interval > 0
        repeat: true
        onTriggered: proc.running = true
    }
}
