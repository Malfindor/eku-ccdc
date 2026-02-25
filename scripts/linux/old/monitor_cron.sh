#!/bin/bash

# Author: Trevor Thibadeau

# Script to monitor all crontabs for all users, including system crontabs
# If a change is found, the changed file will be saved to /var/spool/quarantineCron and the actual crontab will be replaced with the backup
# A log will be generated stating when a change has been detected at /var/spool/logCron
# Backups of the originals are saved at /var/spool/backupCron
# Quarantined files are located at /var/spool/quarantineCron
# Additionally, if the number of files between backup and in use changes, that is noted in the log file
# Finally, if a name discrepancy is detected, the file is moved to quarantine and a note is made in the log file
# FIRST TIME RUNNING - make sure to use the -c flag to make the copies of the crontabs to the backup directory

# Ensure script is being ran as root
if [ "$EUID" -ne 0 ]
then echo "Script must be ran as root!"
    exit
fi

# Usage
print_usage(){
    echo -e "-c copy files to the backup directory before monitoring\nno flags just starts the monitoring"
}

# Make backup directory, log file, and quarantine directory if they don't exist
BACKUP="/var/spool/backupCron/"
LOG="/var/spool/logCron"
QUAR="/var/spool/quarantineCron"

if [ ! -d "$BACKUP" ]
then 
    mkdir "$BACKUP"
    chmod 400 "$BACKUP"
fi

if [ ! -f "$LOG" ]
then 
    touch "$LOG"
    chmod 600 "$LOG"
fi

if [ ! -d "$QUAR" ]
then
    mkdir "$QUAR"
    chmod 400 "$QUAR"
fi

# Make sure hidden files can be detected as well
shopt -s dotglob

# Copy all crontabs for all users to the backup directory, including system crontabs - only runs if the -c flag is used
# TOCHANGE - LOCATIONS FOR CRONTABS NOT CONSISTENT ACROSS DISTROS - NEED TO MAKE DIRECTORIES IF THEY DON'T EXIST
while getopts ":c" option; do
    case $option in
        c)
            cp /var/spool/cron/crontabs/* "$BACKUP"
            cp /var/spool/cron/* "$BACKUP"
            cp  -r /etc/cron* "$BACKUP"
            ;;
        *)
            print_usage
            exit 1
            ;;
    esac
done

# Start infinite loop of checking the integrity of the files
while true
do
    # Check number of files in backup vs in use
    backupNames=($(find "$BACKUP" -type f))
    currentNames=($(find /var/spool/cron/crontabs -type f) /etc/crontab $(find /etc/cron.d -type f) $(find /etc/cron.daily -type f) $(find /etc/cron.hourly -type f) $(find /etc/cron.monthly -type f) $(find /etc/cron.weekly -type f) $(find /etc/cron.yearly -type f))

    if [ "${#backupNames[@]}" != "${#currentNames[@]}" ]
    then
        echo "$(date) ** Number of files in backup and in use are not the same ** In backup: "${#backupNames[@]}" ** In use: "${#currentNames[@]}"" >> "$LOG"
    fi

    # Check names of files in backup vs in use
    for name1 in "${currentNames[@]}"
    do
        found="false"
        for name2 in "${backupNames[@]}"
        do
            if [ "$(basename "$name1")" = "$(basename "$name2")" ]
            then
                found="true"
                break
            fi
        done
        if [ "$found" != "true" ]
        then
            echo "$(date) ** New file name detected in use (not in backup) ** moving to "$QUAR" ** File in question: "$name1"" >> "$LOG"
            mv "$name1" "$QUAR"
        fi
    done

    # Check contents of files for changes
    for FILE in "$BACKUP"/*
    do
        if [ -f "$FILE" ]
        then
            if [ "$(basename "$FILE")" = "crontab" ]
            then
                checksum1=$(md5sum "$FILE" | awk '{print $1}')
                checksum2=$(md5sum "/etc/crontab" | awk '{print $1}')
                if [ "$checksum1" != "$checksum2" ]
                then
                    echo -e "$(date) ** A change has occurred in /etc/crontab ** check /var/spool/quarantineCron/crontab to see the attempted change" >> "$LOG"
                    cp /etc/crontab /var/spool/quarantineCron
                    cp "$FILE" /etc/crontab
                fi
            else
                checksum1=$(md5sum "$FILE" | awk '{print $1}')
                checksum2=$(md5sum "/var/spool/cron/crontabs/$(basename "$FILE")" | awk '{print $1}')
                if [ "$checksum1" != "$checksum2" ]
                then
                    echo -e "$(date) ** A change has occurred in /var/spool/cron/crontabs/$(basename "$FILE") ** check /var/spool/quarantineCron/$(basename "$FILE") to see the attempted change" >> "$LOG"
                    cp /var/spool/cron/crontabs/"$(basename "$FILE")" /var/spool/quarantineCron
                    cp "$FILE" /var/spool/cron/crontabs/"$(basename "$FILE")"
                fi
            fi
        elif [ -d "$FILE" ] && [ "$(find "$FILE" -type f)" ]
        then
            for FILE2 in "$FILE"/*
            do
                if [ "$(basename "$FILE2")" != "*" ]
                then
                    checksum1=$(md5sum "$FILE2" | awk '{print $1}')
                    checksum2=$(md5sum "/etc/$(basename "$FILE")/$(basename "$FILE2")" | awk '{print $1}')
                    if [ "$checksum1" != "$checksum2" ]
                    then
                        echo -e "$(date) ** A change has occurred in /etc/$(basename "$FILE")/$(basename "$FILE2") ** check /var/spool/quarantineCron/$(basename "$FILE2") to see the attempted change" >> "$LOG"
                        cp "/etc/$(basename "$FILE")/$(basename "$FILE2")" /var/spool/quarantineCron
                        cp "$FILE2" /etc/"$(basename "$FILE")/$(basename "$FILE2")"
                    fi
                fi
            done
        fi
    done
    sleep 30
done
