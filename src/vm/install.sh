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
# The virtual monitor prefers 1280x800; keep a resolution the user already picked
MONITOR=$(grep -m1 '^monitor *=' "$VMCONF" 2>/dev/null)
[ -z "$MONITOR" ] && MONITOR="monitor = Virtual-1, 1920x1080@60, 0x0, 1"
{
	echo "# Written by Hyprlain's vm module; delete this file and its source line to undo."
	echo "# Any mode up to 5120x2160 works, e.g. 2560x1440@60 to match a 1440p display"
	echo "$MONITOR"
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
	if sudo dmesg 2>/dev/null | grep -q '+virgl'; then
		# virgl over UTM/QEMU's GLES host advertises only OpenGL 2.1, so apps needing 3.3
		# core (kitty, mpv) fail to start; Hyprland itself renders through GLES and is unaffected
		echo "# virgl 3D: let desktop OpenGL apps request 3.3 core"
		echo "env = MESA_GL_VERSION_OVERRIDE,3.3"
		echo "env = MESA_GLSL_VERSION_OVERRIDE,330"
	else
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
