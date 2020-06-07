#!/bin/bash

OS_ARCH=$(uname -p)

if [[ "$(id -u)" -ne 0 || ${OS_ARCH} == "x86_64" && "$(stat -c %d:%i /)" == "$(stat -c %d:%i /proc/1/root/.)" ]]; then

	echo "you are not in the chroot !"
	exit 0

fi

mkdir -p /etc/apt
touch /etc/apt/sources.list

/bin/cat /dev/null > /etc/apt/sources.list
/bin/cat <<etc_apt_sources_list >> /etc/apt/sources.list
deb http://cdn-fastly.deb.debian.org/debian stretch main contrib non-free
deb-src http://cdn-fastly.deb.debian.org/debian stretch main contrib non-free

etc_apt_sources_list

apt -y update
apt -y install --reinstall dbus
apt-get -y clean
apt -y install locales 
dpkg-reconfigure locales
apt -y install console-common console-data console-setup console-setup-linux iptables iptables-persistent netfilter-persistent		     	
apt -y install usbutils bash-completion isc-dhcp-client isc-dhcp-common net-tools iputils-ping psmisc tar tcpd usbutils dhcpcd5 neofetch
apt -y install util-linux ntp dnsutils udev kmod ethtool lsb-base lsb-release nano dropbear bash-completion netbase unzip git perl python  
apt -y install wget libnl-route-3-200 libnl-3-200 libnl-genl-3-200 iw crda libssl-dev ifupdown iproute2 tzdata fake-hwclock sudo isc-dhcp-server
apt -y upgrade
apt-get -y clean

##########################################################
## Setup #################################################
##########################################################

RPIUSER=pi

useradd -s /bin/bash -G sudo,adm,netdev,www-data -m ${RPIUSER}
sed -i 's/#force_color_prompt=yes/force_color_prompt=yes/g' /home/${RPIUSER}/.bashrc
echo -en 'if [ -f /tmp/rw ];then\n\n\tPS1="[rw][\u@\h]:\w$ "\n\nelse\n\n\techo && neofetch\n\nfi\n' >> /home/${RPIUSER}/.bashrc
# echo '[ -f /tmp/rw ] && PS1="[rw][\u@\h]:\w# "' >> /root/.bashrc

echo "${RPIUSER}:raspberry" | chpasswd
# echo "root:raspberryroot" | chpasswd

#dpkg-reconfigure tzdata
echo "Etc/Universal" >/etc/timezone
dpkg-reconfigure -f noninteractive tzdata

dir=( sudo dhcp dhcpcd5 ntp )
for var_lib_dir in "${dir[@]}"
do

	rm -rf /var/lib/$var_lib_dir
	ln -s /tmp /var/lib/$var_lib_dir

done

# /etc/hostname
rm -rf /etc/hostname /etc/hosts
touch /etc/hostname /etc/hosts
HOSTNAME_RPI=piholeDNS
echo ${HOSTNAME_RPI} >> /etc/hostname

# /etc/hosts
echo -en "::1 localhost localhost.localdomain ${HOSTNAME_RPI}.localdomain\n127.0.0.1 localhost localhost.localdomain ${HOSTNAME_RPI}.localdomain\n
The following lines are desirable for IPv6 capable hosts\n::1		ip6-localhost ip6-loopback\nfe00::0		ip6-localnet\n
ff00::0		ip6-mcastprefix\nff02::1		ip6-allnodes\nff02::2		ip6-allrouters\n\n127.0.1.1\t${HOSTNAME_RPI}\n" >> /etc/hosts

# Don't wait forever and a day for the network to come online
if [ -s /lib/systemd/system/networking.service ]; then

	sed -i -e "s/TimeoutStartSec=5min/TimeoutStartSec=5sec/" /lib/systemd/system/networking.service

fi
if [ -s /lib/systemd/system/ifup@.service ]; then

	echo "TimeoutStopSec=5s" >> /lib/systemd/system/ifup@.service

fi

###########
## mkdir ##
###########

rm -rf /lib/firmware
mkdir -p  /lib/firmware /etc/{network,pihole} /media/overlayfs/{ramdisk,lowerdir}
touch /etc/pihole/whitelist.txt /etc/pihole/blacklist.txt

##################
## /lib/systemd ##
##################

#########################
## save-pihole.service ##
#########################
 
/bin/cat /dev/null > /lib/systemd/system/save-pihole.service
/bin/cat <<save_pihole >> /lib/systemd/system/save-pihole.service

[Unit]
Description="save pihole's files at shutdown"

[Service]
Type=oneshot
RemainAfterExit=true
ExecStop=/bin/bash -c "/usr/sbin/save-pihole"

