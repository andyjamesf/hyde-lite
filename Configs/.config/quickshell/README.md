# Quickshell configuration

One configuration, started by `qs`, with two UIs. `shell.qml` loads one of them:

| Folder | UI | Chosen when |
|---|---|---|
| `island/` | the Morphing Island: one pill that expands (`island/README.md`) | `~/.local/state/morphing-island/active` exists (`island on`) |
| `bar/` | the HyDE-style bar with islands/pills and 7 layouts (`bar/README.md`) | it does not (`island off`, the default) |

`island on|off|toggle` (`~/.local/bin/island`) writes or removes that file and starts the process again, so only the
UI in use is compiled and instantiated. Singletons outlive a UI, which is why a switch restarts the process instead
of swapping the Loader's source.

`lock.qml` and `sync.qml` are the island's lock screen and login-screen sync run on their own while the bar is the
UI (`island lock`, `island login sync-once`); they live here so that `qs.island.*` resolves for them too.

## Modules

Each UI keeps its own folders (`services/`, `components/`, ...) and imports them as `qs.<ui>.<folder>`, for example
`import qs.island.services` or `import qs.bar.modules.bar`. Quickshell finds a module by following the imports that
start at `shell.qml`, so `shell.qml` imports both UI folders even though it loads only one: a file loaded by URL
does not register the modules it imports.

Paths in the code are relative to the configuration root: `Quickshell.shellPath("island/scripts/sddm.py")`.

## Checks

```sh
tools/qml-lint.sh      # qmllint counts per UI against tools/qml-lint.baseline
tools/check.sh         # everything else, including the unit tests
```
