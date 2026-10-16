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
<sup>Forked from <a href="https://github.com/Ascaniolamp/Hyprlain">Ascaniolamp/Hyprlain</a> with Omarchy-style keybinds, robustness fixes, and a one-command installer.</sup>
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
- Builds AUR packages that are marked x86_64-only from source, and skips the ones that are only prebuilt x86 binaries (Spotify, LocalSend).
- Opens Firefox for the browser and music binds when Chrome isn't installed.

Inside any virtual machine it also writes `~/.config/hypr/vm.conf`: a software cursor, software rendering when the hypervisor offers no 3D, and on aarch64, **left Option as Super** because macOS keeps the Command key.

## 🎮 Keybinds (Omarchy-style)

Press **Super + K** to open this cheatsheet inside Hyprland at any time.

### Navigating
| Hotkey | Function |
| --- | --- |
| Super + Space | Application launcher |
| Super + Escape | Lock / suspend / restart / shutdown (wlogout) |
| Super + Ctrl + L | Lock computer |
| Super + W | Close window |
| Super + T | Toggle tiling / floating |
| Super + O | Pin window (sticky float) |
| Super + F | Fullscreen |
| Super + 1–9 | Jump to workspace |
| Super + Tab / Shift+Tab | Next / previous workspace |
| Super + Shift + 1–9 | Move window to workspace |
| Super + Arrow | Move focus |
| Super + Shift + Arrow | Swap windows |
| Super + Equal / Minus | Resize windows |
| Super + G | Toggle window grouping |
| Super + S | Scratchpad |

### System Controls
| Hotkey | Function |
| --- | --- |
| Super + Ctrl + A | Audio controls |
| Super + Ctrl + B | Bluetooth controls |
| Super + Ctrl + W | Wifi controls |
| Super + Ctrl + T | System monitor (btop) |

### Launching Apps
| Hotkey | Function |
| --- | --- |
| Super + Return | Terminal |
| Super + Shift + B | Browser |
| Super + Shift + F | File manager |
| Super + Shift + M | Music (Spotify) |

## 📦 What Gets Installed

The script automatically sets up:

- **Window Manager**: Hyprland + Waybar + Rofi + Dunst
- **Terminal**: Kitty with Oh-My-Zsh
- **Login Screen**: Custom SDDM theme
- **Boot Screen**: Lain GRUB theme
- **Theming**: Full GTK + Qt dark theme, custom icons, custom cursors
- **Apps**: Firefox, Dolphin, Spotify (with Spicetify), Vesktop (Discord)
- **Audio**: PipeWire + PipeWire-JACK (auto-resolves jack2 conflicts)
- **Wallpaper**: Animated wallpaper via swww
- **Utilities**: Screenshots, color picker, clipboard manager, idle lock

## 🙏 Credits

- **[Ascaniolamp](https://github.com/Ascaniolamp/Hyprlain)** — Original Hyprlain rice
- **[Fauux](https://fauux.neocities.org)** — All the amazing Serial Experiments Lain artwork
- **[Omarchy](https://omarchy.com)** — Keybind layout inspiration

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
