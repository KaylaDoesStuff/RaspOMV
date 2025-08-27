#!/bin/bash

# Update package list and install required packages
echo "Updating package list and installing required packages..."
sudo apt-get update
sudo apt-get install -y hostapd dnsmasq wget

# Prompt for SSID and Password
read -p "Enter the SSID for the hotspot: " SSID
read -sp "Enter the password for the hotspot: " PASSWORD
echo

# Install OpenMediaVault
echo "Installing OpenMediaVault..."
echo "This may take some time. Please wait..."
wget -O - https://github.com/openmediavault/openmediavault/archive/refs/tags/6.0.0.tar.gz | tar xz
cd openmediavault-6.0.0
sudo ./install.sh

# Configure the DHCP server (dnsmasq)
cat <<EOL | sudo tee /etc/dnsmasq.conf
interface=wlan0
dhcp-range=192.168.4.2,192.168.4.20,255.255.255.0,24h
EOL

# Configure the access point (hostapd)
cat <<EOL | sudo tee /etc/hostapd/hostapd.conf
interface=wlan0
driver=nl80211
ssid=$SSID
hw_mode=g
channel=6
wmm_enabled=0
macaddr_acl=0
auth_algs=1
ignore_broadcast_ssid=0
wpa=2
wpa_passphrase=$PASSWORD
rsn_pairwise=CCMP
EOL

# Set the hostapd configuration file
sudo sed -i 's|#DAEMON_CONF=""|DAEMON_CONF="/etc/hostapd/hostapd.conf"|' /etc/default/hostapd

# Configure the network interface
cat <<EOL | sudo tee -a /etc/dhcpcd.conf
interface wlan0
    static ip_address=192.168.4.1/24
    nohook wpa_supplicant
EOL

# Create mount points and update fstab for mmcblk and hdd drives
echo "Setting up automatic mounting of drives..."
for drive in /dev/mmcblk* /dev/sd*; do
    if [ -b "$drive" ]; then
        mount_point="/mnt/$(basename $drive)"
        sudo mkdir -p "$mount_point"
        echo "$drive $mount_point auto defaults,nofail 0 0" | sudo tee -a /etc/fstab
    fi
done

# Restart services
sudo systemctl restart dhcpcd
sudo systemctl start hostapd
sudo systemctl start dnsmasq

# Set up OpenMediaVault admin user
echo "Setting up OpenMediaVault admin user..."
OMV_ADMIN_USER="admin"
OMV_ADMIN_PASS="openmediavault"

# Change the default admin password
sudo omv-firstaid set-admin-password

# Enable the web interface
sudo omv-confdbadm populate

# Restart the OMV services
sudo systemctl restart openmediavault-engined

echo "Wi-Fi hotspot '$SSID' is now active."
echo "OpenMediaVault installation is complete."
echo "Access the OMV web interface at http://192.168.4.1"
echo "Default admin username: $OMV_ADMIN_USER"
echo "Default admin password: $OMV_ADMIN_PASS"
