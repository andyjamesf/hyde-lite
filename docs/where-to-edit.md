# Where to edit each bar

All paths are relative to `Configs/.config/quickshell/` in this repository. Once installed they live
under `~/.config/quickshell/`.

| Bar | File | What you edit there |
|---|---|---|
| **Minimal bar** | `bar/modules/minibar/model/MiniBarConfig.qml` | Everything: position, style, height, `batteryShowTime`, and the list of layouts (with a commented template of every module). |
| **Normal bar (HyDE)** | `bar/config/layouts.json` | The layouts and the modules in each zone. |
| | `bar/services/Config.qml` | Each module's options (for example `widgets.battery.showTime`) and the commented catalogue of modules. |
| | `~/.config/quickshell/layouts.json` | Your own layouts, merged over the shipped ones by name (not tracked in this repository). |
| **Island** | `island/config/StatusPillConfig.qml` | The icons on the right and `batteryTime`. |
| | `island/config/Expanded.qml` | The shortcut buttons and icons of the expanded island. |
| | `island/config/Pill.qml` | The clock pill. |

`island/config/` has one file per area; `island/config/README.md` says what each one controls.

## Repository copy vs installed copy

The files in the repository are the ones git tracks. Editing only the installed copy under
`~/.config/quickshell/` keeps the change on that machine. `tools/sync_shell.py` copies the repository
to the installed location.
