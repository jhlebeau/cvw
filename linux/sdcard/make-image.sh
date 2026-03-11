#!/bin/bash
###########################################
## make-image.sh
##
## Written: Jacob Pease jacobpease@protonmail.com
## Created: August 22, 2023
## Edited: Justin Lebeau & Google Gemini
## Edited: January 29th, 2026
##
## Purpose: Generate a bootable Linux image for CORE-V-WALLY RISC-V project.
###########################################

# Exit on any error (return code != 0)
set -e

usage() { echo "Usage: $0 [-zh] [-b <path/to/buildroot>] [-d <dtb>] [-o <output/file>] <device>" 1>&2; exit 1; }

help() {
    echo "Usage: $0 [OPTIONS] <device>"
    echo "  -z                        wipes card with zeros"
    echo "  -b <path/to/buildroot>      get images from given buildroot"
    echo "  -d <device tree binary>    specify .dtb file to use"
    echo "  -o <output/file/path>      create a disk image file instead of writing to a device"
    exit 0;
}

# Output colors
BOLDRED="\e[1;91m"
BOLDGREEN="\e[1;32m"
BOLDYELLOW="\e[1;33m"
NC="\e[0m"
NAME="$BOLDGREEN"${0:2}:"$NC"
ERRORTEXT="$BOLDRED"ERROR:"$NC"

# Default values
BUILDROOT=$RISCV/buildroot
DEVICE_TREE=wally-vcu108.dtb
MNT_DIR=wallyimg
OUTPUT_FILE=""

# 1. Process options (Fixed getopts to include o:)
ARGS=()
while [ $OPTIND -le "$#" ] ; do
    if getopts "hzb:d:o:" arg ; then
        case "${arg}" in
            h) help ;;
            z) WIPECARD=y ;;
            b) BUILDROOT=${OPTARG} ;;
            d) DEVICE_TREE=${OPTARG} ;;
            o) OUTPUT_FILE=${OPTARG} ;;
        esac
    else
        ARGS+=("${!OPTIND}")
        ((OPTIND++))
    fi
done

IMAGES=$BUILDROOT/output/images
FW_JUMP=$IMAGES/fw_jump.bin
LINUX_KERNEL=$IMAGES/Image
SDCARD=${ARGS[0]}

# Determine initial target
if [ -n "$OUTPUT_FILE" ]; then
    TARGET=$OUTPUT_FILE
else
    TARGET=$SDCARD
fi

# 2. Error Checks
if [ -z "$TARGET" ]; then usage; fi

if [ ! -e "$DEVICE_TREE" ]; then
    echo -e "$NAME $ERRORTEXT Device tree file '$DEVICE_TREE' not found."
    exit 1
fi

if [ ! -d "$IMAGES" ] || [ ! -e "$FW_JUMP" ] || [ ! -e "$LINUX_KERNEL" ]; then
    echo -e "$NAME $ERRORTEXT Missing Buildroot images in $IMAGES"
    exit 1
fi

# 3. Calculate Math
DST_SIZE=$(ls -la --block-size=512 $DEVICE_TREE | cut -d' ' -f 5 ) 
FW_JUMP_SIZE=$(ls -la --block-size=512 $FW_JUMP | cut -d' ' -f 5 )
KERNEL_SIZE=$(ls -la --block-size=512 $LINUX_KERNEL | cut -d' ' -f 5 )

FW_JUMP_START=$(( 34 + $DST_SIZE ))
KERNEL_START=$(( $FW_JUMP_START + $FW_JUMP_SIZE ))
FS_START=$(( $KERNEL_START + $KERNEL_SIZE ))

echo -e "$NAME Device tree blocks:   $DST_SIZE"
echo -e "$NAME OpenSBI blocks:       $FW_JUMP_SIZE"
echo -e "$NAME Kernel blocks:        $KERNEL_SIZE"

read -p $'\e[1;33mWarning:\e[0m This will replace ALL data on the target. Continue? y/n: ' -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then exit 1; fi

