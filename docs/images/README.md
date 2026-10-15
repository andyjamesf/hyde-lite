# Screenshots for the README

The README keeps each image line commented out (`<!-- ![...](docs/images/<name>.png) -->`) until the file
exists, so the front page never shows a broken image. Take them on a real Hyprland session with:

```sh
tools/screenshots.sh --list          # what is still missing
tools/screenshots.sh island-launcher # one shot: set the scene, press Enter, it counts down and grabs the monitor
tools/screenshots.sh --all           # walk through every missing shot
```

The script scales to at most 1920 px wide, optimises the PNG (if `oxipng` or `optipng` is installed) and
switches the README line on. Needs `grim`; `--area` needs `slurp`. No personal data on screen (name, e-mail,
notifications). This table is the list the script reads: keep one row per shot, with the file name in
backticks in the first column.

| File | What to show |
|---|---|
| `hero.png` | the whole desktop with the Morphing Island and a couple of tiled windows over a wallpaper |
| `island-clock.png` | the island as the clock pill |
| `island-expanded.png` | the island expanded (workspaces, media, time, status) |
| `island-launcher.png` | the launcher open (`Super+A`) |
| `island-control-center.png` | the control center (`Super+Alt+C`) |
| `island-overview.png` | the workspace overview (`Super+D`) |
| `bar-islands.png` | the bar shell with the Islands layout |
| `bar-editor.png` | the bar layout editor (`qs ipc call bar edit`) |
| `colour-schemes.png` | the colour scheme picker (`Super+Shift+C`), or the same wallpaper in two schemes |
| `lock.png` | the lock screen (`Super+L`) |
| `login.png` | the SDDM login screen |
| `installer.png` | the terminal while `./install.sh` runs, showing the new header |
