#!/usr/bin/env bash
# set -euxo pipefail

RED="\033[0;31m"
YELLOW="\033[0;33m"
GREEN="\033[0;32m"
NOCOLOR="\033[0m"

function confirmnonroot() {
	if [ "$EUID" -eq 0 ]; then
		echo -e "${RED}ERROR! Don't run the script as root, aborting.${NOCOLOR}"
		exit 1
	fi
}

function confirmonline() {
	if ! ping -c1 -w5 8.8.8.8 &> /dev/null; then
		echo -e "${RED}ERROR! System is offline, aborting.${NOCOLOR}"
		exit 1
	fi
}

function getsudo() {
	if ! command -v sudo &> /dev/null; then
		echo -e "${YELLOW}Command 'sudo' not found, installing...${NOCOLOR}"
		su -c "pacman -S --noconfirm sudo"
	fi
}

function getyay() {
	if ! command -v yay &> /dev/null; then
		echo -e "${YELLOW}Command 'yay' not found, installing...${NOCOLOR}"
		sudo pacman -S --needed --noconfirm git base-devel
		git clone --depth=1 https://aur.archlinux.org/yay.git
		cd yay
		makepkg -si --noconfirm || { echo -e "${RED}ERROR! Couldn't build yay, aborting.${NOCOLOR}"; exit 1; }
		cd ..
		rm -rf yay
	fi
}

function pause() {
	if [ -n "$AUTO_INSTALL" ]; then return 0; fi
	echo -e "${GREEN}Press Enter to continue...${NOCOLOR}"; read -rp ""
}

function _confirm() { # _confirm <TXT> <Y/N/X>
	local PROMPT="$1"
	local DEFAULT="$2"
	local CONFIRMATION

	if [ -n "$AUTO_INSTALL" ]; then
		if [[ "$DEFAULT" == "Y" ]] || [[ "$DEFAULT" == "X" ]]; then
			return 0
		elif [[ "$DEFAULT" == "N" ]]; then
			return 1
		fi
	fi

	while true; do
		read -rp "$PROMPT" CONFIRMATION
		case "$CONFIRMATION" in
			[Yy]* ) return 0;;
			[Nn]* ) return 1;;
			"" )
				if [[ "$DEFAULT" == "Y" ]]; then
					return 0
				elif [[ "$DEFAULT" == "N" ]]; then
					return 1
				fi
				;;
			* ) echo -e "${YELLOW}Please answer YES or NO.${NOCOLOR}";;
		esac
	done
}

function confirmYN() { # confirmYN <TXT>
	_confirm "$1 (Yes/No): " "X"
}

function confirmYn() { # confirmYn <TXT>
	_confirm "$1 (Y/n): " "Y"
}

function confirmNy() { # confirmNy <TXT>
	_confirm "$1 (y/N): " "N"
}

BAKORDEL="backup"
ARGUMENT="$1"
if ! [ $# -eq 0 ] && ! [ -z "$ARGUMENT" ]; then
	case "$ARGUMENT" in
		"--no-preserve")
			echo -e "${YELLOW}This option will delete all your previous configurations."
			echo -e "It may also risk affecting other associated files.${NOCOLOR}"
			if confirmNy; then
				BAKORDEL="--no-preserve"
				echo -e "${YELLOW}Proceeding by deletion.${NOCOLOR}"
			else
				echo -e "${GREEN}Aborting.${NOCOLOR}"
				exit 0
			fi
		;;

		"backup" | "--force-mac")
			;;

		*)
			echo -e "${RED}install.sh: unrecognized option '$ARGUMENT'${NOCOLOR}"
			echo
			echo -e "${YELLOW}Usage: install.sh [OPTION]"
			echo -e "Options:"
			echo -e "  --no-preserve	Replace old files by deleting them.${NOCOLOR}${RED}[DANGEROUS]${NOCOLOR}"
		;;
	esac
fi

