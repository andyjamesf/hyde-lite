-- UI switching: the HyDE-style bar or the Morphing Island, the two UIs of one Quickshell configuration,
-- one at a time.
--
-- Loaded last from hyprland.lua, inside pcall: a mistake here must cost the island's keys, not the
-- whole Hyprland session. `island on|off|toggle` (~/.local/bin/island) chooses the shell and writes
-- ~/.local/state/morphing-island/active; every key below reads that file when it is pressed.
--
-- Derived from the maintainer's own configuration (hyprland.lua and keybinds.lua) without the personal parts: the desktop
-- model (desktop.lua) and the personal binds are not here, and neither is that repository's
-- removal of HyDE's F10-F12 and numpad workspace binds.
--
-- Writing keys: "$mod + SHIFT + T"; $mod is HyDE's main modifier (SUPER). Key names are xkb names.
--   island   arguments for `qs ipc call island ...`
--            (see ~/.config/quickshell/island/README.md, "IPC"). nil = the key does nothing there.
--   hyde     a shell command for the bar UI (`qs ipc call ...`). nil = nothing.
--   desc     "[Category] what it does": the category groups it in the keybindings list.

MorphingIsland = {}

local home = os.getenv("HOME")
local state = (os.getenv("XDG_STATE_HOME") or (home .. "/.local/state")) .. "/morphing-island/active"
local ipc = "qs ipc call island "
local mod = hyde.config.modifiers.main

-- True while the Morphing Island is the active shell.
function MorphingIsland.active()
	local f = io.open(state, "r")
	if f then
		f:close()
		return true
	end
	return false
end

-- Called by `island on|off`; the binds decide at key-press time, so nothing to do here.
function MorphingIsland.set(_) end

-- A bind action that runs `island_cmd` when the island is active and `hyde_cmd` otherwise
-- (nil = do nothing in that shell).
local function route(island_cmd, hyde_cmd)
	return function()
		local cmd = MorphingIsland.active() and island_cmd or hyde_cmd
		if cmd then
			hl.exec_cmd(cmd)
		end
	end
end

local function k(spec)
	return (spec:gsub("%$mod", mod))
end

