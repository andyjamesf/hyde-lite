pragma Singleton
import QtQuick
import Quickshell
import qs.island.services

// Colours and surface look. The palettes themselves live in theme/Palettes.qml; the chosen one is
// stored as the Prefs key "theme.name" (Settings → Theme). (Named ThemeConfig because
// theme/Theme.qml computes the colour roles.)
Singleton {
    // Palette used until one is chosen (a name from theme/Palettes.qml, e.g. "Midnight", "Wallpaper",
    // "HyDE"). Default "Midnight".
    readonly property string defaultTheme: "Midnight"
    // Effective palette name (the user's choice, or defaultTheme).
    readonly property string name: Prefs.get("theme.name", defaultTheme)
    // Opacity of the island background (e-ink palettes are always opaque). 0–1, default 0.94.
    readonly property real islandOpacity: 0.94
    // Border alpha over the foreground colour, on dark / light palettes. 0–1, defaults 0.1 / 0.14.
    readonly property real borderAlphaDark: 0.1
    readonly property real borderAlphaLight: 0.14
    // Shadow alpha (black), on dark / light palettes. 0–1, defaults 0.45 / 0.18.
    readonly property real shadowAlphaDark: 0.45
    readonly property real shadowAlphaLight: 0.18
    // Shadow blur (MultiEffect.shadowBlur). 0–1, default 0.7.
    readonly property real shadowBlur: 0.7
    // Shadow vertical offset in pixels. Default 3.
    readonly property real shadowOffsetY: 3
    // Minimum APCA lightness contrast (Lc) of text / accent against the background; colours are
    // nudged towards black or white until they reach it. Range 0-106, defaults 75 / 60.
    //
    // These are Lc, not WCAG ratios. Lc 75 is about WCAG 4.5:1 for body text and Lc 60 about 3:1,
    // which is why the names changed with the units: a leftover `4.5` read as an Lc would be
    // satisfied by almost any pair of colours and would quietly switch the readability pass off.
    // Lower `accentLc` if the danger colour comes out too pale for your taste; Lc 45 is APCA's
    // floor for something that is not body text.
    readonly property real textLc: 75
    readonly property real accentLc: 60
    // Cross-fade between palettes when the theme changes. Milliseconds, default 420.
    readonly property int transitionMs: 420

    // Light or dark for the wallpaper palette. "auto" takes whichever the wallpaper itself is,
    // which is what Material You decides from the image; "dark" and "light" override that. The
    // fixed schemes have a polarity of their own and ignore this.
    readonly property string mode: Prefs.get("theme.mode", "auto")
    readonly property var modes: ["auto", "dark", "light"]

    function setTheme(name) {
        Prefs.set("theme.name", name);
    }

    // Hands the change to `wallpaper-palette mode` (~/.local/bin), which owns it: it writes this
    // (theme.mode, the file Prefs is watching, so the island follows by itself), HyDE's enableWallDcol
    // and the palette in the new polarity, and rebuilds HyDE's templates in the background.
    // Doing it here, as this used to, only moved HyDE's flag and ran theme.switch.sh with the palette
    // still on the old polarity, so HyDE inverted templates that were right, and it took seconds.
    function setMode(m) {
        if (!modes.includes(m))
            return;
        Launch.run(["wallpaper-palette", "mode", m]);
    }

    function cycleMode() {
        setMode(modes[(modes.indexOf(mode) + 1) % modes.length]);
    }
}
