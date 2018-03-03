# DO NOT EDIT THIS FILE
#
# Please edit /boot/armbianEnv.txt to set supported parameters
#

# default values
setenv rootdev "/dev/mmcblk0p1"
setenv verbosity "1"
setenv rootfstype "ext4"

# additional values
setenv initrd_image "boot/uInitrd"
setenv ethaddr "F0:AD:4E:03:64:7F"

if test -e ${boot_interface} 0 /boot/armbianEnv.txt; then
	load ${boot_interface} 0 ${loadaddr} /boot/armbianEnv.txt
	env import -t ${loadaddr} ${filesize}
fi

setenv bootargs "$console root=${rootdev} rootfstype=${rootfstype} rootwait loglevel=${verbosity} usb-storage.quirks=${usbstoragequirks} mtdparts=spi0.0:1536k(uboot),64k(uboot-environment),-(reserved) ${extraargs}"

setenv fdt_name_a boot/dtb/marvell/armada-3720-community.dtb
setenv fdt_name_b boot/dtb/marvell/armada-3720-espressobin.dtb

ext4load $boot_interface 0:1 $kernel_addr $image_name
ext4load $boot_interface 0:1 $initrd_addr $initrd_image
ext4load $boot_interface 0:1 $fdt_addr $fdt_name_a
ext4load $boot_interface 0:1 $fdt_addr $fdt_name_b

booti $kernel_addr $initrd_addr $fdt_addr
# mkimage -C none -A arm -T script -d /boot/boot.cmd /boot/boot.scr

