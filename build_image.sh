#!/bin/bash
set -e

TMPDIR=""
LOOPDEV_ROOT=""
CWD=$(pwd)
COMPRESSION=1

if [[ "${1}" == "--disable-compression" ]]; then
	COMPRESSION=0
fi

function cleanup_mounts {
	if [[ "${CWD}" != "$(pwd)" ]]; then
		popd
	fi
	if [ -d "${TMPDIR}" ]; then
		pushd ${TMPDIR}
		sudo rm -f mnt_root/usr/bin/qemu-arm-static
		sudo rm -f root/etc/resolv.conf
		mountpoint -q root/dev && sudo umount root/dev
		mountpoint -q root/sys && sudo umount root/sys
		mountpoint -q root/proc && sudo umount root/proc
		mountpoint -q root/boot && sudo umount root/boot
		if mountpoint -q root; then
			sudo umount root
		fi
		[ -f "root.loop" ] && sudo losetup -d $(cat root.loop)
		if mountpoint -q boot; then
			sudo umount boot
		fi
		[ -f "boot.loop" ] && sudo losetup -d $(cat boot.loop)
		popd
	fi
	sync
}

function cleanup {
	if [ -d "${TMPDIR}" ]; then
		sudo rm -rf "${TMPDIR}"
	fi
}

function error_handler {
	cleanup_mounts
	cleanup
	echo -e "\e[31mError!\e[39m"
}
trap error_handler ERR

function exit_handler {
	cleanup_mounts
	cleanup
}
trap exit_handler EXIT

RASPIOS_IMAGE="raspios_lite_armhf-2025-05-13/2025-05-13-raspios-bookworm-armhf-lite.img.xz"
RASPIOS_IMAGE_NAME="$(basename ${RASPIOS_IMAGE})"

echo "This tool requires super-user permissions."
sudo true

if [ ! -f "${RASPIOS_IMAGE_NAME}" ]; then
	echo -e "\e[34mDownloading RaspiOS image...\e[39m"
	wget https://downloads.raspberrypi.com/raspios_lite_armhf/images/${RASPIOS_IMAGE}
fi

echo -e "\e[34mExtracting image...\e[39m"
TMPDIR="$(pwd)/build"
mkdir -p ${TMPDIR}
unxz -k -d ${RASPIOS_IMAGE_NAME} -c > "${TMPDIR}/image"

echo -e "\e[34mExtending root partition...\e[39m"
pushd ${TMPDIR}
dd if=/dev/zero bs=1M count=512 >> "image"
sudo parted "image" resizepart 2 100%
parted -s "image" unit B print | awk '/^ / {print $1, $2, $6}' | while read PART START FS
do
	[[ "$START" =~ [0-9]+B ]] || continue # Skip non-numeric lines
	OFFSET=${START%B} # Remove trailing 'B'
	if [[ "${FS}" == "ext4" ]]; then
		LOOPDEV=$(sudo losetup --show -f -o ${OFFSET} image)
		echo ${LOOPDEV} > root.loop
		sudo e2fsck -p -f ${LOOPDEV}
		sudo resize2fs ${LOOPDEV}
		sudo losetup -d ${LOOPDEV}
		rm ${TMPDIR}/root.loop
	fi
done
popd

echo -e "\e[34mMounting image partitions...\e[39m"
pushd ${TMPDIR}
mkdir root boot
parted -s "image" unit B print | awk '/^ / {print $1, $2, $6}' | while read PART START FS
do
	[[ "$START" =~ [0-9]+B ]] || continue # Skip non-numeric lines
	OFFSET=${START%B} # Remove trailing 'B'
	if [[ "${FS}" == "fat32" ]]; then
		TYPE="boot"
		LOOPDEV=$(sudo losetup --show -f -o ${OFFSET} image)
		echo ${LOOPDEV} > boot.loop
		sudo mount ${LOOPDEV} boot
	elif [[ "${FS}" == "ext4" ]]; then
		TYPE="root"
		LOOPDEV=$(sudo losetup --show -f -o ${OFFSET} image)
		echo ${LOOPDEV} > root.loop
		sudo mount ${LOOPDEV} root
	else
		TYPE="unknown"
	fi
	echo "Partition ${PART} (${TYPE}) starts at byte offset ${OFFSET}"
done
sudo mkdir -p root/boot
sudo mount --bind boot root/boot
popd

echo -e "\e[34mPreparing to chroot...\e[39m"
pushd ${TMPDIR}
sudo mount --bind /dev root/dev
sudo mount --bind /sys root/sys
sudo mount --bind /proc root/proc
sudo cp /etc/resolv.conf root/etc/resolv.conf
sudo cp /usr/bin/qemu-arm-static root/usr/bin/
popd

echo -e "\e[34mInstalling dependencies...\e[39m"
pushd ${TMPDIR}
sudo chroot root /bin/bash <<'EOF'
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y nginx libnginx-mod-rtmp mpv fbi imagemagick
EOF
popd

echo -e "\e[34mConfiguring...\e[39m"
sudo touch ${TMPDIR}/boot/ssh
sudo cp resources/userconf.txt ${TMPDIR}/boot/
sudo sed -i 's/user www-data/user nosignal/' ${TMPDIR}/root/etc/nginx/nginx.conf
sudo cp resources/rc.local ${TMPDIR}/root/etc/
sudo chmod +x ${TMPDIR}/root/etc/rc.local
sudo sed -i 's/worker_processes auto;/worker_processes 1;/' ${TMPDIR}/root/etc/nginx/nginx.conf
cat resources/rtmp.conf | sudo tee -a ${TMPDIR}/root/etc/nginx/nginx.conf
sudo cp resources/no-signal.service resources/config-audio.service ${TMPDIR}/root/etc/systemd/system/
sudo mkdir ${TMPDIR}/root/opt/no_signal
sudo cp resources/no_signal.sh resources/no_signal.png resources/configure_audio.sh ${TMPDIR}/root/opt/no_signal
sudo chmod +x ${TMPDIR}/root/opt/no_signal/no_signal.sh ${TMPDIR}/root/opt/no_signal/configure_audio.sh
cat resources/fstab.append | sudo tee -a ${TMPDIR}/root/etc/fstab
sudo sed -i 's/d \/var\/log 0755/d \/var\/log 0777/g' ${TMPDIR}/root/usr/lib/tmpfiles.d/var.conf
echo "d /var/log/nginx 0777 nosignal www-data -" | sudo tee -a ${TMPDIR}/root/usr/lib/tmpfiles.d/var.conf
echo "NoSignal" | sudo tee ${TMPDIR}/root/etc/hostname
pushd ${TMPDIR}
sudo chroot root /bin/bash <<'EOF'
systemctl disable nginx # will be enabled by rc.local, so after user creation
systemctl enable no-signal
systemctl enable config-audio
#systemctl disable dphys-swapfile.service
EOF
popd

echo -e "\e[34mReleasing image...\e[39m"
cleanup_mounts
if [ ${COMPRESSION} -eq 1 ]; then
	xz -k -c ${TMPDIR}/image > nosignal.img.xz
else
	cp ${TMPDIR}/image nosignal.img
fi

echo -e "\e[34mCleaning up...\e[39m"
cleanup
