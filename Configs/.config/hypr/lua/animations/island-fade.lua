-- # -----------------------------------------------------
-- # Island (fade): fast and discreet motion for the Quickshell Edition
-- # -----------------------------------------------------
-- Springs tuned just short of bouncing (the same feel as the Morphing Island) and short fades.
-- Pick it with the animations picker or `hyde-shell animations --set island-fade`. Sibling presets:
-- island (workspaces sideways), island-vertical, island-fade. To tweak one, edit the values below;
-- speeds are in tenths of a second and follow HyDE's duration scale.

local animation = {
    name = "Island (fade)",
    icon = "",
    description = "The calmest: windows and workspaces only fade, nothing moves."
}

if not hl then
    return animation
end
-- prod utilizes the stored hyde.config.anim.duration_scale to dynamically change anim speed!
local prod = function(ds)
    return ds * hyde.config.anim.duration_scale
end

-- Springs: critical damping is 2 * sqrt(stiffness * mass); these sit just under it (settle in ~0.25 s).
hl.curve("islandOpen", {type = "spring", mass = 1, stiffness = 400, dampening = 36})
hl.curve("islandMove", {type = "spring", mass = 1, stiffness = 300, dampening = 33})
-- Quick out, gentle landing (for fades and closing).
hl.curve("islandOut", {type = "bezier", points = {{0.3, 0}, {0.8, 0.15}}})
hl.curve("islandEase", {type = "bezier", points = {{0.2, 0.9}, {0.25, 1}}})

-- Windows: open with the spring, close a little faster, moves and resizes follow the spring.
hl.animation({leaf = "windows", enabled = true, speed = prod(3), spring = "islandOpen", style = "popin 100%"})
hl.animation({leaf = "windowsIn", enabled = true, speed = prod(3), spring = "islandOpen", style = "popin 100%"})
hl.animation({leaf = "windowsOut", enabled = true, speed = prod(1.6), bezier = "islandOut", style = "popin 100%"})
hl.animation({leaf = "windowsMove", enabled = true, speed = prod(3), spring = "islandMove", style = "slide"})

-- Fades (opacity, shadows, dimming, layers, popups).
hl.animation({leaf = "fade", enabled = true, speed = prod(2.5), bezier = "islandEase"})
hl.animation({leaf = "fadeOut", enabled = true, speed = prod(1.6), bezier = "islandEase"})
hl.animation({leaf = "fadeDim", enabled = true, speed = prod(3), bezier = "islandEase"})
hl.animation({leaf = "fadeLayersOut", enabled = true, speed = prod(1.6), bezier = "islandEase"})
hl.animation({leaf = "fadePopupsOut", enabled = true, speed = prod(1.4), bezier = "islandEase"})

-- Menus and other layer surfaces (the shells' own surfaces animate themselves).
hl.animation({leaf = "layers", enabled = true, speed = prod(2.5), bezier = "islandEase", style = "popin 96%"})
hl.animation({leaf = "layersOut", enabled = true, speed = prod(1.6), bezier = "islandOut", style = "fade"})

-- Workspaces, and the scratchpad (special workspace) across them.
hl.animation({leaf = "workspaces", enabled = true, speed = prod(3.5), spring = "islandMove", style = "fade"})
hl.animation({leaf = "specialWorkspace", enabled = true, speed = prod(3.5), spring = "islandMove", style = "fade"})

-- Border colour changes and the rest.
hl.animation({leaf = "border", enabled = true, speed = prod(2.5), bezier = "islandEase"})
hl.animation({leaf = "borderangle", enabled = false})
hl.animation({leaf = "zoomFactor", enabled = true, speed = prod(3), bezier = "islandEase"})
