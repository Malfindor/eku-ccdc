#!/bin/bash

# Author: Raven Dean
# restore.sh
#
# Description: This script restores files that were backed up using ./backup.sh. It includes checks
#  to ensure nothing was tampered with. 
#
# Dependencies: N/A
# Created: 02/04/2024
# Usage: ./restore.sh

script_name="restore.sh"
usage="./restore.sh <directory>"

#TODO: Provide the user with a menu of all current backups.

# Get the path of the repository root
repo_root=$(git rev-parse --show-toplevel)

# Check repository security requirement
check_security

# Import environment variables
. $repo_root/config_files/ekurc

if [ "$EUID" -ne 0 ] # Superuser requirement. Echo the error to stderr and return exit code 1.
then error "This script must be ran as root!"
    exit 1
fi

# Check for the correct number of arguments
if [ "$#" -ne 1 ]
then error $usage
    exit 1
fi

# Check if the supplied directory exists in the backups folder
backup_name=$(realpath $1)
grep --quiet "$backup_name" $backup_dir/map
if [ ! "$?" -eq 0 ]
then
    error "'$1' does not exist in the backups folder!"
    exit 1
fi

# Check if the backup and it's checksum are still immutable

# Validate the backup's checksum

# Everything seems okay... restore the directory from the backup.

# Grab the path information from the map file
read map_backup_path original_path unused <<< $(cat $backup_dir/map | grep "$(realpath $1)")

rm -rf $backup_name
tar -xzf $map_backup_path -C $original_path

exit 0 # Script ended successfully

