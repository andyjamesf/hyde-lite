# Configuration

Every tunable of the island lives in this folder, **one file per area**. Each file is a QML
singleton (`pragma Singleton`, used as `import qs.island.config`), and every property has a comment with
what it does, its unit, a sensible range and the default.

## Files

| File | Controls |
|---|---|
| `Appearance.qml` | fonts: UI font, base font size, Nerd Font / icon font, monospace font |
| `Animations.qml` | animations on/off, global speed, spring stiffness, mode cross-fade and scale timings, `duration(ms)` helper |
| `Behaviour.qml` | mouse guard (ignore fake motion for 300 ms / 3 px after a view opens), focus retry delay |
| `Pill.qml` | the collapsed clock pill: height, minimum width, top margin, padding, hover-to-expand and its collapse delay, hidden pill, equalizer bars |
| `Expanded.qml` | the expanded island: side zone width, gutters, margins, extra height, status icons and their order, shortcut buttons that fill free space, media zone sizes |
| `Clock.qml` | time / short date / long date formats and the locale |
| `WorkspacesConfig.qml` | workspace pill (left edge or next to the clock) and its part of the expanded island: on/off, placement, margins, spacing, icons per workspace, one icon per app, icon size, per-screen or all workspaces |
| `CalendarConfig.qml` | calendar: width, first day of the week, events per day, refresh interval, colours for new calendars, new events' default length and reminder choices (the calendars themselves are in `~/.local/share/quickshell/calendars.json`, outside git) |
| `StatusPillConfig.qml` | status pill (right edge or next to the clock): on/off, placement, margins, which icons and in what order, battery percentage and time left |
| `OsdConfig.qml` | volume / microphone / brightness OSD: timeout, size, bar thickness, mic OSD on/off, startup arm delay, hypridle dimming threshold, brightness step |
| `NotificationsConfig.qml` | notification history size, popup timeouts, queue gap, peace mode rules, HyDE filters, popup layout (widths, radius, padding, avatar, actions, line counts) |
| `ControlCenter.qml` | control center: width, radius, padding, page slide, **tiles and their order** (incl. Caffeine), list row heights, slider throttle, Bluetooth discovery time, night light temperature |
| `MediaConfig.qml` | media card: art size, card radius, padding, position refresh, ignored MPRIS players |
| `ThemeConfig.qml` | default palette, island opacity, border and shadow strength, WCAG contrast targets, theme transition |
| `WallpapersConfig.qml` | wallpaper folders (with `{theme}`, `{pictures}`, `{hydeConfig}` placeholders), extensions, minimum size, polling |
| `LockScreenConfig.qml` | lock card size/padding/radius/offset, clock and avatar size, avatar path, password field size, blur and veil, PAM service, error and release timings |
| `LoginScreenConfig.qml` | login screen (SDDM theme in `sddm/`): keep it in sync with the island, how often the wallpaper is checked. Install: `island login install` |
| `Power.qml` | power menu actions (id, label, glyph, command, confirm), confirm timeout, tile size |
| `PolkitConfig.qml` | polkit dialog: attempts per request, failure notice time, arm delay |
| `SettingsScreen.qml` | Settings screen: size, slider ranges, save debounce, which keys "Reset to defaults" removes |
| `Launcher.qml`, `PickersConfig.qml` | the launcher and its pickers (documented in those files) |

Files whose area has a service or view with the same name carry a `Config` suffix
(`OsdConfig` vs `components/Osd.qml`, `NotificationsConfig` vs `services/Notifications.qml`, …):
QML cannot tell two singletons with the same name apart when a file imports both folders.

## Live reload

The island runs as `morphing-island.service` and Quickshell watches its files: saving any file here
reloads the shell within a second, keeping the lock screen and notifications. A typo makes the
reload fail and the previous configuration keeps running; check the log with

```sh
journalctl --user -u morphing-island.service --since -2min
```

Write files atomically (save to a temporary file, then rename) so a half-written file is never
loaded.

## Settings overrides (prefs.json)

Values chosen in the Settings screen are stored in `~/.local/state/morphing-island/prefs.json` and
override the file; Reset removes the overrides. The same file keeps a few toggles set from the
control center or IPC. It is a flat JSON object; a missing key means "use the config file":

