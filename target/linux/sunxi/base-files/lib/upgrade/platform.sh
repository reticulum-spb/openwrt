RAMFS_COPY_BIN="${RAMFS_COPY_BIN:+$RAMFS_COPY_BIN }/usr/sbin/slot-env-update stat blockdev mktemp"

ab_check_image() {
	local diskdev partdev part size root_size payload=/tmp/ab-check-payload.$$ result

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	# Require the boot partition and enough space in both rootfs slots.
	for part in 1 2 3; do
		export_partdevice partdev "$part" || {
			echo "Unable to find partition $part"
			return 1
		}
		[ "$part" -eq 1 ] && continue

		size="$(blockdev --getsize64 "/dev/$partdev")" || return 1
		if [ -z "$root_size" ] || [ "$size" -lt "$root_size" ]; then
			root_size="$size"
		fi
	done

	ab_strip_payload "$1" "$payload" && ab_payload_layout "$payload" &&
		[ "$AB_ROOT_BYTES" -le "$root_size" ]
	result=$?

	rm -f "$payload"
	[ "$result" -eq 0 ] || echo "Invalid A/B firmware image or rootfs too large"
	return "$result"
}

single_check_image() {
	local diskdev partdev diff

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	get_partitions "/dev/$diskdev" bootdisk

	#extract the boot sector from the image
	get_image "$@" | dd of=/tmp/image.bs count=1 bs=512b 2>/dev/null

	get_partitions /tmp/image.bs image

	#compare tables
	diff="$(grep -F -x -v -f /tmp/partmap.bootdisk /tmp/partmap.image)"

	rm -f /tmp/image.bs /tmp/partmap.bootdisk /tmp/partmap.image

	if [ -n "$diff" ]; then
		echo "Partition layout has changed. Full image will be written."
		ask_bool 0 "Abort" && exit 1
		return 0
	fi
}

platform_check_image() {
	case "$(board_name)" in
		xunlong,orangepi-zero) ab_check_image "$1" ;;
		*) single_check_image "$@" ;;
	esac
}

platform_copy_config() {
	local partdev

	if export_partdevice partdev 1; then
		mount -t vfat -o rw,noatime "/dev/$partdev" /mnt
		cp -af "$UPGRADE_BACKUP" "/mnt/$BACKUP_FILE"
		umount /mnt
	fi
}

ab_do_upgrade() {
	local diskdev partdev bootdev slot newslot part payload=/tmp/ab-upgrade-payload.$$
	local part_size root_blocks overlay_blocks result

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	slot="$(fw_printenv -n ab_state 2>/dev/null)"
	case "$slot" in
		stable_a) newslot=b; part=3 ;;
		stable_b) newslot=a; part=2 ;;
		*) echo "Cannot upgrade from A/B state: $slot"; return 1 ;;
	esac

	[ "$(cmdline_get_var ab.rescue)" != 1 ] &&
		[ "$(cmdline_get_var ab.slot)" = "${slot#stable_}" ] &&
		[ "$(fw_printenv -n ab_env_seeded 2>/dev/null)" = 1 ] &&
		[ -x /usr/sbin/slot-env-update ] || {
		echo "A/B upgrade is not available from this boot"
		return 1
	}

	export_partdevice partdev "$part" && export_partdevice bootdev 1 || return 1

	ab_strip_payload "$1" "$payload" && ab_payload_layout "$payload" || {
		rm -f "$payload"
		return 1
	}

	part_size="$(blockdev --getsize64 "/dev/$partdev")"
	root_blocks=$(( (AB_ROOT_BYTES + 65535) / 65536 * 16 ))
	[ "$AB_ROOT_BYTES" -le "${part_size:-0}" ] || {
		echo "Rootfs does not fit /dev/$partdev"
		rm -f "$payload"
		return 1
	}
	overlay_blocks=$((part_size / 4096 - root_blocks))
	[ "$overlay_blocks" -gt 0 ] || overlay_blocks=0

	sync

	# Clear the old overlay and write the inactive rootfs.
	echo "Writing rootfs to /dev/$partdev..."
	dd if=/dev/zero of="/dev/$partdev" bs=4096 seek="$root_blocks" \
		count="$overlay_blocks" conv=fsync &&
	dd if="$payload" of="/dev/$partdev" bs=4096 skip="$((AB_ROOT_OFF / 4096))" \
		count="$(( (AB_ROOT_BYTES + 4095) / 4096 ))" conv=fsync &&
	mkdir -p /mnt && mount -t vfat -o rw,noatime "/dev/$bootdev" /mnt
	result=$?

	if [ "$result" -eq 0 ]; then
		echo "Writing kernel to uImage_$newslot..."
		dd if="$payload" of="/mnt/uImage_$newslot" bs="$AB_FIT_SIZE" count=1 conv=fsync
		result=$?
		umount /mnt || result=1
	fi

	rm -f "$payload"
	[ "$result" -eq 0 ] || return 1

	# Switch slots only after both writes and unmount succeed.
	/usr/sbin/slot-env-update stage "$newslot"
}

