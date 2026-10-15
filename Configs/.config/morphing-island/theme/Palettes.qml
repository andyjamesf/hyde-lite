pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The island's colour schemes (palettes). Each one defines only the base roles; Theme derives the
// rest (and guarantees the minimum contrast). kind: "dark" | "light" | "eink" (e-ink has no
// shadows, transparency nor gradients). This is the only file with hand-written colours.
//
// Adding a palette: append an entry to `list` below, in its kind's section:
//   { name: "My Theme", kind: "dark", background: "#101010", surface: "#1a1a1a",
//     foreground: "#eeeeee", accent: "#ff8800", danger: "#ff5555" /* optional */ }
// It shows up in Settings → Theme right away (live reload).
//
// There are two dynamic schemes, always first in the list, that update by themselves:
//  - "Wallpaper": colours of the current wallpaper. If ~/.cache/wallust/colors.json exists (a
//    wallust template in pywal's format: { special: { background, foreground }, colors: { color0…15 } }),
//    it takes priority; otherwise ~/.cache/hyde/wall.dcol is used, which HyDE's wallbash rewrites on
//    every wallpaper change (dcol_pry1 dominant, dcol_txt1 text, dcol_1xa1…9 shades, dcol_4xa7
//    accent, dcol_mode dark/light).
//  - "HyDE": the bar colours of the current HyDE theme (~/.config/waybar/theme.css, @define-color
//    main-bg, main-fg, wb-act-bg…), which HyDE rewrites on every theme change.
// While the source does not exist, the dynamic scheme uses the colours of the first fixed scheme
// and is marked unavailable (available: false).
Singleton {
    id: root

    readonly property color black: "#000000"
    readonly property color white: "#ffffff"
    // Default error red (a scheme may bring its own in `danger`).
    readonly property color dangerDark: "#ff6b6b"
    readonly property color dangerLight: "#c62828"

    readonly property var list: [
        // --- Dark ---
        {
            name: "Midnight",
            kind: "dark",
            background: "#14151c",
            surface: "#1e2029",
            foreground: "#e6e8f0",
            accent: "#8ab4ff"
        },
        {
            name: "Fjord",
            kind: "dark",
            background: "#2b303b",
            surface: "#353b48",
            foreground: "#e5e9f0",
            accent: "#88c0d0"
        },
        {
            name: "Vampire",
            kind: "dark",
            background: "#1e1f29",
            surface: "#282a36",
            foreground: "#f8f8f2",
            accent: "#bd93f9",
            danger: "#ff5555"
        },
        {
            name: "Ember",
            kind: "dark",
            background: "#1d2021",
            surface: "#282828",
            foreground: "#ebdbb2",
            accent: "#fe8019",
            danger: "#fb4934"
        },
        {
            name: "Mocha",
            kind: "dark",
            background: "#181825",
            surface: "#1e1e2e",
            foreground: "#cdd6f4",
            accent: "#cba6f7",
            danger: "#f38ba8"
        },
        {
            name: "Neon Tokyo",
            kind: "dark",
            background: "#16161e",
            surface: "#1f2335",
            foreground: "#c0caf5",
            accent: "#7aa2f7",
            danger: "#f7768e"
        },
        {
            name: "Rosewood",
            kind: "dark",
            background: "#191724",
            surface: "#1f1d2e",
            foreground: "#e0def4",
            accent: "#ebbcba",
            danger: "#eb6f92"
        },
        {
            name: "Forest",
            kind: "dark",
            background: "#232a2e",
            surface: "#2d353b",
            foreground: "#d3c6aa",
            accent: "#a7c080",
            danger: "#e67e80"
        },
        {
            name: "Ocean",
            kind: "dark",
            background: "#0b1622",
            surface: "#13233a",
            foreground: "#d6e6f5",
            accent: "#4fc3f7"
        },
        {
            name: "Graphite",
            kind: "dark",
            background: "#161616",
            surface: "#222222",
            foreground: "#e4e4e4",
            accent: "#a3b8cc"
        },
        // --- Light ---
        {
            name: "Paper",
            kind: "light",
            background: "#f7f6f2",
            surface: "#ecebe6",
            foreground: "#1f1f1f",
            accent: "#3a6df0"
        },
        {
            name: "Latte",
            kind: "light",
            background: "#eff1f5",
            surface: "#e6e9ef",
            foreground: "#4c4f69",
            accent: "#8839ef",
            danger: "#d20f39"
        },
        {
            name: "Sakura",
            kind: "light",
            background: "#fdf2f4",
            surface: "#f7e1e6",
            foreground: "#3d2930",
            accent: "#d6557a"
        },
        {
            name: "Sand",
            kind: "light",
            background: "#f4ecd8",
            surface: "#eadfc4",
            foreground: "#3b3226",
            accent: "#b5651d"
        },
        {
            name: "Mint",
            kind: "light",
            background: "#eef8f3",
            surface: "#dcefe5",
            foreground: "#1f3a2e",
            accent: "#1f9d6b"
        },
        {
            name: "Sky",
            kind: "light",
            background: "#eef5fc",
            surface: "#dde9f7",
            foreground: "#1b2b40",
            accent: "#2b7de9"
        },
        // --- E-ink (black and white only) ---
        {
            name: "E-Ink",
            kind: "eink",
            background: "#ffffff",
            surface: "#ffffff",
            foreground: "#000000",
            accent: "#000000"
        },
        {
            name: "E-Ink Dark",
            kind: "eink",
            background: "#000000",
            surface: "#000000",
            foreground: "#ffffff",
            accent: "#ffffff"
        }
    ]

    // Colours read from the dynamic sources ({ kind, background, surface, foreground, accent } or null).
    property var matugen: null
    property var wallust: null
    property var wallbash: null
    property var hyde: null
    // Raw text of the last wall.dcol that was parsed, so the re-reads of `settle` below only
    // publish a real change (one cross-fade per wallpaper, not one per read).
    property string _dcolText: ""
    readonly property var wallpaper: matugen ?? wallust ?? wallbash
    // Source of the "Wallpaper" scheme ("matugen", "wallust", "wallbash" or "" if none exists).
    readonly property string wallpaperSource: matugen ? "matugen" : wallust ? "wallust" : wallbash ? "wallbash" : ""

    // Names of the dynamic schemes (fixed: the picker builds its grid from names only).
    readonly property var dynamicNames: ["Wallpaper", "HyDE"]
    readonly property var dynamicList: [entry(dynamicNames[0], wallpaper), entry(dynamicNames[1], hyde)]
    // All schemes in picker order: dynamic, dark, light, e-ink.
    readonly property var all: dynamicList.concat(list)

    function find(name) {
        return all.find(p => p.name === name) ?? list[0];
    }

    function entry(name, src) {
        const base = src ?? list[0];
        return {
            name: name,
            kind: base.kind,
            background: base.background,
            surface: base.surface,
            foreground: base.foreground,
            accent: base.accent,
            // Only matugen gives one, and it is worth keeping: a red derived with the rest of the
            // scheme instead of the fixed one. undefined here means Theme falls back, as before.
            danger: base.danger,
            dynamic: true,
            available: !!src
        };
    }

    // --- Colour utilities (only to interpret the dynamic sources) ---------------------------------

    function blend(a, b, t) {
        a = Qt.color(a);
        b = Qt.color(b);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // Approximate lightness (enough to decide whether a background is light or dark).
    function lightness(c) {
        c = Qt.color(c);
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    // Approximate saturation (difference between the strongest and weakest channel).
    function chroma(c) {
        c = Qt.color(c);
        return Math.max(c.r, c.g, c.b) - Math.min(c.r, c.g, c.b);
    }

    // Qt does not understand "rgba(r, g, b, a)" with 0..255 components; converted here.
    function cssColor(v) {
        const m = /^rgba?\(([^)]*)\)$/.exec(String(v).trim());
        if (!m)
            return Qt.color(String(v).trim());
        const p = m[1].split(",").map(s => parseFloat(s));
        return Qt.rgba(p[0] / 255, p[1] / 255, p[2] / 255, p.length > 3 ? p[3] : 1);
    }

    // Colour with transparency applied over the background: the colour actually seen.
    function flatten(c, over) {
        c = Qt.color(c);
        return c.a >= 0.99 ? Qt.rgba(c.r, c.g, c.b, 1) : blend(over, Qt.rgba(c.r, c.g, c.b, 1), c.a);
    }

    // Among several colours, the most saturated (a good accent candidate).
    function mostChromatic(colors) {
        return colors.reduce((best, c) => chroma(c) > chroma(best) ? c : best, colors[0]);
    }

    function fromCss(css) {
        const bg = flatten(cssColor(css["main-bg"]), black);
        const fg = flatten(cssColor(css["main-fg"] ?? white), bg);
        const cands = ["wb-act-bg", "wb-hvr-bg", "wb-act-fg", "wb-hvr-fg"].filter(k => css[k] !== undefined).map(k => flatten(cssColor(css[k]), bg));
        // The theme's accent is wb-act-bg; if it is almost grey, the most vivid bar colour is used.
        let accent = cands.length ? cands[0] : fg;
        if (chroma(accent) < 0.12 && cands.length > 1)
            accent = mostChromatic(cands);
        return {
            kind: lightness(bg) < 0.5 ? "dark" : "light",
            background: bg,
            surface: blend(bg, fg, 0.07),
            foreground: fg,
            accent: accent
        };
    }

    function fromDcol(p) {
        const bg = Qt.color(p.pry1);
        const dark = p.mode === "light" ? false : p.mode === "dark" ? true : lightness(bg) < 0.5;
        const fg = Qt.color(p.txt1 ?? (dark ? white : black));
        return {
            kind: dark ? "dark" : "light",
            background: bg,
            // A slight elevation of the background, keeping the palette's own hue (1xa1), like the
            // 0.07 the other two sources use. It used to be a half-way blend, which on wallpapers
            // whose 1xa1 is near-white (HyDE's light dcols) pushed the surface past the text colour:
            // everything drawn on a surface — fields, chips, tiles, the login screen's password
            // pill — then had foreground and faint text landing on top of their own background.
            surface: p["1xa1"] ? blend(bg, p["1xa1"], 0.12) : blend(bg, fg, 0.07),
            foreground: fg,
            accent: Qt.color(p["4xa7"] ?? p["1xa7"] ?? p.txt1 ?? (dark ? white : black))
        };
    }

    // Matugen's JSON → the five roles. Material You names a lot of colours; these are the ones that
    // mean the same thing here:
    //
    //   background         the desktop behind everything
    //   surface_container  a card on top of it -- `surface` equals `background` in this scheme, so
    //                      using it would make the island invisible against the desktop
    //   on_background      what is legible on that background, by construction
    //   primary            the accent the whole scheme is built around
    //   error              red, already harmonised with the rest instead of a fixed red
    function fromMatugen(j) {
        const c = j?.colors;
        if (!c)
            return null;
        // What the image is, unless ThemeConfig says otherwise. Matugen generates both polarities
        // of every role, so forcing one costs nothing and needs no second run.
        const auto = j.is_dark_mode ? "dark" : "light";
        const mode = ThemeConfig.mode === "dark" || ThemeConfig.mode === "light" ? ThemeConfig.mode : auto;
        const pick = role => c[role]?.[mode]?.color;
        const bg = pick("background");
        if (!bg)
            return null;
        return {
            kind: mode,
            background: bg,
            surface: pick("surface_container") ?? bg,
            foreground: pick("on_background") ?? root.white,
            accent: pick("primary") ?? root.white,
            danger: pick("error")
        };
    }

    function fromWallust(j) {
        const s = j.special ?? {};
        const c = j.colors ?? {};
        const bg = Qt.color(s.background ?? c.color0);
        const fg = Qt.color(s.foreground ?? c.color15 ?? c.color7 ?? (lightness(bg) < 0.5 ? white : black));
        const cands = ["color1", "color2", "color3", "color4", "color5", "color6"].filter(k => c[k]).map(k => Qt.color(c[k]));
        return {
            kind: lightness(bg) < 0.5 ? "dark" : "light",
            background: bg,
            surface: blend(bg, fg, 0.07),
            foreground: fg,
            accent: cands.length ? mostChromatic(cands) : fg
        };
    }

    readonly property string cacheDir: Paths.cacheHome
    readonly property string configDir: Paths.configHome

    // Format: dcol_pry1="23162D", dcol_1xa1="402952", dcol_mode="dark"…
    //
    // wall.dcol is a symlink to ~/.cache/hyde/dcols/<sha1 of the wallpaper>.dcol, and on a wallpaper
    // change HyDE only re-points it: the dcol files themselves are a per-wallpaper cache, written
    // once and never touched again. inotify follows the link, so the watch stays on the previous
    // wallpaper's file and onFileChanged never arrives — without `settle` below, the "Wallpaper"
    // scheme would keep the colours it had when the shell started.
    FileView {
        id: dcolFile
        path: `${root.cacheDir}/hyde/wall.dcol`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            const src = text();
            if (src === root._dcolText)
                return;
            root._dcolText = src;
            const p = {};
            const re = /^dcol_(mode|pry\d|txt\d|\dxa\d)="([^"]*)"/gm;
            let m;
            while ((m = re.exec(src)) !== null)
                p[m[1]] = m[1] === "mode" ? m[2] : `#${m[2]}`;
            root.wallbash = p.pry1 ? root.fromDcol(p) : null;
        }
        onLoadFailed: {
            root._dcolText = "";
            root.wallbash = null;
        }
    }

    // HyDE renders the wallbash templates first and re-points wall.dcol about a second later, so the
    // link is still the old one when theme.css below changes. Every template change therefore starts
    // a short burst of re-reads, which stops by itself once the link has moved (6 s at most, and
    // nothing runs in between).
    Timer {
        id: settle
        interval: 300
        repeat: true
        property int tries: 0
        onTriggered: {
            dcolFile.reload();
            if (++tries >= 20)
                stop();
        }
    }

    // Re-reads the wallpaper palette after a HyDE change (see `settle`).
    function reloadWallpaper() {
        settle.tries = 0;
        settle.restart();
        matugenRun.running = true;
    }

    // --- Matugen ---------------------------------------------------------------------------------
    // Material You from the wallpaper: one seed colour out of the image, then a whole tonal system
    // derived from it. The other two sources extract the colours that happen to be in the picture,
    // which on a grey wallpaper gives a grey accent; this derives one instead.
    //
    // It writes its templates too (~/.config/matugen/config.toml), which is how kitty and anything
    // added there get the same colours as the island from the same run -- the two can never drift
    // apart on one wallpaper. `reload_apps = false` in that config keeps matugen from going off and
    // restarting other programs; each template says for itself how to be picked up. `--prefer
    // saturation`
    // is needed because matugen asks which colour to seed from when the image offers several, and
    // with no terminal to ask it stops; the most saturated candidate is the one worth an accent.
    //
    // Written through a temporary file so the watch below never reads half a JSON.
    //
    // wallbash-matugen then hands the same palette to HyDE, which is what colours kitty's sixteen
    // ANSI colours, the Qt and KDE programs through kdeglobals, rofi, waybar and the rest: one file
    // rewritten instead of a template per program. It does nothing when the palette has not moved,
    // which matters because rebuilding HyDE's templates touches files this shell watches.
    readonly property string matugenPath: `${root.cacheDir}/morphing-island/matugen.json`

    Process {
        id: matugenRun
        running: true
        // The watch below cannot follow a file that does not exist yet, which is the state on a
        // first run, so the read is asked for here instead of waited for.
        onExited: matugenFile.reload()
        // wallpaper-palette (~/.local/bin) is the one place the matugen command lives: it applies the
        // scheme and mode chosen in the palette picker, so a new wallpaper keeps the choice instead of
        // going back to the default. It writes matugen.json (read below) and hands the palette to HyDE.
        // The old direct call stays as the fallback for a machine that has not pulled it yet.
        command: ["sh", "-c", 'if command -v wallpaper-palette >/dev/null 2>&1; then wallpaper-palette apply >/dev/null 2>&1; exit 0; fi\n' + 'command -v matugen >/dev/null 2>&1 || exit 0\n' + 'w=$(readlink -f -- "$1") || exit 0\n' + '[ -f "$w" ] || exit 0\n' + 'mkdir -p -- "$(dirname -- "$2")"\n' + 'matugen --json hex --prefer saturation image "$w" > "$2.tmp" && mv -- "$2.tmp" "$2"\n' + 'command -v wallbash-matugen >/dev/null 2>&1 && wallbash-matugen >/dev/null 2>&1 || true\n', "sh", `${root.cacheDir}/hyde/wall.set`, root.matugenPath]
    }

    FileView {
        id: matugenFile
        path: root.matugenPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.matugen = root.fromMatugen(JSON.parse(text()));
            } catch (e) {
                root.matugen = null;
            }
        }
        onLoadFailed: root.matugen = null
    }

    // Optional: only exists if wallust is installed with a colors.json template.
    FileView {
        path: `${root.cacheDir}/wallust/colors.json`
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const j = JSON.parse(text());
                root.wallust = (j.special?.background || j.colors?.color0) ? root.fromWallust(j) : null;
            } catch (e) {
                // File half-written: the previous value stays until the next notification.
            }
        }
        onLoadFailed: root.wallust = null
    }

    // Bar colours of the HyDE theme (@define-color name value;). HyDE rewrites this one in place on
    // every theme *and* wallpaper change, so it is also what tells the wallpaper palette to re-read.
    FileView {
        path: `${root.configDir}/waybar/theme.css`
        watchChanges: true
        printErrors: false
        onFileChanged: {
            reload();
            root.reloadWallpaper();
        }
        onLoaded: {
            const out = {};
            const re = /@define-color\s+([\w-]+)\s+([^;]+);/g;
            const css = text().replace(/\/\*[\s\S]*?\*\//g, "");
            let m;
            while ((m = re.exec(css)) !== null) {
                const v = m[2].trim();
                const value = v.startsWith("@") ? out[v.slice(1)] : v;
                if (value !== undefined)
                    out[m[1]] = value;
            }
            root.hyde = out["main-bg"] ? root.fromCss(out) : null;
        }
        onLoadFailed: root.hyde = null
    }
}
