#!/usr/bin/env python3
"""Login screen (SDDM) of the Morphing Island: installs the theme in sddm/ and keeps it matching the
island (colours, font, sizes, wallpaper, avatar).

    sddm.py install            install the theme and make it SDDM's (asks for sudo once)
    sddm.py uninstall          back to the previous SDDM theme (asks for sudo)
    sddm.py sync JSON [--dir D] copy the theme files, wallpaper and avatar and write theme.conf.user
                               from the island's values (JSON object); run by services/SddmTheme.qml
    sddm.py test [--dir D]     show the installed theme in a window (sddm-greeter --test-mode)

The theme lives in /usr/share/sddm/themes/morphing-island, owned by you after `install` (as HyDE
does with its SDDM themes), so sync needs no sudo. SDDM's own user cannot read your home, which is
why the wallpaper, avatar and font are copied there.
"""
import getpass
import glob
import json
import os
import shutil
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
SOURCE = os.path.join(os.path.dirname(HERE), "sddm")
# The Quickshell configuration the island runs from (island/ is one level down): what `qs -p` addresses.
CONFIG = os.path.dirname(os.path.dirname(HERE))
THEME_DIR = "/usr/share/sddm/themes/morphing-island"
CONF = "/etc/sddm.conf.d/zz-morphing-island.conf"
HOME = os.path.expanduser("~")
CACHE = os.environ.get("XDG_CACHE_HOME", os.path.join(HOME, ".cache"))
FONT_CANDIDATES = [
    os.path.join(HOME, ".local/share/fonts/Inter/Inter-VariableFont_opsz,wght.ttf"),
    "/usr/share/fonts/inter/InterVariable.ttf",
    "/usr/share/fonts/TTF/InterVariable.ttf",
]
# The icon font: a Nerd Font, found by pattern because releases name the file differently.
ICON_FONT_GLOBS = [
    os.path.join(HOME, ".local/share/fonts/**/JetBrainsMono*NerdFont*-Regular.ttf"),
    os.path.join(HOME, ".local/share/fonts/**/JetBrainsMonoNF*-Regular.ttf"),
    "/usr/share/fonts/**/JetBrainsMono*NerdFont*-Regular.ttf",
    "/usr/share/fonts/**/JetBrainsMonoNF*-Regular.ttf",
]


def find_icon_font():
    for pattern in ICON_FONT_GLOBS:
        found = sorted(glob.glob(pattern, recursive=True))
        if found:
            return found[0]
    return None


def out(obj):
    print(json.dumps(obj), flush=True)


def write_if_changed(path, data):
    """Writes bytes only when they differ (sync runs often; the files rarely change)."""
    try:
        with open(path, "rb") as f:
            if f.read() == data:
                return False
    except OSError:
        pass
    tmp = path + ".tmp"
    with open(tmp, "wb") as f:
        f.write(data)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)
    return True


def copy_if_changed(src, dst):
    try:
        with open(src, "rb") as f:
            return write_if_changed(dst, f.read())
    except OSError:
        return False


def copy_sources(target):
    for root, _dirs, files in os.walk(SOURCE):
        rel = os.path.relpath(root, SOURCE)
        os.makedirs(os.path.join(target, rel), exist_ok=True)
        for name in files:
            copy_if_changed(os.path.join(root, name), os.path.join(target, rel, name))


def image_copy(src, dst):
    """Copies a still image; other formats (gif, video wallpapers) become a PNG of the first frame."""
    src = os.path.realpath(src)
    if not os.path.isfile(src):
        return False
    ext = os.path.splitext(src)[1].lower()
    if ext in (".png", ".jpg", ".jpeg", ".webp", ".blur", ".bmp", "") or not shutil.which("magick"):
        return copy_if_changed(src, dst)
    tmp = dst + ".conv.png"
    ok = subprocess.run(["magick", src + "[0]", tmp], capture_output=True).returncode == 0
    if ok:
        copy_if_changed(tmp, dst)
        os.remove(tmp)
    return ok


def bundle_fonts(target):
    """Copies the UI and icon fonts into the theme and returns the keys that point at them.

    SDDM runs as its own user and cannot read your home, so a font that only lives in
    ~/.local/share/fonts is invisible to the login screen. Returns {} when neither is found, which
    leaves the theme on its font family names.
    """
    conf = {}
    font = next((f for f in FONT_CANDIDATES if os.path.isfile(f)), None)
    icon_font = find_icon_font()
    if font or icon_font:
        os.makedirs(os.path.join(target, "fonts"), exist_ok=True)
    # The destination is what decides, not copy_if_changed()'s result: that is False both when the
    # copy failed and when the file was already identical, which is the common case on a re-sync.
    for src, name, key in ((font, "Inter.ttf", "fontFile"), (icon_font, "Icons.ttf", "iconFontFile")):
        if not src:
            continue
        dst = os.path.join(target, "fonts", name)
        copy_if_changed(src, dst)
        if os.path.isfile(dst):
            conf[key] = "fonts/" + name
    return conf


