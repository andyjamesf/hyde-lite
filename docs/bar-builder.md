# Bar builder: design

Status: **proposal for the owner to review. No code is written until it is approved** (PLAN 3.1).

Scope: the HyDE-style bar in `Configs/.config/quickshell/bar/`. The Morphing Island is one pill that
expands and has no layouts, so it is not touched here (open question 1).

## What exists today

A *layout* (the code calls it a preset) is an object in `config/layouts.json`, keyed by name. Seven ship:
`islands`, `minimal`, `compact`, `floating`, `productivity`, `media`, `bottom`.
`services/BarLayout.qml` reads the file (and re-reads it when it changes), picks the current layout
(IPC/menu choice in `Prefs`, else `bar.layout` in `config.json`, else the first one) and exposes its fields.
`modules/bar/Bar.qml` draws three sections; each section is a list of islands (pills); each island is a list
of widget ids; `services/BarWidgets.qml` maps an id to `widgets/<Name>Widget.qml` (`modules/bar/WidgetLoader.qml` loads it).

So the data model the builder needs is already the one in use: **zones -> groups -> widgets**. The builder
adds a way to write, validate and edit it, not a new model.

## Layout schema

```jsonc
{
  "<name>": {
    "label": "Islands",                // shown in menus
    "description": "…",                // optional
    "style": "islands",                // "islands" (one pill per group) | "continuous" (one strip)
    "position": "top",                 // "top" | "bottom"; optional, else config.json bar.position
    "height": 23,                      // px, 16..40
    "margin": 4,                       // px around the bar, islands style only
    "spacing": 4,                      // px between pills; optional
    "radius": 10,                      // optional, else Hyprland's decoration:rounding
    "opacity": 0.85,                   // optional, else config.json bar.opacity
    "pillStyle": "glass",              // optional; a name from BarLayout.pillStyles or "#rrggbb[aa]"
    "fontSize": 13, "iconSize": 15,    // optional, else derived from height
    "left":   [["hyde"], ["workspaces"]],   // list of groups; a group is a list of widget ids
    "center": [["clock"]],
    "right":  [["tray"], ["audio", "network", "battery"]]
  }
}
```

Rules the validator will enforce (PLAN 3.2): `style`, `position`, ranges as above; `left/center/right` are
arrays of non-empty arrays of strings; every id is in the catalogue; unknown keys are an error, so a typo does
not silently do nothing; a widget id may appear once per layout (some widgets register an IPC name from their
id, see below). A group whose widgets all hide themselves (for example `battery` on a desktop) disappears,
which `Island.qml` already does; the validator does not treat that as an error.

Not in the schema on purpose: per-widget options. They stay in `config.json` under `widgets.<id>` (clock
format, workspace count, tray hidden list...), because they are preferences, not layout.

## Where layouts live

- Shipped presets: `config/layouts.json` (in this repository, overwritten on update).
- The owner's layouts: a separate file in the user's config (proposal:
  `~/.config/quickshell/layouts.json`), same format, merged over the shipped one by name. A user layout with
  the shipped name replaces it. This keeps edits out of the repository and out of `Prefs`, which
  deliberately never touches `config.json`.
- Which layout is active stays as today: `Prefs.layout` (menu/IPC), else `config.json`.

## Widget catalogue

Ids, from `services/BarWidgets.qml` (20 files, 843 lines in total):

| id | file | what it shows |
|---|---|---|
| hyde | HydeMenu | HyDE menu button |
| workspaces | Workspaces | workspaces with app icons |
| activeWindow | ActiveWindow | title of the focused window |
| clock | Clock | time, optional date, opens the calendar |
| media | Media | now playing |
| cava | Cava | audio visualizer |
| aiUsage | AiUsage | AI tools usage |
| tray | Tray | system tray |
| audio | Audio | volume |
| mic | Mic | microphone |
| brightness | Brightness | screen brightness |
| network | Network | network |
| bluetooth | Bluetooth | bluetooth |
| battery | Battery | battery (hides itself when there is none) |
| stats | Stats | CPU, memory, temperature |
| idle | Idle | idle inhibitor |
| nightLight | NightLight | night light |
| notifications | Notifications | notification centre |
| power | Power | power menu |
| controlCenter | ControlCenter | control centre |

