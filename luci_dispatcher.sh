#!/bin/bash

XDIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

DIR_TARGET=$XDIR/package/feeds/luci/luci-base/luasrc
FILE_PATCH=$XDIR/luci_dispatcher.patch
FILE_TARGET=$DIR_TARGET/dispatcher.lua

if [ $( grep -q "function aux_menu(" $FILE_TARGET >/dev/null; echo "$?" ) != "0" ]; then
	FILE_ORG=$DIR_TARGET/dispatcher__orig.lua
	FILE_NEW=$DIR_TARGET/dispatcher__new.lua
	if [ ! -f "$FILE_ORG" ]; then
		cp -f $FILE_TARGET $FILE_ORG
	fi
	patch -lN $FILE_TARGET -i $FILE_PATCH -o $FILE_NEW
	if [ "$?" == "0" ]; then
		cp -f $FILE_NEW $FILE_TARGET
	fi
	rm -f $FILE_NEW
fi


