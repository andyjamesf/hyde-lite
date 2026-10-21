# Troubleshooting

## Quickshell uses too much CPU

A shell that is quiet at start-up and later keeps a core busy for no visible reason is the hardest kind of
problem: it starts on its own and a restart cures it. The way to deal with it is to catch it in the act, then
read what it was saying. Everything below was used on a real runaway Morphing Island; the commands are the ones
that worked.

### 1. See that it is the shell, and which thread

```sh
top -b -n1 | head -15                      # is `qs` the one at ~100 %?
PID=$(pgrep -f 'qs -p .*/quickshell$' | head -1)   # the island; the bar UI runs as a plain `qs`
ps -o pid,etime,time,rss,nlwp,args -p $PID # which shell, since when, how many threads (about 22 is normal)
top -H -b -n1 -p $PID | head -14           # which thread: a render thread, or the main one
```

### 2. Leave a watcher running

`tools/qs-watch.sh` samples the CPU of the shell every 15 s and, when it stays above 60 % twice in a row, saves a
snapshot (threads sorted by CPU, children, open files, the most repeated log lines, the last log lines) to
`~/qs-snap-*.txt`:

```sh
nohup tools/qs-watch.sh >/dev/null 2>&1 &
tail ~/qs-watch.log                        # one line per sample
```

Options: `--threshold`, `--hits`, `--interval`, `--window`, `--out`, `--max-loops`; see `--help`.

### 3. Read the log of the instance that was running

Every Quickshell instance writes a log, and the logs of earlier instances stay until you log out:

```sh
ls -lt /run/user/$UID/quickshell/by-id/*/log.qslog     # a runaway shows up as a very large one (tens of MB)
qs log /run/user/$UID/quickshell/by-id/<ID>/log.qslog | sed 's/^[0-9: .-]*//' | sort | uniq -c | sort -rn | head -20
qs log -t 25 <the same file>                           # its last lines
qs log -r '*.debug=true' <file>                        # also the debug messages
```

The file is a positional argument of `qs log` (there is no `--file`). A line repeated tens of thousands of times
is the clue. Messages you will meet:

| Message | Meaning |
|---|---|
| `OSD storm: "mic" has been requested without a 1.5 s pause for 20 s; ignoring it until it stops` | something other than a person keeps changing that value (an app moving the microphone gain, a flapping brightness); the island ignores its OSD until it stops. The name tells you which one. |
| `qt.qpa.wayland.textinput ... Trying to disable ... but ... is focused` | Qt's input-method plumbing, printed when a window's keyboard focus keeps going in and out. A flood of them means the island is changing state over and over. |
| `Binding loop detected for property ...` | a QML binding that depends on itself; the line names the file. |
| `QML Image ...: Cannot open: file:///...` | an image that is gone (an old screenshot, a deleted wallpaper); harmless. |
| `calendar: ... Temporary failure in name resolution` | no network at that moment; harmless. |

### 4. Watching what it launches

```sh
sudo timeout -s INT 60 strace -f -tt -e trace=execve -s 200 -p $PID -o /tmp/qs-exec.txt
grep execve /tmp/qs-exec.txt | sed 's/.*execve("\([^"]*\)".*/\1/' | sort | uniq -c | sort -rn | head
```

A quiet shell launches a handful of programs a minute (`nmcli`, `readlink`, ...). `strace -f` also prints
`Process N attached` for every new **thread**, so a burst of those is not a burst of programs; only `execve` lines
are programs.

Pitfalls, all met in practice:

- Only one `strace` can attach to a process. A second one fails with `already being traced by pid N`; stop the
  first (`sudo kill -INT N`) and check with `pgrep -a strace`. While attached it slows the shell down, so never leave
  one running.
- `sudo kill -INT %1` does not work: `%1` is your shell's job number and the `kill` that `sudo` runs does not know
  it. Use `timeout -s INT 60 strace ...` as above, or the real PID.
- Use `timeout` rather than `Ctrl-C` when you have several commands on the line: `Ctrl-C` cancels the lines after it.

### 5. Restart it

```sh
island off && island on      # or: systemctl --user restart morphing-island.service
```

## Seen so far

- 2026-10-15, Morphing Island: one core at 92 % for hours with nothing happening, a 29 MB log dominated by
  `textinput` warnings. A restart cured it and it has not been seen again. The cause is not known; the storm guard
  above and the watcher exist to name it the next time.
