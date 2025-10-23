#!/bin/bash
###########################################
## make-image.sh
##
## Edited: Justin Lebeau 
## Created: October 10th, 2025
##
## Purpose: A script to generate bootable linux image. To be used for moving image from Linux VM to a physical machine.
##
## A component of the CORE-V-WALLY configurable RISC-V project.
## https://github.com/openhwgroup/cvw
##
## Copyright (C) 2021-24 Harvey Mudd College & Oklahoma State University
##
## SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
##
## Licensed under the Solderpad Hardware License v 2.1 (the “License”); you may not use this file
## except in compliance with the License, or, at your option, the Apache License version 2.0. You
## may obtain a copy of the License at
##
## https:##solderpad.org/licenses/SHL-2.1/
##
## Unless required by applicable law or agreed to in writing, any work distributed under the
## License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
## either express or implied. See the License for the specific language governing permissions
## and limitations under the License.
################################################################################################

# Exit on any error (return code != 0)
# set -e

usage() { echo "Usage: $0 [-zh] [-b <path/to/buildroot>] [-o <output/file/path>] <device>" 1>&2; exit 1; }

help() {
    echo "Usage: $0 [OPTIONS] <device>"
    echo "  -z                          wipes card with zeros"
    echo "  -b <path/to/buildroot>      get images from given buildroot"
    echo "  -d <device tree name>       specify device tree to use"
    echo "  -o <output/file/path>       create a disk image file instead of writing to a device"
    exit 0;
}

# Output colors
GREEN="\e[32m"
RED="\e[31m"
BOLDRED="\e[1;91m"
BOLDGREEN="\e[1;32m"
BOLDYELLOW="\e[1;33m"
NC="\e[0m"
NAME="$BOLDGREEN"${0:2}:"$NC"
ERRORTEXT="$BOLDRED"ERROR:"$NC"
WARNINGTEXT="$BOLDYELLOW"Warning:"$NC"

# Default values for buildroot and device tree
BUILDROOT=$RISCV/buildroot
DEVICE_TREE=wally-vcu108.dtb
MNT_DIR=wallyimg
#default output file is empty
OUTPUT_FILE=""

# Process options and arguments. The following code grabs the single
# sdcard device argument no matter where it is in the positional
# parameters list.
ARGS=()
while [ $OPTIND -le "$#" ] ; do
    if getopts "hzb:d:o:" arg ; then
        case "${arg}" in
            h) help
               ;;
            z) WIPECARD=y
               ;;
            b) BUILDROOT=${OPTARG}
               ;;
            d) DEVICE_TREE=${OPTARG}
               ;;
            o) OUTPUT_FILE=${OPTARG}
                ;;
        esac
    else
        ARGS+=("${!OPTIND}")
        ((OPTIND++))
    fi
done

# File location variables
IMAGES=$BUILDROOT/output/images
FW_JUMP=$IMAGES/fw_jump.bin
LINUX_KERNEL=$IMAGES/Image
#DEVICE_TREE=$IMAGES/$DEVICE_TREE

SDCARD=${ARGS[0]}

#determine if writing to file or direct to SD card
if [ -n "$OUTPUT_FILE" ]; then
    TARGET=$OUTPUT_FILE
else
    TARGET=$SDCARD
fi

# User Error Checks ===================================================

if [ "$#" -eq "0" ] ; then
    usage
fi

# Check to make sure sd card device exists
if [ -z "$OUTPUT_FILE" ] && [ ! -e "$TARGET" ] ; then
    echo -e "$NAME $ERRORTEXT SD card device does not exist."
    exit 1
fi

# Prefix partition with "p" for non-SCSI disks (mmcblk, nvme)
if [ -z "$OUTPUT_FILE" ]; then
    if [[ $TARGET == "/dev/sd"* ]]; then
        PART_PREFIX=""
    else
        PART_PREFIX="p"
    fi
else
    PART_PREFIX=""
fi

# If no images directory, images have not been built
if [ ! -d $IMAGES ] ; then
    echo -e "$ERRORTEXT Buildroot images directory does not exist"
    echo '       Make sure you have built the images before'
    echo '       running this script.'
    exit 1
else
    # If images are not built, exit
    if [ ! -e $FW_JUMP ] || [ ! -e $LINUX_KERNEL ] ; then
        echo -e '$ERRORTEXT Missing images in buildroot output directory.'
        echo '       Build images before running this script.'
        exit 1
    fi
fi

# Ensure device tree binaries exist
if [ ! -e $DEVICE_TREE ] ; then
    echo -e "$NAME $ERRORTEXT Missing device tree files"
    echo -e "$NAME generating all device tree files into buildroot"
    make -C ../ generate BUILDROOT=$BUILDROOT