getpkg() { # getpkg <CMD> [<PKG>]
	local CMD="$1"
	local PKG="${2:-$CMD}"

	if ! command -v "$CMD" &> /dev/null; then
		if [[ "$CMD" == "$PKG" ]]; then
			echo -e "${YELLOW}Command '${CMD}' not found, installing...${NOCOLOR}"
		else
			echo -e "${YELLOW}Command '${CMD}' not found, installing package '${PKG}'...${NOCOLOR}"
		fi
		if pacman -Si --needed --noconfirm "$PKG" &> /dev/null; then
			sudo pacman -S --noconfirm "$PKG"
		else
			yay -S --needed --noconfirm "$PKG"
		fi
	fi
}

function handleold () {
	ACTOPTION="$1"
	DIRFILE="$2"

	case "$ACTOPTION" in
		"--no-preserve")
			sudo rm -r "$DIRFILE" || true
			;;

		"backup" | "--force-mac")
			sudo rm -r "${DIRFILE}.hyprlainbak" || true
			sudo mv "$DIRFILE" "${DIRFILE}.hyprlainbak" || true
			;;

		*)
			echo -e "${RED}Unrecognized argument '$1' passed to handleold function.${NOCOLOR}"
			exit 254
		;;
	esac

	sudo mkdir -p $(dirname "$DIRFILE")
}

function substitute () {
	ACTOPTION="$1"
	DIRFILE="$2"
	GITFILE="$3"

	# If files are already identical, skip the work
	if [ -e "$DIRFILE" ] && diff -rq "$GITFILE" "$DIRFILE" &>/dev/null; then
		return 0
	fi

	handleold "$ACTOPTION" "$DIRFILE"
	sudo cp -r "$GITFILE" "$DIRFILE"
}

ARCH=$(uname -m)
# AUR packages that only repackage prebuilt x86_64 binaries (no aarch64 source)
X86_BINARY_ONLY="spotify"
# Most AUR packages marked x86_64-only build fine from source on other architectures
AURFLAGS=()
[ "$ARCH" != "x86_64" ] && AURFLAGS=(--mflags "--ignorearch")

function inrepos () {
	pacman -Si "$1" &>/dev/null
}

function resolvepkg () { # resolvepkg <PKG> -> "repo|aur|skip <NAME>"
	local PKG="$1"
	local ROFIVER
	case "$PKG" in
		swww)
			# swww was renamed awww upstream; swwwcompat keeps the old commands working
			if ! inrepos swww && inrepos awww; then echo "repo awww"; return; fi
			;;
		rofi-wayland|rofi-emoji|rofi-calc)
			if ! inrepos rofi-wayland; then
				# rofi-wayland was merged into rofi 2.x; older repos (Arch Linux ARM) still ship 1.7
				ROFIVER=$(pacman -Si rofi 2>/dev/null | awk '/^Version/ {print $3; exit}')
				if [ -n "$ROFIVER" ] && [ "$(vercmp "$ROFIVER" 2)" -ge 0 ]; then
					[ "$PKG" == "rofi-wayland" ] && { echo "repo rofi"; return; }
				else
					case "$PKG" in
						rofi-wayland) echo "aur rofi-git"; return;;
						*) echo "aur ${PKG}-git"; return;;
					esac
				fi
			fi
			;;
	esac
	if [ "$ARCH" != "x86_64" ] && [[ " $X86_BINARY_ONLY " == *" $PKG "* ]]; then
		echo "skip $PKG"; return
	fi
	if inrepos "$PKG"; then echo "repo $PKG"; else echo "aur $PKG"; fi
}

function swwwcompat () {
	# Hyprlain's wallpaper config calls swww; point it at awww where only awww exists
	local BIN
	for BIN in swww swww-daemon; do
		if ! command -v "$BIN" &> /dev/null && command -v "${BIN/swww/awww}" &> /dev/null; then
			echo -e "${YELLOW}Linking ${BIN} to ${BIN/swww/awww}...${NOCOLOR}"
			printf '#!/bin/sh\nexec %s "$@"\n' "$(command -v "${BIN/swww/awww}")" | sudo tee "/usr/local/bin/${BIN}" > /dev/null
			sudo chmod 755 "/usr/local/bin/${BIN}"
		fi
	done
}