[Install]
WantedBy=multi-user.target

save_pihole

cp /lib/systemd/system/save-pihole.service /etc/systemd/system/save-pihole.service

#####################
# overlayfs_service #
#####################

/bin/cat /dev/null > /lib/systemd/system/overlayfs.service
/bin/cat <<overlayfs_service >> /lib/systemd/system/overlayfs.service
[Unit]
Description=mount overlayfs after fstab
After=local-fs.target

[Service]
Type=simple        
ExecStart=/bin/bash -c "/usr/sbin/ramdisk-mkdir"

[Install]
WantedBy=multi-user.target 

overlayfs_service

cp /lib/systemd/system/overlayfs.service /etc/systemd/system/overlayfs.service

##############
# pihole 10M #
##############

# service

/bin/cat /dev/null > /lib/systemd/system/pihole10M.service
/bin/cat <<pihole10M_service >> /lib/systemd/system/pihole10M.service
[Unit]
Description=check pihole every 10Minutes and save if change
Conflicts=reboot.target halt.target shutdown.target
After=overlayfs.service

[Service]
Type=simple        
ExecStart=/bin/bash -c "/usr/sbin/save-pihole"

[Install]
WantedBy=multi-user.target 

pihole10M_service

cp /lib/systemd/system/pihole10M.service /etc/systemd/system/pihole10M.service

# timer

/bin/cat /dev/null > /lib/systemd/system/pihole10M.timer
/bin/cat <<pihole10M_timer >> /lib/systemd/system/pihole10M.timer
[Unit]
Description=check pihole every 10Minutes and save if change

[Timer]
OnBootSec=5min
OnUnitActiveSec=10min

[Install]
WantedBy=multi-user.target pihole10M.service

pihole10M_timer

cp /lib/systemd/system/pihole10M.timer /etc/systemd/system/pihole10M.timer

################
# fake-hwclock #
################

# service

/bin/cat /dev/null > /lib/systemd/system/fake-hwclock1h.service
/bin/cat <<fake_hwclock1h >> /lib/systemd/system/fake-hwclock1h.service
[Unit]
Description=write hardware clock every hour

[Service]
Type=simple        
ExecStart=/bin/bash -c "/usr/sbin/fake-hwclock1h"

[Install]
WantedBy=multi-user.target 

fake_hwclock1h

cp /lib/systemd/system/fake-hwclock1h.service /etc/systemd/system/fake-hwclock1h.service

# timer

/bin/cat /dev/null > /lib/systemd/system/fake-hwclock1h.timer
/bin/cat <<fake_hwclock1h_timer >> /lib/systemd/system/fake-hwclock1h.timer
[Unit]
Description=write hardware clock every hour

[Timer]
OnBootSec=0min
OnUnitActiveSec=1h

[Install]
WantedBy=multi-user.target fake-hwclock1h.service

fake_hwclock1h_timer

cp /lib/systemd/system/fake-hwclock1h.timer /etc/systemd/system/fake-hwclock1h.timer

###########
## /etc/ ##
###########

/bin/cat /dev/null >  /etc/pihole/pihole_variables
/bin/cat <<pihole_variables >>  /etc/pihole/pihole_variables

# Pihole variables manage

pihole="setupVars.conf,blacklist.txt,whitelist.txt,regex.list,pihole-FTL.conf,gravity.list,black.list,local.list"
dnsmasq="01-pihole.conf,02-pihole-dhcp.conf,03-pihole-wildcard.conf,04-pihole-static-dhcp.conf"

# pihole and dnsmasq files
declare -x -a piholefs=\$(awk -v piholefiles=\$pihole -v dnsmasqfiles=\$dnsmasq 'BEGIN{split(piholefiles,files,",");for(f in files) printf "/etc/pihole/"files[f]"\n"; \
split(dnsmasqfiles,filesd,",");for(fd in filesd) printf "/etc/dnsmasq.d/"filesd[fd]"\n"}')

# pihole files saving manage
declare -x -a piholetds=\$(awk 'BEGIN{split("piholef,tosave",pihole_save_dirs,",");for(d in pihole_save_dirs) printf "/tmp/"pihole_save_dirs[d]"\n"}')

declare -x -a overlaydirs=("etc" "lib/systemd" "var" "usr")
declare -x nopiholetds=\$(find \${piholetds} -type d 2> /dev/null | awk 'END{print NR}')
declare -x nopiholefs=\$(find \${piholefs} -type f 2> /dev/null | awk 'END{print NR}')
pihole_variables


##############
# interfaces #
##############

