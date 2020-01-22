#!/bin/bash -e
echo 'root:changeme' | chpasswd

if [ $LMBUILD == raspbian ] ;then
	userdel -r -f pi
	rm /etc/sudoers.d/010_pi-nopasswd
fi

if [ ! -d /home/user ] ; then
	adduser --home /home/user --quiet --disabled-password -gecos "lysmarine" user
fi
echo 'user:changeme' | chpasswd

echo -n 'lysmarine' > /etc/hostname
echo '127.0.1.1	lysmarine' >> /etc/hosts

echo "user ALL=(ALL:ALL) ALL" >> /etc/sudoers

install -v $FILE_FOLDER/all_all_users_to_shutdown_reboot.pkla "/etc/polkit-1/localauthority/50-local.d/"


if [ $LMBUILD == armbian-pineA64 ] ;then
	usermod -a -G tty user
	usermod -a -G sudo user
	echo 'PATH="/sbin:/usr/sbin:$PATH"' > /home/user/.profile

fi

# cat <<EOF > /etc/default/locale
# LANG="en_US.UTF-8"
# LANGUAGE=en_US:en
# LC_NUMERIC="de_DE.UTF-8"
# LC_TIME="de_DE.UTF-8"
# LC_MONETARY="de_DE.UTF-8"
# LC_PAPER="de_DE.UTF-8"
# LC_NAME="de_DE.UTF-8"
# LC_ADDRESS="de_DE.UTF-8"
# LC_TELEPHONE="de_DE.UTF-8"
# LC_MEASUREMENT="de_DE.UTF-8"
# LC_IDENTIFICATION="de_DE.UTF-8"
# EOF
# locale-gen en_US.UTF-8 de_DE.UTF-8
# dpkg-reconfigure locales