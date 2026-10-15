#!/bin/bash

# source variables
confDir="${confDir:-$HOME/.config}"
kittyConf="${confDir}/kitty/kitty.conf"
hydeKitty="${HYDE_DATA_HOME}/kitty.conf"

INC_LINE="include hyde.conf"

# kitty.conf is often a symlink into a dotfiles repo: edit through the link (--follow-symlinks)
# and only when something has to change, so the link is never replaced by a plain copy.
if grep -q "include .*share/hyde/kitty.conf" "$kittyConf"; then
    sed -i --follow-symlinks "/include .*share\/hyde\/kitty.conf.*/d" "$kittyConf"
fi
# Ensure the line is at the top and remove duplicates
if ! grep -Fxq "$INC_LINE" "$kittyConf"; then
    sed -i --follow-symlinks "1i $INC_LINE" "$kittyConf"
fi

# Refresh kitty terminal
killall -SIGUSR1 kitty
