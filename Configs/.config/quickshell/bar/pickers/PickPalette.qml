pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colour palette picker: which Material You scheme matugen derives from the current wallpaper
// (`wallpaper-palette`, ~/.local/bin). One wallpaper gives ten palettes -- muted, vivid, close to the
// image, greys -- and the same wallpaper can be dark or light.
//
// Every row shows the colours that scheme actually gives THIS wallpaper (surface, primary, secondary,
// tertiary) as its icon, so the choice is made by looking. The swatches are cached per wallpaper:
// the first opening after a wallpaper change takes about a second and a half, later ones are instant.
//
// Rows: the schemes, then Dark / Light / Auto for the mode. Choosing one writes the island's prefs
// (theme.scheme, theme.mode), regenerates the palette and has HyDE rebuild its templates from it.
Singleton {
    id: root

    readonly property string name: "palette"
    readonly property string title: "Wallpaper palette"
    readonly property string placeholder: "Search palettes…"
    readonly property string glyph: "󰏘"
    readonly property bool loading: _loading && _schemes.length === 0
    readonly property bool grid: false
    readonly property bool keepOpen: false

    readonly property var modes: [
        {
            key: "mode:dark",
            id: "dark",
            title: "Dark",
            subtitle: "Always dark, whatever the wallpaper",
            glyph: "󰖔"
        },
        {
            key: "mode:light",
            id: "light",
            title: "Light",
            subtitle: "Always light, whatever the wallpaper",
            glyph: "󰖙"
        },
        {
            key: "mode:auto",
            id: "auto",
            title: "Auto",
            subtitle: "Dark or light, whichever suits the wallpaper",
            glyph: "󰔎"
        }
    ]

    // [{ id, title, subtitle, icon }]
    property var _schemes: []
    property string _scheme: ""
    property string _mode: "auto"
    property bool _loading: false
    property bool _again: false

    function refresh() {
        if (reader.running) {
            // A read is already running: repeat it at the end, the wallpaper may have changed.
            _again = true;
            return;
        }
        _loading = true;
        reader.running = true;
    }

    function items(query) {
        const q = String(query ?? "").trim().toLowerCase();
        const rows = [];
        for (const s of _schemes)
            rows.push({
                key: s.id,
                title: s.title,
                subtitle: s.subtitle,
                icon: s.icon,
                text: "",
                glyph: s.icon === "" ? root.glyph : "",
                badge: s.id === _scheme ? "Current" : ""
            });
        for (const m of modes)
            rows.push({
                key: m.key,
                title: `Mode: ${m.title}`,
                subtitle: m.subtitle,
                icon: "",
                text: "",
                glyph: m.glyph,
                badge: m.id === _mode ? "Current" : ""
            });
        if (q === "")
            return rows;
        return rows.filter(r => `${r.title} ${r.subtitle}`.toLowerCase().includes(q));
    }

    function activate(item) {
        if (!item || !item.key)
            return;
        const isMode = item.key.startsWith("mode:");
        const scheme = isMode ? _scheme : item.key;
        const mode = isMode ? item.key.slice(5) : _mode;
        if (scheme === "")
            return;
        // Optimistic: the next refresh() confirms it.
        _scheme = scheme;
        _mode = mode;
        // Regenerating runs matugen and rebuilds HyDE's templates, a few seconds: it goes through
        // Launch.run (its own unit) so it finishes even if the shell restarts.
        Launch.run(["sh", "-c", 'if r=$(wallpaper-palette set "$1" "$2" 2>&1); then notify-send -a "HyDE Alert" "󰏘 Palette" "$r"; else notify-send -a "HyDE Alert" -u critical "Palette failed" "$r"; fi', "sh", scheme, mode]);
    }

    function _parse(text) {
        const list = [];
        for (const line of text.split("\n")) {
            const f = line.split("\t");
            if (f[0] === "@@CURRENT@@") {
                _scheme = f[1] ?? "";
                _mode = f[2] ?? "auto";
            } else if (f.length >= 3 && f[0] !== "") {
                list.push({
                    id: f[0],
                    title: f[1],
                    subtitle: f[2],
                    icon: f[3] ? "file://" + f[3] : ""
                });
            }
        }
        // Keep what we had when a read comes back empty (no wallpaper yet, matugen missing).
        if (list.length > 0)
            _schemes = list;
        _loading = false;
    }

    Process {
        id: reader
        command: ["wallpaper-palette", "preview"]
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
        onRunningChanged: {
            if (!running && root._again) {
                root._again = false;
                root.refresh();
            }
        }
    }
}
