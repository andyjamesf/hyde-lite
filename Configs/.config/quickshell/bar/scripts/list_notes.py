#!/usr/bin/env python3
"""List the quick notes of a folder as JSON, newest first, for the notes window.

    list_notes.py DIR

Each note: path, name (file name without .md), mtime, title (first heading or line), preview (what the
card shows) and search (the first 3000 characters, for the filter). Standard library only.
"""
import json
import pathlib
import re
import sys


def clean(line):
    """A line of Markdown as plain text, good enough for a card."""
    line = re.sub(r"^\s*(#{1,6}|[-*+]|\d+\.|>|- \[[ xX]\])\s+", "", line)
    line = re.sub(r"!?\[\[([^\]|]*\|)?([^\]]*)\]\]", r"\2", line)
    line = re.sub(r"!?\[([^\]]*)\]\([^)]*\)", r"\1", line)
    return re.sub(r"[*_`~]", "", line).strip()


def main():
    folder = pathlib.Path(sys.argv[1])
    out = []
    for f in folder.glob("*.md") if folder.is_dir() else []:
        try:
            text = f.read_text(errors="replace")[:3000]
            mtime = f.stat().st_mtime
        except OSError:
            continue
        # Obsidian properties at the top are not content.
        text = re.sub(r"\A---\n.*?\n---\n", "", text, flags=re.S)
        lines = [clean(l) for l in text.splitlines()]
        lines = [l for l in lines if l]
        out.append({
            "path": str(f),
            "name": f.stem,
            "mtime": mtime,
            "title": lines[0] if lines else f.stem,
            "preview": "\n".join(lines[1:7]),
            "search": (f.stem + "\n" + text).lower(),
        })
    out.sort(key=lambda n: n["mtime"], reverse=True)
    print(json.dumps(out))


main()
