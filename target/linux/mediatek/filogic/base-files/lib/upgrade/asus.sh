#!/bin/ash
# SPDX-License-Identifier: GPL-2.0-or-later OR MIT
# shellcheck shell=dash

. /lib/functions.sh

MAGIC_TRX="27051956"             # uImage header (TRX)
MAGIC_FIT="d00dfeed"             # FIT header
MAGIC_UBI="55424923"             # "UBI#"
MAGIC_SYSUPG="7379737570677261"  # TAR "sysupgrade"

ASUS_BOARD=
ASUS_INITRAMFS_MODE=
ASUS_FW_FILE=""
ASUS_FW_SIZE=0
ASUS_FW_MAGIC=
ASUS_FW_MODEL=
ASUS_UBI_DEV=
ASUS_UBIFS_PART="UBI_DEV"
ASUS_KERNEL_VOL="linux"
ASUS_ROOTFS_VOL="rootfs"
ASUS_KERNEL_SIZE=0x45fe000


log_msg() {
	echo "$@"
}

log_err() {
	echo "ERROR: $*" >&2
}

die() {
	log_err "$@"
	echo "========================================================="
	sleep 1
	exit 1
}

get_hexdump_at() {
	local offset=$1
	local size=$2
	[ $(( offset + size )) -gt "$ASUS_FW_SIZE" ] && { echo ""; return; }
	dd if="$ASUS_FW_FILE" skip="$offset" bs=1 count="$size" 2>/dev/null \
		| hexdump -v -n "$size" -e '1/1 "%02x"'
}

get_vol_id_by_name() {
	local vol_name=$1
	/usr/sbin/ubinfo "$ASUS_UBI_DEV" -N "$vol_name" 2>/dev/null \
		| awk 'NR==1 {print $3}'
}

get_ubi_vol_dev() {
	local vol_name=$1
	local ubivoldir
	local ubidevdir="/sys/class/ubi/"
	if [ -d "$ubidevdir" ]; then
		for ubivoldir in "$ubidevdir"/"$ASUS_UBI_DEV"_*; do
			if [ -d "$ubivoldir" ]; then
				if [ "$( cat $ubivoldir/name )" = "$vol_name" ]; then
					basename $ubivoldir
					return 0
				fi
			fi
		done
	fi
	return 1
}

asus_do_upgrade() {
	local fit_offset=0
	local kernel_vol_dev

	if ! asus_check_image "$1" "$2" "do"; then
		die "Image file '$ASUS_FW_FILE' is incorrect!"
	fi
	
	if [ "$ASUS_FW_MAGIC" = "$MAGIC_TRX" ] || [ "$ASUS_FW_MAGIC" = "$MAGIC_FIT" ]; then
		ASUS_UBI_DEV=$( nand_find_ubi $ASUS_UBIFS_PART )
		if [ -z "$ASUS_UBI_DEV" ]; then
			die "cannot detect ubi device for '$ASUS_UBIFS_PART'"
		fi

		kernel_vol_dev=$( get_ubi_vol_dev "$ASUS_KERNEL_VOL" )
		if [ -z "$kernel_vol_dev" ]; then
			die "cannot found ubi volume with name '$ASUS_KERNEL_VOL'"
		fi

		ASUS_FIT_IMAGE=$ASUS_FW_FILE
		if [ "$ASUS_FW_MAGIC" = "$MAGIC_TRX" ]; then
			fit_offset=64
			ASUS_FIT_IMAGE=$ASUS_FW_FILE.fit
			dd if="$ASUS_FW_FILE_ORIG" bs=64 skip=1 of="$ASUS_FIT_IMAGE"
		fi
		
		ubirmvol /dev/ubi0 -N "$ASUS_ROOTFS_VOL" 2> /dev/null
		ubirmvol /dev/ubi0 -N rootfs_data        2> /dev/null
		
		if [ "$ASUS_FW_MAGIC" = "$MAGIC_TRX" ]; then
			# for revert to stock firmware
			ubirmvol /dev/ubi0 -N jffs2
			ubirmvol /dev/ubi0 -N "$ASUS_KERNEL_VOL"
			ubimkvol /dev/ubi0 -N "$ASUS_KERNEL_VOL" -s "$ASUS_KERNEL_SIZE"
		else
			# for install initramfs image
			ubirmvol /dev/ubi0 -N "$ASUS_KERNEL_VOL"
			ubimkvol /dev/ubi0 -N "$ASUS_KERNEL_VOL" -s "$ASUS_FW_SIZE"
		fi

		kernel_vol_dev=$( get_ubi_vol_dev "$ASUS_KERNEL_VOL" )
		if [ -z "$kernel_vol_dev" ]; then
			die "cannot found ubi volume with name '$ASUS_KERNEL_VOL'"
		fi
		
		ubiupdatevol /dev/$kernel_vol_dev "$ASUS_FIT_IMAGE"
		if [ "$( echo -n $? )" -ne 0 ]; then
			log_err "Failed to flash '$ASUS_KERNEL_VOL'"
			return 1
		fi
		log_msg "FIT image flashed to '$ASUS_KERNEL_VOL'"
		log_msg "Image write successful! Reboot..."
		log_msg "==================================================="
		reboot
		exit $?
	fi

	log_msg "Check TAR-image..."
	asus_check_tar || die "Incorrect TAR-image!"

	log_msg "SysUpgrade start..."
	nand_do_upgrade "$ASUS_FW_FILE"
}

