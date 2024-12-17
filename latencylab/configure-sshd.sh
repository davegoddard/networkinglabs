#!/bin/bash

# Path to the SSH configuration file
sshd_config="/etc/ssh/sshd_config"
isUpdated=0

# Check if Port 22 is commented and uncomment it
sudo sed -i '/^#Port 22/s/^#//' $sshd_config

# Check if Port 2224 is already present
grep -q "^Port 2224" $sshd_config

# If Port 2224 is not present, add it under Port 22
if [ $? -ne 0 ]; then
    sudo sed -i '/^Port 22/a Port 2224' $sshd_config
    isUpdated=1
    echo "Added Port 2224 to the sshd configuration"
fi

# Restart the SSH service to apply changes
if [ $isUpdated -eq 1 ] ; then
    echo "Restarting sshd to reflect new config"
    sudo systemctl daemon-reload
    sudo systemctl restart ssh.socket
fi
