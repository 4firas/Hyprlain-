#!/usr/bin/env bash
THISDIR=$(dirname "$(realpath "$0")")
GITSRC="${THISDIR}/src"
source "${THISDIR}/../helper.sh"

if ! helpersourced; then
	echo -e "${RED}ERROR! Couldn't source necessary helper script.${NOCOLOR}"
	exit 1
fi

PRODUCT_NAME=$(cat /sys/class/dmi/id/product_name 2>/dev/null)
echo -e "${YELLOW}Hardware detected: ${PRODUCT_NAME}${NOCOLOR}"

IS_MAC=0
if [[ "$PRODUCT_NAME" == MacBookPro13,* ]] || [[ "$PRODUCT_NAME" == MacBookPro14,* ]] || [ "$FORCE_MAC" == "1" ]; then
    IS_MAC=1
fi

if [ "$IS_MAC" -eq 0 ]; then
    echo -e "${YELLOW}No MacBook Pro 2016/2017 detected.${NOCOLOR}"
    # In unattended mode, we'll assume NO unless FORCE_MAC is 1 to avoid accidental driver installs on the wrong PC.
    # However, for this specific USER, they WANT it forced.
    if confirmNy "Are you preparing a portable USB for use on a MacBook?"; then
        echo -e "${GREEN}Preparing Universal/Portable MacBook fixes...${NOCOLOR}"
        IS_MAC=1
    fi
fi

if [ "$IS_MAC" -eq 1 ]; then
    echo -e "${GREEN}Applying MacBook Pro hardware fixes...${NOCOLOR}"

    # 0. Ensure Kernel Headers are installed for DKMS
    echo -e "${YELLOW}Ensuring kernel headers are installed...${NOCOLOR}"
    KERNEL_VER=$(uname -r)
    if [[ "$KERNEL_VER" == *-lts ]]; then
        getpkg linux-lts-headers
    else
        getpkg linux-headers
    fi

    # 1. Wifi Fix: Module Blacklisting & Firmware
    echo -e "${YELLOW}Configuring Wifi modules (Broadcom)...${NOCOLOR}"
    
    FW_BRCM="/lib/firmware/brcm"
    CHIP="brcmfmac43602-pcie"
    MACHINE="Apple Inc.-MacBookPro13,2"
    
    sudo mkdir -p "$FW_BRCM"
    
    # Acquire firmware configuration (.txt)
    if [ ! -f "$FW_BRCM/$CHIP.txt" ] || [ $(stat -c%s "$FW_BRCM/$CHIP.txt") -lt 100 ]; then
        echo -e "${YELLOW}Downloading Broadcom firmware configuration...${NOCOLOR}"
        sudo curl -L https://gist.githubusercontent.com/MikeRatcliffe/9614c16a8ea09731a9d5e91685bd8c80/raw/brcmfmac43602-pcie.txt -o "$FW_BRCM/$CHIP.txt"
    else
        echo -e "${GREEN}Broadcom firmware configuration already present, skipping...${NOCOLOR}"
    fi

    # Acquire binary firmware (bin/clm_blob) from official linux-firmware repo
    for ext in "bin" "clm_blob"; do
        if [ ! -f "$FW_BRCM/$CHIP.$ext" ] || grep -q "HTML" "$FW_BRCM/$CHIP.$ext" 2>/dev/null; then
            echo -e "${YELLOW}Acquiring raw binary $ext for Broadcom...${NOCOLOR}"
            sudo curl -L -o "$FW_BRCM/$CHIP.$ext" "https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git/plain/brcm/$CHIP.$ext"
        else
            echo -e "${GREEN}Raw binary $CHIP.$ext already present, skipping...${NOCOLOR}"
        fi
    done

    # Standardize names for machine-specific queries
    if [ ! -f "$FW_BRCM/$CHIP.$MACHINE.bin" ]; then
        echo -e "${YELLOW}Standardizing firmware names for MacBook model...${NOCOLOR}"
        sudo cp "$FW_BRCM/$CHIP.bin" "$FW_BRCM/$CHIP.$MACHINE.bin" 2>/dev/null
        sudo cp "$FW_BRCM/$CHIP.txt" "$FW_BRCM/$CHIP.$MACHINE.txt" 2>/dev/null
        sudo cp "$FW_BRCM/$CHIP.clm_blob" "$FW_BRCM/$CHIP.$MACHINE.clm_blob" 2>/dev/null
    fi
    
    WIFI_CONF="/etc/modprobe.d/hyprlain-mac-wifi.conf"
    if [ ! -f "$WIFI_CONF" ]; then
        sudo bash -c "cat > $WIFI_CONF <<EOF
