# Raspberry Setup
This note explains the process of performing a headless setup of a raspberry pi.

### Prepare Boot Device
- prepare USB Device or Micro SD card with Raspberry Pi Imager
  - choose image (Raspberry Pi OS Lite)
  - use shift+ctrl+x to access "advanced settings" menu to add ssh public key, set Hostname, and wifi information
  - select storage device and click write
- To set up partitions on the device, we need to disable the default behavior of image which sets the size of the root (`"/"`) partition on first startup. To do so modify the `cmdline.txt` on the usb device. Remove part that says `init=/usr/lib/raspi-config/init_resize.sh`.

Note that enabling ssh, can be done by adding an empty file called `ssh` at the root of the storage device. Too add wifi information a file named `wpa_supplicant.conf` should be added. see [here](configs/wpa_supplicant.conf) for an example.

### Setting Up Root, Swap, and Storage Partitions
This section only applies, if the you intend to setup partitions on the boot device and have disabled the `init_resize.sh` script, if so skip ahead. Otherwise if you list block devices you should see something like this
```
pi@berry:~ $ lsblk
NAME   MAJ:MIN RM   SIZE RO TYPE MOUNTPOINT
sda      8:0    0 931.5G  0 disk
├─sda1   8:1    0   256M  0 part /boot
└─sda2   8:2    0   1.6G  0 part /
```

Here you see that the boot device has two partitions, a boot (`/boot`) and root (`"/"`). You can also see that the device has much more available space. So the first thing we need to do is to expand the root partition as this is where applications, tools, etc. will be installed.

We do this using `sudo fdisk /dev/sda` follow the instructions on screen to create the partitions you want. The two things to remember is that you need to delete the second (root) partition first and create a new one with the desired size. Here it is important to ensure that the "new" partition starts with the same sector. Be sure to run the verify command before running the write command. Below is a suggested partition setup. For recommendation on swap partitions see [this faq](https://help.ubuntu.com/community/SwapFaq)

```
Device     Boot     Start        End    Sectors   Size Id Type
/dev/sda1            8192     532479     524288   256M  c W95 FAT32 (LBA)
/dev/sda2          532480  134739959  134207480    64G 83 Linux
/dev/sda3       134739960  151516919   16776960     8G 82 Linux swap / Solaris
/dev/sda4       151516920 1953525167 1802008248 859.3G 83 Linux
```

Next we need to resize the root partition and properly format the new partitions. With the above setup, the required commands are

```
sudo resize2fs /dev/sda2
sudo mkswap /dev/sda3
sudo mkfs.ext4 /dev/sda4
```

## Preparing Install Variables
Next up is preparing, simply fill out the [install-vars](bin/install-vars) file. To obtain the partition uuid's for setting up auto-mount of storage and other usb-devices run `ls -l /dev/disk/by-partuuid`.

## Convenience Setup
- give user passwordless sudo access by inserting `{USER} ALL=(ALL:ALL) NOPASSWD:ALL` into `/etc/sudoers` using `sudo visudo`
- user password with `raspi-config`
- reboot with `sudo reboot`

## Running Install Script
You are now ready to go. If desired run the [pi-setup.sh](bin/pi-setup.sh) script to finish the installation. This will

# Reinstall from image
If something goes wrong you can reinstall the os without using the Raspberry Pi Imager. In short, download the OS, unzip, create loopback device, map partitions, copy to the target partition. You will have to add `ssh` and `wpa_supplicant` files to the boot partition manually and setup ssh keys on boot.

```
# Download the image file
wget https://downloads.raspberrypi.org/raspios_lite_armhf/images/raspios_lite_armhf-2021-11-08/2021-10-30-raspios-bullseye-armhf-lite.zip
unzip 2021-10-30-raspios-bullseye-armhf-lite.zip

# Create a loopback device to let you treat the image as a disk
sudo losetup /dev/loop0 2021-10-30-raspios-bullseye-armhf-lite.img

# Map the image's partitions
sudo partprobe /dev/loop0

#  Completely overwrite one of your partitions with one from the image
#  MAKE SURE YOU DON'T HAVE THE PARTITION MOUNTED WHEN YOU OVERWRITE IT
sudo dd if=/dev/loop0p2 of={TARGET_PARTITION} status=progress
```

## automatic backup of os
https://rsnapshot.org/
