#!/usr/bin/env bash
THISDIR=$(dirname "$(realpath "$0")")
GITSRC="${THISDIR}/src"
source "${THISDIR}/../helper.sh"

if ! helpersourced; then
	echo -e "${RED}ERROR! Couldn't source necessary helper script.${NOCOLOR}"
	exit 1
fi

downdependencies "${GITSRC}/pacpkgs.lst" "${GITSRC}/aurpkgs.lst"

substitute "$BAKORDEL" "${HOME}/.config/rofi/themes/Hyprlain.rasi" "${GITSRC}/Hyprlain.rasi"
substitute "$BAKORDEL" "${HOME}/.config/rofi/config.rasi" "${GITSRC}/config.rasi"
substitute "$BAKORDEL" "${HOME}/.config/rofi/spotlight.rasi" "${GITSRC}/spotlight.rasi"

echo -e "${GREEN}Rofi Hyprlain theme installed successfully.${NOCOLOR}"