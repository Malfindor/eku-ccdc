#!/bin/bash

# Author: Raven Dean
# Script: backup.sh
#
# Description: This script creates a backup of the files and directories passed in the arguments.
#  This script works in tandem with ./restore.sh 
#
# Dependencies: $repo_root/config_files/ekurc
#
# Notes:
#  Stores backup files in the path specified in $repo_root/config_files/ekurc
#  'Overwritten' backups are just renamed with a leading . and trailing ~, however they must be manually restored because the map
#   and checksum data is deleted.
#
#  Backups can be restored using ./restore.sh
#
# Created: 02/04/2024
# Usage: <./backup.sh <directory>>

script_name="backup.sh"
usage="Usage: ./$script_name <directory>"

# Get the path of the repository root
repo_root=$(git rev-parse --show-toplevel)

# Import environment variables
. $repo_root/config_files/ekurc

# Check repository security requirement
check_security

if [ "$EUID" -ne 0 ] # Superuser requirement. Echo the error to stderr and return exit code 1.
then error "This script must be ran as root!" >&2
    exit 1
fi

# Check for the correct number of arguments
if [ "$#" -lt 1 ]
then error $usage >&2
    exit 1
fi

# Create necessary files and set the umask
umask 027 # rw-r-----
mkdir -p $backup_dir # Backup directory
touch $backup_dir/map # Map to original location
touch $backup_dir/checksums # sha256sums
chattr +a $backup_dir/map # Make the map file immutable and appendable only
chattr +a $backup_dir/checksums

info "Creating backups..."

# For each argument, check if the argument is a valid file or directory.
for item in "$@"
do
    if [ -d "$item" ] || [ -f "$item" ]; then
        # Variable definitions. 
        # The usage of 'date' is not to timestamp archives, but to make sure that no naming collisions occur when backing up multiple files with the same name. Also note that there is still a chance of collision if multiple files with the same name are backed up in the same second.
        backup_path="$backup_dir/$(basename $item)-$(date +%s).tar.gz"
        checksum_path="$backup_dir/checksums"
        original_dir="$(dirname $(realpath $item))"

        # If the original directory is not the root directory, append a /
        if [ $(dirname $item) != "/" ]
        then
            original_dir="$original_dir/"
        fi

        # If the item already exists in the map, show a warning and confirm the overwrite
        grep --quiet " $(realpath $item)$" $backup_dir/map
        if [ "$?" -eq 0 ]
        then
            warn "'$item' already exists in the backups folder. Overwrite? (y/n)."
            read -n 1 -s yn

            if [ "$yn" == "n" ];
            then
                info "Skipping '$item'..."
                continue
            else # Dereference the old backup and continue.
                # Grab the path information from the map file
                read map_backup_path unused_vars <<< $(cat $backup_dir/map | grep "$(realpath $item)")

                # Remove the immutability.
                chattr -ia $map_backup_path $backup_dir/checksums $backup_dir/map

                # Rename the original backup and remove it's relevant information
                mv $map_backup_path ".$map_backup_path~"
                sed -i "\|$map_backup_path|d" $backup_dir/checksums $backup_dir/map

                # Restore immutability to the old archive
                chattr +i .$map_backup_path~
                chattr +a $backup_dir/checksums $backup_dir/map
            fi
        fi

        # Create the archive, generate it's hash, and store the original file location for later restoration
        tar -czf $backup_path $item 2>/dev/null
        if [ ! "$?" -eq 0 ]
        then
            # Something went wrong while making the backup. Abort the process and continue to the next item.
            error "Archiving failed for '$item'." >&2
            rm -f $backup_path
            chattr -a $backup_dir/map
            sed -i "\|$backup_path|d" $backup_dir/map
            chattr +a $backup_dir/map
            continue
        fi

        sha256sum $backup_path >> $backup_dir/checksums
        printf "$backup_path $original_dir $(realpath $item)\n" >> $backup_dir/map

        # Make the backup immutable to protect backup integrity
        chattr +i $backup_path

        # Backup complete!
        success "The backup of '$(realpath $item)' was completed successfully!"
    else
        error "'$item': No such file or directory." >&2
    fi
done

exit 0 # Script ended successfully

