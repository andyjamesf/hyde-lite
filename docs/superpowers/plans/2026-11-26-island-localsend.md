# LocalSend in the Morphing Island: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan
> task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** a `localsend` status icon in the island that opens a Control Center page.

**Architecture:** the page is one more Control Center subview, like Bluetooth, over the unchanged
`shared/services/LocalSend.qml` protocol.

**Spec:** `docs/superpowers/specs/2026-11-26-island-localsend-design.md`

## Global Constraints

- The id is `localsend` in the island (its ids are lowercase and the tests rely on it).
- `tools/qml-lint.sh` counts must not grow compared with `main`.
- No new property in `island/config/`: the installer preserves that folder, so an existing machine may keep
  old files, and the new code must work with them.
- Commit only when the owner asks.

## Review Focus

- The file picker closes the island: the page returns, with the picked path filled in.
- The picker leaves the island open: reopening must not toggle it closed.
- `localsend-cli` missing: the page says so and a click retries.
- A request that expires while the page is open disappears from the list.
- Long device names and paths elide.

---

### Task 1: Icon, mode and page

**Files:**
- Create: `island/components/CcLocalSendPage.qml`, `tools/tests/test_island_localsend.py`
- Modify (under `Configs/.config/quickshell/island`): `core/IslandState.qml`, `components/ControlCenterView.qml`,
  `components/StatusZone.qml`, `services/Shortcuts.qml`, `Shell.qml`, `config/SettingsScreen.qml`,
  `config/StatusPillConfig.qml`, `config/Expanded.qml`, `README.md`
- Modify: `shared/services/LocalSend.qml` (comment on `pickSource` only)

**Interfaces:**
- Consumes: `LocalSend.pending/devices/history/selectedTarget/pickedPath/sendBusy/lastSendError`,
  `answer(sessionId, decision)`, `sendFiles(target, paths)`, `browseFile(source)`, `restart()`,
  signal `filePicked(path)`.
- Produces: `IslandState.localsend: "localsend"`, `CcLocalSendPage { signal releaseFocus }`.

- [x] **Step 1:** write the wiring tests; run them and see them fail.
- [x] **Step 2:** register the mode, the loader, the icon, the hint, the click and the Settings choice.
- [x] **Step 3:** write the page; pass `pickSource` `"island"` and reopen from `Shell.qml` only when
  `IslandController.mode !== IslandState.localsend`.
- [x] **Step 4:** run `bash tools/check.sh`; compare `tools/qml-lint.sh` with `main`.
- [x] **Step 5:** deploy, switch to the island, look at the icon and the page, switch back.