| Key | Overrides | Set from |
|---|---|---|
| `pill.height` | `Pill.height` | Settings → Bar height |
| `appearance.fontSize` | `Appearance.fontSize` | Settings → Font size |
| `theme.name` | `ThemeConfig.defaultTheme` | Settings → Theme, theme picker |
| `theme.scheme` | matugen scheme of the Wallpaper palette (default `scheme-tonal-spot`) | the palette picker (`pick palette`), `wallpaper-palette set` |
| `pill.hoverExpand` | `Pill.hoverExpand` | Settings → Expand on hover |
| `notifications.peaceMode` | peace mode (default off) | Settings, control center tile, `island ipc peace` |
| `animations.enabled` | `Animations.enabled` | Settings → Animations |
| `animations.speed` | `Animations.speed` | Settings → Speed |
| `pill.hidden` | `Pill.hidden` | `Super+,` / `island ipc hide` |
| `idle.caffeine` | Caffeine (default off) | control center tile, `island ipc caffeine` |
| `pill.topMargin` | `Pill.topMargin` (0–24) | Settings → Top margin |
| `clock.hour12` | 12-hour time in `Clock.timeFormat` | Settings → 12-hour clock |
| `statusPill.enabled`, `statusPill.nearClock` | `StatusPillConfig.enabled`, `.placement` | Settings → Status pill |
| `statusPill.icons` | `StatusPillConfig.icons` (a list of ids) | Settings → Icons → Status |
| `expanded.extraButtons` | `Expanded.extraButtons` (a list of ids) | Settings → Icons → Shortcuts |
| `pills.extra` | extra pills beside the clock, see [`docs/island-builder.md`](../../../../../docs/island-builder.md) | Settings → Extra pills |

The file is watched, so editing it by hand also applies live. Files written by older versions (flat
keys such as `barHeight`, `theme`) are migrated automatically on load.

`qs ipc call island-debug prefs` prints the current overrides.

## Examples

Show the pill a bit lower and keep the expanded island open longer after the pointer leaves
(`Pill.qml`):

```qml
readonly property int topMargin: 10
readonly property int hoverCollapseDelay: 600
```

Drop the Bluetooth icon and put the battery first in the expanded island (`Expanded.qml`):

```qml
readonly property var statusIcons: ["battery", "volume", "wifi"]
```

Reorder the control center tiles and remove Night Light (`ControlCenter.qml`):

```qml
readonly property var tiles: ["wifi", "bluetooth", "sound", "caffeine", "peace"]
```

12-hour clock with US names (`Clock.qml`):

```qml
readonly property string timeFormat: "h:mm AP"
readonly property string locale: "en_US"
```

Add a hibernate tile to the power menu (`Power.qml`, inside `actions`):

```qml
{
    id: "hibernate",
    label: "Hibernate",
    glyph: "suspend",
    command: ["systemctl", "hibernate"],
    confirm: true
}
```

Keep notification popups longer and let critical ones respect peace mode
(`NotificationsConfig.qml`):

```qml
readonly property int normalTimeout: 8000
readonly property bool criticalBypassesPeace: false
```

## Adding a palette

Palettes live in `theme/Palettes.qml` (the only file with hand-written colours). Append an entry to
`list`, in the section of its kind:

```qml
{
    name: "My Theme",
    kind: "dark",            // "dark", "light" or "eink"
    background: "#101218",
    surface: "#1a1d26",
    foreground: "#e8eaf0",
    accent: "#ff9e64",
    danger: "#ff5c5c"        // optional
}
```

Only the base roles are needed: `theme/Theme.qml` derives the rest (dim/faint text, borders,
shadows, hover and pressed states) and nudges text and accent towards black or white until they
reach the contrast targets in `ThemeConfig.qml`. The new palette shows up in Settings → Theme right
away; pick it there (or set `defaultTheme` in `ThemeConfig.qml`).

## Keybindings

Keys are not an island setting: they are Hyprland binds, configured in `~/.config/hypr/keybinds.lua`
(one documented table: shell binds routed to the active shell, plain binds, and removed HyDE binds).
