pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Runs a shell command without waiting for it (like Waybar's on-click).
    function run(cmd) {
        Quickshell.execDetached(["sh", "-c", cmd]);
    }

    // HyDE's scripts produce Pango markup; Qt's StyledText only knows <font color>.
    // `mapColor` (optional) adjusts each embedded color (e.g. to get contrast with the background).
    function pango(s, mapColor) {
        if (!s)
            return "";
        return String(s).replace(/<span([^>]*)>/g, (_, attrs) => {
            const c = /(?:foreground|fgcolor|color)=['"]([^'"]+)['"]/.exec(attrs);
            return c ? `<font color="${mapColor ? mapColor(c[1]) : c[1]}">` : "<font>";
        }).replace(/<\/span>/g, "</font>").replace(/ {2,}/g, m => "&nbsp;".repeat(m.length)).replace(/\n/g, "<br>");
    }

    // Date/time formatted in the config.json language (the system locale may be English).
    function formatDate(date, format) {
        return date.toLocaleString(Qt.locale(Config.appearance.locale), format);
    }

    function dayName(day, format) {
        return Qt.locale(Config.appearance.locale).dayName(day, format);
    }

    // Picks an element from a list ordered by level (0..100), like Waybar does with format-icons.
    function level(list, percent) {
        return list[Math.max(0, Math.min(list.length - 1, Math.floor(percent * list.length / 101)))];
    }

    // "now", "5 min ago", "2 h ago", or the time/date for older things.
    function relativeTime(date) {
        const s = (Date.now() - date.getTime()) / 1000;
        if (s < 60)
            return "now";
        if (s < 3600)
            return `${Math.floor(s / 60)} min ago`;
        if (s < 6 * 3600)
            return `${Math.floor(s / 3600)} h ago`;
        const today = new Date();
        return date.toDateString() === today.toDateString() ? formatDate(date, "HH:mm") : formatDate(date, "d MMM, HH:mm");
    }

    function formatDuration(seconds) {
        const h = Math.floor(seconds / 3600);
        const m = Math.floor(seconds % 3600 / 60);
        return h > 0 ? `${h} h ${m} min` : `${m} min`;
    }

    function formatBytes(bytes) {
        const units = ["B", "KB", "MB", "GB"];
        let i = 0;
        while (bytes >= 1024 && i < units.length - 1) {
            bytes /= 1024;
            i++;
        }
        return `${bytes.toFixed(i > 1 ? 1 : 0)} ${units[i]}`;
    }
}
