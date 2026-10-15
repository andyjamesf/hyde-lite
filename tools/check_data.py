#!/usr/bin/env python3
"""Parse every tracked TOML and JSON file and check dots `include` lists.

Called by tools/check.sh with the repository root as argument; prints one line
per problem and exits 1 if there is any.
"""
import json
import subprocess
import sys
import tomllib
from pathlib import Path

# Config files that are JSON with comments, which is what the editors read.
JSONC_DIRS = ("Configs/.config/Code", "Configs/.config/VSCodium")


def strip_jsonc(text):
    """Remove // and /* */ comments and trailing commas, leaving strings alone."""
    out, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                j += 2 if text[j] == "\\" else 1
            out.append(text[i : j + 1])
            i = j + 1
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            if end < 0:
                # Unterminated: keep the text so json.loads rejects the file.
                out.append(text[i:])
                break
            out.append(" ")  # keep token boundaries: 1/*x*/2 must not become 12
            i = end + 2
        else:
            out.append(c)
            i += 1
    cleaned = "".join(out)
    result, k = [], 0
    while k < len(cleaned):
        c = cleaned[k]
        if c == '"':
            j = k + 1
            while j < len(cleaned) and cleaned[j] != '"':
                j += 2 if cleaned[j] == "\\" else 1
            result.append(cleaned[k : j + 1])
            k = j + 1
            continue
        if c == ",":
            rest = cleaned[k + 1 :].lstrip()
            if rest[:1] in ("}", "]"):
                k += 1
                continue
        result.append(c)
        k += 1
    return "".join(result)


def main(root):
    root = Path(root)
    files = subprocess.run(
        ["git", "-C", str(root), "ls-files", "-z"], capture_output=True, check=True
    ).stdout.decode().split("\0")
    problems, counts = [], {"toml": 0, "json": 0, "include": 0}

    for rel in filter(None, files):
        path = root / rel
        if not path.is_file():
            continue
        if rel.endswith(".toml"):
            counts["toml"] += 1
            try:
                data = tomllib.loads(path.read_text(encoding="utf-8"))
            except (tomllib.TOMLDecodeError, UnicodeDecodeError) as e:
                problems.append(f"{rel}: TOML: {e}")
                continue
            for inc in data.get("global", {}).get("include", []):
                counts["include"] += 1
                # dots-groups use paths relative to the file, dots.toml relative to the root
                base = root if rel == "dots.toml" else path.parent
                if not (base / inc).is_file():
                    problems.append(f"{rel}: include not found: {inc}")
        elif rel.endswith(".json"):
            counts["json"] += 1
            try:
                text = path.read_text(encoding="utf-8")
                if rel.startswith(JSONC_DIRS):
                    text = strip_jsonc(text)
                json.loads(text)
            except (json.JSONDecodeError, UnicodeDecodeError) as e:
                problems.append(f"{rel}: JSON: {e}")

    for p in problems:
        print(p)
    print(
        f"data: {counts['toml']} toml, {counts['json']} json, "
        f"{counts['include']} includes, {len(problems)} problems"
    )
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "."))