# 4. Handle Image File vs Device Logic
LOOPDEVICE=""
if [ -n "$OUTPUT_FILE" ]; then
    echo -e "$NAME Creating disk image file..."
    FS_MIN_SIZE=409600 # ~200MB
    TOTAL_SIZE=$(( $FS_START + $FS_MIN_SIZE + 2048 )) # +2048 for GPT backup padding
    
    # Create/Overwrite the file
    truncate -s $(( $TOTAL_SIZE * 512 )) "$OUTPUT_FILE"
    
    # Force the file to be world-writable for a second to ensure loop device picks it up correctly
    chmod 666 "$OUTPUT_FILE"

    # Set up loop device. Added --read-only=0 to ensure it's RW
    LOOPDEVICE=$(sudo losetup -fP --show "$OUTPUT_FILE")
    TARGET=$LOOPDEVICE
    PART_PREFIX="p"
else
    # Device logic
    if [[ $TARGET == "/dev/sd"* ]]; then PART_PREFIX=""; else PART_PREFIX="p"; fi
    CHECKMOUNT=$(lsblk | grep "$(basename $TARGET)${PART_PREFIX}4" | tr -s ' ' | cut -d' ' -f 7 || true)
    if [ -n "$CHECKMOUNT" ]; then sudo umount -v $CHECKMOUNT; fi
    
    if [ "$WIPECARD" == "y" ]; then
        echo -e "$NAME Wiping target..."
        sudo dd if=/dev/zero of=$TARGET bs=64k status=progress conv=fsync
    fi
fi

# 5. Partitioning
echo -e "$NAME Creating GPT..."
# Removed the manual dd line that was causing "Operation not permitted"
sudo sgdisk -z $TARGET
sudo sgdisk -g --clear --set-alignment=1 \
    --new=1:34:+$DST_SIZE --change-name=1:'fdt' \
    --new=2:$FW_JUMP_START:+$FW_JUMP_SIZE --change-name=2:'opensbi' --typecode=2:2E54B353-1271-4842-806F-E436D6AF6985 \
    --new=3:$KERNEL_START:+$KERNEL_SIZE --change-name=3:'kernel' \
    --new=4:$FS_START:-0 --change-name=4:'filesystem' \
    $TARGET

sudo partprobe $TARGET
echo -e "$NAME Waiting for partitions..."
MAX_RETRIES=5
COUNT=0
while [ ! -e "${TARGET}${PART_PREFIX}4" ] && [ $COUNT -lt $MAX_RETRIES ]; do
    sleep 1; ((COUNT++))
done

# 6. Binary Copying (Direct to RAW TARGET via offsets)
RAW_TARGET=$TARGET
if [ -n "$OUTPUT_FILE" ]; then RAW_TARGET=$OUTPUT_FILE; fi

echo -e "$NAME Copying binaries..."
DD_OPTS="bs=512 conv=notrunc status=progress"
sudo dd if=$DEVICE_TREE of=$RAW_TARGET $DD_OPTS seek=34 count=$DST_SIZE
sudo dd if=$FW_JUMP of=$RAW_TARGET $DD_OPTS seek=$FW_JUMP_START count=$FW_JUMP_SIZE
sudo dd if=$LINUX_KERNEL of=$RAW_TARGET $DD_OPTS seek=$KERNEL_START count=$KERNEL_SIZE
sync

# 7. Filesystem Setup
FS_TARGET="${TARGET}${PART_PREFIX}4"
echo -e "$NAME Formatting $FS_TARGET..."
sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 "$FS_TARGET"
sudo mkdir -p /mnt/$MNT_DIR
sudo mount "$FS_TARGET" /mnt/$MNT_DIR

# (Place for file copies if needed)

echo -e "$NAME Cleaning up..."
sudo umount /mnt/$MNT_DIR
sudo rmdir /mnt/$MNT_DIR
if [ -n "$LOOPDEVICE" ]; then sudo losetup -d $LOOPDEVICE; fi

echo -e "\n$NAME Done. GPT Status:"
sudo sgdisk -p "$TARGET_REPORT" 2>/dev/null || sudo sgdisk -p "$OUTPUT_FILE"