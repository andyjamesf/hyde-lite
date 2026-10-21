pragma Singleton
import QtQuick
import Quickshell

// Input behaviour shared by all views (launcher, pickers, power menu, settings, themes…).
Singleton {
    // Mouse guard: when a view opens (or grows) under a still cursor, the compositor sends synthetic
    // motion events. Motion is ignored for this long after the view opens. Milliseconds, 0–2000,
    // default 300.
    readonly property int mouseGuardMs: 300
    // …and afterwards only movements larger than this (on either axis) count as real movement.
    // Pixels, 0–20, default 3.
    readonly property int mouseGuardPx: 3
    // The window's keyboard focus arrives a moment after a view opens (and the island reclaims it
    // when the mode changes): views call forceActiveFocus() again after this delay.
    // Milliseconds, 0–500, default 30.
    readonly property int focusRetryMs: 30
}
