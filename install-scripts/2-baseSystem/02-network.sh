#!/bin/bash -e

# Network manager
apt-get install -y -q network-manager make


# Resolve lysmarine.local
apt-get install -y -q avahi-daemon
install -v $FILE_FOLDER/hostname "/etc/"
cat $FILE_FOLDER/hosts >> /etc/hosts


# Access Point management
apt-get install -y -q createap
install -m0600 -v $FILE_FOLDER/lysmarine-hotspot.nmconnection "/etc/NetworkManager/system-connections/"
systemctl disable dnsmasq


##  NetworkManager provide its own wpa_supplicant, stop the others to avoid conflicts.
if service --status-all | grep -Fq 'dhcpcd'; then
	systemctl disable dhcpcd.service
fi
systemctl disable wpa_supplicant.service
systemctl disable hostapd.service


## Disable some useless networking services
systemctl disable NetworkManager-wait-online.service # if we do not boot remote user over the network this is not needed
systemctl disable ModemManager.service # for 2G/3G/4G
systemctl disable pppd-dns.service # For dial-up Internet LOL