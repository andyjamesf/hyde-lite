import qs.bar.components
import qs.bar.services

// Menu with the shell options (bar layout, color source) and the HyDE actions
// (theme, wallpaper, animations, workflows, night light…).
BarItem {
    icon: "palette"
    iconColor: Theme.primary
    tooltip: `HyDE and shell options\nLayout: ${BarLayout.preset.label ?? BarLayout.current}`
    menuOnLeftClick: true
    menu: [
        {
            label: "󰕮  Bar layout",
            items: BarLayout.names.map(name => ({
                        label: BarLayout.presets[name].label ?? name,
                        checked: name === BarLayout.current,
                        action: () => BarLayout.select(name)
                    }))
        },
        {
            label: "󰆧  Bar islands",
            items: BarLayout.pillStyles.map(s => ({
                        label: s.label,
                        checked: s.id === BarLayout.pillStyle,
                        action: () => BarLayout.setPillStyle(s.id)
                    })).concat([
                {
                    sep: true
                }
            ], [1, 0.85, 0.7, 0.5].map(v => ({
                        label: `Opacity ${Math.round(v * 100)}%`,
                        checked: Math.abs(BarLayout.opacity - v) < 0.01,
                        action: () => BarLayout.setPillOpacity(v)
                    })))
        },
        {
            label: "󰁌  Bar height",
            items: [
                {
                    label: `Layout default (${BarLayout.layoutHeight} px)`,
                    checked: Prefs.barHeight === 0,
                    action: () => BarLayout.setHeight(0)
                }
            ].concat(BarLayout.heights.map(h => ({
                        label: `${h.label} (${h.value} px)`,
                        checked: Prefs.barHeight === h.value,
                        action: () => BarLayout.setHeight(h.value)
                    })), [
                {
                    sep: true
                },
                {
                    label: "Taller (+2 px)",
                    action: () => BarLayout.adjustHeight(2)
                },
                {
                    label: "Shorter (−2 px)",
                    action: () => BarLayout.adjustHeight(-2)
                }
            ])
        },
        {
            label: "󰏘  Shell colors",
            items: [
                {
                    label: "Material You (matugen, Super+Shift+C)",
                    checked: Theme.source === "matugen",
                    action: () => Theme.setColorSource("matugen")
                },
                {
                    label: "HyDE theme (bar colors)",
                    checked: Theme.source === "hyde",
                    action: () => Theme.setColorSource("hyde")
                },
                {
                    label: "Theme palette (wallbash)",
                    checked: Theme.source === "wallbash",
                    action: () => Theme.setColorSource("wallbash")
                },
                {
                    label: "Wallpaper colors",
                    checked: Theme.source === "wallpaper",
                    action: () => Theme.setColorSource("wallpaper")
                },
                {
                    sep: true
                },
                {
                    label: "HyDE wallbash mode (system)…",
                    cmd: "hyde-shell wallbashtoggle.sh -m"
                }
            ]
        },
        {
            sep: true
        }
    ].concat(HydeActions.hyde)
}
