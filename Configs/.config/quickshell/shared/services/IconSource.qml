pragma Singleton
import QtQuick
import Quickshell

// Icon name, absolute path or URL → image source ("" = none). What the launcher's pickers hand to an
// Image: a freedesktop name is looked up in the icon theme.
Singleton {
    function resolve(name) {
        const s = String(name ?? "");
        if (s === "")
            return "";
        if (s.startsWith("/"))
            return "file://" + s;
        if (/^[a-z]+:/.test(s))
            return s;
        return Quickshell.iconPath(s, true) ?? "";
    }
}
