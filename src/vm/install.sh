#!/usr/bin/env bash
THISDIR=$(dirname "$(realpath "$0")")
source "${THISDIR}/../helper.sh"

if ! helpersourced; then
	echo -e "${RED}ERROR! Couldn't source necessary helper script.${NOCOLOR}"
	exit 1
fi

VIRT=$(systemd-detect-virt 2>/dev/null)
if [ -z "$VIRT" ] || [ "$VIRT" == "none" ]; then
	echo -e "${GREEN}Not running in a virtual machine, skipping VM tweaks.${NOCOLOR}"
	exit 0
fi
echo -e "${YELLOW}Virtual machine detected (${VIRT}), applying VM tweaks...${NOCOLOR}"

VMCONF="${HOME}/.config/hypr/vm.conf"
sudo mkdir -p "$(dirname "$VMCONF")"
{
	echo "# Written by Hyprlain's vm module; delete this file and its source line to undo."
	echo "# Virtual GPUs expose no hardware cursor plane Hyprland can use"
	echo "cursor {"
	echo "	no_hardware_cursors = true"
	echo "}"
	if [ "$ARCH" == "aarch64" ]; then
		# aarch64 VMs run on Apple Silicon Macs, where macOS keeps Command for itself
		echo "# Left Option acts as Super, since macOS keeps the Command key"
		echo "input {"
		echo "	kb_options = altwin:swap_lalt_lwin"
		echo "}"
	fi
	if ! sudo dmesg 2>/dev/null | grep -q '+virgl'; then
		# Without virgl the virtual GPU is 2D only; render through Mesa's llvmpipe instead
		echo "# No 3D acceleration from the hypervisor: software rendering"
		echo "env = LIBGL_ALWAYS_SOFTWARE,1"
		echo "decoration {"
		echo "	blur {"
		echo "		enabled = false"
		echo "	}"
		echo "}"
	fi
} | sudo tee "$VMCONF" > /dev/null
sudo chown "$USER:$USER" "$VMCONF"

HYPRCONF="${HOME}/.config/hypr/hyprland.conf"
if [ -f "$HYPRCONF" ] && ! grep -q 'hypr/vm.conf' "$HYPRCONF"; then
	echo 'source = ~/.config/hypr/vm.conf' | sudo tee -a "$HYPRCONF" > /dev/null
fi

getpkg spice-vdagent
sudo systemctl enable spice-vdagentd.service 2>/dev/null || true

echo -e "${GREEN}VM tweaks applied (${VMCONF}).${NOCOLOR}"
