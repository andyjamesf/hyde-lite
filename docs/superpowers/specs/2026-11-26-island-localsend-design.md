# LocalSend in the Morphing Island

Approved by the owner on 2026-11-26.

## Intent

The owner wants LocalSend in all three bars `$mod+SHIFT+I` cycles through. The HyDE bar and the minimal bar
already have the widget; the island has nothing, and nothing in it references the `LocalSend` singleton, so the
background receiver is not started by it.

## Goals

- A `localsend` status icon, usable in the status pill, the expanded island and the extra pills.
- A click opens a Control Center page: answer pending requests (accept, accept and pair, decline), pick a nearby
  device, send a file, see recent activity.
- The page comes back after the file picker closes it.

## Non-goals

- No changes to the receiver protocol or to `third-party/localsend-cli`.
- No `quickSave` setting, no new IPC target, no key binding.
- `install.sh` does not start building `localsend-cli`.

## Constraints

- Reuse `shared/services/LocalSend.qml`; the bar keeps working as it does today.
- `tools/qml-lint.sh` counts must not grow compared with `main`.

## Approaches

1. **A Control Center page, like Bluetooth (picked).** Follows the island's own pattern; more code than an icon.
2. Icon only. Small, but a request from an unpaired device could not be answered and times out after 60 s.
3. Reuse the bar's `LocalSendPanel`. It is built from the bar's components and theme, which the island does not load.

## Left to the builder

The page's layout (following `CcBluetoothPage.qml`), the icon, the hint text.
