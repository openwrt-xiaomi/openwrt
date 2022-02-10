#!/usr/bin/env bash

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

BOARD=$1
SUBTARGET=$2
OUTDIR=$3

[ -z "$OUTDIR" ] && OUTDIR=$SCRIPT_DIR

log_msg() {
	printf "%s\n" "$1"
}

log_err() {
	local _Y="\\033[33m"
	local _R="\\033[31mERROR: "
	local _N="\\033[m"
	printf "$_R%s$_N\n" "ERROR: $1"
}

die() {
	log_err "$1"
	exit 1
}

#rm -f $OUTDIR/vermagic-*.list 2>/dev/null

config_file="$OUTDIR/.config"
#CONFIG_TARGET_BOARD="ipq806x"
#CONFIG_TARGET_SUBTARGET="generic"

if [ -z "$BOARD" ]; then
	[ ! -f $config_file ] && die "File '.config' not found"
	BOARD=$( grep -o -P '(?<=CONFIG_TARGET_BOARD=").*(?=")' $config_file 2>/dev/null )
	[ -z "$BOARD" ] && die "Cannot determine BOARD"
fi
if [ -z "$SUBTARGET" ]; then
	[ ! -f $config_file ] && die "File '.config' not found"
	SUBTARGET=$( grep -o -P '(?<=CONFIG_TARGET_SUBTARGET=").*(?=")' $config_file 2>/dev/null )
	[ -z "$SUBTARGET" ] && die "Cannot determine SUBTARGET"
fi

rm -f $OUTDIR/vermagic-$BOARD-$SUBTARGET*.list 2>/dev/null

#kernel_ver_file="$OUTDIR/include/kernel-version.mk"
#LINUX_RELEASE?=1
#LINUX_KERNEL_HASH-5.4.154 = 058994f4666b6b0474a4d5228583e394594e406783b7e93d487c2a66c35f3c06 

#LINUX_VERSION=$( grep -o -P '(?<=LINUX_KERNEL_HASH-).*(?=\ =\ )' $kernel_ver_file 2>/dev/null )
#LINUX_VERSION=$( echo "$LINUX_VERSION" | xargs )
#[ -z "$LINUX_VERSION" ] && die "Cannot determine kernel version"
#echo "LINUX_VERSION = '$LINUX_VERSION'"

#LINUX_RELEASE=$( grep -o -P '(?<=LINUX_RELEASE\?=).*' $kernel_ver_file 2>/dev/null )
#LINUX_RELEASE=$( echo "$LINUX_RELEASE" | xargs )
#[ -z "$LINUX_RELEASE" ] && die "Cannot determine kernel release number"
#echo "LINUX_RELEASE = '$LINUX_RELEASE'"

version_file="$OUTDIR/include/version.mk"
#VERSION_NUMBER:=$(if $(VERSION_NUMBER),$(VERSION_NUMBER),21.02.1)
#VERSION_REPO:=$(if $(VERSION_REPO),$(VERSION_REPO),https://downloads.openwrt.org/releases/21.02.1)

VERSION_NUMBER=$( grep -o -P '(?<=,\$\(VERSION_NUMBER\),).*(?=\))' $version_file 2>/dev/null )
[ -z "$VERSION_NUMBER" ] && die "Cannot determine VERSION_NUMBER"
#echo "VERSION_NUMBER = '$VERSION_NUMBER'"

VERSION_REPO=$( grep -o -P '(?<=,\$\(VERSION_REPO\),http).*(?=\))' $version_file 2>/dev/null )
[ -z "$VERSION_REPO" ] && die "Cannot determine VERSION_REPO"
VERSION_REPO=http$VERSION_REPO
#echo "VERSION_REPO = '$VERSION_REPO'"

kmods_url=$VERSION_REPO/targets/$BOARD/$SUBTARGET/kmods/
kmods=$( curl -s $kmods_url )
[ -z "$kmods" ] && die "Cannot download WEB-page from '$kmods_url'"
vermagic=$( echo "$kmods" | grep '<tr><td class="' 2>/dev/null | sed -e 's/.*href="//;s/\/">.*//' 2>/dev/null )
[ -z "$vermagic" ] && die "Cannot found kmods on '$kmods_url'"

vermagic_file=vermagic-$BOARD-$SUBTARGET-$VERSION_NUMBER.list
echo "$vermagic" > $OUTDIR/$vermagic_file && log_msg "File '$vermagic_file' updated."

