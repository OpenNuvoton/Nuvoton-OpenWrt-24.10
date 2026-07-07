#
# Copyright (C) 2010 OpenWrt.org
#

. /lib/ma35d0.sh


platform_check_image() {
	return 0
}

platform_do_upgrade_dtb() {
	local tar_file="$1"
	local board_dir

	# Locate the sysupgrade-<board> directory inside the tarball
	board_dir=$(tar tf "$tar_file" 2>/dev/null | grep -m 1 '^sysupgrade-.*/$')
	board_dir="${board_dir%/}"
	[ -n "$board_dir" ] || return 0

	# Skip silently if this image does not carry a device tree
	tar tf "$tar_file" "${board_dir}/dtb" >/dev/null 2>&1 || return 0

	# Two partitions are named "device-tree" because both the raw NAND and
	# the SPI-NAND controllers are enabled. Relying on /proc/mtd order alone
	# is fragile (it depends on probe order), so bind the choice to the flash
	# we actually booted from: u-boot passes boot=nand / boot=spinand on the
	# kernel command line, and each mtd's parent controller in sysfs tells us
	# which flash it belongs to (SPI-NAND sits on an SPI bus). Only shell
	# builtins are used -- head/tail/cut/readlink are not in the ramdisk.
	local want_spi=0 dtb_mtd="" d name path
	grep -q "boot=spinand" /proc/cmdline && want_spi=1

	for d in /sys/class/mtd/mtd*; do
		case "$d" in *ro) continue ;; esac	# skip mtdNro read-only aliases
		[ -r "$d/name" ] || continue
		read -r name < "$d/name"
		[ "$name" = "device-tree" ] || continue

		# Resolve the parent controller path (cd+pwd avoids readlink)
		path=$(cd "$d/device" 2>/dev/null && pwd -P)
		case "$path" in
		*spi*) [ "$want_spi" = 1 ] && dtb_mtd=${d##*/} ;;
		*)     [ "$want_spi" = 0 ] && dtb_mtd=${d##*/} ;;
		esac
	done

	# Fallback if sysfs could not disambiguate: use /proc/mtd order
	# (NAND probes first, SPI-NAND last).
	if [ -z "$dtb_mtd" ]; then
		local line mtd
		while IFS= read -r line; do
			case "$line" in
			*'"device-tree"'*)
				mtd="${line%%:*}"
				dtb_mtd="$mtd"
				[ "$want_spi" = 1 ] || break
				;;
			esac
		done < /proc/mtd
	fi

	[ -n "$dtb_mtd" ] || {
		echo "device-tree partition not found, skipping DTB update."
		return 0
	}

	echo "Updating device-tree partition (/dev/$dtb_mtd)..."
	tar xf "$tar_file" "${board_dir}/dtb" -O > /tmp/dtb.bin
	mtd write /tmp/dtb.bin "/dev/$dtb_mtd"
	rm -f /tmp/dtb.bin
}

platform_do_upgrade_sdcard() {
	local diskdev partdev diff

	export_bootdevice && export_partdevice diskdev 0 || {
		echo "Unable to determine upgrade device"
		return 1
	}

	sync

	if [ "$UPGRADE_OPT_SAVE_PARTITIONS" = "1" ]; then
		get_partitions "/dev/$diskdev" bootdisk

		#read the first 256 KiB (partition table area) from the image
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

	#skip first partition
	# 1: redundant for loaders
	# 2: kernel
	# 3: rootfs
	sed -i '1d' /tmp/partmap.image

	# The device tree lives in the raw gap between the loader and kernel
	# partitions (sector 5632 = 0x2c0000, 256 KiB) and is read by u-boot via
	# "mmc read fdt 0x1600 0x80". It is not covered by any partition device,
	# so the per-partition writes below would skip it. Copy it straight from
	# the image to keep DTB+kernel+rootfs in sync, matching NAND/SPI-NAND OTA.
	echo "Writing device-tree to /dev/$diskdev..."
	get_image "$@" | dd of="/dev/$diskdev" ibs=512 obs=512 skip=5632 seek=5632 count=512 conv=fsync

	#(disabled) write u-boot image
	#get_image "$@" | dd of="$diskdev" bs=1024 skip=8 seek=8 count=1016 conv=fsync
	#iterate over each partition (kernel, rootfs) from the image and write it to the boot disk
	while read part start size; do
		if export_partdevice partdev $part; then
			case "$part" in
				2) imgname="kernel" ;;
				3) imgname="rootfs" ;;
				*) imgname="partition $part" ;;
			esac
			echo "Writing $imgname to /dev/$partdev..."
			get_image "$@" | dd of="/dev/$partdev" ibs="512" obs=1M skip="$start" count="$size" conv=fsync
		else
			echo "Unable to find partition $part device, skipped."
		fi
	done < /tmp/partmap.image

	#(disabled) copy partition uuid
	#echo "Writing new UUID to /dev/$diskdev..."
	#get_image "$@" | dd of="/dev/$diskdev" bs=1 skip=440 count=4 seek=440 conv=fsync
}

platform_do_upgrade() {
	local board=$(ma35d0_board_name)

	case "$board" in
	*nand*)
		platform_do_upgrade_dtb "$1"
		PART_NAME="firmware"
		REQUIRE_IMAGE_METADATA=1
		#default_do_upgrade "$1"
		nand_do_upgrade "$1"
		;;
	*sdcard*)
		platform_do_upgrade_sdcard "$1"
		return 0
		;;
	*)
		echo "Sysupgrade is not currently supported on $board"
		;;
	esac
}

