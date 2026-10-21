pragma Singleton
import QtQuick
import Quickshell

// Small helpers shared by the pickers that drive HyDE (themes, wallbash, hyprlock and the Lua
// selectors: animations, workflows, layouts, shaders). Every action goes through Launch.run, so it
// finishes in its own unit even if the shell restarts halfway.
Singleton {
    id: root

    // HyDE's state directory (staterc, config, lua_state/…).
    readonly property string stateDir: `${Quickshell.env("HYDE_STATE_HOME") || Paths.stateHome + "/hyde"}`
    // HyDE's config directory (themes/, config.toml, websearch.lst…).
    readonly property string configDir: `${Quickshell.env("HYDE_CONFIG_HOME") || Paths.configHome + "/hyde"}`
    // Key=value state files, in the order HyDE sources them (the second one overrides the first,
    // as in export_hyde_config).
    readonly property var stateFiles: [`${stateDir}/staterc`, `${stateDir}/config`]

    // State file HyDE writes when a Lua selector applies an option (Hyprland `require`s it).
    function luaStateFile(module) {
        return `${stateDir}/lua_state/${module}.lua`;
    }

    // Applies option `key` of a HyDE Lua selector (`hyde-shell <module> --set <key>`, exactly what
    // HyDE's rofi.<module>.lua calls after a choice). With `firstReload`, also runs `hyprctl reload`
    // when the state file did not exist yet: Hyprland has nothing to watch until then (the rule
    // rofi.workflows.lua applies on the first choice). Later changes hot-reload on their own.
    function hydeSet(module, key, firstReload) {
        if (!module || !key)
            return;
        if (firstReload)
            Launch.run(["sh", "-c", '[ -e "$1" ] && first=0 || first=1; hyde-shell "$2" --set "$3" >/dev/null && [ "$first" = 1 ] && hyprctl reload >/dev/null 2>&1', "sh", luaStateFile(module), module, key]);
        else
            Launch.run(["hyde-shell", module, "--set", key]);
    }

    // Runs `script` in bash after `hyde-shell init` (HyDE's functions and variables: set_conf,
    // $LIB_DIR, $ICONS_DIR…). `args` are "$1", "$2"… in the script, never interpolated into it.
    function initRun(script, args) {
        Launch.run(["bash", "-c", 'eval "$(hyde-shell init)" || exit 1; ' + script, "bash"].concat((args ?? []).map(a => String(a))));
    }

    // Value of `key` in the concatenated text of HyDE's key=value state files (the last assignment
    // wins, quotes removed), or `fallback` when it is not set.
    function confValue(text, key, fallback) {
        let value = fallback;
        const re = new RegExp(`^\\s*${key}=(.*)$`);
        for (const line of String(text ?? "").split("\n")) {
            const m = line.match(re);
            if (m)
                value = m[1].trim().replace(/^(["'])(.*)\1$/, "$2");
        }
        return value;
    }
}
