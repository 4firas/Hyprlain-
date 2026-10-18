#!/usr/bin/env bash
THISDIR=$(dirname "$(realpath "$0")")
GITSRC="${THISDIR}/src"
source "${THISDIR}/../helper.sh"

if ! helpersourced; then
	echo -e "${RED}ERROR! Couldn't source necessary helper script.${NOCOLOR}"
	exit 1
fi

echo -e "${YELLOW}Downloading every theme's relative application...${NOCOLOR}"
downdependencies "${GITSRC}/pacpkgs.lst" "${GITSRC}/aurpkgs.lst"

substitute "$BAKORDEL" "${HOME}/.local/share/audacious/Skins/lainampborders" "${GITSRC}/audacious/lainampborders"
if ! grep -q "skin=" "${GITSRC}/audacious/config" 2>/dev/null; then
	echo "skin=${HOME}/.local/share/audacious/Skins/lainampborders" >> "${GITSRC}/audacious/config"
fi
substitute "$BAKORDEL" "${HOME}/.config/audacious/config" "${GITSRC}/audacious/config"

echo -e "${YELLOW}To install the Firefox theme, follow the README's instructions!${NOCOLOR}"

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

# Lain GRUB theme from uiriansan/LainGrubTheme at a pinned commit, only where GRUB boots the system.
# Its patch_entries.sh is left out: it edits the grub package's own /etc/grub.d scripts and renames
# 30_os-prober, so the next grub update brings that file back and boot entries show up twice.
GRUBTHEME_COMMIT="1cf38e3b46e26cfd9166613bb49669f27efab12c"
setgrub() { # setgrub <KEY> <VALUE>: set a variable in /etc/default/grub, commented out or not
	if sudo grep -qE "^#?[[:space:]]*$1=" /etc/default/grub; then
		sudo sed -i -E "s|^#?[[:space:]]*$1=.*|$1=$2|" /etc/default/grub
	else
		echo "$1=$2" | sudo tee -a /etc/default/grub > /dev/null
	fi
}
if [ -f /etc/default/grub ] && [ -d /boot/grub ] && command -v grub-mkconfig &> /dev/null; then
	getpkg git
	GRUBTHEME_TMP=$(mktemp -d)
	if git -C "$GRUBTHEME_TMP" init -q && git -C "$GRUBTHEME_TMP" fetch -q --depth=1 https://github.com/uiriansan/LainGrubTheme "$GRUBTHEME_COMMIT" && git -C "$GRUBTHEME_TMP" checkout -q FETCH_HEAD; then
		GRUBDEFAULTS=$(sudo cat /etc/default/grub)
		sudo install -d /boot/grub/themes
		sudo rm -rf /boot/grub/themes/lain
		sudo cp -r "${GRUBTHEME_TMP}/lain" /boot/grub/themes/lain
		setgrub GRUB_THEME '"/boot/grub/themes/lain/theme.txt"'
		# The theme is laid out for 1920x1080; firmware without that mode picks its own
		setgrub GRUB_GFXMODE "1920x1080,auto"
		# In a VM the firmware's own boot entries (UEFI shell, UiApp...) only crowd the menu;
		# on real hardware they can be another OS, so they stay
		systemd-detect-virt -q && setgrub GRUB_DISABLE_BOOTNEXT true
		# grub-mkconfig only replaces grub.cfg once the new one checks out
		if [ "$GRUBDEFAULTS" != "$(sudo cat /etc/default/grub)" ] || ! sudo grep -q "themes/lain/theme.txt" /boot/grub/grub.cfg; then
			sudo grub-mkconfig -o /boot/grub/grub.cfg
		fi && echo -e "${GREEN}Lain GRUB theme installed.${NOCOLOR}" ||
			echo -e "${RED}grub-mkconfig failed, so the boot menu keeps its previous configuration.${NOCOLOR}"
	else
		echo -e "${RED}Couldn't download the Lain GRUB theme, skipping it.${NOCOLOR}"
	fi
	rm -rf "$GRUBTHEME_TMP"
else
	echo -e "${YELLOW}GRUB isn't the bootloader here, skipping the Lain GRUB theme.${NOCOLOR}"
fi

echo -e "${GREEN}Hyprlain dotfiles installed successfully.${NOCOLOR}"