def ensure_font_keys(user_conf, font_conf):
    """Adds the bundled font keys to theme.conf.user, keeping every key already in it.

    A sync writes the whole file; this only fills in what is missing, so installing over a machine
    whose island has already synced does not drop its colours, and a theme.conf.user written by an
    older version (or by a sync that found no fonts) still gets the font paths.
    """
    if not font_conf:
        return
    try:
        with open(user_conf, encoding="utf-8") as f:
            lines = f.read().splitlines()
    except OSError:
        lines = ["[General]", "# Written by sddm.py install; a sync adds the island's own settings."]
    have = {ln.split("=", 1)[0].strip() for ln in lines if "=" in ln}
    missing = [f"{k}={json.dumps(v)}" for k, v in sorted(font_conf.items()) if k not in have]
    if not missing:
        return
    at = next((i for i, ln in enumerate(lines) if ln.strip() == "[General]"), -1) + 1
    while at < len(lines) and lines[at].lstrip().startswith("#"):
        at += 1
    lines[at:at] = missing
    write_if_changed(user_conf, ("\n".join(lines) + "\n").encode())


def sync(values, target):
    if not os.path.isdir(target) or not os.access(target, os.W_OK):
        out({"ok": False, "reason": f"{target} is not installed (run: sddm.py install)"})
        return
    copy_sources(target)
    conf = {k: v for k, v in values.items() if isinstance(v, (str, int, float))}

    if image_copy(os.path.join(CACHE, "hyde/wall.set"), os.path.join(target, "background.png")) or os.path.exists(os.path.join(target, "background.png")):
        conf["wallpaper"] = "background.png"
    if image_copy(os.path.join(CACHE, "hyde/wall.blur"), os.path.join(target, "background-blur.png")) or os.path.exists(os.path.join(target, "background-blur.png")):
        conf["wallpaperBlur"] = "background-blur.png"

    face = os.path.expanduser(values.get("avatarPath", "~/.face"))
    if os.path.isfile(face):
        os.makedirs(os.path.join(target, "faces"), exist_ok=True)
        copy_if_changed(face, os.path.join(target, "faces", getpass.getuser() + ".png"))

    conf.update(bundle_fonts(target))

    # SDDM draws at 1×: the theme scales the island by the desktop's scale (focused monitor).
    try:
        mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=5).stdout)
        mon = next((m for m in mons if m.get("focused")), mons[0])
        conf["scale"] = float(mon.get("scale", 1))
    except Exception:
        pass
    conf.pop("avatarPath", None)
    lines = ["[General]", "# Written by the Morphing Island (scripts/sddm.py sync): edit the island, not this file."]
    # Strings are quoted: SDDM reads this with QSettings, which splits unquoted commas into a list.
    def ini(v):
        return json.dumps(v) if isinstance(v, str) else str(v)
    lines += [f"{k}={ini(v)}" for k, v in sorted(conf.items())]
    changed = write_if_changed(os.path.join(target, "theme.conf.user"), ("\n".join(lines) + "\n").encode())
    out({"ok": True, "changed": changed})


def sudo(*cmd):
    return subprocess.run(["sudo", *cmd]).returncode == 0


def install():
    user = getpass.getuser()
    print(f"Installing the Morphing Island login screen in {THEME_DIR} (sudo)…")
    if not (sudo("mkdir", "-p", THEME_DIR, "/etc/sddm.conf.d") and sudo("chown", "-R", f"{user}:", THEME_DIR)):
        sys.exit("sudo failed: nothing was changed.")
    copy_sources(THEME_DIR)
    # Last file in /etc/sddm.conf.d wins, hence "zz-": HyDE's the_hyde_project.conf stays untouched.
    conf = "# Morphing Island login screen. Remove this file (sddm.py uninstall) to go back.\n[Theme]\nCurrent=morphing-island\n"
    p = subprocess.run(["sudo", "tee", CONF], input=conf.encode(), stdout=subprocess.DEVNULL)
    if p.returncode != 0:
        sys.exit("Could not write " + CONF)
    # The fonts are copied here and not left to the sync below: on a fresh install no island is
    # running yet, so that IPC call is a no-op, and the theme fell back to its font family names.
    # SDDM's user cannot see ~/.local/share/fonts, so the very first login screen came up with no
    # icons and only fixed itself after the first login.
    ensure_font_keys(os.path.join(THEME_DIR, "theme.conf.user"), bundle_fonts(THEME_DIR))
    # Colours and wallpaper come from the running island, when there is one.
    subprocess.run(["qs", "-p", CONFIG, "ipc", "call", "island", "sddmSync"], capture_output=True)
    print("Done: the next login uses it. Preview: sddm.py test")


def uninstall():
    ok = sudo("rm", "-f", CONF) and sudo("rm", "-rf", THEME_DIR)
    print("Back to the previous SDDM theme." if ok else "sudo failed.")


def test(target):
    greeter = shutil.which("sddm-greeter-qt6") or shutil.which("sddm-greeter")
    os.execvp(greeter, [greeter, "--test-mode", "--theme", target])


def main():
    args = sys.argv[1:]
    target = THEME_DIR
    if "--dir" in args:
        i = args.index("--dir")
        target = args[i + 1]
        del args[i:i + 2]
    cmd = args[0] if args else ""
    if cmd == "install":
        install()
    elif cmd == "uninstall":
        uninstall()
    elif cmd == "sync":
        sync(json.loads(args[1]) if len(args) > 1 else {}, target)
    elif cmd == "test":
        test(target)
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
