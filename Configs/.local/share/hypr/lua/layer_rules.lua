-- # // █░░ ▄▀█ █▄█ █▀▀ █▀█   █▀█ █░█ █░░ █▀▀ █▀
-- # // █▄▄ █▀█ ░█░ ██▄ █▀▄   █▀▄ █▄█ █▄▄ ██▄ ▄█

local util = _G.hyde.utils

local blur_layers =
  util.regex_compile(
  {
    namespace = {
      "rofi",
      "notifications",
      "swaync-(notification-window|control-center)",
      "waybar",
      "logout_dialog"
    }
  },
  true
)

local ignore_alpha_layers =
  util.regex_compile(
  {
    namespace = {
      "rofi",
      "notifications",
      "swaync-(notification-window|control-center)",
      "waybar",
      "selection"
    }
  },
  true
)

hl.layer_rule({
  name  = "hyde_layer_blur",
  match = { namespace = blur_layers.namespace },
  blur  = true,
})

hl.layer_rule({
  name         = "hyde_layer_ignore_alpha",
  match        = { namespace = ignore_alpha_layers.namespace },
  ignore_alpha = 0,
})

-- Quickshell shell surfaces (namespaces "quickshell:*"): blur behind them, but not behind their
-- fully transparent parts (the gaps between the bar islands); the shell animates them itself.
hl.layer_rule({
  name         = "hyde_layer_quickshell",
  match        = { namespace = "^quickshell:.*$" },
  blur         = true,
  blur_popups  = true, -- the bar popouts are popups of the bar layer
  ignore_alpha = 0.1,
  no_anim      = true,
})

hl.layer_rule({
  name    = "hyde_layer_no_anim",
  no_anim = true,
  match   = { namespace = "selection" },
})