The builder shows this list with the one-line description; the descriptions come from a comment at the top of
each widget file, so there is one place to edit.

## Adding a widget

1. Create `modules/bar/widgets/<Name>Widget.qml`, normally a `BarItem` (icon, text, tooltip, optional popout).
   Optional properties the loader already understands: `shown` (false hides it and its group if it was the only
   visible one), `bar` (the bar window, injected), `ipcName` (the id, injected).
2. Add `"<id>": "<Name>"` to the map in `services/BarWidgets.qml`. The loader, the validator and the editor all read that one map.
3. Options, if any, go under `widgets.<id>` in `services/Config.qml` with their defaults.
4. Nothing else: the validator and the editor read the catalogue, they do not keep their own list. The
   editor shows an id as its camel-case words ("activeWindow" -> "Active window").

## Phases (PLAN 3.2 to 3.5) and what each one costs

- 3.2 Validator in `tools/check.sh`: `Configs/.config/quickshell/bar/scripts/validate_layouts.py` (standard library only; it lives in the shell so the shell can run it too), implementing the
  rules above and reading the widget ids and pill styles from the QML, so there is no JSON Schema file to keep in
  step with it (decision 3: a helper script). No QML. Every shipped layout must pass. Done.
- 3.3 Live reload: the shipped file was already watched. This step adds the owner's file
  (`~/.config/quickshell/layouts.json`), watched too; on every change `BarLayout.qml` runs the validator with
  `Process`, applies the file only if it passes (user layouts replace shipped ones by name), and otherwise keeps
  the previous layouts and sends a critical notification with the first problem. Deleting the file drops the
  user layouts.
- 3.4 In-shell editor (written, **not seen on screen**): `qs ipc call bar edit` opens
  `modules/barbuilder/BarEditor.qml` (Esc or Cancel closes without saving). Click a widget to select it, then: earlier / later
  (at the end of a pill it joins the neighbouring pill), split the pill at it, join the pill with the previous one,
  send it to another zone, remove it; click a widget under "Not in this layout" to add it after the selection (or
  as a new pill in the highlighted zone: click a zone name). Height, islands / one strip and the pill style are
  chips at the top. Save writes the layout, under the current layout's name, to `~/.config/quickshell/layouts.json`
  (shipped names are replaced by it); "Back to shipped" removes the owner's version. The file is validated and
  applied by the live reload of 3.3. Original plan: in-shell editor: a picker (same family as the launcher's `layouts` picker) with the three zones as rows
  of pills; actions: add widget to group, remove, move left/right, split group, merge with next, set height /
  style / opacity, save to the user's file. No drag and drop in the first version.
- 3.5 Presets "Islands" and "Minimal" already exist under those names; this step is only to confirm they stay
  the two documented ones and that the rest are plain data files.

## Open questions for the owner

1. Should the Morphing Island get a layout too, or is the bar builder only for the HyDE-style bar? (Proposal:
   bar only; the island keeps its fixed features, D2.)
2. Per-monitor layouts (a different bar on each screen)? Today there is one layout for all screens. Proposal:
   not now; the schema can add an optional `screens` map later without breaking files.
3. Validation in QML or in a helper script? A helper (`python3`, already a dependency) is one implementation for
   `check.sh` and for live reload, at the cost of a process spawn per reload (a file edit, not a hot path).
   Proposal: helper script.
4. Is the user layouts path above right, or should user layouts live in the user's own dotfiles repository?

## NOT TESTED

This is a design written from reading the code; nothing was run on a screen, and the 843-line count and the
widget list were read from the working tree, not from a running shell.