# Blacklist conflicting modules for MacBook Broadcom chips
blacklist wl
blacklist b43
blacklist bcma
blacklist brcmsmac
# Prefer brcmfmac and disable power management for stability
options brcmfmac roamoff=1
EOF"
    fi
    echo -e "${GREEN}Wifi configuration and firmware applied.${NOCOLOR}"

    # 2. Input Fix: MacBook SPI Driver
    echo -e "${YELLOW}Checking MacBook SPI driver...${NOCOLOR}"
    getpkg "macbook12-spi-driver-dkms"
    
    # Patch the source in /usr/src for kernel 6.x compatibility
    SPI_SRC_DIR=$(ls -d /usr/src/macbook12-spi-driver-* 2>/dev/null | tail -n 1)
    if [ -n "$SPI_SRC_DIR" ]; then
        # Check if already patched by looking for our 'void' return fix
        if ! grep -q "static void appletb_platform_remove" "$SPI_SRC_DIR/apple-ib-tb.c" 2>/dev/null; then
            echo -e "${YELLOW}Patching SPI driver source in $SPI_SRC_DIR for kernel 6.x...${NOCOLOR}"
            # Fix signatures and returns
            for file in "apple-ib-tb.c" "apple-ib-als.c" "applespi.c" "apple-ibridge.c"; do
                [ ! -f "$SPI_SRC_DIR/$file" ] && continue
                sudo sed -i 's/static int appletb_platform_remove/static void appletb_platform_remove/g' "$SPI_SRC_DIR/$file"
                sudo sed -i 's/static int appleals_platform_remove/static void appleals_platform_remove/g' "$SPI_SRC_DIR/$file"
                sudo sed -i 's/static int applespi_remove/static void applespi_remove/g' "$SPI_SRC_DIR/$file"
                sudo sed -i 's/static int appleacpi_remove/static void appleacpi_remove/g' "$SPI_SRC_DIR/$file"
                sudo sed -i 's/static int appleib_remove/static void appleib_remove/g' "$SPI_SRC_DIR/$file"
                sudo sed -i '/static void .*_remove/,/}/ s/return .*;//' "$SPI_SRC_DIR/$file"
            done
            sudo sed -i 's#asm/unaligned.h#linux/unaligned.h#g' "$SPI_SRC_DIR/applespi.c"
            sudo sed -i 's/\.owner[[:space:]]*=[[:space:]]*THIS_MODULE,//g' "$SPI_SRC_DIR/apple-ibridge.c"
            sudo sed -i 's/static __u8 \*appleib_report_fixup/static const __u8 \*appleib_report_fixup/g' "$SPI_SRC_DIR/apple-ibridge.c"
            sudo sed -i 's/no_llseek/noop_llseek/g' "$SPI_SRC_DIR/applespi.c"
        else
            echo -e "${GREEN}SPI driver source already patched, skipping...${NOCOLOR}"
        fi
    fi

    # DKMS Check for SPI
    if ! dkms status -m macbook12-spi-driver -k "$(uname -r)" | grep -q "installed"; then
        echo -e "${YELLOW}Installing MacBook SPI driver via DKMS...${NOCOLOR}"
        export KCFLAGS="-Wno-error=incompatible-pointer-types"
        sudo dkms install -m macbook12-spi-driver -v 0+git.315 -k "$(uname -r)" --force || true
    else
        echo -e "${GREEN}MacBook SPI driver already installed for this kernel, skipping rebuild.${NOCOLOR}"
    fi

    # 3. Audio Fix: Cirrus Logic Driver & Model Override
    echo -e "${YELLOW}Checking Cirrus Logic Audio driver...${NOCOLOR}"
    getpkg "alsa-ucm-conf"
    getpkg "sof-firmware"
    getpkg "snd-hda-macbookpro-dkms-git" 

    # DKMS Check for Audio
    if ! dkms status -m snd-hda-macbookpro -k "$(uname -r)" | grep -q "installed"; then
        echo -e "${YELLOW}Installing Cirrus Logic Audio driver via DKMS...${NOCOLOR}"
        sudo dkms install -m snd-hda-macbookpro -v 0.1 -k "$(uname -r)" --force || true
    else
        echo -e "${GREEN}Cirrus Logic driver already installed for this kernel, skipping rebuild.${NOCOLOR}"
    fi

    AUDIO_CONF="/etc/modprobe.d/apple-audio.conf"
    if [ ! -f "$AUDIO_CONF" ]; then
        echo -e "${YELLOW}Applying Audio model overrides...${NOCOLOR}"
        sudo rm -f /etc/modprobe.d/hyprlain-mac-audio.conf
        sudo bash -c "cat > $AUDIO_CONF <<EOF
# Force macbook-pro-v1 model for CS8409 codec (MBP 13,2/13,3)
options snd-hda-intel model=macbook-pro-v1
EOF"
    fi

    # 4. TouchBar Support: tiny-dfr
    if ! systemctl is-active --quiet tiny-dfr; then
        echo -e "${YELLOW}Activating TouchBar support (tiny-dfr)...${NOCOLOR}"
        getpkg "tiny-dfr"
        sudo systemctl enable --now tiny-dfr 2>/dev/null || true
    fi

    # 5. Camera Support: bcwc-pcie
    if ! pacman -Qq bcwc-pcie-git &>/dev/null; then
        echo -e "${YELLOW}Installing FaceTime HD Camera support...${NOCOLOR}"
        getpkg "bcwc-pcie-git"
        getpkg "facetimehd-firmware"
    fi

    # 6. Thermal & Power: thermald
    if ! systemctl is-active --quiet thermald; then
        echo -e "${YELLOW}Activating Thermal management (thermald)...${NOCOLOR}"
        getpkg "thermald"
        sudo systemctl enable --now thermald 2>/dev/null || true
    fi

    # 7. Final Polish: Fix ownership of config files (only if necessary)
    if [ "$(stat -c %U "$HOME/.config")" != "l4in" ]; then
        echo -e "${YELLOW}Restoring user l4in ownership to configuration files...${NOCOLOR}"
        sudo chown -R l4in:l4in "$HOME/.config" "$HOME/Hyprlain-" 2>/dev/null || true
    fi
    echo -e "${GREEN}MacBook hardware fixes checked and applied!${NOCOLOR}"
else
    echo -e "${YELLOW}No specific MacBook Pro 2016/2017 hardware fixes required for this model.${NOCOLOR}"
fi
