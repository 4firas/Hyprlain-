#!/usr/bin/env bash

# ⌘⇧/: show the cheatsheet in a floating kitty window.
# glow renders the markdown in a pager; q closes the window.
CHEATSHEET="$HOME/.config/hypr/cheatsheet.md"

if command -v glow &>/dev/null; then
    kitty --class cheatsheet -e glow -p -w 120 "$CHEATSHEET"
else
    kitty --class cheatsheet -e less -R "$CHEATSHEET"
fi