asus_check_tar() {
	local tar_file="$ASUS_FW_FILE"
	local board_dir
	local control_len  kernel_len  rootfs_len

	if [ "$ASUS_FW_MAGIC" != $MAGIC_SYSUPG ]; then
		log_msg "incorrect TAR-image!"
		return 1
	fi	
	board_dir=$( tar tf "$tar_file" | grep -m 1 '^sysupgrade-.*/$' )
	[ -z "$board_dir" ] && {
		log_msg "incorrect TAR-image! (board dir not found)"
		return 1
	}
	board_dir=${board_dir%/}

	control_len=$( (tar xf "$tar_file" "$board_dir/CONTROL" -O | wc -c) 2> /dev/null)
	if [ "$control_len" -lt 3 ]; then
		log_msg "incorrect TAR-image! (CONTROL not found)"
		return 1
	fi
	kernel_len=$( (tar xf "$tar_file" "$board_dir/kernel" -O | wc -c) 2> /dev/null)
	if [ "$kernel_len" -lt 1000000 ]; then
		log_msg "incorrect TAR-image! (kernel not found)"
		return 1
	fi
	rootfs_len=$( (tar xf "$tar_file" "$board_dir/root" -O | wc -c) 2> /dev/null)
	if [ "$rootfs_len" -lt 1000000 ]; then
		log_msg "incorrect TAR-image! (rootfs not found)"
		return 1
	fi
	return 0
}

asus_check_fw_model() {
	local model_name="$1"
	local xx=$( grep -c -F "$model_name" "$ASUS_FW_FILE" )
	if [ "$xx" -lt 1 ]; then
		xx=$( grep -c -F "$ASUS_BOARD" "$ASUS_FW_FILE" )
	fi
	[ "$xx" -lt 1 ] && return 1
	ASUS_FW_MODEL="$1"
	return 0
}

