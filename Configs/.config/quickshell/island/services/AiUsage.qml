pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.island.config

// AI usage (config/AiUsageConfig.qml): one ai-usage-watch stream per tool, always running so the
// icon's colour stays current. Each reading keeps the short value, the script's class, and the
// windows parsed from its tooltip (5-hour, 7-day, monthly, credits…) with how full they are and
// when they reset; the AI popup (components/AiUsageView.qml) shows them. refresh() asks every
// stream (or one) for fresh numbers at once (SIGUSR1).
Singleton {
    id: root

    // name → { text, cls, glyph, color, windows: [{ label, percent, detail, reset }], notes: [],
    //          updated: Date }.
    property var states: ({})
    // At least one tool answered: the icon shows only then.
    readonly property bool available: Object.values(states).some(s => s.text !== "")
    // The fullest window of any tool, 0..100 (-1 = none known).
    readonly property real highest: Object.values(states).reduce((m, s) => Math.max(m, ...s.windows.map(w => w.percent)), -1)
    // "high" | "mid" | "low": from the fullest window (≥ 90 % / ≥ 70 %) and the scripts' classes.
    readonly property string worst: {
        const classes = Object.values(states).map(s => s.cls);
        if (highest >= 90 || classes.some(c => c.includes("critical") || c.endsWith("-high")))
            return "high";
        if (highest >= 70 || classes.some(c => c.endsWith("-mid")))
            return "mid";
        return "low";
    }
    // One line per tool, e.g. "Claude   61% · 3h06m" (the hint).
    readonly property string summary: AiUsageConfig.agents.map(a => {
        const s = states[a.name];
        return `${a.label}   ${s && s.text !== "" ? s.text : "…"}`;
    }).join("\n")

    // Fresh numbers for every tool, or only `name`.
    function refresh(name) {
        const who = name ? `${name} ` : "";
        Quickshell.execDetached(["pkill", "-USR1", "-f", `[a]i-usage-watch ${who}`]);
    }

    // The scripts write "<span …>icon</span> value <span …>icon</span> value": keep the values.
    // Markup and icons (Nerd Font glyphs, symbols with no letter or digit) are dropped.
    function plain(markup) {
        return Array.from(String(markup).replace(/<[^>]*>/g, " ")).filter(ch => {
            const c = ch.codePointAt(0);
            return !((c >= 0xE000 && c <= 0xF8FF) || c >= 0xF0000);
        }).join("").trim().split(/\s+/).filter(x => /[A-Za-z0-9]/.test(x)).join(" · ");
    }

    // The tool's own icon and colour: the first <span foreground='#…'>glyph</span>.
    function brand(markup) {
        const m = /<span([^>]*)>([^<]*)<\/span>/.exec(String(markup));
        if (!m)
            return {
                glyph: "",
                color: ""
            };
        const c = /(?:foreground|fgcolor|color)=['"]([^'"]+)['"]/.exec(m[1]);
        return {
            glyph: m[2].trim(),
            color: c ? c[1] : ""
        };
    }

    // Tooltip → windows and notes. Rows like "5-Hour   30%   1h34m" or "Monthly  0%  29d23h";
    // Copilot's "Used: 93.2 / 200 (47%)" + "Reset: 2026-10-01". Headers, rules and "Click to…"
    // lines are skipped; lines in brackets become notes.
    function parseTooltip(text) {
        const windows = [], notes = [];
        let credits = null;
        for (const raw of String(text).split("\n")) {
            const line = raw.trim();
            if (line === "" || /^[━─=-]+$/.test(line) || /^click/i.test(line) || /^window\s+used/i.test(line))
                continue;
            let m = /^(.+?)\s+(\d+(?:\.\d+)?)%\s+(\S+)$/.exec(line);
            if (m) {
                windows.push({
                    label: m[1].trim(),
                    percent: parseFloat(m[2]),
                    detail: "",
                    reset: m[3]
                });
                continue;
            }
            m = /^Used:\s*(.+?)\s*\((\d+(?:\.\d+)?)%\)/i.exec(line);
            if (m) {
                credits = {
                    label: "Credits",
                    percent: parseFloat(m[2]),
                    detail: m[1],
                    reset: ""
                };
                windows.push(credits);
                continue;
            }
            m = /^Reset:\s*(.+)$/i.exec(line);
            if (m && credits) {
                credits.reset = m[1];
                continue;
            }
            if (/^\(.*\)$/.test(line))
                notes.push(line.slice(1, -1));
        }
        return {
            windows: windows,
            notes: notes
        };
    }

    function _set(name, line) {
        let d;
        try {
            d = JSON.parse(line);
        } catch (e) {
            return;
        }
        const cls = Array.isArray(d.class) ? d.class.join(" ") : (d.class ?? "");
        const prev = states[name];
        const parsed = parseTooltip(d.tooltip ?? "");
        const b = brand(d.text ?? "");
        const s = Object.assign({}, states);
        s[name] = {
            text: plain(d.text ?? ""),
            cls: cls,
            glyph: b.glyph || prev?.glyph || "",
            color: b.color || prev?.color || "",
            // While syncing, the last numbers stay on show.
            windows: cls === "syncing" && prev ? prev.windows : parsed.windows,
            notes: parsed.notes,
            updated: cls === "syncing" && prev ? prev.updated : new Date()
        };
        states = s;
    }

    // `cmd` as config/AiUsageConfig.qml gives it: a list is the argv, a plain string is split on
    // whitespace, which is what the old `sh -c "... -- ${cmd}"` line did implicitly. Building the
    // argv here instead means no shell at all: nothing to quote, and one process less per agent.
    // ai-usage-watch takes the command as `argv[4:]`, so it wants the words separate anyway.
    function _argv(cmd) {
        if (cmd === undefined || cmd === null)
            return [];
        if (typeof cmd === "string")
            return cmd.trim().split(/\s+/).filter(a => a !== "");
        // A list reaching a `var` model property arrives as a QVariantList: array-like, but
        // Array.isArray() says false for it, and String() would glue it with commas.
        if (typeof cmd.length === "number")
            return Array.prototype.map.call(cmd, String);
        return [String(cmd)];
    }

    Instantiator {
        model: AiUsageConfig.agents

        Process {
            required property var modelData
            command: ["ai-usage-watch", String(modelData.name), String(modelData.period), "--"].concat(root._argv(modelData.cmd))
            running: true
            stdout: SplitParser {
                onRead: line => root._set(modelData.name, line)
            }
        }
    }
}
