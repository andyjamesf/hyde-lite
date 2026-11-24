pragma Singleton
import QtQuick
import Quickshell

// Colour arithmetic that the bar's and the island's themes both need, in one place. Each theme keeps
// its own `blend()` and `relativeLuminance()` as one-line calls to these, so nothing that uses them
// changes.
Singleton {
    // Linear blend of two colors (t = 0 → a, t = 1 → b), always opaque.
    function blend(a, b, t) {
        a = Qt.color(a);
        b = Qt.color(b);
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // WCAG 2 relative luminance (0 black … 1 white).
    function relativeLuminance(c) {
        c = Qt.color(c);
        const lin = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }
}
