-- UI switching: the HyDE-style bar or the Morphing Island, the two UIs of one Quickshell configuration,
-- one at a time, and the keys that work in both.
--
-- Loaded last from hyprland.lua, inside pcall: a mistake here must cost the shell's keys, not the
-- whole Hyprland session. `island on|off|toggle` (~/.local/bin/island) chooses the shell and writes
-- ~/.local/state/morphing-island/active; every key reads that file when it is pressed.
--
-- This file is code only. The keys are data, in ~/.config/hypr/keybinds.lua (documented there): one
-- list for every machine, so two machines cannot drift apart. Hardware belongs in host.lua.
-- ~/.config/hypr/desktop.lua is optional and personal: if it exists, its `binds` (terminal, browser,
-- file manager) are registered too, and its `apps` name the programs.

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
			hl.dispatch(hl.dsp.exec_cmd(cmd))
		end
	end
end

local function k(spec)
	return (spec:gsub("%$mod", mod))
end

local keys = dofile(home .. "/.config/hypr/keybinds.lua")

-- HyDE binds the keys reassign or drop: removed first, or both would fire.
for _, spec in ipairs(keys.unbind or {}) do
	hl.unbind(k(spec))
end

for _, b in ipairs(keys.shell or {}) do
	hl.bind(k(b.keys), route(b.island and (ipc .. b.island), b.hyde), { description = b.desc })
end

-- `cmd` runs as written; `dsp` builds a Hyprland dispatcher (for what is not a command).
for _, b in ipairs(keys.binds or {}) do
	hl.bind(k(b.keys), b.dsp and b.dsp() or hl.dsp.exec_cmd(b.cmd), { description = b.desc })
end

-- Personal program keys, if the machine has a desktop model. pcall: a missing or broken model must
-- not take the whole Hyprland config down with it, it only adds keys.
local okDesktop, desktop = pcall(dofile, home .. "/.config/hypr/desktop.lua")
if okDesktop and type(desktop) == "table" then
	for _, b in ipairs(desktop.binds or {}) do
		local cmd = b.run or ((desktop.apps or {})[b.app] or {}).run
		if cmd then
			hl.unbind(k(b.keys))
			hl.bind(k(b.keys), hl.dsp.exec_cmd(cmd), { description = b.desc })
		end
	end
end

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
