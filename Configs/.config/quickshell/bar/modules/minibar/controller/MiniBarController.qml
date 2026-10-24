pragma Singleton
import QtQuick
import Quickshell
import qs.bar.modules.minibar.model

// The commands behind the "minibar" IPC target. The target itself is declared in bar/Shell.qml,
// where every target of this shell lives so that `qs ipc show` lists them in one place; those
// functions are one line each and call into here, so the behaviour has a single home and the view
// never writes the state itself.
Singleton {
    id: root

    function toggle(): void {
        setSwitchedOn(!MiniBarState.switchedOn);
    }

    function show(): void {
        setSwitchedOn(true);
    }

    function hide(): void {
        setSwitchedOn(false);
    }

    // The one place the stored choice changes.
    function setSwitchedOn(on: bool): void {
        if (!MiniBarConfig.enabled) {
            console.warn('minibar: switched off in modules/minibar/model/MiniBarConfig.qml ("enabled")');
            return;
        }
        if (MiniBarState.switchedOn === on)
            return;
        MiniBarState.switchedOn = on;
        MiniBarState.save();
    }

    // Which bar is in use, for `qs ipc call minibar status`.
    function status(): string {
        if (!MiniBarConfig.enabled)
            return 'off (disabled in modules/minibar/model/MiniBarConfig.qml: "enabled")';
        return MiniBarState.switchedOn ? "minimal bar" : "main bar";
    }
}
