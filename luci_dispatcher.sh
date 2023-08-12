#!/bin/bash

XDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DIR_TARGET=$XDIR/package/feeds/luci/luci-base/ucode
FILE_PATCH=$XDIR/luci_dispatcher.patch
FILE_TARGET=$DIR_TARGET/dispatcher.uc

if [ $( grep -q "aux_menu(tree);" $FILE_TARGET >/dev/null; echo "$?" ) != "0" ]; then
	FILE_ORG=$DIR_TARGET/dispatcher__orig.uc
	FILE_NEW=$DIR_TARGET/dispatcher__new.uc
	if [ ! -f "$FILE_ORG" ]; then
		cp -f $FILE_TARGET $FILE_ORG
	fi
	patch -lN $FILE_TARGET -i $FILE_PATCH -o $FILE_NEW
	if [ "$?" == "0" ]; then
		cp -f $FILE_NEW $FILE_TARGET
	fi
	rm -f $FILE_NEW
fi
