# Debian for Pihole

1. Introduction :

The main aim of this project it was to build an OS linux based on Debian, who limit the SD card usage much as possible.
This project is mainly optimized for raspberry pi 3b+ in 64bit with uboot. It could works with raspberry pi a/a+/b/b+/zero/zerow and 2b. For the Raspberry 4 it's your business ;). The sources are here, you are able to git clone my project then I consider that you have the brain to fit it for the hardware of your choice !

2. How it's work :

You have to run the script "Debian_Chroot_RPI_AP.sh" as root ( or with sudo ) and you have to tell which kernel to compile. 
There's an help menu :

![alt text](https://www.zupimages.net/up/20/23/mg5x.jpg)

You do not have to run the script "package_debian_based.sh". Anyway if you run it, you will get this message :

![alt text](https://www.zupimages.net/up/20/23/2d5z.jpg)

Modify it if you know what are you doing.

After you build your image ( it takes some time ), you have to write your image to your SD card ( which is obvious ), you have to install Pihole and then you have to run the script "save_overlay.sh" from the directory "opt". This script will set up the OS in "read-only" and the writes will be redirected on the ram except for the script "fake-hwclock" and "pihole". 

fake-hwclock gonna write on sd card every hour. Pihole will check if you add something to save every 10 minutes. If yes, it will writes on the sd card. If no, nothing gonna happen.  