fi

# Calculate partition information =====================================

# Size of OpenSBI and the Kernel in 512B blocks
DST_SIZE=$(ls -la --block-size=512 $DEVICE_TREE | cut -d' ' -f 5 ) 
FW_JUMP_SIZE=$(ls -la --block-size=512 $FW_JUMP | cut -d' ' -f 5 )
KERNEL_SIZE=$(ls -la --block-size=512 $LINUX_KERNEL | cut -d' ' -f 5 )

# Start sectors of OpenSBI and Kernel Partitions
FW_JUMP_START=$(( 34 + $DST_SIZE ))
KERNEL_START=$(( $FW_JUMP_START + $FW_JUMP_SIZE ))
FS_START=$(( $KERNEL_START + $KERNEL_SIZE ))

# Print out the sizes of the binaries in 512B blocks
echo -e "$NAME Device tree block size:     $DST_SIZE"
echo -e "$NAME OpenSBI FW_JUMP block size: $FW_JUMP_SIZE"
echo -e "$NAME Kernel block size:          $KERNEL_SIZE"

read -p $'\e[1;33mWarning:\e[0m Doing this will replace all data on this card. Continue? y/n: ' -n 1 -r
echo
# ... (Print out the sizes of the binaries and the 'read -p' prompt remain the same) ...

