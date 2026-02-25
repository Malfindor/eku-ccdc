#!/usr/bin/env bash

if [ "$EUID" -ne 0 ] # Superuser requirement.
then error "This script must be ran as root!"
    exit 1
fi

# Update repos
mkdir /etc/yum.repos.d/old
mv /etc/yum.repos.d/CentOS*.repo /etc/yum.repos.d/old/
mv /etc/yum.repos.d/epel*.repo /etc/yum.repos.d/old/

curl --insecure -o /etc/yum.repos.d/CentOS.repo https://raw.githubusercontent.com/ravesec/eku-ccdc/refs/heads/main/config_files/CentOS.repo
curl --insecure -o /etc/yum.repos.d/epel.repo https://raw.githubusercontent.com/ravesec/eku-ccdc/refs/heads/main/config_files/epel.repo

yum clean all
yum-config-manager --disable epel
yum update

# Get rid of broken repos
rm /etc/yum.repos.d/CentOS-*
echo "Update complete. If you run 'yum update' again, make sure to delete the broken repos that it adds to /etc/yum.repos.d/"

exit 0 # Script ended successfully
