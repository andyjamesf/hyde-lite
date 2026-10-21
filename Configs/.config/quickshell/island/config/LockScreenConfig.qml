pragma Singleton
import QtQuick
import Quickshell

// Lock screen (ext-session-lock + PAM). (Named LockScreenConfig because core/LockScreen.qml is the
// lock itself.)
Singleton {
    // Width of the password card in pixels. Default 380.
    readonly property int cardWidth: 380
    // Inner padding of the card in pixels. Default 30.
    readonly property int cardPadding: 30
    // Corner radius of the card in pixels. Default 30.
    readonly property int cardRadius: 30
    // Vertical offset of the card from the screen centre, as a fraction of the screen height
    // (negative = up, leaving room for the status pill below). Default -0.04.
    readonly property real cardOffset: -0.04
    // Clock font size on the card in pixels. Default 64.
    readonly property int clockSize: 64
    // Avatar diameter in pixels. Default 76.
    readonly property int avatarSize: 76
    // Avatar image ("~/" is expanded); a missing file shows the user's initial. Default "~/.face".
    readonly property string avatarPath: "~/.face"
    // Password field size in pixels. Defaults 300 × 46.
    readonly property int fieldWidth: 300
    readonly property int fieldHeight: 46

    // Background: blurred wallpaper. Maximum blur radius (MultiEffect.blurMax). Default 64.
    readonly property int blurMax: 64
    // Veil in the theme background colour over the blurred wallpaper (gives the card contrast).
    // Alpha 0–1, default 0.4.
    readonly property real veil: 0.4
    // Blur fade in/out. Milliseconds, default 420.
    readonly property int blurFadeMs: 420

    // How the lock appears: "rise" (the island's clock pill grows into the card, and goes back into
    // the pill on unlock) or "fade" (no pill: the card fades in at the centre and fades out). The
    // island uses "rise"; `island lock` starts the lock-only shell of the bar with ISLAND_LOCK_ENTRY=fade.
    readonly property string entry: Quickshell.env("ISLAND_LOCK_ENTRY") === "fade" ? "fade" : "rise"

    // PAM service (/etc/pam.d/<name>). Default "hyprlock" (same password rules as HyDE's lock).
    readonly property string pamService: "hyprlock"
    // Error messages disappear after this long. Milliseconds, default 3500.
    readonly property int errorMs: 3500
    // After a successful unlock, the lock is released after the exit animation. Milliseconds,
    // default 560 (0 when animations are off).
    readonly property int releaseMs: 560
}
