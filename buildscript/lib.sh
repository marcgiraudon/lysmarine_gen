log () {
	echo -e "\e[32m["$(date +'%T' )"]  \e[1m $1 \e[0m " #| tee -a "${LOG_FILE}"
}

logErr () {
	echo -e "\e[91m ["$(date +'%T' )"] ---> $1 \e[0m" #| tee -a "${LOG_FILE}"
}



# Create caching folder hierarchy to work with this architecture
setupWorkSpace () {
	thisArch=$1
	mkdir -p ./cache/$thisArch
	mkdir -p ./work/$thisArch
	mkdir -p ./work/$thisArch/rootfs
	mkdir -p ./work/$thisArch/bootfs
	mkdir -p ./release/$thisArch
}



# Check if the user run with root privileges
checkRoot () {
	if [ $EUID -ne 0 ]; then
		echo "This tool must be run as root."
		exit 1
	fi
}



# Validate cache or download all the needed scripts from 3rd partys
get3rdPartyAssets () {
	#pishrink is needed to deflate the disk size at the end
	if [ ! -f ./cache/pishrink.sh ] ; then
		log "Downloading pishrink."
		pushd ./cache
		wget https://raw.githubusercontent.com/Drewsif/PiShrink/master/pishrink.sh
		chmod +x pishrink.sh
		popd

	else
		log "Using pishrink from cache."

	fi

}



createEmptyImageFile () {
	if [ ! -f ./cache/emptyImage.img ] ;then
		log "Create empty image file with qemu"
		qemu-img create -f raw ./cache/emptyImage.img 6G
		echo -e "g\nn\n\n\n+300M\nn\n\n\n\nw\n" | fdisk ./cache/emptyImage.img

		loopId=$(kpartx -sav ./cache/emptyImage.img |  cut -d" " -f3 | grep -o "[^a-z]" | head -n 1)

		mkfs.vfat  /dev/mapper/loop${loopId}p1
		mkfs.ext4  /dev/mapper/loop${loopId}p2

		kpartx -d ./cache/emptyImage.img
	else
		log "Using empty image from cache"
	fi
}



mountImageFile () {
	thisArch=$1
	imageFile=$2

	log "Mounting Image File"

	## Make sure it's not already mounted
	if [ ! -z "$(ls -A ./work/$thisArch/rootfs)" ]; then
		logErr "./work/$thisArch/rootfs is not empty. Previous failiure to unmount ?"
		umountImageFile $1 $2
		exit
	fi

	# Mount the image and make the binds required to chroot.
	IFS=$'\n' #to split lines into array
	partitions=($(kpartx -sav $imageFile |  cut -d" " -f3))
	partQty=${#partitions[@]}
	echo $partQty partitions detected.

	# mount partition table in /dev/loop
	loopId=$(kpartx -sav $imageFile |  cut -d" " -f3 | grep -o "[^a-z]" | head -n 1)
		e2fsck -f /dev/mapper/loop${loopId}p$partQty
		resize2fs /dev/mapper/loop${loopId}p$partQty
	if [ $partQty == 2 ] ; then
		mount -v /dev/mapper/loop${loopId}p2 ./work/$thisArch/rootfs/
		if [ ! -d ./work/$thisArch/rootfs/boot ] ; then mkdir ./work/$thisArch/rootfs/boot ; fi
		mount -v /dev/mapper/loop${loopId}p1 ./work/$thisArch/rootfs/boot/

	elif [ $partQty == 1 ] ; then
		mount -v /dev/mapper/loop${loopId}p1 ./work/$thisArch/rootfs/

	else
		log "ERROR: unsuported amount of partitions."
		exit 1
	fi

}



umountImageFile (){
	thisArch=$1
	imageFile=$2
	sync

	umount ./work/$thisArch/rootfs/boot
	umount ./work/$thisArch/rootfs/lysmarine
	umount ./work/$thisArch/rootfs
	sync

	kpartx -d imageFile
}



inflateImage () {
	thisArch=$1
	imageLocation=$2

	if [ ! -f $imageLocation-inflated ]; then
		log "Inflating OS image to have enough space to build lysmarine. "
		cp -fv $imageLocation $imageLocation-inflated

		# Mounting image disk (but not the partitions yet)
		log "Mounting image."
		partQty=$(fdisk -l $imageLocation-inflated | grep -o "^$imageLocation-inflated" | wc -l)

		log  "$partQty partitions detected."

		# Add 6G to the image file
		truncate -s "6G" $imageLocation-inflated

		# Inflate last partition to maximum available space.
		parted $imageLocation-inflated --script "resizepart $partQty 100%" ;


		#mount the inage drive
		mountImageFile $thisArch $imageLocation
		log "Resize the root file system to fill the new drive size."
		resize2fs /dev/mapper/loop${loopId}p$partQty

		log "Unmount OS image"
		umountImageFile $thisArch $imageLocation

	else
		log "Using Ready to build image from cache"
	fi
}



function addLysmarineScripts {
	thisArch=$1
  log "copying lysmarine on the image"
  cp -r ../lysmarine ./work/$thisArch/rootfs/
  chmod 0775 ./work/$thisArch/rootfs/lysmarine/build.sh
	find ./ -name run.sh  -exec chmod 775 {} \;
}