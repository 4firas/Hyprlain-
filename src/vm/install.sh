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
# The virtual monitor prefers 1280x800; keep a resolution the user already picked,
# including from the backup the hyprland module makes when it replaces ~/.config/hypr
MONITOR=$(grep -m1 -h '^monitor *=' "$VMCONF" "${HOME}/.config/hypr.hyprlainbak/vm.conf" 2>/dev/null | head -1)
[ -z "$MONITOR" ] && MONITOR="monitor = Virtual-1, 1920x1080@60, 0x0, 1"
{
	echo "# Written by Hyprlain's vm module; delete this file and its source line to undo."
	echo "# Any mode up to 5120x2160 works, e.g. 2560x1440@60 to match a 1440p display"
	echo "$MONITOR"
	echo "# Virtual GPUs expose no hardware cursor plane Hyprland can use"
	echo "cursor {"
	echo "	no_hardware_cursors = true"
	echo "}"
	# While UTM captures input, the host's pointer movement (already accelerated by macOS)
	# arrives through a relative USB mouse in host points; scale it to the guest's pixels,
	# about 1.75 for 2560 pixels across a 1470-point MacBook display, without accelerating again
	echo "# Captured pointer: linear, and as fast as on the host"
	echo "device {"
	echo "	name = qemu-qemu-usb-mouse"
	echo "	accel_profile = flat"
	echo "	sensitivity = 0.75"
	echo "}"
	# Clipboard shared with the host through the SPICE agent
	echo "exec-once = ~/.config/hypr/scripts/vm-clipboard"
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

# hypridle suspends after 30 idle minutes; a suspended guest drops off the network and
# the hypervisor window doesn't wake it reliably. Locking and screen-off still apply.
sudo install -d /etc/systemd/sleep.conf.d
printf '[Sleep]\nAllowSuspend=no\nAllowHibernation=no\nAllowHybridSleep=no\nAllowSuspendThenHibernate=no\n' | sudo tee /etc/systemd/sleep.conf.d/10-hyprlain-vm.conf > /dev/null

# UTM's QEMU on Apple silicon hangs when the guest resets itself, so a reboot never comes
# back. Keep the installed kernel loaded for kexec: systemctl reboot then starts it directly
# without going through the hypervisor reset. A pacman hook reloads it after kernel updates.
if [ "$(uname -m)" == "aarch64" ] && [ -f /boot/Image ]; then
	getpkg kexec kexec-tools
	sudo tee /etc/systemd/system/hyprlain-kexec-load.service > /dev/null <<- 'EOF'
		[Unit]
		Description=Load the installed kernel so reboots skip the hypervisor reset (Hyprlain vm module)
		ConditionPathExists=/boot/Image
		ConditionPathExists=/boot/initramfs-linux.img

		[Service]
		Type=oneshot
		RemainAfterExit=yes
		ExecStart=/usr/bin/kexec --load /boot/Image --initrd=/boot/initramfs-linux.img --reuse-cmdline

		[Install]
		WantedBy=multi-user.target
	EOF
	sudo install -d /etc/pacman.d/hooks
	# Runs after 90-mkinitcpio-install.hook has rebuilt the initramfs
	sudo tee /etc/pacman.d/hooks/95-hyprlain-kexec.hook > /dev/null <<- 'EOF'
		[Trigger]
		Type = Path
		Operation = Install
		Operation = Upgrade
		Target = boot/Image
		Target = usr/lib/modules/*/vmlinuz
		Target = usr/lib/initcpio/*

		[Action]
		Description = Reloading the kernel for kexec reboots...
		When = PostTransaction
		Exec = /usr/bin/systemctl restart hyprlain-kexec-load.service
	EOF
	sudo systemctl daemon-reload
	sudo systemctl enable --now hyprlain-kexec-load.service
fi

getpkg spice-vdagent
getpkg xclip
getpkg clipnotify
sudo systemctl enable spice-vdagentd.service 2>/dev/null || true

echo -e "${GREEN}VM tweaks applied (${VMCONF}).${NOCOLOR}"