asus_init() {
	ASUS_BOARD="$1"
	ASUS_FW_FILE="$2"
	ASUS_FW_SIZE=$( wc -c "$ASUS_FW_FILE" 2> /dev/null | awk '{print $1}' )
	ASUS_FW_MAGIC=
	ASUS_FW_MODEL=
	ASUS_UBIFS_PART=$CI_UBIPART
	ASUS_KERNEL_VOL=$CI_KERNPART
	ASUS_ROOTFS_VOL=$CI_ROOTPART
	ASUS_KERNEL_SIZE=
	ASUS_INITRAMFS_MODE=
	[ -z "$ASUS_FW_SIZE" ] && return 1
	[ "$ASUS_FW_SIZE" -lt 1000000 ] && return 1
	ASUS_FW_MAGIC=$( get_hexdump_at 0 4 )
	local magic8
	magic8=$( get_hexdump_at 0 8 )
	if [ "$magic8" = $MAGIC_SYSUPG ]; then
		ASUS_FW_MAGIC="$magic8"
	fi
	if [ "$(rootfs_type)" = "tmpfs" ]; then
		ASUS_INITRAMFS_MODE=1
	fi
	if [ "$ASUS_FW_MAGIC" != "$MAGIC_SYSUPG" ]; then
		if [ "$ASUS_FW_MAGIC" = "$MAGIC_TRX" ]; then
			ASUS_FW_FILE_ORIG=$ASUS_FW_FILE
			ASUS_FW_FILE=$ASUS_FW_FILE.hdr
			dd if="$ASUS_FW_FILE_ORIG" bs=64 count=1 of="$ASUS_FW_FILE" 2>/dev/null
		fi
		case "$ASUS_BOARD" in
		asus,rt-ax59u)
			asus_check_fw_model "RT-AX59U"
			ASUS_KERNEL_SIZE=0x45fe000
			;;
		asus,tuf-ax4200)
			asus_check_fw_model "TUF-AX4200"
			ASUS_KERNEL_SIZE=0x45fe000
			;;
		asus,tuf-ax6000)
			asus_check_fw_model "TUF-AX6000"
			ASUS_KERNEL_SIZE=0x45fe000
			;;
		*)
			;;
		esac
		if [ "$ASUS_FW_MAGIC" = "$MAGIC_TRX" ]; then
			ASUS_FW_FILE=$ASUS_FW_FILE_ORIG
		fi
	fi
	return 0
}

asus_check_image() {
	local stage=$3
	local xx
	
	if ! asus_init "$1" "$2"; then
		log_msg ". <<< Image file '$ASUS_FW_FILE' is incorrect! >>>"
		return 1
	fi
	if [ -z "$ASUS_FW_SIZE" ]; then
		log_msg ". <<< File '$ASUS_FW_FILE' not found! >>>"
		return 1
	fi
	if [ "$ASUS_FW_SIZE" -lt 1000000 ]; then
		log_msg ". <<< File '$ASUS_FW_FILE' is incorrect >>>"
		return 1
	fi

	if [ "$ASUS_FW_MAGIC" = "$MAGIC_FIT" ]; then
		if [ -z "$ASUS_FW_MODEL" ]; then
			log_msg ". <<< Incorrect fit image! Model not found! >>>"
			return 1
		fi
		xx=$( grep -c -F "initrd-1" "$ASUS_FW_FILE" )
		if [ "$xx" != "0" ]; then
			log_msg ". <<< Incorrect fit image! Found 'initrd-1' part! >>>"
			return 1
		fi
		xx=$( grep -c -F "rootfs-1" "$ASUS_FW_FILE" )
		if [ "$xx" != "0" ]; then
			log_msg ". <<< Incorrect fit image! Found 'rootfs-1' part! >>>"
			return 1
		fi
		log_msg ". Detect FIT initramfs image."
		return 0
	fi

	if [ "$ASUS_FW_MAGIC" = "$MAGIC_TRX" ]; then
		if [ -z "$ASUS_FW_MODEL" ]; then
			log_msg ". <<< Incorrect stock firmware! Model not found! >>>"
			return 1
		fi
		xx=$( get_hexdump_at 64 4 )
		if [ "$xx" != "$MAGIC_FIT" ]; then
			log_msg ". <<< Incorrect stock firmware! FIT image not found! >>>"
			return 1
		fi
		#if [ "$ASUS_INITRAMFS_MODE" != "1" ]; then
		#	log_msg ". <<< TRX images can only be flashed in InitRamFs mode! >>>"
		#	return 1
		#fi
		xx=$( grep -c -F "rootfs-1" "$ASUS_FW_FILE" )
		if [ "$xx" == "0" ]; then
			log_msg ". <<< Incorrect TRX image! Part 'rootfs-1' not found! >>>"
			return 1
		fi
		log_msg ". Detect TRX stock image."
		return 0
	fi

	asus_check_tar || return 1
	nand_do_platform_check "$ASUS_BOARD" "$ASUS_FW_FILE" || return 1
	return 0
}
