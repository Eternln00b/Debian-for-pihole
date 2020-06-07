#!/bin/bash

if [[ $(id -u) == "0" && -w / ]];then

	sed -i -e "s|/dev/mmcblk0p2  /               ext4    defaults     0       1|/dev/mmcblk0p2  /               ext4    defaults,ro     0       1|" /etc/fstab 

	overfdirs=( etc lib/systemd var usr )
	for var_lib_dirs in "${overfdirs[@]}"
	do

		mkdir -p /media/overlayfs/lowerdir/${var_lib_dirs}
		[[ ${var_lib_dirs} != "lib/systemd" ]] && cp -al /${var_lib_dirs} /media/overlayfs/lowerdir

	done
	[[ ${var_lib_dirs} == "lib/systemd" ]] && cp -al /${var_lib_dirs} /media/overlayfs/lowerdir/lib
	echo " Restarting Raspberry Pi.."
	shutdown -r now

else

	echo "Run this script as root please"

fi