/bin/cat /dev/null > /etc/network/interfaces
/bin/cat <<etc_network_interfaces >> /etc/network/interfaces
source-directory /etc/network/interfaces.d

etc_network_interfaces

#########
# fstab #
#########

/bin/cat /dev/null > /etc/fstab
/bin/cat <<etc_fstab >> /etc/fstab
# classic
proc            /proc           proc    defaults        0       0
/dev/mmcblk0p1  /boot           vfat    defaults,ro     0       2
/dev/mmcblk0p2  /               ext4    defaults     0       1

# logs
tmpfs           /tmp            tmpfs   nodiratime,noatime,nodev,nosuid,mode=01777,size=192M        0       0

# ramdisk
tmpfs		/media/overlayfs/ramdisk	tmpfs	nodiratime,noatime,nodev,nosuid,mode=01777,size=324M        0       0

# squashfs
/media/firmware.squashfs          /lib/firmware           squashfs        loop    0       0

etc_fstab

#################
# journald.conf #
#################

/bin/cat /dev/null > /etc/systemd/journald.conf
/bin/cat <<journald_conf >> /etc/systemd/journald.conf
[Journal]
Storage=volatile
Compress=yes
#Seal=yes
#SplitMode=uid
#SyncIntervalSec=5m
#RateLimitIntervalSec=30s
#RateLimitBurst=1000
#SystemMaxUse=
#SystemKeepFree=
#SystemMaxFileSize=
#SystemMaxFiles=100
#RuntimeMaxUse=
#RuntimeKeepFree=
#RuntimeMaxFileSize=
#RuntimeMaxFiles=100
#MaxRetentionSec=
#MaxFileSec=1month
#ForwardToSyslog=yes
#ForwardToKMsg=no
#ForwardToConsole=no
#ForwardToWall=yes
#TTYPath=/dev/console
#MaxLevelStore=debug
#MaxLevelSyslog=debug
#MaxLevelKMsg=notice
#MaxLevelConsole=info
#MaxLevelWall=emerg
#LineMax=48K

journald_conf

###########
## /usr/ ##
###########

################
# fake-hwclock #
################

rm -rf /etc/cron.hourly/fake-hwclock
/bin/cat /dev/null > /usr/sbin/fake-hwclock1h
/bin/cat <<fake_hwclock >> /usr/sbin/fake-hwclock1h
#!/bin/bash

###########################
## Fake hwclock file gen ##
###########################

if [[ \$(id -u) != "0" ]];then

	echo "only root can save the clock"

else

	if [[ ! -w / && \$( awk '/overlayfs/ && /\57etc/' /proc/mounts ) ]];then

		mount -o rw,remount /
		mount --rbind /media/overlayfs/lowerdir/etc /etc
		/bin/bash -c "/sbin/fake-hwclock save"
		umount /etc
		mount -o ro,remount /
	
	else

		/sbin/fake-hwclock save

	fi

fi

fake_hwclock


#################
# ramdisk-mkdir #
#################

/bin/cat /dev/null > /usr/sbin/ramdisk-mkdir
/bin/cat <<ramdisk-mkdir >> /usr/sbin/ramdisk-mkdir
#!/bin/bash

################################
## make directory on the boot ##
################################

if [[ \$(id -u) == "0"  && \$( awk '/tmpfs/ && /media\57overlayfs\57ramdisk/' /proc/mounts ) && ! -w / ]];then

	overlaydirs=("etc" "lib/systemd" "var" "usr")
	for mount_overf in "\${overlaydirs[@]}"
	do

		if [[ \$( awk -v dir=\${mount_overf} '/overlay/ && \$0 ~ dir ' /proc/mounts ) ]];then 

			echo -en "/\${mount_overf} is already an overlay nothing to do ...\n"

		else

			mkdir -p  /media/overlayfs/ramdisk/\${mount_overf}/{upper,rw}
			mount -t overlay overlay -o rw,lowerdir=/media/overlayfs/lowerdir/\${mount_overf},upperdir=/media/overlayfs/ramdisk/\${mount_overf}/upper,workdir=/media/overlayfs/ramdisk/\${mount_overf}/rw	/\${mount_overf}

		fi

	done

	pihole="setupVars.conf,blacklist.txt,whitelist.txt,regex.list,pihole-FTL.conf,gravity.list,black.list,local.list"
	dnsmasq="01-pihole.conf,02-pihole-dhcp.conf,03-pihole-wildcard.conf,04-pihole-static-dhcp.conf"
	piholefs=\$(awk -v piholefiles=\$pihole -v dnsmasqfiles=\$dnsmasq 'BEGIN{split(piholefiles,files,",");for(f in files) printf "/etc/pihole/"files[f]"\n"; \
	split(dnsmasqfiles,filesd,",");for(fd in filesd) printf "/etc/dnsmasq.d/"filesd[fd]"\n"}')

	if [[ \$(find /usr/bin -name pihole-FTL) && \$( awk '/tmpfs/ && /\57tmp/' /proc/mounts ) && \$( find \${piholefs} -type f 2> /dev/null | awk 'END{print NR}' )  -ge "8" ]];then
	
		mkdir -p /tmp/{piholef,tosave}
		chown -R root:root /tmp/{piholef,tosave}
		find \$piholefs -type f -exec bash -c '/bin/cp \$1 /tmp/piholef/\${1##*/}' _ {} \; 2> /dev/null
		
	fi

