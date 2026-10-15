pragma Singleton
import QtQuick
import Quickshell
import qs.config

// The island's colour roles. No component uses hand-written colours: everything comes from here,
// so the same code serves dark, light and e-ink themes.
//
// The scheme comes from ThemeConfig.name (fixed or dynamic, see Palettes). Before reaching the
// roles it goes through a readability check (APCA): text keeps a lightness contrast
// ≥ ThemeConfig.textLc with the background and the accent ≥ ThemeConfig.accentLc, moving them
// towards black or white as little as needed. Opacity, border, shadow and transition: config/ThemeConfig.qml.
//
// Transition: each role is a mix between the previous colours (fromRoles) and the new ones
// (toRoles), driven by a single `progress`. One animation handles all colours (many Behaviors in
// a singleton crash Qt).
Singleton {
    id: root

    readonly property var palette: Palettes.find(ThemeConfig.name)
    readonly property string kind: palette.kind
    readonly property bool eink: kind === "eink"
    readonly property bool dark: kind === "dark" || (eink && relativeLuminance(palette.background) < 0.5)

    // Final roles of the current scheme (target of the transition).
    readonly property var targetRoles: roles(resolve(palette))

    property var fromRoles: null
    property var toRoles: null
    property real progress: 1
    // In the first moments (preferences still loading) colours change without animation.
    property bool ready: false

    readonly property color background: mix("background")
    readonly property color surface: mix("surface")
    readonly property color foreground: mix("foreground")
    readonly property color accent: mix("accent")
    readonly property color accentContent: mix("accentContent")
    readonly property color dim: mix("dim")
    readonly property color faint: mix("faint")
    readonly property color border: mix("border")
    readonly property color shadow: mix("shadow")
    readonly property color icon: mix("icon")
    readonly property color danger: mix("danger")
    readonly property color hover: mix("hover")
    readonly property color pressed: mix("pressed")
    readonly property real islandOpacity: eink ? 1 : ThemeConfig.islandOpacity

    // Base colours (already readable) of any scheme, without applying it: for the picker swatches.
    // Returns { name, kind, available, background, surface, foreground, accent, accentContent }.
    function preview(name) {
        const p = Palettes.find(name);
        const b = resolve(p);
        b.name = p.name;
        b.available = p.available ?? true;
        b.accentContent = onColor(b.accent);
        return b;
    }

    // Scheme → base colours with the minimum contrast guaranteed.
    function resolve(p) {
        const bg = Qt.color(p.background);
        return {
            kind: p.kind,
            background: bg,
            surface: Qt.color(p.surface),
            foreground: readable(p.foreground, bg, ThemeConfig.textLc),
            accent: readable(p.accent, bg, ThemeConfig.accentLc),
            danger: p.danger ? Qt.color(p.danger) : null
        };
    }

    // Base colours → all roles.
    function roles(b) {
        const eink = b.kind === "eink";
        const dark = b.kind === "dark" || (eink && relativeLuminance(b.background) < 0.5);
        const fg = b.foreground, bg = b.background;
        return {
            background: bg,
            surface: b.surface,
            foreground: fg,
            accent: b.accent,
            accentContent: onColor(b.accent),
            dim: readable(blend(fg, bg, 0.4), bg, ThemeConfig.accentLc),
            faint: blend(fg, bg, 0.62),
            border: eink ? fg : Qt.alpha(fg, dark ? ThemeConfig.borderAlphaDark : ThemeConfig.borderAlphaLight),
            shadow: eink ? Qt.rgba(0, 0, 0, 0) : Qt.rgba(0, 0, 0, dark ? ThemeConfig.shadowAlphaDark : ThemeConfig.shadowAlphaLight),
            icon: fg,
            danger: eink ? fg : readable(b.danger ?? (dark ? Palettes.dangerDark : Palettes.dangerLight), bg, ThemeConfig.accentLc),
            hover: Qt.alpha(fg, eink ? 0.12 : 0.08),
            pressed: Qt.alpha(fg, eink ? 0.2 : 0.14)
        };
    }

    function mix(role) {
        const b = (toRoles ?? targetRoles)[role];
        const a = fromRoles ? fromRoles[role] : b;
        const t = progress;
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
    }

    // New colours: start from the ones on screen now (even midway through another transition). If
    // nothing changed (e.g. the wallpaper changed but the theme is fixed), there is no transition.
    onTargetRolesChanged: {
        const next = targetRoles;
        if (toRoles && Object.keys(next).every(k => Qt.colorEqual(next[k], toRoles[k])))
            return;
        const current = {};
        for (const role in next)
            current[role] = root[role];
        transition.stop();
        fromRoles = current;
        toRoles = next;
        if (Animations.enabled && ready) {
            progress = 0;
            transition.start();
        } else {
            progress = 1;
        }
    }

    NumberAnimation {
        id: transition
        target: root
        property: "progress"
        from: 0
        to: 1
        duration: ThemeConfig.transitionMs
        easing.type: Easing.InOutCubic
    }

    Timer {
        running: true
        interval: 600
        onTriggered: root.ready = true
    }

    // --- Contrast (APCA) --------------------------------------------------------------------------
    //
    // APCA, the WCAG 3 candidate, is the readability metric here instead of WCAG 2's contrast ratio.
    // WCAG 2 is known to misjudge dark themes: the flare term in (L1+0.05)/(L2+0.05) dominates once
    // both colours are dark, so it over-rewards light-on-dark and under-rewards the mid tones. This
    // shell is dark most of the time, which is exactly where that error lives. Measured on the
    // palette this machine was running, WCAG 2 passed `faint` #808285 on #32353a at 3.19:1 where
    // APCA puts it at Lc 29, barely legible, and `danger` #ff6b6b at 4.44:1 where APCA says Lc 43.
    //
    // APCA reports a signed Lc of about -108..106, where the sign is the polarity (positive = dark
    // text on a light background). Only the magnitude matters here, so contrastLc() returns it
    // absolute.

    function blend(a, b, t) {
        a = Qt.color(a);
        b = Qt.color(b);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // APCA 0.1.9 (W3C draft). A fitted set, not free parameters: change one and the Lc scale stops
    // meaning what its thresholds say.
    readonly property var apca: ({
            trc: 2.4,
            rco: 0.2126729,
            gco: 0.7151522,
            bco: 0.0721750,
            normBg: 0.56,
            normTxt: 0.57,
            revBg: 0.65,
            revTxt: 0.62,
            blkThrs: 0.022,
            blkClmp: 1.414,
            scale: 1.14,
            loOffset: 0.027,
            loClip: 0.1,
            deltaYmin: 0.0005
        })

    // Screen luminance for APCA: a plain power curve rather than WCAG's piecewise one, then the soft
    // clamp that stops near-blacks from reading as more contrasty than they are.
    function apcaY(c) {
        c = Qt.color(c);
        const k = root.apca;
        const y = k.rco * Math.pow(c.r, k.trc) + k.gco * Math.pow(c.g, k.trc) + k.bco * Math.pow(c.b, k.trc);
        return y < k.blkThrs ? y + Math.pow(k.blkThrs - y, k.blkClmp) : y;
    }

    // Lightness contrast of `fg` over `bg` as an absolute Lc: 0 is nothing, ~106 is black on white.
    // Not symmetric, unlike the WCAG ratio -- the argument order is the polarity.
    function contrastLc(fg, bg) {
        const k = root.apca;
        const yTxt = root.apcaY(fg), yBg = root.apcaY(bg);
        if (Math.abs(yBg - yTxt) < k.deltaYmin)
            return 0;
        if (yBg > yTxt) {
            const normal = (Math.pow(yBg, k.normBg) - Math.pow(yTxt, k.normTxt)) * k.scale;
            return normal < k.loClip ? 0 : (normal - k.loOffset) * 100;
        }
        const reverse = (Math.pow(yBg, k.revBg) - Math.pow(yTxt, k.revTxt)) * k.scale;
        return reverse > -k.loClip ? 0 : -(reverse + k.loOffset) * 100;
    }

    // Still WCAG 2's luminance, on purpose: `dark` at the top of this file is a lightness test and
    // not a contrast one, and swapping the curve there could flip which palettes count as dark.
    function relativeLuminance(c) {
        c = Qt.color(c);
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // Black or white, whichever reads better on top of `c`.
    function onColor(c) {
        return root.contrastLc(Palettes.black, c) > root.contrastLc(Palettes.white, c) ? Palettes.black : Palettes.white;
    }

    // Returns `fg` if it already has the minimum contrast with `bg`; otherwise moves it towards black
    // or white (whichever contrasts more with the background) until it gets there, keeping the hue.
    function readable(fg, bg, minLc) {
        fg = Qt.color(fg);
        bg = Qt.color(bg);
        const target = minLc ?? ThemeConfig.textLc;
        if (root.contrastLc(fg, bg) >= target)
            return fg;
        const toward = root.onColor(bg);
        for (let t = 0.05; t < 1; t += 0.05) {
            const c = root.blend(fg, toward, t);
            if (root.contrastLc(c, bg) >= target)
                return Qt.rgba(c.r, c.g, c.b, fg.a);
        }
        return Qt.color(toward);
    }
}
