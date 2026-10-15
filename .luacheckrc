-- Hyprland runs the configuration with these globals already defined: `hl` is Hyprland's Lua API and
-- `hyde` is the helper table HyDE's own modules build. `MorphingIsland` is the table island.lua publishes
-- on purpose, so the other Lua files can read the island's settings.
std = "lua54"
globals = { "hl", "hyde", "MorphingIsland" }
-- keybind tables are long one-line records
max_line_length = false
