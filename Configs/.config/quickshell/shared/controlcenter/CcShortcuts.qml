pragma Singleton
import QtQuick
import Quickshell

// The row of shortcut buttons under the control centre, as data — the companion to CcToggles, and
// the other half of "both shells offer the same things".
//
// They were written twice: the bar had six buttons inline in its panel, the island five driven by
// its own Shortcuts service, and the two rows had drifted apart in which buttons they had and in
// what they were called.
//
// What a view needs per entry:
//   id       what run() takes, and what a view keys its own glyph on
//   label    the tooltip (bar) or the hint under the pointer (island)
//   icon     Material Symbols name, for the views that draw with them
//   glyph    Nerd Font character, for the views that draw with those
//   pick     the picker it opens, if it opens one
//
// A button nobody can answer is left out rather than drawn dead: these three used to run HyDE's
// rofi scripts and, with no rofi installed, sat there looking alive and did nothing. Which ones
// those are depends on the shell, though — the island opens its own wallpaper page where the bar
// opens a picker — so each shell names what it cannot do in `hidden`, and the list does the rest.
//
// Opening a picker or the keybindings list is the launcher's business and each shell drives its
// own, so this asks with `openRequested` the way the HyDE menu picker does.
Singleton {
    id: root

    // A shell's own button (the bar's bar-layout one, which has nothing to cycle in the island).
    property var extra: []

    // Ids this shell cannot offer, named by it. Not a picker check: a shell that answers
    // openRequested its own way keeps the button.
    property var hidden: []

    // Open the launcher: "pick:<name>" for a picker, "keys" for the keybindings list.
    signal openRequested(string what)

    readonly property var items: [
        {
            id: "nextwallpaper",
            label: "Next wallpaper",
            icon: "skip_next",
            glyph: "\u{F04AD}"
        },
        {
            id: "wallpaper",
            pick: "wallpapers",
            label: "Choose wallpaper",
            icon: "image",
            glyph: "\u{F02E9}"
        },
        {
            id: "hydetheme",
            pick: "themes",
            label: "Choose theme",
            icon: "palette",
            glyph: "\u{F03D8}"
        },
        {
            id: "animations",
            pick: "animations",
            label: "Animations",
            icon: "animation",
            glyph: "\u{F05D8}"
        },
        {
            id: "keybindings",
            label: "Keybindings",
            icon: "keyboard",
            glyph: "\u{F030C}"
        }
    ]

    readonly property var shown: items.filter(s => !root.hidden.includes(s.id)).concat(extra)

    function get(id) {
        return shown.find(s => s.id === id) ?? null;
    }

    function run(id: string): void {
        switch (id) {
        case "nextwallpaper":
            Quickshell.execDetached(["hyde-shell", "wallpaper", "--next"]);
            return;
        case "wallpaper":
            openRequested("pick:wallpapers");
            return;
        case "hydetheme":
            openRequested("pick:themes");
            return;
        case "animations":
            openRequested("pick:animations");
            return;
        case "keybindings":
            openRequested("keys");
            return;
        default:
            const own = extra.find(s => s.id === id);
            if (own && own.run)
                own.run();
        }
    }
}