if [[ $REPLY =~ ^[Yy]$ ]] ; then
    DEVBASENAME=$(basename $TARGET)

    # === Conditional logic for creating a file or using a device ===
    LOOPDEVICE="" # Variable to hold the loop device name if one is created

    if [ -n "$OUTPUT_FILE" ]; then
        echo -e "$NAME Creating disk image file: $OUTPUT_FILE"

        # Calculate total size for the image file: FS_START + a minimum size for the FS (409600 blocks = ~200MB)
        FS_MIN_SIZE=409600
        TOTAL_SIZE=$(( $FS_START + $FS_MIN_SIZE ))
        
        # Create a sparse file of the required size
        truncate -s $(( $TOTAL_SIZE * 512 )) "$OUTPUT_FILE"
        
        # Set up a loop device for partitioning operations
        LOOPDEVICE=$(sudo losetup -f --show "$OUTPUT_FILE")
        if [ -z "$LOOPDEVICE" ]; then
            echo -e "$NAME $ERRORTEXT Could not create loop device for image file."
            exit 1
        fi
        TARGET=$LOOPDEVICE # All subsequent operations will target the loop device
        
        # We need to ensure that the partitions are accessible via /dev/loopXpY
        sudo partprobe $TARGET
        sleep 2

        # Partitions on a loop device are always prefixed with 'p'
        PART_PREFIX="p"

        # No need to check for mounts or umount for a newly created file/loop device
    else
        # Original device-based logic
        CHECKMOUNT=$(lsblk | grep "$DEVBASENAME"4 | tr -s ' ' | cut -d' ' -f 7)
        if [ ! -z $CHECKMOUNT ] ; then
            sudo umount -v $CHECKMOUNT
        fi

        # Make empty image (original 'wipe card' logic)
        if [ ! -z $WIPECARD ] ; then
            echo -e "$NAME Wiping SD card. This could take a while."
            sudo dd if=/dev/zero of=$TARGET bs=64k status=progress && sync
        fi
    fi
    # =================================================================

    # GUID Partition Tables (GPT) - Use $TARGET, which is either the device or the loop device
    # ... (sgdisk commands remain the same, but using $TARGET instead of $SDCARD) ...

    # The SDCARD variable must now be replaced with $TARGET
    sudo sgdisk -z $TARGET

    sleep 1
    
    echo -e "$NAME Creating GUID Partition Table"
    sudo sgdisk -g --clear --set-alignment=1 \
              --new=1:34:+$DST_SIZE: --change-name=1:'fdt' \
              --new=2:$FW_JUMP_START:+$FW_JUMP_SIZE --change-name=2:'opensbi' --typecode=1:2E54B353-1271-4842-806F-E436D6AF6985 \
              --new=3:$KERNEL_START:+$KERNEL_SIZE --change-name=3:'kernel' \
              --new=4:$FS_START:-0 --change-name=4:'filesystem' \
              $TARGET # <--- Replaced $SDCARD with $TARGET

    sudo partprobe $TARGET

    echo -e "$NAME Forcing kernel to re-read partition table..."
    sudo partprobe $TARGET
    sudo kpartx -a $TARGET

    # Determine the base device name (e.g., /dev/loop0)
    LOOP_BASE=$(basename $TARGET)

    # Wait for the partitions to appear in /dev/mapper/
    i=0
    while [ ! -e "/dev/mapper/${LOOP_BASE}p4" ] && [ $i -lt 10 ]; do
        echo -e "$NAME Waiting for partitions to appear on /dev/mapper/..."
        sleep 1
        i=$((i + 1))
    done

    if [ ! -e "/dev/mapper/${LOOP_BASE}p4" ]; then
        echo -e "$NAME $ERRORTEXT Partitions did not appear in /dev/mapper/. Aborting."
        sudo kpartx -d $TARGET # Clean up
        sudo losetup -d $TARGET
        exit 1
    fi

    # Set the filesystem target to the newly mapped partition
    FS_TARGET="/dev/mapper/${LOOP_BASE}p4"

    # Set the DD targets to the raw file for binary copying, as the kernel-mapped
    # partitions might interfere with sector-accurate 'seek' operations on the file.
    RAW_TARGET=$OUTPUT_FILE

    echo -e "$NAME Copying binaries into their partitions."
    DD_FLAGS="bs=4k iflag=direct,fullblock oflag=dsync conv=fsync status=progress"
    
    # NOTE: For DD, we need to write to the absolute offsets of the partitions in the RAW FILE.
    # Writing to /dev/loopXpY would work for filesystems (mkfs), but for raw binary copies
    # like the ones below, writing to the loop device partitions might not be ideal or even possible
    # due to how the loop device partitions are mapped.
    #
    # The simplest solution for your scenario (copying raw binaries to specific offsets)
    # is to **write directly to the output file using the sector offsets** determined earlier,
    # and ONLY use the loop device for the filesystem (mkfs/mount) steps.

    if [ -n "$OUTPUT_FILE" ]; then
        # If creating an image file, write to the file at the calculated offsets
        RAW_TARGET=$OUTPUT_FILE
        # DD uses 'seek' in 'bs' units, and 'count' in 'bs' units.
        # We'll use bs=512 for sector-accurate writing.
        DD_RAW_FLAGS="bs=512 conv=notrunc status=progress"

        echo -e "$NAME Copying device tree to raw file offset"
        # Start sector is 34. Size is $DST_SIZE blocks.
        sudo dd if=$DEVICE_TREE of=$RAW_TARGET $DD_RAW_FLAGS seek=34 count=$DST_SIZE && sync

        echo -e "$NAME Copying OpenSBI to raw file offset"
        # Start sector is $FW_JUMP_START. Size is $FW_JUMP_SIZE blocks.
        sudo dd if=$FW_JUMP of=$RAW_TARGET $DD_RAW_FLAGS seek=$FW_JUMP_START count=$FW_JUMP_SIZE && sync

        echo -e "$NAME Copying Kernel to raw file offset"
        # Start sector is $KERNEL_START. Size is $KERNEL_SIZE blocks.
        sudo dd if=$LINUX_KERNEL of=$RAW_TARGET $DD_RAW_FLAGS seek=$KERNEL_START count=$KERNEL_SIZE && sync

    else
        # Original device-based logic
        echo -e "$NAME Copying device tree"
        sudo dd if=$DEVICE_TREE of="$TARGET""$PART_PREFIX"1 $DD_FLAGS && sync

        echo -e "$NAME Copying OpenSBI"
        sudo dd if=$FW_JUMP of="$TARGET""$PART_PREFIX"2 $DD_FLAGS && sync

        echo -e "$NAME Copying Kernel"
        sudo dd if=$LINUX_KERNEL of="$TARGET""$PART_PREFIX"3 $DD_FLAGS && sync
        
        FS_TARGET=$TARGET$PART_PREFIX4
    fi

    # Filesystem operations - always use the partition block device ($FS_TARGET)
    sudo mkfs.ext4 -E lazy_itable_init=0,lazy_journal_init=0 "$FS_TARGET" 
    sudo fsck -fv "$FS_TARGET"
    sudo mkdir -p /mnt/$MNT_DIR

    sudo mount -o init_itable=0 -v "$FS_TARGET" /mnt/$MNT_DIR

    # ... (umount and rmdir logic remains the same) ...
    sudo kpartx -d $LOOPDEVICE
    sudo umount -v /mnt/$MNT_DIR

    sudo rmdir /mnt/$MNT_DIR

    # Cleanup the loop device if one was created
    if [ -n "$LOOPDEVICE" ] ; then
        echo -e "$NAME Detaching loop device $LOOPDEVICE"
        sudo losetup -d $LOOPDEVICE
    fi
fi

echo
if [ -n "$OUTPUT_FILE" ]; then
    echo "GPT Information for $OUTPUT_FILE (Image File) ==================================="
    sudo sgdisk -p "$OUTPUT_FILE"
else
    echo "GPT Information for $TARGET ==================================="
    sudo sgdisk -p $TARGET
fi
