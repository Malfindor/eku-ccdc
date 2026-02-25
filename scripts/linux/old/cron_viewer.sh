#!/bin/bash
# Author: Raven

# Get all users from /etc/passwd
users=$(cat /etc/passwd | cut -d ':' -f 1)

# Loop through each user and display their crontab
for user in $users; do
    echo "Crontab for user: $user"
    crontab -l -u "$user"
    echo "-----------------------------"
done

#TODO: Check /var/spool/cron

# Display the system crontab
printf "System Crontab: \n%s\n" "$(cat /etc/crontab)"

