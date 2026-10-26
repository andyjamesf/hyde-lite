-- ============================================================================
-- Keybindings: the ones this setup adds or changes on top of HyDE's defaults
-- ============================================================================
-- This file only holds data; ~/.config/hypr/hyprland.lua reads it and creates the binds.
-- After editing, run `hyprctl reload` (then `hyprctl configerrors` must print nothing).
-- Super+\ lists every active keybinding, including HyDE's own.
--
-- Writing keys
--   "$mod + SHIFT + T"   $mod is HyDE's main modifier (SUPER). Modifiers: SUPER, SHIFT, CTRL, ALT.
--   Key names are xkb names: A…Z, 1…9, Return, TAB, Delete, comma, period, backslash, Up, Left…
--   On a Portuguese keyboard "/" is Shift+7, so use backslash instead of slash.
--
-- Where HyDE's default binds come from
--   Workspaces, window management, media keys, screenshots… are defined by HyDE in
--   ~/.local/share/hypr/key_binds.lua (HyDE's file: overwritten on HyDE updates, don't edit it).
--   To change or remove one of those, list its keys in `unbind` below and, to reassign the
--   action, add it to `binds`.

local M = {}

-- ----------------------------------------------------------------------------
-- Shell binds: the same keys work in both desktop shells
-- ----------------------------------------------------------------------------
-- `island on|off|toggle` (or $mod+SHIFT+I, which also steps through the minimal bar) chooses the shell. When a key is pressed, its action
-- goes to whichever shell is running:
--   island   arguments for `qs ipc call island …`
--            (see ~/.config/quickshell/island/README.md, "IPC"). nil = the key does nothing there.
--   hyde     a shell command for the HyDE Quickshell shell (`qs ipc call …`). nil = nothing.
--   desc     "[Category] what it does": the category groups it in the keybindings list.
M.shell = {
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

-- ----------------------------------------------------------------------------
-- Plain command binds
-- ----------------------------------------------------------------------------
-- `cmd` runs as written, in whichever shell is up: for actions that are the same
-- in both. Keys that drive the bar or the launcher belong in M.shell above.
M.binds = {
	-- The three faces of the shell on one key: Morphing Island -> HyDE bar -> minimal bar -> back.
	-- This is the only key for it (Configs/.local/bin/shell-cycle): `island on|off|toggle` and
	-- `qs ipc call minibar on|off|toggle` do the single steps from a terminal.
	{ keys = "$mod + SHIFT + I", cmd = "shell-cycle", desc = "[Theming and Wallpaper] next shell: island, bar, minimal bar" },

	-- Layers: $mod+CTRL+arrows step through something. Left/Right the wallpaper, Up/Down the palette.
	-- Every wallpaper in the library, not only the current theme's folder (HyDE's own keys, unbound below).
	-- $mod+SHIFT+W opens the grid to pick one; `wallpaper-library random` is a random one.
	{ keys = "$mod + CTRL + Right", cmd = "wallpaper-library next", desc = "[Theming and Wallpaper] next wallpaper (all of them)" },
	{ keys = "$mod + CTRL + Left", cmd = "wallpaper-library prev", desc = "[Theming and Wallpaper] previous wallpaper (all of them)" },
	-- The colour schemes matugen can give the current wallpaper; $mod+SHIFT+C lists them with a swatch each.
	{ keys = "$mod + CTRL + Up", cmd = "sh -c 'notify-send -a Palette -t 2500 \"$(wallpaper-palette next)\"'", desc = "[Theming and Wallpaper] next wallpaper palette" },
	{ keys = "$mod + CTRL + Down", cmd = "sh -c 'notify-send -a Palette -t 2500 \"$(wallpaper-palette prev)\"'", desc = "[Theming and Wallpaper] previous wallpaper palette" },

	-- Through loginctl, so hypridle runs the active shell's lock screen. Without hypridle, lock
	-- directly: the island's lock for either shell, then HyDE's hyprlock.
	{
		keys = "$mod + L",
		cmd = "sh -c 'pgrep -x hypridle >/dev/null && exec loginctl lock-session; "
			.. "\"$HOME/.local/bin/island\" lock lock || hyde-shell lockscreen.sh'",
		desc = "[Window Management] lock session",
	},

	-- The terminal. HyDE binds $mod+T; $mod+Return is the one key kept (a machine's desktop.lua may
	-- rebind it to its own terminal). `hyde.config.app.terminal` is HyDE's choice of program.
	{ keys = "$mod + Return", dsp = function() return hl.dsp.exec_cmd(hyde.config.app.terminal) end, desc = "[Launcher|Apps] terminal emulator" },

	-- Moving between screens. Machine-independent: with one screen they do nothing. `dsp` builds a
	-- Hyprland dispatcher instead of running a command. Two screens only, so "+1" is "the other one".
	{ keys = "$mod + O", dsp = function() return hl.dsp.focus({ monitor = "+1" }) end, desc = "[Window Management|Monitors] focus the other screen" },
	{ keys = "$mod + SHIFT + O", dsp = function() return hl.dsp.window.move({ monitor = "+1" }) end, desc = "[Window Management|Monitors] move the active window to the other screen" },
	{ keys = "$mod + CTRL + O", dsp = function() return hl.dsp.workspace.move({ monitor = "+1" }) end, desc = "[Window Management|Monitors] move this workspace to the other screen" },
}

