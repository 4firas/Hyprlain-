<div align="center">
<img src="./logo.svg" alt="banner">
<br>
<img alt="Hyprland" src="https://img.shields.io/badge/hyprland-tested-blue?style=for-the-badge&logo=hyprland&logoColor=C1B48E&logoSize=auto&labelColor=000000&color=CE7688">
<img alt="Arch Linux" src="https://img.shields.io/badge/arch-tested-blue?style=for-the-badge&logo=archlinux&logoColor=C1B48E&logoSize=auto&labelColor=000000&color=CE7688">
<a href="./LICENSE">
	<img alt="License" src="https://img.shields.io/github/license/4firas/Hyprlain-?style=for-the-badge&logo=gplv3&logoColor=C1B48E&logoSize=auto&labelColor=000000&color=CE7688">
</a>
<br><br>
A complete Hyprland rice for Arch Linux inspired by Serial Experiments Lain.
<br>
<sup>Forked from <a href="https://github.com/Ascaniolamp/Hyprlain">Ascaniolamp/Hyprlain</a> with a Mac-style keyboard and desktop, robustness fixes, and a one-command installer.</sup>
<br>
<hr>
<img src="./src/hyprland/cmdwired.gif" width="400">
<img src="./src/hyprland/background.gif" width="400">
<img src="./src/gtkqtxdg/qtshowcase.png" width="400">
<img src="./src/gtkqtxdg/gtkshowcase.png" width="400">
<img src="./src/sddm/showcase.gif" width="400">
<img src="./src/dotfiles/firefox.gif" width="400">
</div>

## ⚡ One-Command Install

On a fresh **Arch Linux** install with the **Hyprland** profile selected during `archinstall`, open a terminal and run:
```sh
sudo pacman -Syu --needed git && git clone https://github.com/4firas/Hyprlain-.git && cd Hyprlain- && bash auto-install.sh
```

That's it. Reboot when it finishes and you're done.

> **Already installed?** To pull config updates and re-apply, just:
> ```sh
> cd ~/Hyprlain- && git pull && bash auto-install.sh
> ```
> The script is fully idempotent — it skips everything already installed and only applies new changes.

## 🍎 ARM64 and Apple Silicon (UTM)

The same command works on **Arch Linux ARM** (aarch64), including a UTM virtual machine on an Apple Silicon Mac. On ARM the installer:

- Swaps in the packages Arch Linux ARM actually ships: `rofi-git` (rofi 2.x with Wayland) for `rofi-wayland`, the `-git` rofi plugins to match it, and `awww` for `swww` (renamed upstream, with `swww` commands kept working).
- Builds AUR packages that are marked x86_64-only from source, and skips the ones that are only prebuilt x86 binaries (Spotify).
- Opens Firefox for the browser and music binds when Chrome isn't installed.

Inside any virtual machine it also writes `~/.config/hypr/vm.conf`: a software cursor, OpenGL 3.3 for apps on virgl (or software rendering when the hypervisor offers no 3D), and a clipboard shared with the host through the SPICE agent. On aarch64 it keeps the kernel loaded for kexec, because UTM hangs when the guest resets itself: restarting goes straight into the new boot instead.

UTM passes ⌘ shortcuts to the guest only while it captures input; otherwise ⌘Space, ⌘Tab and the rest go to macOS, and ⌘Q, ⌘W, ⌘H go to UTM's own menus. In UTM → **Settings → Input**, turn on both **Capture input automatically when entering full screen** and **…when window is focused**: clicking into the VM then captures, and ⌃⌥ hands the keyboard and pointer back to macOS (press it again to return). That's also why no Hyprlain shortcut holds ⌃ and ⌥ together, and why lock and log out have no shortcut (⌃⌘Q and ⇧⌘Q would hit macOS whenever input isn't captured). Leave **Use Command+Option (⌘+⌥) for input capture/release** off, since Hyprlain uses ⌥⌘ shortcuts.

## ⌨️ Works like a Mac

⌘ is Command, ⌥ Option, ⌃ Control. The everyday shortcuts are the macOS ones in every app, the terminal included: ⌘C, ⌘V, ⌘Z, ⌘F, ⌘T, ⌘W, ⌥ and ⌘ arrows through text, ⌥⌫ and ⌘⌫. Press **⌘⇧/** in Hyprlain for the full cheatsheet.

| Keys | What it does |
| --- | --- |
| ⌘ Space | Spotlight |
| ⌘Tab | App switcher: tap for the last app, hold ⌘ to pick one |
| ⌘Q, ⌘H, ⌘M | Quit, hide, minimise |
| ⌥⌘⎋ | Force Quit |
| ⌃↑ or the bottom-left corner | Mission Control |
| ⌃←, ⌃→ | Previous or next desktop |
| ⌘⇧3, ⌘⇧4, ⌘⇧5 | Screenshot the screen, an area, a window (add ⌃ to copy) |
| ⌘⇧V | Clipboard history |
| ⌃ Space | Next input source |

The menu bar shows the Lain menu (About, Force Quit, Lock, Log Out, Restart, Shut Down…) and the focused app's name, and the Dock appears when the pointer reaches the bottom edge. Windows tile instead of overlapping: ⌥⌘F floats one.

## 📦 What Gets Installed

The script automatically sets up:

- **Desktop**: Hyprland + Waybar menu bar + Rofi Spotlight + nwg-dock Dock + Dunst, with a ⌘Tab switcher and Mission Control
- **Terminal**: Kitty with Oh-My-Zsh
- **Login Screen**: Custom SDDM theme
- **Boot Screen**: Lain GRUB theme (where GRUB is the bootloader)
- **Theming**: Full GTK + Qt dark theme, custom icons, custom cursors
- **Apps**: Firefox, Nautilus, Spotify (with Spicetify), Vesktop (Discord)
- **Audio**: PipeWire + PipeWire-JACK (auto-resolves jack2 conflicts)
- **Wallpaper**: Animated wallpaper via swww
- **Utilities**: Screenshots, color picker, clipboard manager, idle lock

## 🙏 Credits

- **[Ascaniolamp](https://github.com/Ascaniolamp/Hyprlain)** — Original Hyprlain rice
- **[Fauux](https://fauux.neocities.org)** — All the amazing Serial Experiments Lain artwork

## License

<div align="center">
<strong>⚠️ I DO NOT OWN ANY RIGHTS TO THE GRAPHICS AND SOUNDS USED IN THIS PROJECT ⚠️</strong><br>
<strong>THEY'RE THE PROPERTY OF THEIR CORRESPONDING OWNERS</strong><br>
<sub>
This is a fanmade project inspired by Serial Experiments Lain.
All characters, images, logos, and stylistic elements are the intellectual property of their respective rights holders.
This project is shared for non-commercial, educational, and entertainment purposes under fair use.
</sub>
</div>
<br>

This project is licensed under the [GPLv3.0 license](./LICENSE).
