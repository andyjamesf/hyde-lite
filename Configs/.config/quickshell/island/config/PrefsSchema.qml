pragma Singleton
import QtQuick
import Quickshell

// Shape of every key that may appear in prefs.json (the user overrides read by services/Prefs.qml).
//
// That file is hand-editable and watched: a value typed into it applies live, straight into the UI,
// and until this existed nothing checked it. A `pill.height` of 300 or a `"13"` where a number was
// expected went through silently and the shell drew itself wrong with no explanation; a misspelled
// key such as `pill.heigth` was simply ignored, which is the same symptom as the setting not working.
//
// Prefs vets the file against this on every load: a value of the wrong type or outside its range is
// dropped, so the config file's own default applies again, and an unknown key is kept but reported.
// Both go through services/Errors.qml, as one notification naming each key.
//
// `type` is "number", "boolean", "string", "list" (an array of non-empty strings) or "pills" (see below). `min`/`max` are inclusive and only for numbers;
// `integer` rejects a fractional value. The ranges are the ones documented beside each property in
// the config file that reads the key -- keep the two in step.
Singleton {
    readonly property var keys: ({
            // config/Pill.qml
            "pill.height": {
                "type": "number",
                "integer": true,
                "min": 30,
                "max": 51
            },
            "pill.hoverExpand": {
                "type": "boolean"
            },
            "pill.hidden": {
                "type": "boolean"
            },
            "pill.topMargin": {
                "type": "number",
                "integer": true,
                "min": 0,
                "max": 24
            },
            // config/Clock.qml
            "clock.hour12": {
                "type": "boolean"
            },
            // config/StatusPillConfig.qml
            "statusPill.enabled": {
                "type": "boolean"
            },
            "statusPill.nearClock": {
                "type": "boolean"
            },
            // config/Appearance.qml
            "appearance.fontSize": {
                "type": "number",
                "integer": true,
                "min": 11,
                "max": 18
            },
            // config/Animations.qml
            "animations.enabled": {
                "type": "boolean"
            },
            "animations.speed": {
                "type": "number",
                "min": 0.5,
                "max": 2
            },
            // config/ThemeConfig.qml. A palette name from theme/Palettes.qml: checked as a non-empty
            // string rather than against the list, so a palette added later is not rejected here.
            "theme.name": {
                "type": "string",
                "notEmpty": true
            },
            // The matugen scheme of the Wallpaper palette (scheme-vibrant, scheme-monochrome...). Written by
            // `wallpaper-palette` (~/.local/bin), which owns the list of schemes and falls back to its default
            // for one it does not know, so it is only checked as a non-empty string here: a scheme added
            // there does not have to be added in this file too.
            "theme.scheme": {
                "type": "string",
                "notEmpty": true
            },
            // Unlike the name, this is a closed set, so a typo in it is worth catching.
            "theme.mode": {
                "type": "string",
                "oneOf": ["auto", "dark", "light"]
            },
            // config/NotificationsConfig.qml
            "notifications.peaceMode": {
                "type": "boolean"
            },
            // services/Caffeine.qml. Milliseconds since the epoch, 0 = stays on until turned off.
            "idle.caffeine": {
                "type": "boolean"
            },
            "idle.caffeineUntil": {
                "type": "number",
                "min": 0
            },
            // services/SysStats.qml. x/y are the detached card's corner; -1 means "never placed".
            "stats.detached": {
                "type": "boolean"
            },
            "stats.compact": {
                "type": "boolean"
            },
            "stats.screen": {
                "type": "string"
            },
            "stats.x": {
                "type": "number",
                "integer": true,
                "min": -1
            },
            "stats.y": {
                "type": "number",
                "integer": true,
                "min": -1
            },
            // config/StatusPillConfig.qml and config/Expanded.qml: icon ids in display order. Only the shape
            // is checked (an array of non-empty strings, [] allowed), not the ids: plugins add ids of their
            // own, and the zones already skip an id nothing provides.
            // config/PillsConfig.qml: [{ side: "left" | "right", widgets: [ids] }], at most 4 pills.
            "pills.extra": {
                "type": "pills"
            },
            "statusPill.icons": {
                "type": "list"
            },
            "expanded.extraButtons": {
                "type": "list"
            }
        })

    // "" when `value` fits `key`, otherwise one line saying what is wrong with it. An unknown key is
    // not this function's business: Prefs reports those separately.
    function fault(key, value) {
        const rule = keys[key];
        if (rule === undefined)
            return "";
        if (rule.type === "pills") {
            if (!Array.isArray(value))
                return `${key} is ${JSON.stringify(value)}, expected a list of pills`;
            if (value.length > 4)
                return `${key} has ${value.length} pills, the most is 4`;
            for (let i = 0; i < value.length; i++) {
                const p = value[i];
                if (p === null || typeof p !== "object" || Array.isArray(p))
                    return `${key}[${i}] is ${JSON.stringify(p)}, expected an object with side and widgets`;
                if (p.side !== "left" && p.side !== "right")
                    return `${key}[${i}].side is ${JSON.stringify(p.side)}, expected "left" or "right"`;
                if (!Array.isArray(p.widgets) || p.widgets.length < 1 || p.widgets.length > 12 || p.widgets.some(w => typeof w !== "string" || w === ""))
                    return `${key}[${i}].widgets must be 1 to 12 non-empty strings`;
            }
            return "";
        }
        if (rule.type === "list") {
            if (!Array.isArray(value))
                return `${key} is ${JSON.stringify(value)}, expected a list`;
            const at = value.findIndex(v => typeof v !== "string" || v === "");
            return at < 0 ? "" : `${key} has ${JSON.stringify(value[at])} at position ${at}, expected only non-empty strings`;
        }
        if (typeof value !== rule.type)
            return `${key} is ${JSON.stringify(value)}, expected a ${rule.type}`;
        if (rule.type === "string") {
            if (rule.oneOf !== undefined && !rule.oneOf.includes(value))
                return `${key} is ${JSON.stringify(value)}, expected one of ${rule.oneOf.join(", ")}`;
            return rule.notEmpty === true && value === "" ? `${key} is empty` : "";
        }
        if (rule.type !== "number")
            return "";
        if (!isFinite(value))
            return `${key} is ${JSON.stringify(value)}, expected a finite number`;
        if (rule.integer === true && Math.floor(value) !== value)
            return `${key} is ${value}, expected a whole number`;
        if (rule.min !== undefined && value < rule.min)
            return `${key} is ${value}, below the minimum ${rule.min}`;
        if (rule.max !== undefined && value > rule.max)
            return `${key} is ${value}, above the maximum ${rule.max}`;
        return "";
    }
}