ab_strip_payload() {
	local image="$1" output="$2"

	fwtool -T -i /dev/null "$image" > "$output" || return 1
	[ -s "$output" ]
}

ab_payload_layout() {
	local payload="$1" size magic fit_size

	size="$(stat -c %s "$payload")" || return 1

	# FIT starts at offset 0; its size is a big-endian uint32 at offset 4.
	magic="$(hexdump -n 4 -e '1/1 "%02x"' "$payload")"
	[ "$magic" = d00dfeed ] || return 1

	fit_size="$(hexdump -v -n 4 -s 4 -e '1/1 "%02x"' "$payload")"
	[ "${#fit_size}" -eq 8 ] || return 1

	AB_FIT_SIZE=$((0x$fit_size))
	[ "$AB_FIT_SIZE" -ge 40 ] || return 1

	# SquashFS follows FIT, aligned to 4096 bytes; its header is 96 bytes.
	AB_ROOT_OFF=$(( (AB_FIT_SIZE + 4095) / 4096 * 4096 ))
	[ "$AB_ROOT_OFF" -le "$((size - 96))" ] || return 1

	magic="$(hexdump -n 4 -s "$AB_ROOT_OFF" -e '1/1 "%02x"' "$payload")"
	[ "$magic" = 68737173 ] || return 1

	# SquashFS bytes_used is a little-endian uint64 at header offset 40.
	set -- $(hexdump -v -n 8 -s "$((AB_ROOT_OFF + 40))" -e '1/1 "%02x "' "$payload")
	[ "$#" -eq 8 ] || return 1

	AB_ROOT_BYTES=$((0x$8$7$6$5$4$3$2$1))
	[ "$AB_ROOT_BYTES" -ge 96 ] && [ "$AB_ROOT_BYTES" -le "$((size - AB_ROOT_OFF))" ]
}

ab_cleanup() {
	[ "${ab_mounted:-0}" = 1 ] && umount /mnt 2>/dev/null || :
	ab_mounted=0
	rm -f "$1" /tmp/partmap.ab_current
}

single_do_upgrade() {
	local diskdev partdev diff

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	sync

	if [ "$UPGRADE_OPT_SAVE_PARTITIONS" = "1" ]; then
		get_partitions "/dev/$diskdev" bootdisk

		#extract the boot sector from the image
		get_image "$@" | dd of=/tmp/image.bs count=1 bs=512b

		get_partitions /tmp/image.bs image

		#compare tables
		diff="$(grep -F -x -v -f /tmp/partmap.bootdisk /tmp/partmap.image)"
	else
		diff=1
	fi

	if [ -n "$diff" ]; then
		get_image "$@" | dd of="/dev/$diskdev" bs=4096 conv=fsync

		# Separate removal and addtion is necessary; otherwise, partition 1
		# will be missing if it overlaps with the old partition 2
		partx -d - "/dev/$diskdev"
		partx -a - "/dev/$diskdev"

		return 0
	fi

	#write uboot image
	get_image "$@" | dd of="$diskdev" bs=1024 skip=8 seek=8 count=1016 conv=fsync
	#iterate over each partition from the image and write it to the boot disk
	while read part start size; do
		if export_partdevice partdev $part; then
			echo "Writing image to /dev/$partdev..."
			get_image "$@" | dd of="/dev/$partdev" ibs="512" obs=1M skip="$start" count="$size" conv=fsync
		else
			echo "Unable to find partition $part device, skipped."
		fi
	done < /tmp/partmap.image

	#copy partition uuid
	echo "Writing new UUID to /dev/$diskdev..."
	get_image "$@" | dd of="/dev/$diskdev" bs=1 skip=440 count=4 seek=440 conv=fsync
}

platform_do_upgrade() {
	case "$(board_name)" in
		xunlong,orangepi-zero) ab_do_upgrade "$1" ;;
		*) single_do_upgrade "$@" ;;
	esac
}
