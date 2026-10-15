"""Helpers for the tests that run the plain-JavaScript parts of a .qml file in Node.

extract_function cuts `function name(...) { ... }` out of the source by matching braces, so functions that
contain nested functions or braces inside strings and regular expressions come out whole.
extract_property cuts `readonly property var name: ({ ... })`-style object literals the same way.
"""
import json
import subprocess


def _matching(src, start, open_ch, close_ch):
    """Index just past the bracket that closes the one at src[start], skipping strings, template literals,
    comments and regular expression literals (good enough for the QML in this repository)."""
    depth, i, n = 0, start, len(src)
    prev = ""  # last significant character, to tell a regex from a division
    while i < n:
        c = src[i]
        if c in "\"'`":
            q = c
            i += 1
            while i < n and src[i] != q:
                i += 2 if src[i] == "\\" else 1
        elif src.startswith("//", i):
            while i < n and src[i] != "\n":
                i += 1
            continue
        elif src.startswith("/*", i):
            i = src.index("*/", i) + 2
            continue
        elif c == "/" and prev in "(,=:[!&|?{};" + "":
            i += 1
            in_class = False
            while i < n and (src[i] != "/" or in_class):
                if src[i] == "\\":
                    i += 1
                elif src[i] == "[":
                    in_class = True
                elif src[i] == "]":
                    in_class = False
                i += 1
        elif c == open_ch:
            depth += 1
        elif c == close_ch:
            depth -= 1
            if depth == 0:
                return i + 1
        if not c.isspace():
            prev = c
        i += 1
    raise ValueError("unbalanced brackets")


def extract_function(src, name):
    start = src.index(f"    function {name}(")
    brace = src.index("{", src.index(")", start))
    return src[start:_matching(src, brace, "{", "}")].replace("    function", "function", 1)


def extract_property(src, name):
    """The right-hand side of `readonly property var NAME: <value>`, for ({...}) and [...] values."""
    start = src.index(f"property var {name}:") + len(f"property var {name}:")
    while src[start] in " \n":
        start += 1
    if src[start] == "(":
        return src[start:_matching(src, start, "(", ")")]
    return src[start:_matching(src, start, "[", "]")]


def run_node(js):
    """Run the script and parse the JSON it prints."""
    out = subprocess.run(["node", "-e", js], capture_output=True, text=True, timeout=30)
    if out.returncode != 0:
        raise RuntimeError(out.stderr)
    return json.loads(out.stdout)
