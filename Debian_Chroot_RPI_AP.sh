#!/bin/bash

############################################
## Author : https://github.com/Eternln00b ##
##########################################################################################
## based on this script https://gist.github.com/stewdk/f4f36c3f6599072583bd40f15b5cdbef ##
##########################################################################################

if [[ "$(id -u)" -ne 0 ]]; then

	echo "[!] This script must run as root"
	exit 1
	
fi

KERNEL=$1

if [[ -z ${KERNEL} ]];then 

	echo "which kernel please ?"
	echo -en "RPI3 64 bit: sudo bash Debian_Chroot_RPI_AP.sh kernel8\nRPI2,3: sudo bash Debian_Chroot_RPI_AP.sh kernel7\nRPI0,1AB: sudo bash Debian_Chroot_RPI_AP.sh kernel\n"
	echo "If you have to configure the kernel : sudo bash Debian_Chroot_RPI_AP.sh kernel8 kernel_config"
	exit 1
	
fi


echo "installing or checking softwares"
apt install -y device-tree-compiler libssl-dev bison flex debootstrap qemu-utils kpartx git curl gcc-aarch64-linux-gnu g++-aarch64-linux-gnu pkg-config-aarch64-linux-gnu gcc-arm-linux-gnueabihf g++-arm-linux-gnueabihf pkg-config-arm-linux-gnueabihf gcc-arm-linux-gnueabi pkg-config-arm-linux-gnueabi g++-arm-linux-gnueabi qemu-user-static binfmt-support parted bc libncurses5-dev wpasupplicant -qq &> /dev/null
apt install -y squashfs-tools squashfs-tools-dbg -qq &> /dev/null