function downdependencies () {
	PACPKGS="$1"
	AURPKGS="$2"

	# Lazy sync: only sync if not done in the last hour
	local SYNC_CACHE="/tmp/.hyprlain_pacman_sync"
	local CURRENT_TIME=$(date +%s)
	local LAST_SYNC=0
	[ -f "$SYNC_CACHE" ] && LAST_SYNC=$(cat "$SYNC_CACHE")
	
	if [ $((CURRENT_TIME - LAST_SYNC)) -gt 3600 ]; then
		echo -e "${YELLOW}Syncing pacman databases...${NOCOLOR}"
		sudo pacman -Sy && echo "$CURRENT_TIME" > "$SYNC_CACHE"
	else
		echo -e "${GREEN}Pacman databases synced recently, skipping...${NOCOLOR}"
	fi

	# Read all packages (excluding empty lines), resolve each to what this system's
	# repos carry, and skip the ones already installed
	local to_install_pacman=()
	local to_install_aur=()
	local pkg where name
	while read -r pkg; do
		read -r where name < <(resolvepkg "$pkg")
		pacman -Qq "$name" &>/dev/null && continue
		case "$where" in
			repo) to_install_pacman+=("$name");;
			aur) to_install_aur+=("$name");;
			skip) echo -e "${YELLOW}Skipping '${pkg}': no ${ARCH} build exists.${NOCOLOR}";;
		esac
	done < <(cat "$PACPKGS" "$AURPKGS" 2>/dev/null | grep -v '^[[:space:]]*$')

	# rofi from the AUR has to land before the repo packages that depend on rofi
	if printf '%s\n' "${to_install_aur[@]}" | grep -qx "rofi-git"; then
		echo -e "${YELLOW}Installing rofi-git (Wayland-capable rofi 2.x)...${NOCOLOR}"
		yay -S --needed --noconfirm --useask "${AURFLAGS[@]}" rofi-git || echo -e "${RED}Warning: rofi-git failed to install.${NOCOLOR}"
	fi

	if [ ${#to_install_pacman[@]} -gt 0 ]; then
		# Resolve known conflicts: archinstall pre-installs jack2 which conflicts with pipewire-jack
		if printf '%s\n' "${to_install_pacman[@]}" | grep -qx "pipewire-jack" && pacman -Qq jack2 &>/dev/null; then
			echo -e "${YELLOW}Removing conflicting jack2 in favour of pipewire-jack...${NOCOLOR}"
			sudo pacman -Rdd --noconfirm jack2 || true
		fi
		echo -e "${YELLOW}Installing missing PACMAN packages: ${to_install_pacman[*]}${NOCOLOR}"
		sudo pacman -S --needed --noconfirm "${to_install_pacman[@]}" || echo -e "${RED}Warning: some pacman packages failed to install.${NOCOLOR}"
	else
		echo -e "${GREEN}All local packages already installed.${NOCOLOR}"
	fi

	# AUR packages, one at a time so a single failed build doesn't stop the rest
	if [ ${#to_install_aur[@]} -gt 0 ]; then
		echo -e "${YELLOW}Installing missing AUR packages: ${to_install_aur[*]}${NOCOLOR}"
		for pkg in "${to_install_aur[@]}"; do
			pacman -Qq "$pkg" &>/dev/null && continue
			yay -S --needed --noconfirm "${AURFLAGS[@]}" "$pkg" || echo -e "${RED}Warning: AUR package '${pkg}' failed to install.${NOCOLOR}"
		done
	else
		echo -e "${GREEN}All AUR packages already installed.${NOCOLOR}"
	fi
}

function helpersourced() {
	return 0
}

confirmnonroot
confirmonline
getsudo
getyay