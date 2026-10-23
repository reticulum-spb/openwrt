#!/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
#
# Copyright (C) 2013 OpenWrt.org

set -ex
[ $# -eq 6 ] || [ $# -eq 7 ] || {
    echo "SYNTAX: $0 <file> <bootfs image> <rootfs image> <bootfs size> <rootfs size> <u-boot image> [ab]"
    exit 1
}

OUTPUT="$1"
BOOTFS="$2"
ROOTFS="$3"
BOOTFSSIZE="$4"
ROOTFSSIZE="$5"
UBOOT="$6"
AB="${7:-}"

head=4
sect=63

if [ "$AB" = ab ]; then
    [ "$(stat -c %s "$UBOOT")" -le $((0xF0000 - 0x2000)) ] || {
        echo "U-Boot overlaps reserved environment area" >&2
        exit 1
    }
    set $(ptgen -o $OUTPUT -h $head -s $sect -l 1024 \
        -t c -p ${BOOTFSSIZE}M  \
        -t 83 -p ${ROOTFSSIZE}M \
        -t 83 -p ${ROOTFSSIZE}M)
else
    set $(ptgen -o $OUTPUT -h $head -s $sect -l 1024 \
        -t c -p ${BOOTFSSIZE}M  \
        -t 83 -p ${ROOTFSSIZE}M)
fi

BOOTOFFSET="$(($1 / 512))"
BOOTSIZE="$(($2 / 512))"
ROOTFSOFFSET="$(($3 / 512))"
ROOTFSSIZE="$(($4 / 512))"

dd bs=1024 if="$UBOOT" of="$OUTPUT" seek=8 conv=notrunc
dd bs=512 if="$BOOTFS" of="$OUTPUT" seek="$BOOTOFFSET" conv=notrunc
dd bs=512 if="$ROOTFS" of="$OUTPUT" seek="$ROOTFSOFFSET" conv=notrunc

if [ "$AB" = ab ]; then
    ROOTFSBOFFSET="$(($5 / 512))"
    dd bs=512 if="$ROOTFS" of="$OUTPUT" seek="$ROOTFSBOFFSET" conv=notrunc
    dd bs=512 if=/dev/zero of="$OUTPUT" seek=$((0xF0000 / 512)) count=128 conv=notrunc
    # ptgen describes the full partition table; make the sparse output reach
    # the end of p3 even when the rootfs does not fill the partition.
    OUTPUT_SECTORS="$(($ROOTFSBOFFSET + $ROOTFSSIZE))"
    truncate -s "$((OUTPUT_SECTORS * 512))" "$OUTPUT"
fi
