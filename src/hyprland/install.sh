#!/usr/bin/env bash
THISDIR=$(dirname "$(realpath "$0")")
GITSRC="${THISDIR}/src"
source "${THISDIR}/../helper.sh"

if ! helpersourced; then
	echo -e "${RED}ERROR! Couldn't source necessary helper script.${NOCOLOR}"
	exit 1
fi

downdependencies "${GITSRC}/pacpkgs.lst" "${GITSRC}/aurpkgs.lst"
swwwcompat


getpkg zsh
if [ ! -d "${HOME}/.oh-my-zsh" ]; then
	echo -e "${YELLOW}Installing Oh-My-Zsh...${NOCOLOR}"
	handleold "$BAKORDEL" "${HOME}/.oh-my-zsh"
	RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
	echo -e "${GREEN}Oh-My-Zsh already installed, skipping...${NOCOLOR}"
fi

substitute "$BAKORDEL" "${HOME}/.config/wlogout/style.css" "${GITSRC}/wlogout/style.css"
substitute "$BAKORDEL" "${HOME}/.config/waybar/config.jsonc" "${GITSRC}/waybar/config.jsonc"
substitute "$BAKORDEL" "${HOME}/.config/waybar/power_menu.xml" "${GITSRC}/waybar/power_menu.xml"
substitute "$BAKORDEL" "${HOME}/.config/waybar/style.css" "${GITSRC}/waybar/style.css"
substitute "$BAKORDEL" "${HOME}/.config/hypr" "${GITSRC}/hypr"
substitute "$BAKORDEL" "${HOME}/.config/hypr/cheatsheet.md" "${GITSRC}/hypr/cheatsheet.md"
substitute "$BAKORDEL" "${HOME}/.config/dunst/dunstrc" "${GITSRC}/dunst/dunstrc"
substitute "$BAKORDEL" "${HOME}/.config/nwg-dock-hyprland/style.css" "${GITSRC}/nwg-dock-hyprland/style.css"
substitute "$BAKORDEL" "${HOME}/.config/waycorner/config.toml" "${GITSRC}/waycorner/config.toml"
substitute "$BAKORDEL" "${HOME}/.config/assets" "${GITSRC}/assets"

substitute "$BAKORDEL" "${HOME}/.config/neofetch/config.conf" "${GITSRC}/neofetch/config.conf"
substitute "$BAKORDEL" "${HOME}/.config/neofetch/logo" "${GITSRC}/neofetch/logo"

substitute "$BAKORDEL" "${HOME}/.config/kitty/kitty.conf" "${GITSRC}/kitty/kitty.conf"
substitute "$BAKORDEL" "${HOME}/.config/kitty/current-theme.conf" "${GITSRC}/kitty/current-theme.conf"
substitute "$BAKORDEL" "${HOME}/.config/kitty/themes/hyprlain.conf" "${GITSRC}/kitty/themes/hyprlain.conf"
substitute "$BAKORDEL" "${HOME}/.config/kitty/themes/hyprlain.conf-colors" "${GITSRC}/kitty/themes/hyprlain-colors.conf"

# Spotlight lists apps the way Launchpad does: hide the developer and system tools that come
# in as dependencies (they still run from a terminal). Delete a file to bring its app back.
HIDDENAPPS=(assistant avahi-discover bssh bvnc cmake-gui designer linguist lstopo nm-connection-editor qdbusviewer qt5ct qt6ct qv4l2 qvidcap rofi rofi-theme-selector vim wiremix xgps xgpsspeed)
mkdir -p "${HOME}/.local/share/applications"
for APP in "${HIDDENAPPS[@]}"; do
	OVERRIDE="${HOME}/.local/share/applications/${APP}.desktop"
	[ -f "/usr/share/applications/${APP}.desktop" ] && [ ! -e "$OVERRIDE" ] || continue
	printf '[Desktop Entry]\nType=Application\nName=%s\nHidden=true\n' "$APP" > "$OVERRIDE"
done

if ! grep -q "source \${HOME}/.profile" "${HOME}/.profile" 2>/dev/null && ! grep -q "export PATH" "${HOME}/.profile" 2>/dev/null; then
	cat "${GITSRC}/.profile" >> "${HOME}/.profile"
fi

DOTPROFILE_SHLINE="[[ -f ~/.profile ]] && . ~/.profile"
if ! grep -qF "$DOTPROFILE_SHLINE" "${HOME}/.bashrc" 2>/dev/null; then
	echo "$DOTPROFILE_SHLINE" >> "${HOME}/.bashrc"
fi
if ! grep -qF "$DOTPROFILE_SHLINE" "${HOME}/.zshrc" 2>/dev/null; then
	echo "$DOTPROFILE_SHLINE" >> "${HOME}/.zshrc"
fi

echo -e "${GREEN}Hyprland Hyprlain theme installed successfully.${NOCOLOR}"
