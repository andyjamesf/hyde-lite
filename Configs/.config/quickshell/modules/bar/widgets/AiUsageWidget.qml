import QtQuick
import qs.components
import qs.services

// Usage of the AI tools (Claude Code, Codex, Copilot), from the user's scripts
// (~/.local/bin/ai-usage-watch). Stays collapsed behind a button: the icon turns red if any of them
// is close to its limit, the tooltip summarizes all three and a click shows/hides the details
// (the choice is remembered). Clicking one of the details forces a refresh of that one.
Row {
    id: root

    readonly property var agents: [
        {
            name: "claude",
            label: "Claude",
            period: 120,
            cmd: "/usr/bin/claude-usage --waybar --show-5h"
        },
        {
            name: "codex",
            label: "Codex",
            period: 120,
            cmd: "codex-credits"
        },
        {
            name: "copilot",
            label: "Copilot",
            period: 300,
            cmd: "copilot-credits"
        }
    ]
    readonly property bool expanded: Prefs.aiExpanded
    // State of each agent (text without markup, and class), filled by the streams below.
    property var states: ({})
    readonly property bool anyData: Object.values(states).some(s => s.text !== "")
    readonly property string worst: {
        const classes = Object.values(states).map(s => s.cls);
        if (classes.some(c => c.includes("critical") || c.endsWith("-high")))
            return "high";
        if (classes.some(c => c.endsWith("-mid")))
            return "mid";
        return "low";
    }
    property bool shown: anyData

    // A Nerd Font glyph: a Private Use Area code point (BMP or supplementary planes 15-16).
    function isNerdGlyph(ch) {
        const c = ch.codePointAt(0);
        return (c >= 0xE000 && c <= 0xF8FF) || c >= 0xF0000;
    }

    // "<span foreground='#c'>G</span> 61% <span …>G</span> 3h06m" → [{glyph, color, text}, …]:
    // each icon with the value that follows it.
    function parse(markup) {
        const out = [];
        const re = /<span([^>]*)>([^<]*)<\/span>|([^<]+)/g;
        let m;
        while ((m = re.exec(markup || "")) !== null) {
            if (m[3] !== undefined) {
                const t = m[3].trim();
                if (!t)
                    continue;
                if (out.length && out[out.length - 1].text === "")
                    out[out.length - 1].text = t;
                else
                    out.push({
                        glyph: "",
                        color: "",
                        text: t
                    });
            } else {
                const c = /(?:foreground|fgcolor|color)=['"]([^'"]+)['"]/.exec(m[1]);
                // A span may hold the icon and a value together: the errors are
                // "<span …>󰜡 Auth Err</span>". Only the Nerd Font glyphs (Private Use Area) at the start
                // are the icon; the rest is text (in the fixed-width icon box it covered its neighbours).
                const content = m[2].trim();
                const chars = Array.from(content);
                let n = 0;
                while (n < chars.length && root.isNerdGlyph(chars[n]))
                    n++;
                out.push({
                    glyph: chars.slice(0, n).join(""),
                    color: c ? c[1] : "",
                    text: chars.slice(n).join("").trim()
                });
            }
        }
        return out;
    }

    function setState(name, text, cls) {
        const s = Object.assign({}, states);
        s[name] = {
            // Icon and value separated by spaces (stuck together, the glyph covered the number in the tooltip).
            text: root.parse(text).map(g => [g.glyph, g.text].filter(x => x).join("&nbsp;&nbsp;")).join("&nbsp;&nbsp;&nbsp;&nbsp;"),
            cls: cls
        };
        states = s;
    }

    BarItem {
        id: toggle
        height: root.height
        icon: "smart_toy"
        ipcName: "aiUsage"
        iconFill: root.expanded ? 1 : 0
        iconColor: root.worst === "high" ? Theme.error : root.worst === "mid" ? Theme.warning : Theme.primary
        active: root.expanded
        tooltip: root.agents.map(a => `<b>${a.label}</b>&nbsp;&nbsp;${root.states[a.name]?.text || "…"}`).join("\n") + `\n\n${root.expanded ? "Click to collapse" : "Click to expand"}`
        onClicked: {
            Prefs.aiExpanded = !Prefs.aiExpanded;
            Prefs.save();
        }
    }

    Repeater {
        model: root.agents

        BarItem {
            id: item

            required property var modelData
            readonly property string cls: stream.cls

            // The scripts write "<span …>icon</span> value"; the icon (Nerd Font) is drawn
            // separately, in its own box: inside the Inter text, the glyph overlapped the numbers.
            readonly property var segments: root.parse(stream.text)

            shown: root.expanded && stream.text !== ""
            height: root.height
            padding: Math.round(BarLayout.height * 0.3)
            tooltip: stream.tooltip
            opacity: cls === "syncing" ? 0.6 : 1
            textColor: cls.includes("critical") ? Theme.error : cls.endsWith("-low") ? Theme.success : cls.endsWith("-mid") ? Theme.warning : cls.endsWith("-high") ? Theme.error : Theme.text

            onClicked: Utils.run(`pkill -USR1 -f '[a]i-usage-watch ${modelData.name} '`)

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(BarLayout.height * 0.3)

                Repeater {
                    model: item.segments

                    Row {
                        id: seg

                        required property var modelData

                        anchors.verticalCenter: parent.verticalCenter
                        spacing: Math.round(BarLayout.height * 0.22)

                        StyledText {
                            visible: seg.modelData.glyph !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            width: BarLayout.iconSize
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideNone
                            text: seg.modelData.glyph
                            font.family: Config.appearance.monoFont
                            font.pixelSize: Math.round(BarLayout.iconSize * 0.85)
                            color: BarLayout.readable(seg.modelData.color || item.textColor, 3)
                        }

                        StyledText {
                            visible: seg.modelData.text !== ""
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideNone
                            text: seg.modelData.text
                            font.pixelSize: BarLayout.fontSize
                            color: BarLayout.readable(item.textColor, 4.5)
                        }
                    }
                }
            }

            // The streams always run (even when collapsed), so the icon and tooltip stay accurate.
            JsonStream {
                id: stream
                exec: `ai-usage-watch ${item.modelData.name} ${item.modelData.period} -- ${item.modelData.cmd}`
                onTextChanged: root.setState(item.modelData.name, text, cls)
                onClsChanged: root.setState(item.modelData.name, text, cls)
            }
        }
    }
}