local shell = {
	-- Launcher and its modes.
	{ keys = "$mod + A", island = "open launcher", hyde = "qs ipc call launcher toggle", desc = "[Launcher] application finder" },

	-- Workspace overview: every workspace of this screen as a tile, with live previews of its
	-- windows (components/OverviewView.qml). Only the island has it.
	{ keys = "$mod + D", island = "open overview", hyde = nil, desc = "[Window Management] workspace overview" },

	-- Scratch page, saved as you type (components/NotepadView.qml). Only the island has it.
	{ keys = "$mod + ALT + N", island = "open notepad", hyde = nil, desc = "[Utilities] notepad" },

	-- Steps the wallpaper palette through auto, dark and light, taking HyDE's programs with it.
	{ keys = "$mod + SHIFT + D", island = "scheme ''", hyde = "sh -c 'notify-send -a Palette -t 2500 \"$(wallpaper-palette mode next)\"'", desc = "[Theming and Wallpaper] light or dark (auto, dark, light)" },
	{ keys = "$mod + V", island = "launcher ':'", hyde = "qs ipc call launcher clipboard", desc = "[Launcher] clipboard" },
	{ keys = "$mod + SHIFT + K", island = "launcher '='", hyde = "qs ipc call launcher calc", desc = "[Launcher] calculator" },
	{ keys = "$mod + backslash", island = "launcher '?'", hyde = "qs ipc call launcher keys", desc = "[Launcher] keybindings" },

	-- Control center, notifications, island settings.
	{ keys = "$mod + ALT + C", island = "open controlcenter", hyde = "qs ipc call controlcenter toggle", desc = "[Launcher] control center" },
	{ keys = "$mod + N", island = "open controlcenter", hyde = "qs ipc call notifications toggle", desc = "[Utilities] notification center" },
	{ keys = "$mod + ALT + comma", island = "open settings", hyde = nil, desc = "[Morphing Island] settings" },

	-- Theme and wallpaper.
	{ keys = "$mod + SHIFT + T", island = "open theme", hyde = "qs ipc call launcher pick themes", desc = "[Theming and Wallpaper] select a theme" },
	{ keys = "$mod + SHIFT + W", island = "open wallpaper", hyde = "qs ipc call launcher pick wallpapers", desc = "[Theming and Wallpaper] select a global wallpaper" },

	-- HyDE's rofi menus, ported to both shells: launcher pickers (`pick <name>`; the island's are in
	-- ~/.config/quickshell/island/services/Pickers.qml, the bar's in ~/.config/quickshell/bar/pickers/).
	{ keys = "$mod + TAB", island = "pick windows", hyde = "qs ipc call launcher pick windows", desc = "[Launcher|Pickers] window switcher" },
	{ keys = "$mod + SHIFT + E", island = "pick files", hyde = "qs ipc call launcher pick files", desc = "[Launcher|Pickers] file finder" },
	{ keys = "$mod + period", island = "pick glyph", hyde = "qs ipc call launcher pick glyph", desc = "[Launcher|Pickers] glyph picker" },
	{ keys = "$mod + SHIFT + comma", island = "pick emoji", hyde = "qs ipc call launcher pick emoji", desc = "[Launcher|Pickers] emoji picker" },
	{ keys = "$mod + SHIFT + backslash", island = "pick web", hyde = "qs ipc call launcher pick web", desc = "[Launcher|Pickers] web search" },
	{ keys = "$mod + SHIFT + R", island = "pick wallbash", hyde = "qs ipc call launcher pick wallbash", desc = "[Theming and Wallpaper] wallbash mode selector" },
	{ keys = "$mod + SHIFT + C", island = "pick palette", hyde = "qs ipc call launcher pick palette", desc = "[Theming and Wallpaper] wallpaper palette (colour scheme)" },
	{ keys = "$mod + SHIFT + Y", island = "pick animations", hyde = "qs ipc call launcher pick animations", desc = "[Theming and Wallpaper] select animations" },
	{ keys = "$mod + SHIFT + U", island = "pick hyprlock", hyde = "qs ipc call launcher pick hyprlock", desc = "[Theming and Wallpaper] select Hyprlock layout" },
	{ keys = "$mod + SHIFT + G", island = "pick games", hyde = "qs ipc call launcher pick games", desc = "[Utilities] game launcher" },
	-- Every picker in one list (workflows, shaders, layouts, HyDE themes… have no key of their own).
	{ keys = "$mod + SHIFT + A", island = "pick menu", hyde = "qs ipc call launcher pick menu", desc = "[Launcher] HyDE menus" },

	-- Bar.
	{ keys = "$mod + comma", island = "hide", hyde = "qs ipc call bar toggle", desc = "[Window Management] hide or show the bar" },
	{ keys = "$mod + CTRL + B", island = "hide", hyde = "qs ipc call bar toggle", desc = "[Window Management] hide or show the bar" },
	-- Island: expanded (workspaces, media, time, status) ⇄ back to the single clock pill. A click on
	-- the clock opens the calendar, a right click expands too.
	{ keys = "$mod + ALT + B", island = "pin", hyde = nil, desc = "[Morphing Island] expand the island or shrink it back to one pill" },
	-- Bar layouts only exist in the HyDE shell.
	{ keys = "$mod + ALT + Up", island = nil, hyde = "qs ipc call bar next", desc = "[Theming and Wallpaper] next bar layout" },
	{ keys = "$mod + ALT + Down", island = nil, hyde = "qs ipc call bar prev", desc = "[Theming and Wallpaper] previous bar layout" },

	-- Screenshots: the island shows the capture with Copy, Save, Edit and Delete (HyDE's shell: HyDE's
	-- script, which opens satty). OCR ($mod+CTRL+S) stays HyDE's.
	{ keys = "$mod + P", island = "screenshot area", hyde = "hyde-shell screenshot s", desc = "[Utilities] partial screenshot capture" },
	{ keys = "$mod + CTRL + P", island = "screenshot freeze", hyde = "hyde-shell screenshot sf", desc = "[Utilities] partial screenshot capture (frozen screen)" },
	{ keys = "$mod + ALT + P", island = "screenshot output", hyde = "hyde-shell screenshot m", desc = "[Utilities] print monitor" },
	{ keys = "Print", island = "screenshot screen", hyde = "hyde-shell screenshot p", desc = "[Utilities] print all monitors" },

	-- Session: the power menu asks before logging out, rebooting or powering off.
	-- ($mod+Delete used to exit Hyprland instantly; it now opens the same menu.)
	{ keys = "CTRL + ALT + DELETE", island = "open power", hyde = "qs ipc call powermenu toggle", desc = "[Window Management] logout menu" },
	{ keys = "$mod + Delete", island = "open power", hyde = "qs ipc call powermenu toggle", desc = "[Window Management] logout menu" },
}