-- ----------------------------------------------------------------------------
-- Programs and their keys: ~/.config/hypr/desktop.lua
-- ----------------------------------------------------------------------------
-- Optional and personal: if ~/.config/hypr/desktop.lua exists, island.lua reads it for the keys
-- that launch the terminal, browser and file manager. Without it HyDE's own keys apply.


-- ----------------------------------------------------------------------------
-- Removed HyDE binds
-- ----------------------------------------------------------------------------
-- Removed before the binds above are added, so a key listed in both is reassigned.
M.unbind = {
	"$mod + slash", -- keybindings list: moved to $mod+backslash ("/" is Shift+7 on pt keyboards)
	"$mod + SHIFT + slash", -- web search: moved to $mod+SHIFT+backslash
	"$mod + ALT + T", -- dropdown terminal: needs pyprland, not installed (the key would install it)
	"$mod + ALT + G", -- HyDE's game mode: reassigned above
	"$mod + T", -- second terminal key: $mod+Return is enough
	"$mod + CTRL + B", -- second hide-bar key: $mod+comma is enough
	"$mod + L", -- lock: reassigned above (goes through hypridle)
	-- HyDE's next/previous global wallpaper only walk the current theme's folder: its keys are freed
	-- here and the wallpaper-library ones sit on $mod+CTRL+Left/Right (M.binds above).
	-- HyDE's relative-workspace and empty-workspace keys sit on $mod+CTRL+arrows; the layers give that
	-- family to stepping through wallpapers and palettes (workspaces stay on $mod+1..9 and $mod+S).
	"$mod + CTRL + Right",
	"$mod + CTRL + Left",
	"$mod + CTRL + Down",
	"$mod + CTRL + Up",
	"$mod + ALT + Right",
	"$mod + ALT + Left",
	-- HyDE's screenshot keys: reassigned above (routed to the island).
	"$mod + P",
	"$mod + CONTROL + P", -- written as HyDE writes it (CTRL does not match)
	"$mod + ALT + P",
	"Print",
	-- Bare F10/F11/F12 change the volume in HyDE; they are taken back for apps (fullscreen, devtools).
	-- The volume keys (XF86Audio…) still work.
	"F10",
	"F11",
	"F12",
}

-- Nine workspaces: HyDE's key 0 (workspace 10) and the numpad (workspaces 11-20) are removed, for
-- going to a workspace ($mod), moving a window there ($mod+SHIFT) and moving it silently ($mod+ALT).
-- Each numpad key has two names (Num Lock on/off).
for _, prefix in ipairs({ "$mod + ", "$mod + SHIFT + ", "$mod + ALT + " }) do
	table.insert(M.unbind, prefix .. "0")
end
for _, key in ipairs({ "KP_1", "KP_End", "KP_2", "KP_Down", "KP_3", "KP_Next", "KP_4", "KP_Left", "KP_5",
	"KP_Begin", "KP_6", "KP_Right", "KP_7", "KP_Home", "KP_8", "KP_Up", "KP_9", "KP_Prior", "KP_0", "KP_Insert" }) do
	table.insert(M.unbind, "$mod + " .. key)
	table.insert(M.unbind, "$mod + SHIFT + " .. key)
end

return M