else

	echo "can't create ramdisks or root is not in readonly or whatever ..."
	exit 1

fi

ramdisk-mkdir

###############
# save_pihole #
###############

/bin/cat /dev/null > /usr/sbin/save-pihole
/bin/cat <<save_pihole >> /usr/sbin/save-pihole
#!/bin/bash

source /etc/pihole/pihole_variables

if [[ \$(id -u) == "0" && -d /etc/pihole && ! -w / && "\$( awk '/tmpfs/ && /\57tmp/' /proc/mounts )" && "\$(find /usr/bin -name pihole-FTL)" && "\${nopiholetds}" -eq "2" ]]; then

        for pihole_file in \$(find \${piholefs} -type f 2> /dev/null)
        do

		# check if there's something to save

                if [[ -f /tmp/piholef/\${pihole_file##*/} && -f \${pihole_file} && ! -f /tmp/tosave/\${pihole_file##*/} ]];then

			# there's something to save

			[[ "\$( diff -q /tmp/piholef/\${pihole_file##*/} \${pihole_file} )" ]] && cp \${pihole_file} /tmp/tosave/\${pihole_file##*/}    

                else
			
			# there's nothing to save
			
                        echo "the file \${pihole_file} doesn't exist or can't tell if I have to save it or whatever ... "
			
                fi

        done
	
	if [[ "\$( find /tmp/tosave/* -type f 2> /dev/null | awk 'END{print NR}' )" -ge "1" ]];then

		mount -o rw,remount /
		mount --rbind /media/overlayfs/lowerdir/etc /etc
		/bin/bash -c "/usr/sbin/fpiholets"	      
		umount /etc
 		mount -o ro,remount /			
	
	fi

else

        echo "does it worth to trying save something ?"

fi

save_pihole

#############################
# find pihole files to save #
#############################

/bin/cat /dev/null > /usr/sbin/fpiholets
/bin/cat <<fpinholets >> /usr/sbin/fpiholets
#!/bin/bash

source /etc/pihole/pihole_variables

if [[ \$(id -u) == "0" && -d /etc/pihole && "\$( awk '/tmpfs/ && /\57tmp/' /proc/mounts )" && "\$(find /usr/bin -name pihole-FTL)" && "\${nopiholetds}" -eq "2" ]]; then

	find \$piholefs -type f -exec bash -c '/bin/cp /tmp/tosave/\${1##*/} \$1' _ {} \; 2> /dev/null
	[[ \$(awk 'BEGIN{split("reboot,halt,shutdown,",sys,",");for(s in sys) pid=system("systemctl show --property MainPID --value "sys[s]" > /dev/null "); sum+=sys[s];print sum;}') -eq "0" ]] && \
	rm -rf /tmp/{tosave,piholef}/* && find \$piholefs -type f -exec cp {} /tmp/piholef \; 2> /dev/null 
		
else

	echo "can't save ..."

fi

fpinholets

chmod 0600 /etc/network/interfaces
chmod 0644 /etc/pihole/pihole_variables
chmod 0644 /etc/systemd/system/overlayfs.service
chmod 0644 /etc/systemd/system/save-pihole.service
chmod 0644 /etc/systemd/system/fake-hwclock1h.service
chmod 0644 /etc/systemd/system/fake-hwclock1h.timer
chmod 0644 /etc/systemd/system/pihole10M.service
chmod 0644 /etc/systemd/system/pihole10M.timer
chmod 0755 /usr/sbin/fake-hwclock1h
chmod 0755 /usr/sbin/save-pihole
chmod 0755 /usr/sbin/ramdisk-mkdir
chmod 0755 /usr/sbin/fpiholets
systemctl enable overlayfs.service
systemctl enable save-pihole.service
systemctl enable fake-hwclock1h.service
systemctl enable fake-hwclock1h.timer
systemctl enable pihole10M.service
systemctl enable pihole10M.timer
systemctl disable cron
systemctl mask cron