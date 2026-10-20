#!/usr/bin/env python3
"""Writes Configs/.config/matugen/templates/zed.json, the matugen template for Zed's theme.

    python3 -I tools/gen_zed_template.py

One file holds both themes ("Matugen Dark" and "Matugen Light"), so Zed's settings can say
{"theme": {"mode": "system", "dark": "Matugen Dark", "light": "Matugen Light"}} and follow the system
colour scheme, which follows the mode matugen chose. Each theme reads the roles of its own polarity
(`colors.<role>.dark.hex` / `.light.hex`), not `default`, so both are always right in one render.
The surface roles are the grey ones wallpaper-palette writes; accents come from the wallpaper. The
ANSI colours of the terminal are the fixed ones of Configs/.config/wallbash/theme/kitty.dcol.
Zed fills in what a theme leaves out, so this lists what carries the look, not all 140 keys.
"""
import json
import pathlib

OUT = pathlib.Path(__file__).resolve().parents[1] / "Configs/.config/matugen/templates/zed.json"

# Zed key -> matugen role, or a literal (#hex / "transparent") when it starts with '='.
ROLES = {
    "background": "background",
    "surface.background": "surface_container_low",
    "elevated_surface.background": "surface_container_high",
    "panel.background": "background",
    "title_bar.background": "background",
    "title_bar.inactive_background": "background",
    "status_bar.background": "background",
    "toolbar.background": "surface_container_low",
    "tab_bar.background": "background",
    "tab.inactive_background": "background",
    "tab.active_background": "surface_container_low",
    "editor.background": "surface_container_low",
    "editor.gutter.background": "surface_container_low",
    "editor.foreground": "on_surface",
    "editor.line_number": "outline",
    "editor.active_line_number": "on_surface",
    "editor.active_line.background": "surface_container",
    "editor.highlighted_line.background": "surface_container_high",
    "editor.indent_guide": "outline_variant",
    "editor.indent_guide_active": "outline",
    "editor.wrap_guide": "outline_variant",
    "text": "on_surface",
    "text.muted": "on_surface_variant",
    "text.placeholder": "outline",
    "text.disabled": "outline",
    "text.accent": "primary",
    "icon": "on_surface_variant",
    "icon.muted": "outline",
    "icon.disabled": "outline",
    "icon.accent": "primary",
    "border": "outline_variant",
    "border.variant": "outline_variant",
    "border.disabled": "outline_variant",
    "border.focused": "primary",
    "border.selected": "primary",
    "border.transparent": "=transparent",
    "pane.focused_border": "primary",
    "pane_group.border": "outline_variant",
    "element.background": "surface_container",
    "element.hover": "surface_container_high",
    "element.active": "surface_container_highest",
    "element.selected": "surface_container_high",
    "element.disabled": "surface_container",
    "ghost_element.background": "=transparent",
    "ghost_element.hover": "surface_container_high",
    "ghost_element.active": "surface_container_highest",
    "ghost_element.selected": "surface_container_high",
    "ghost_element.disabled": "=transparent",
    "scrollbar.thumb.background": "outline_variant",
    "scrollbar.thumb.hover_background": "outline",
    "scrollbar.thumb.border": "=transparent",
    "scrollbar.track.background": "=transparent",
    "scrollbar.track.border": "=transparent",
    "link_text.hover": "primary",
    "error": "error",
    "error.border": "error",
    "warning": "tertiary",
    "warning.border": "tertiary",
    "success": "secondary",
    "success.border": "secondary",
    "info": "primary",
    "info.border": "primary",
    "terminal.background": "surface_container_low",
    "terminal.foreground": "on_surface",
}
# What syntax scopes get: accents from the wallpaper, the rest neutral.
SYNTAX = {
    "keyword": "primary", "function": "secondary", "type": "tertiary", "string": "secondary",
    "number": "tertiary", "constant": "tertiary", "boolean": "tertiary", "comment": "outline",
    "operator": "on_surface_variant", "punctuation": "on_surface_variant", "property": "on_surface",
    "variable": "on_surface", "attribute": "tertiary", "tag": "primary", "link_uri": "primary",
    "emphasis.strong": "on_surface", "title": "primary", "preproc": "primary", "constructor": "tertiary",
}
ANSI = {
    "black": "#1d2021", "red": "#cc6666", "green": "#b5bd68", "yellow": "#c9a96a", "blue": "#81a2be",
    "magenta": "#b294bb", "cyan": "#8abeb7", "white": "#c5c8c6",
}
ANSI_BRIGHT = {
    "black": "#666666", "red": "#d54e53", "green": "#b9ca4a", "yellow": "#d4b97a", "blue": "#7aa6da",
    "magenta": "#c397d8", "cyan": "#70c0b1", "white": "#eaeaea",
}


def value(spec, polarity, alpha=None):
    if spec.startswith("="):
        return spec[1:]
    base = f"{{{{colors.{spec}.{polarity}.hex}}}}"
    return base + alpha if alpha else base


def theme(polarity):
    style = {key: value(spec, polarity) for key, spec in ROLES.items()}
    style["search.match_background"] = value("primary", polarity, "55")
    style["editor.document_highlight.read_background"] = value("primary", polarity, "26")
    style["editor.document_highlight.write_background"] = value("primary", polarity, "40")
    for name, colour in ANSI.items():
        style[f"terminal.ansi.{name}"] = colour
    for name, colour in ANSI_BRIGHT.items():
        style[f"terminal.ansi.bright_{name}"] = colour
    style["players"] = [{
        "cursor": value("primary", polarity),
        "background": value("primary", polarity),
        "selection": value("primary", polarity, "40"),
    }]
    style["syntax"] = {scope: {"color": value(role, polarity)} for scope, role in SYNTAX.items()}
    style["syntax"]["comment"]["font_style"] = "italic"
    return {"name": f"Matugen {polarity.title()}", "appearance": polarity, "style": style}


def main():
    doc = {"$schema": "https://zed.dev/schema/themes/v0.2.0.json", "name": "Matugen", "author": "hyde-lite",
           "themes": [theme("dark"), theme("light")]}
    OUT.write_text(json.dumps(doc, indent=2) + "\n")
    print(f"wrote {OUT}")


if __name__ == "__main__":
    main()
