do_ma35d05k() {
	. /lib/ma35d05k.sh

	ma35d05k_board_detect
}

# On NAND/SPINAND the overlay is a UBIFS volume that fstools mounts directly
# (mount_root -> mount_overlay). /sbin/block (block-mount) is only needed for
# the SD-card ext4 "rootfs_data" extroot, but it is now shipped in the shared
# squashfs because of the SD-card overlay feature. On every boot mount_root
# calls mount_extroot(), which - the moment it finds a regular /sbin/block -
# runs "block extroot"; that mounts the data volume to hunt for extroot config,
# producing the extra "block:" messages and the ubifs mount/unmount/remount
# cycle even on NAND where there is no ext4 rootfs_data at all.
#
# mount_extroot() bails out early (return -1) if /sbin/block is not a regular
# file, so on NAND/SPINAND we shadow it with /dev/null before mount_root runs.
# This makes NAND boot as clean as an image without block-mount. The bind mount
# lives only in the pre-pivot namespace; once mount_root pivots the UBIFS
# overlay, /sbin/block resolves to the real binary from the squashfs lower
# again, so runtime block/hotplug and SD-card extroot are unaffected.
ma35d05k_skip_extroot() {
	case "$(cat /proc/cmdline)" in
	*boot=nand*|*boot=spinand*) ;;
	*) return 0 ;;
	esac

	[ -e /sbin/block ] || return 0

	mount -o bind /dev/null /sbin/block
}

boot_hook_add preinit_main do_ma35d05k
boot_hook_add preinit_main ma35d05k_skip_extroot
