#!/bin/bash
#
# Copyright (c) 2015 Igor Pecovnik, igor.pecovnik@gma**.com
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/igorpecovnik/lib
#
#
# Source patching functions
#
#

# advanced_patch <dest> <family> <device> <description>
#
# parameters:
# <dest>: u-boot, kernel
# <family>: u-boot: u-boot, u-boot-neo; kernel: sun4i-default, sunxi-next, ...
# <device>: cubieboard, cubieboard2, cubietruck, ...
# <description>: additional description text
#
# priority:
# $SRC/userpatches/<dest>/<family>/<device>
# $SRC/userpatches/<dest>/<family>
# $SRC/lib/patch/<dest>/<family>/<device>
# $SRC/lib/patch/<dest>/<family>
#
advanced_patch () {

	local dest=$1
	local family=$2
	local device=$3
	local description=$4

	local names=()
	local dirs=("$SRC/userpatches/$dest/$family/$device" "$SRC/userpatches/$dest/$family" "$SRC/lib/patch/$dest/$family/$device" "$SRC/lib/patch/$dest/$family")

	# required for "for" command
	shopt -s nullglob dotglob

	# get patch file names	
	for dir in "${dirs[@]}"; do	
		for patch in $dir/*.patch; do
			names+=($(basename $patch))
		done		
	done

	# remove duplicates
	names=$(echo "${names[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' ')

	# apply patches
	for name in "${names[@]}"; do
		for dir in "${dirs[@]}"; do
			if [ -f "$dir/$name" ] || [ -L "$dir/$name" ]; then
				if [ -s "$dir/$name" ]; then
					process_patch_file "$dir/$name" "$description"
				else
					display_alert "... ${description} ${name}" "skipped" "info"
				fi
				break # next name
			fi
		done
	done
}
	
# process_patch_file <file> <description>
#
# parameters:
# <file>: path to patch file
# <description>: additional description text
#
process_patch_file() {

	local patch=$1
	local description=$2

	# detect and remove files which patch will create
	LANGUAGE=english patch --batch --dry-run -p1 -N < $patch | grep create \
		| awk '{print $NF}' | sed -n 's/,//p' | xargs -I % sh -c 'rm %'

	# main patch command
	echo "$patch" >> $DEST/debug/install.log
	patch --batch --silent -p1 -N < $patch >> $DEST/debug/install.log 2>&1

	if [ $? -ne 0 ]; then
		display_alert "... $(basename $patch) $description" "failed" "wrn";
	else
		display_alert "... $(basename $patch) $description" "succeeded" "info"
	fi
}


patching_sources(){
#--------------------------------------------------------------------------------------------------------------------------------
# Patching kernel
#--------------------------------------------------------------------------------------------------------------------------------

	cd $SOURCES/$LINUXSOURCE

	# fix kernel tag
	if [[ $KERNELTAG == "" ]] ; then 
		KERNELTAG="$LINUXDEFAULT"; 
	fi
	
	if [[ $BRANCH == "next" ]] ; then 
		git checkout $FORCE -q $KERNELTAG; 
	else 
		git checkout $FORCE -q $LINUXDEFAULT; 
	fi

	# what are we building
	grab_kernel_version

	# this is a patch that Ubuntu Trusty compiler works
	if [ "$(patch --dry-run -t -p1 < $SRC/lib/patch/kernel/compiler.patch | grep Reversed)" != "" ]; then 
		patch --batch --silent -t -p1 < $SRC/lib/patch/kernel/compiler.patch > /dev/null 2>&1
	fi

	# this exception is needed if we switch to legacy sunxi sources in configuration.sh to https://github.com/dan-and/linux-sunxi
	if [[ $LINUXKERNEL == *dan-and* && ($BOARD == bana* || $BOARD == orangepi* || $BOARD == lamobo*) ]]; then 
		LINUXFAMILY="banana";
	fi

	# this exception is needed since AW boards share single mainline kernel
	[[ $LINUXFAMILY == sun*i && $BRANCH != "default" ]] && LINUXFAMILY="sunxi"
		
	advanced_patch "kernel" "$LINUXFAMILY-$BRANCH" "$BOARD" "$LINUXFAMILY-$BRANCH $VER"

	# it can be changed in this process
	grab_kernel_version


#---------------------------------------------------------------------------------------------------------------------------------
# Patching u-boot
#---------------------------------------------------------------------------------------------------------------------------------
	
	cd $SOURCES/$BOOTSOURCE

	# fix u-boot tag
	if [ -z $UBOOTTAG ] ; then 
		git checkout $FORCE -q $BOOTDEFAULT; 
	else 
		git checkout $FORCE -q $UBOOTTAG;
	fi

	advanced_patch "u-boot" "$BOOTSOURCE" "$BOARD" "$UBOOTTAG"

}