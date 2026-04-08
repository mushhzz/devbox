#!/usr/bin/env bash
#
# Build a custom Ubuntu autoinstall ISO that provisions a dev laptop
# using the Ansible playbook in this repo.
#
# Usage:
#   ./autoinstall/build-iso.sh <path-to-ubuntu-24.04-server-amd64.iso>
#
# Prerequisites:
#   sudo apt install xorriso p7zip-full
#
# Output:
#   ubuntu-autoinstall.iso in the current directory
#

set -euo pipefail

# --- Argument handling ---

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-ubuntu-server-iso>"
    echo ""
    echo "Download Ubuntu 24.04 Server first:"
    echo "  wget https://releases.ubuntu.com/24.04/ubuntu-24.04-live-server-amd64.iso"
    exit 1
fi

SOURCE_ISO="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_DIR="$(mktemp -d)"
OUTPUT_ISO="ubuntu-autoinstall.iso"

echo "============================================="
echo "  Ubuntu Autoinstall ISO Builder"
echo "============================================="
echo "  Source ISO: $SOURCE_ISO"
echo "  Output:     $OUTPUT_ISO"
echo "  Work dir:   $WORK_DIR"
echo "============================================="
echo ""

# --- Check prerequisites ---

for cmd in xorriso 7z; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "Error: '$cmd' is required. Install with:"
        echo "  sudo apt install xorriso p7zip-full"
        exit 1
    fi
done

if [[ ! -f "$SOURCE_ISO" ]]; then
    echo "Error: Source ISO not found: $SOURCE_ISO"
    exit 1
fi

if [[ ! -f "$SCRIPT_DIR/user-data" ]]; then
    echo "Error: user-data not found in $SCRIPT_DIR"
    exit 1
fi

# --- Extract ISO ---

echo "[1/4] Extracting ISO..."
7z x -o"$WORK_DIR/iso" "$SOURCE_ISO" > /dev/null

# Remove the [BOOT] catalog directory that 7z extracts
rm -rf "$WORK_DIR/iso/[BOOT]"

# --- Extract boot images from the original ISO ---

echo "[2/4] Extracting boot images..."
BOOT_DIR="$WORK_DIR/boot"
mkdir -p "$BOOT_DIR"

xorriso -osirrox on -indev "$SOURCE_ISO" \
    -extract_boot_images "$BOOT_DIR" 2>/dev/null

# --- Add autoinstall config ---

echo "[3/4] Adding autoinstall configuration..."

# Create nocloud directory on the ISO
mkdir -p "$WORK_DIR/iso/nocloud"
cp "$SCRIPT_DIR/user-data" "$WORK_DIR/iso/nocloud/user-data"
cp "$SCRIPT_DIR/meta-data" "$WORK_DIR/iso/nocloud/meta-data"

# Update GRUB config to use autoinstall
# For UEFI boot
if [[ -f "$WORK_DIR/iso/boot/grub/grub.cfg" ]]; then
    sed -i 's|---||g' "$WORK_DIR/iso/boot/grub/grub.cfg"

    # Add autoinstall entry as the default
    sed -i '/^menuentry "Try or Install Ubuntu Server"/,/^}/ {
        s|linux\t/casper/vmlinuz|linux\t/casper/vmlinuz autoinstall ds=nocloud\\;s=/cdrom/nocloud/|
    }' "$WORK_DIR/iso/boot/grub/grub.cfg"

    # Set timeout to 1 second so it boots quickly
    sed -i 's/^set timeout=.*/set timeout=1/' "$WORK_DIR/iso/boot/grub/grub.cfg"
fi

# For legacy BIOS boot (isolinux/syslinux)
if [[ -f "$WORK_DIR/iso/isolinux/txt.cfg" ]]; then
    sed -i 's|---|autoinstall ds=nocloud;s=/cdrom/nocloud/ ---|' "$WORK_DIR/iso/isolinux/txt.cfg"
fi

# --- Build the new ISO ---

echo "[4/4] Building ISO..."

# Determine the boot image paths from extracted boot catalog
MBR_IMG=""
EFI_IMG=""

# Find the MBR/BIOS boot image
if [[ -f "$BOOT_DIR/eltorito_img1_bios.img" ]]; then
    MBR_IMG="$BOOT_DIR/eltorito_img1_bios.img"
elif [[ -f "$BOOT_DIR/eltorito_img1_uefi.img" ]]; then
    MBR_IMG="$BOOT_DIR/eltorito_img1_uefi.img"
fi

# Find the EFI boot image
if [[ -f "$BOOT_DIR/eltorito_img2_uefi.img" ]]; then
    EFI_IMG="$BOOT_DIR/eltorito_img2_uefi.img"
fi

cd "$WORK_DIR/iso"

if [[ -n "$MBR_IMG" && -n "$EFI_IMG" ]]; then
    # Hybrid BIOS + UEFI ISO
    xorriso -as mkisofs \
        -r -V "Ubuntu Autoinstall" -J \
        --grub2-mbr "$MBR_IMG" \
        -partition_offset 16 \
        --mbr-force-bootable \
        -append_partition 2 28732ac11ff8d211ba4b00a0c93ec93b "$EFI_IMG" \
        -appended_part_as_gpt \
        -iso_mbr_part_type a2a0d0ebe5b9334487c068b6b72699c7 \
        -c '/boot.catalog' \
        -b '/boot/grub/i386-pc/eltorito.img' \
        -no-emul-boot -boot-load-size 4 -boot-info-table --grub2-boot-info \
        -eltorito-alt-boot \
        -e '--interval:appended_partition_2:::' \
        -no-emul-boot \
        -o "$OLDPWD/$OUTPUT_ISO" \
        . 2>/dev/null
elif [[ -n "$MBR_IMG" ]]; then
    # BIOS-only fallback
    xorriso -as mkisofs \
        -r -V "Ubuntu Autoinstall" -J \
        -b boot/grub/i386-pc/eltorito.img \
        -no-emul-boot -boot-load-size 4 -boot-info-table \
        -o "$OLDPWD/$OUTPUT_ISO" \
        . 2>/dev/null
else
    echo "Error: Could not find boot images in the source ISO."
    echo "Contents of $BOOT_DIR:"
    ls -la "$BOOT_DIR"
    exit 1
fi

cd "$OLDPWD"

# --- Cleanup ---

rm -rf "$WORK_DIR"

echo ""
echo "============================================="
echo "  Done! ISO created: $OUTPUT_ISO"
echo "============================================="
echo ""
echo "Next steps:"
echo "  1. Flash to USB:  sudo dd if=$OUTPUT_ISO of=/dev/sdX bs=4M status=progress"
echo "     Or use Balena Etcher / Ventoy"
echo "  2. Boot the target machine from the USB"
echo "  3. Installation is fully automatic"
echo "  4. After first boot, open Intune app to complete enrollment"
echo ""
echo "Default credentials:"
echo "  User:     dev"
echo "  Password: changeme"
echo ""
