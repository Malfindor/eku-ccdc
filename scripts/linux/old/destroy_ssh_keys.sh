#!/bin/bash

# Author - Raven

# Read all filenames in /tmp/destroy_ssh.tmp and forcefull delete them.
destroy_keys() {
    cat /tmp/destroy_ssh.tmp | while read filename; do rm -f $filename; done
	echo "Successfully deleted $(wc -l < /tmp/destroy_ssh.tmp) files!"
}

if [ "$EUID" -ne 0 ]
then echo "This script must be ran as root!"
    exit
fi

# Create temporary file and make is rw by root only
touch /tmp/destroy_ssh.tmp
chmod 600 /tmp/destroy_ssh.tmp

# Find the authorized key files and store them in /tmp/destroy_ssh.tmp
find /root /home -name authorized_keys -type f -path '*.ssh/*' > /tmp/destroy_ssh.tmp

# Confirm deletion
echo $(wc -l < /tmp/destroy_ssh.tmp) authorized_keys files were found.
read -p "Do you want to permanently delete these files? (y/n) " choice
case "$choice" in
    y|Y ) destroy_keys;;
    n|N ) echo "Operation cancelled.";;
    * ) echo "Choose y/n.";;
esac

# Deletion complete, remove temporary file
rm /tmp/destroy_ssh.tmp
exit 0