rm -rf /tmp/*
cp $(pwd)/{save_overlay.sh,package_debian_based.sh} /tmp/
chmod +x /tmp/{save_overlay.sh,package_debian_based.sh}

##################
## Kernel pt1
##################

WRKDIR=/home/${USER}/Documents/
OUTPUT_IMG_DIR=$(pwd)
NPROC=$(nproc)
export ${KERNEL}

finish () {
  
	cd ${WRKDIR}
	sync
	umount -l ${MNTROOTFS}proc || true
	umount -l ${MNTROOTFS}dev/pts || true
	umount -l ${MNTROOTFS}dev || true
	umount -l ${MNTROOTFS}sys || true
	umount -l ${MNTROOTFS}tmp || true
	umount -l ${MNTBOOT} || true
	umount -l ${MNTROOTFS} || true
	kpartx -dvs ${IMGFILE} || true
	rmdir ${MNTROOTFS} || true
	mv ${IMGFILE} . || true
	#mv ${IMGFILE} ${WRKDIR} || true
	umount -l ${MNTRAMDISK} || true
	rmdir ${MNTRAMDISK} || true
	output_img_to_move=$(ls -1 ${WRKDIR}*.img)
	chown 1000:1000 ${output_img_to_move} &> /dev/null
	mv ${output_img_to_move} ${OUTPUT_IMG_DIR}

}

if [ "${KERNEL}" == "kernel8" ]; then

	IMGNAME=debian_rpi3_64bit
	ARCH="arm64"
	QARCH="aarch64"
	CROSS_COMPILER=aarch64-linux-gnu-
	echo -en "Compiling Debian for the rpi3 in 64 bits\n"

else

	if [ "${KERNEL}" == "kernel7" ];then

		ARCH="armhf"
		QARCH="arm"
		CROSS_COMPILER=arm-linux-gnueabihf-
		echo -en "Compiling Debian for the rpi3 or the rpi2 in 32 bits\n"
		IMGNAME=debian_rpi23_32bit

	else

		KERNEL="kernel"
		ARCH="armel"
		QARCH="armeb"
		CROSS_COMPILER=arm-linux-gnueabi-
		echo -en "Compiling Debian for the rpi1(a/b) or the rpi0 in 32 bits. There's no hard float (armhf) there !\n"
		IMGNAME=debian_rpi01_32bit

	fi

fi

[[ -f $(pwd)/${IMGNAME}.img ]] && rm -rf $(pwd)/${IMGNAME}.img

if [ ! -d ${WRKDIR}firmware ]; then

	echo -en "Downloading the Firmware ! \n"
	git clone --depth 1 https://github.com/raspberrypi/firmware.git ${WRKDIR}firmware &> /dev/null

fi

if [ ! -d ${WRKDIR}linux ]; then

	echo -en "Downloading the Kernel sources ! \n"

	if [[ ! -d ${WRKDIR}u-boot && "${KERNEL}" == "kernel8" ]]; then
	
		# cp $(pwd)/config_test ${WRKDIR}linux/.config
		git clone --depth 1 --branch rpi-4.19.y https://github.com/raspberrypi/linux.git ${WRKDIR}linux &> /dev/null
		echo -en "Checking u-boot tools ! \n"
		apt install -y u-boot-tools -qq &> /dev/null
		echo -en "Downloading the Uboot ! \n"
		git clone --depth 1 git://git.denx.de/u-boot.git ${WRKDIR}u-boot &> /dev/null
		cp $(pwd)/u-boot/rpi3-bootscript.txt ${WRKDIR}u-boot/rpi3-bootscript.txt

	else
	
		git clone --depth 1 https://github.com/raspberrypi/linux.git ${WRKDIR}linux &> /dev/null

	fi

fi

if [ "${KERNEL}" == "kernel8" ]; then
# Build 64-bit Raspberry Pi 3 kernel
    
	if [[ ! -s ${WRKDIR}u-boot/u-boot.bin && ! -s ${WRKDIR}linux/arch/arm64/boot/Image ]]; then        

		cd ${WRKDIR}linux
   		make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILER} bcmrpi3_defconfig &> /dev/null
   		# Uncomment the following line if you wish to change the kernel configuration
   		[[ -n $2 && $2 == "kernel_config" ]] && make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILER} menuconfig 
   		echo "Building kernel. This takes a while. To monitor progress, open a new terminal and use \"tail -f buildoutput.log\""
   		make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILER} -j ${NPROC} > ${WRKDIR}buildoutput.log 2> ${WRKDIR}buildoutput2.log
  		cd ${WRKDIR}

		cd ${WRKDIR}u-boot
		echo "Building uboot"
		make -j${NPROC} CROSS_COMPILE=${CROSS_COMPILER} distclean &> /dev/null
		make -j${NPROC} CROSS_COMPILE=${CROSS_COMPILER} rpi_arm64_defconfig &> /dev/null
		make -j${NPROC} CROSS_COMPILE=${CROSS_COMPILER} &> /dev/null
		cd ${WRKDIR}
	
	fi


elif [ "${KERNEL}" == "kernel7" ]; then
# Build 32-bit Raspberry Pi 2 kernel
    
	if [ ! -s ${WRKDIR}linux/arch/arm/boot/zImage ]; then
        
		cd ${WRKDIR}linux
    		make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} bcm2709_defconfig &> /dev/null
    		# Uncomment the following line if you wish to change the kernel configuration
    		[[ -n $2 && $2 == "kernel_config" ]] && make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} menuconfig 
    		echo "Building kernel. This takes a while. To monitor progress, open a new terminal and use \"tail -f buildoutput.log\""
    		make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} zImage modules dtbs -j ${NPROC} > ${WRKDIR}buildoutput.log 2> ${WRKDIR}buildoutput2.log
    		cd ${WRKDIR}
    	
	fi

elif [ "${KERNEL}" == "kernel" ]; then
# Build 32-bit Raspberry Pi 1 kernel
    	
	if [ ! -s ${WRKDIR}linux/arch/arm/boot/zImage ]; then
        		
		cd ${WRKDIR}linux
   		make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} bcmrpi_defconfig &> /dev/null
   		# Uncomment the following line if you wish to change the kernel configuration
   		[[ -n $2 && $2 == "kernel_config" ]] && make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} menuconfig 
   		echo "Building kernel. This takes a while. To monitor progress, open a new terminal and use \"tail -f buildoutput.log\""
   		make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} zImage modules dtbs -j ${NPROC} > ${WRKDIR}buildoutput.log 2> ${WRKDIR}buildoutput2.log
   		cd ${WRKDIR}

	fi

fi

MNTRAMDISK=/mnt/ramdisk/
MNTROOTFS=/mnt/rpi-rootfs/
MNTBOOT=${MNTROOTFS}boot/
IMGFILE=${MNTRAMDISK}${IMGNAME}.img

trap finish EXIT

mkdir -p ${MNTRAMDISK}
mount -t tmpfs -o size=3g tmpfs ${MNTRAMDISK}

cd ${WRKDIR} 

qemu-img create -f raw ${IMGFILE} 915M > /dev/null 
(echo "n"; echo "p"; echo "1"; echo "2048"; echo "+50M"; echo "n"; echo "p"; echo "2"; echo ""; echo ""; echo "t"; echo "1"; echo "c"; echo "w") | fdisk ${IMGFILE} > /dev/null
LOOPDEVS=$(kpartx -avs ${IMGFILE} | awk '{print $3}')
LOOPDEVBOOT=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $1}')
LOOPDEVROOTFS=/dev/mapper/$(echo ${LOOPDEVS} | awk '{print $2}')

mkfs.vfat ${LOOPDEVBOOT} 
mkfs.ext4 ${LOOPDEVROOTFS} 

fatlabel ${LOOPDEVBOOT} Boot
e2label ${LOOPDEVROOTFS} Debian

mkdir -p ${MNTROOTFS}
mount ${LOOPDEVROOTFS} ${MNTROOTFS}
qemu-debootstrap --keyring /usr/share/keyrings/debian-archive-stretch-stable.gpg --include=ca-certificates --arch=${ARCH} stretch ${MNTROOTFS} http://cdn-fastly.deb.debian.org/debian/
mount ${LOOPDEVBOOT} ${MNTBOOT}

mount -o bind /proc ${MNTROOTFS}proc
mount -o bind /dev ${MNTROOTFS}dev
mount -o bind /dev/pts ${MNTROOTFS}dev/pts
mount -o bind /sys ${MNTROOTFS}sys
mount -o bind /tmp ${MNTROOTFS}tmp

###################
## Kernel pt2 
###################

cp $( which qemu-${QARCH}-static ) ${MNTROOTFS}usr/bin/
cp ${WRKDIR}firmware/boot/bootcode.bin ${WRKDIR}firmware/boot/fixup*.dat ${WRKDIR}firmware/boot/start*.elf ${MNTBOOT}
chroot ${MNTROOTFS} /tmp/package_debian_based.sh
cp /tmp/save_overlay.sh ${MNTROOTFS}opt

#######################
## non free firmware ##
#######################

git clone --depth 1  https://github.com/RPi-Distro/firmware-nonfree.git /tmp/firmware
mksquashfs /tmp/firmware ${MNTROOTFS}media/firmware.squashfs  -b 1048576 -comp xz -Xdict-size 100%

############
## u-boot ##
############

[ "${KERNEL}" == "kernel8" ] && cat /dev/null > /tmp/rpi3-bootscript.txt
[ "${KERNEL}" == "kernel8" ] && cat <<rpi3_bootscript >> /tmp/rpi3-bootscript.txt
setenv kernel_addr_r 0x01000000
setenv ramdisk_addr_r 0x02100000
fatload mmc 0:1 \${kernel_addr_r} kernel8.img
fatload mmc 0:1 \${ramdisk_addr_r} initrd.img
fatload mmc 0:1 \${fdt_addr_r} bcm2710-rpi-3-b-plus.dtb
setenv initrdsize \$filesize
setenv bootargs earlyprintk dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 elevator=noop rw rootwait
booti \${kernel_addr_r} \${ramdisk_addr_r}:\${initrdsize} \${fdt_addr_r}
rpi3_bootscript

################
## Kernel pt3 ## 
################

if [ "${KERNEL}" == "kernel8" ]; then
		
	cp ${WRKDIR}linux/arch/arm64/boot/Image ${MNTBOOT}${KERNEL}.img
	cp ${WRKDIR}linux/arch/arm64/boot/dts/broadcom/bcm2710-rpi-3-b*.dtb ${MNTBOOT}
    	cd ${WRKDIR}linux
	
    	make ARCH=arm64 CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=${MNTROOTFS} modules_install -j ${NPROC} > ${WRKDIR}modules_install.log
	echo -en "apt -y install initramfs-tools-core initramfs-tools\nmkinitramfs -o /boot/initrd.img /lib/modules/\$(ls -1 /lib/modules/)\n" >> /tmp/initrd_script.sh
	chmod +x /tmp/initrd_script.sh
	chroot ${MNTROOTFS} /tmp/initrd_script.sh

	cp ${WRKDIR}u-boot/u-boot.bin ${MNTBOOT}
	echo -en "device_tree_address=0x100\ndevice_tree_end=0x8000\narm_control=0x200\nkernel=u-boot.bin\n" >> ${MNTBOOT}config.txt
	mkimage -A arm64 -O linux -T script -C none -a 0x00000000 -e 0x00000000 -n "u-boot rpi3B+ 64bit" -d /tmp/rpi3-bootscript.txt ${MNTBOOT}boot.scr	    	
	cd ${WRKDIR}

else

	${WRKDIR}linux/scripts/mkknlimg ${WRKDIR}linux/arch/arm/boot/zImage ${MNTBOOT}${KERNEL}.img
    	cp ${WRKDIR}linux/arch/arm/boot/dts/*.dtb ${MNTBOOT}
    	cd ${WRKDIR}linux
    	make ARCH=arm CROSS_COMPILE=${CROSS_COMPILER} INSTALL_MOD_PATH=${MNTROOTFS} modules_install -j ${NPROC} > ${WRKDIR}modules_install.log
	echo -en "dwc_otg.lpm_enable=0 console=ttyAMA0,115200 console=tty1 root=/dev/mmcblk0p2 rootfstype=ext4 cgroup_enable=memory elevator=deadline rootwait\n" >> ${MNTBOOT}cmdline.txt
	echo -en "kernel=${KERNEL}.img\nenable_uart=1\n" >> ${MNTBOOT}config.txt
	cd ${WRKDIR}

fi