-- Plain command binds: the same in either shell (the colour pipeline's wallpaper-palette and
-- wallpaper-library, see Scripts/dots/colour.toml).
local binds = {
	-- Every wallpaper in the library, not only the current theme's folder (HyDE's own keys, unbound below).
	{ keys = "$mod + ALT + Right", cmd = "wallpaper-library next", desc = "[Theming and Wallpaper] next wallpaper (all of them)" },
	{ keys = "$mod + ALT + Left", cmd = "wallpaper-library prev", desc = "[Theming and Wallpaper] previous wallpaper (all of them)" },
	-- The colour schemes matugen can give the current wallpaper; $mod+SHIFT+C lists them with a swatch each.
	{ keys = "$mod + CTRL + Up", cmd = "sh -c 'notify-send -a Palette -t 2500 \"$(wallpaper-palette next)\"'", desc = "[Theming and Wallpaper] next wallpaper palette" },
	{ keys = "$mod + CTRL + Down", cmd = "sh -c 'notify-send -a Palette -t 2500 \"$(wallpaper-palette prev)\"'", desc = "[Theming and Wallpaper] previous wallpaper palette" },
}

-- HyDE binds the shell keys reassigns: removed first, or both would fire.
-- ($mod + slash and SHIFT + slash moved to backslash because "/" is Shift+7 on pt keyboards.)
for _, spec in ipairs({
	"$mod + slash",
	"$mod + SHIFT + slash",
	"$mod + ALT + T",
	"$mod + ALT + G",
	"$mod + ALT + Right", -- HyDE's next/previous wallpaper: reassigned to wallpaper-library
	"$mod + ALT + Left",
	"$mod + P",
	"$mod + CONTROL + P", -- written as HyDE writes it (CTRL does not match)
	"$mod + ALT + P",
	"Print",
}) do
	hl.unbind(k(spec))
end

for _, b in ipairs(shell) do
	hl.bind(k(b.keys), route(b.island and (ipc .. b.island), b.hyde), { description = b.desc })
end

for _, b in ipairs(binds) do
	hl.bind(k(b.keys), hl.dsp.exec_cmd(b.cmd), { description = b.desc })
end

hl.bind(k("$mod + ALT + I"), hl.dsp.exec_cmd(home .. "/.local/bin/island toggle"), {
	description = "[Morphing Island] switch between the island and the HyDE shell",
})

-- At login: start the island instead of the HyDE shell, and let it be the polkit, Wi-Fi and
-- Bluetooth agent.
if MorphingIsland.active() then
	-- `island run` starts it again if it crashes (and it locks again if the screen was locked).
	hyde.config.start.bar = "hyde-shell app -u morphing-island.service -t service -- " .. home .. "/.local/bin/island run"
	hyde.config.start.auth_dialogue = ""
	-- The island also answers Wi-Fi passwords and Bluetooth pairing (island/scripts/agents.py).
	hyde.config.start.applet_network_manager = ""
	hyde.config.start.applet_bluetooth = ""
end

-- With the bar shell the island is not running, so nothing keeps the login screen (which is the island's
-- in both cases) up to date: sync it once at login, with the fade entry (no pill).
if not MorphingIsland.active() then
	hyde.config.start.island_login_sync = "hyde-shell app -t service -- " .. home .. "/.local/bin/island login sync-once"
end
