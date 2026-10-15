#!/usr/bin/env python3
"""Validate bar layout files (docs/bar-builder.md). Standard library only.

    validate_layouts.py [LAYOUTS.json ...]

Run by tools/check.sh (shipped layouts) and by the shell itself (the owner's layouts file, on every change).
With no arguments it checks the shipped config/layouts.json. Widget ids come from
the map in services/BarWidgets.qml and pill styles from services/BarLayout.qml, so there is no second
list to keep in step. Exit 0: valid, 1: problems (one per line), 2: could not run.
"""
import json
import pathlib
import re
import sys

SHELL = pathlib.Path(__file__).resolve().parents[1]
ZONES = ("left", "center", "right")
STYLES = ("islands", "continuous")
POSITIONS = ("top", "bottom")
# Every key a layout may have; anything else is rejected so a typo does not silently do nothing.
KEYS = {"label", "description", "style", "position", "height", "margin", "spacing", "radius", "opacity",
        "pillStyle", "fontSize", "iconSize", *ZONES}
INT_RANGES = {"height": (16, 40), "margin": (0, 64), "spacing": (0, 64), "radius": (0, 64),
              "fontSize": (6, 64), "iconSize": (6, 64)}


def widget_ids():
    text = (SHELL / "services/BarWidgets.qml").read_text()
    block = re.search(r"readonly property var files: \(\{(.*?)\}\)", text, re.S)
    if not block:
        raise RuntimeError("cannot find the widget map in BarWidgets.qml")
    return set(re.findall(r'"([A-Za-z0-9_]+)"\s*:', block.group(1)))


def pill_styles():
    text = (SHELL / "services/BarLayout.qml").read_text()
    block = re.search(r"readonly property var pillStyles: \[(.*?)\n    \]", text, re.S)
    if not block:
        raise RuntimeError("cannot find pillStyles in BarLayout.qml")
    return set(re.findall(r'id:\s*"([A-Za-z0-9_]+)"', block.group(1)))


def is_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def check_layout(name, lay, ids, styles):
    p = []
    if not isinstance(lay, dict):
        return [f"{name}: must be an object"]
    for k in sorted(set(lay) - KEYS):
        p.append(f"{name}: unknown key '{k}'")
    for k in ("label", "description"):
        if k in lay and not isinstance(lay[k], str):
            p.append(f"{name}.{k}: must be a string")
    if "label" not in lay:
        p.append(f"{name}: 'label' is required")
    if "style" in lay and lay["style"] not in STYLES:
        p.append(f"{name}.style: must be one of {', '.join(STYLES)}")
    if "position" in lay and lay["position"] not in POSITIONS:
        p.append(f"{name}.position: must be one of {', '.join(POSITIONS)}")
    for k, (lo, hi) in INT_RANGES.items():
        if k in lay and not (is_int(lay[k]) and lo <= lay[k] <= hi):
            p.append(f"{name}.{k}: must be an integer from {lo} to {hi}")
    if "opacity" in lay and not (isinstance(lay["opacity"], (int, float)) and not isinstance(lay["opacity"], bool)
                                 and 0 <= lay["opacity"] <= 1):
        p.append(f"{name}.opacity: must be a number from 0 to 1")
    if "pillStyle" in lay:
        v = lay["pillStyle"]
        if not (isinstance(v, str) and (v in styles or re.fullmatch(r"#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?", v))):
            p.append(f"{name}.pillStyle: must be one of {', '.join(sorted(styles))} or '#rrggbb[aa]'")
    seen = {}
    for z in ZONES:
        if z not in lay:
            continue
        groups = lay[z]
        if not isinstance(groups, list):
            p.append(f"{name}.{z}: must be a list of groups")
            continue
        for gi, g in enumerate(groups):
            where = f"{name}.{z}[{gi}]"
            if not isinstance(g, list) or not g:
                p.append(f"{where}: a group must be a non-empty list of widget ids")
                continue
            for w in g:
                if not isinstance(w, str):
                    p.append(f"{where}: widget ids must be strings")
                elif w not in ids:
                    p.append(f"{where}: unknown widget '{w}'")
                elif w in seen:
                    p.append(f"{where}: widget '{w}' is already used in {seen[w]}")
                else:
                    seen[w] = where
    return p


def check_file(path, ids, styles):
    try:
        data = json.loads(pathlib.Path(path).read_text())
    except (OSError, ValueError) as e:
        return [f"{path}: {e}"]
    if not isinstance(data, dict) or not data:
        return [f"{path}: must be a non-empty object of layouts"]
    problems = []
    for name, lay in data.items():
        problems += [f"{path}: {m}" for m in check_layout(name, lay, ids, styles)]
    return problems


def main(argv):
    try:
        ids, styles = widget_ids(), pill_styles()
    except (OSError, RuntimeError) as e:
        print(f"validate_layouts: {e}", file=sys.stderr)
        return 2
    files = argv or [str(SHELL / "config/layouts.json")]
    problems = [m for f in files for m in check_file(f, ids, styles)]
    print("\n".join(problems) if problems else f"layouts: {len(files)} file(s) ok, {len(ids)} widgets known")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
