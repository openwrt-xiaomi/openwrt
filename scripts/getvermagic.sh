#!/usr/bin/env bash

BOARD=$1
SUBTARGET=$2
VERSION_NUMBER=$3
LINUX_VERSION=$4
LINUX_RELEASE=$5
OUTFILE=$6

if [ -t 8 ]; then
	BUILD_STATE=true
	OUTPUT_PIPE=8
else
	BUILD_STATE=false
	OUTPUT_PIPE=2
fi

log_msg() {
	printf "%s\n" "$1" >&$OUTPUT_PIPE
}

log_err() {
	local msg="$1"
	local _Y _R _N
	if [ "$IS_TTY" == "1" -a "$NO_COLOR" != "1" ]; then
		_Y=\\033[33m
		_R=\\033[31m
		_N=\\033[m
	fi
	printf "$_R%s$_N\n" "$msg" >&$OUTPUT_PIPE
}

die() {
	log_err "$1"
	exit 1
}

if [ -z "$VERSION_NUMBER" ]; then
	version_file="$TOPDIR/include/version.mk"
	VERSION_NUMBER=$( grep -o -P '(?<=,\$\(VERSION_NUMBER\),).*(?=\))' $version_file 2>/dev/null )
fi
[ -z "$VERSION_NUMBER" ] && die "Cannot determine VERSION_NUMBER"

vermagic_file="$TOPDIR/vermagic-$BOARD-$SUBTARGET-$VERSION_NUMBER.list"
if [ ! -f "$vermagic_file" ]; then
	log_msg "Using standard vermagic"
	exit 0
fi

KERNEL_VER=$LINUX_VERSION-$LINUX_RELEASE
vermagic=$( grep -o -P "(?<=$KERNEL_VER-).*" $vermagic_file 2>/dev/null )

if [ -z "$vermagic" ]; then
	die "Cannot found vermagic for kernel $KERNEL_VER"
fi
if [ "$( echo "$vermagic" | wc -l )" -gt 1 ]; then
	log_msg "Found a few vermagic for kernel $KERNEL_VER"
fi
vermagic=$( echo "$vermagic" | sed -n '1p' )
log_msg "vermagic = $vermagic"

if [ -n "$OUTFILE" ]; then
	echo $vermagic > "$OUTFILE"
else
	echo $vermagic
fi

