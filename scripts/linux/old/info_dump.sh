#!/bin/bash
# Author: Raven

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    printf "This script must be run as root!\n" >&2
    exit 1
fi

# Get the repository root
repo_root=$(git rev-parse --show-toplevel)

# Import environment variables
. $repo_root/config_files/ekurc

# Check the repository security requirement
check_security

printf "/******************************/
/* OS and Account Information */
/******************************/\n\n"

printf "<!-- OS Release Information --!>\n\n%s\n\n" "$(cat /etc/os-release)"

printf "<!-- User Accounts --!>\n\n%s\n\n" "$(cat /etc/passwd | grep sh$ | cut -d ':' -f 1)"

printf "<!-- Group Information --!>\n\n%s\n\n" "$(cat /etc/group)"

printf "<!-- Sudoers Information --!>\n\n%s\n\n" "$(cat /etc/sudoers)"

printf "<!-- Login Information --!>\n\n%s\n\n" "$(last -f /var/log/wtmp)"

printf "<!-- Authentication Logs --!>\n\n%s\n\n" "$(cat /var/log/auth.log)"

printf "/************************/
/* System Configuration */
/************************/\n\n"

printf "<!-- System Uptime --!>\n\n%s\n\n" "$(uptime)"

printf "<!-- Hostname --!>\n\n%s\n\n" "$(cat /etc/hostname)"

printf "<!-- Timezone Information --!>\n\n%s\n" "$(cat /etc/timezone)"
date +"%H:%M:%S %Z %z"
printf "\n"

printf "<!-- Valid Shells --!>\n\n%s\n\n" "$(cat /etc/shells)"

printf "<!-- Network Configuration --!>\n\n%s\n\n%s\n\n" "$(cat /etc/network/interfaces)" "$(ip address show)"

printf "<!-- Active Network Connections --!>\n\n%s\n\n" "$(ss -luntp)"

printf "<!-- Running Processes --!>\n\n%s\n\n" "$(ps -aux && ps -ef --forest)"

printf "<!-- DNS Information --!>\n\n%s\n\n%s\n\n" "$(cat /etc/hosts)" "$(cat /etc/resolv.conf)"

printf "/**************************/
/* Persistence Mechanisms */
/**************************/\n\n"

printf "<!-- Cron Jobs --!>\n\n"

# Get all users from /etc/passwd
users=$(cat /etc/passwd | cut -d ':' -f 1)

# Loop through each user and display their crontab
for user in $users; do
    echo "Crontab for user: $user"
    crontab -l -u "$user"
    echo "-----------------------------"
done

# Display the system crontab
printf "System Crontab: \n%s\n" "$(cat /etc/crontab)"

printf "/**********************************/
/* Dangerous Binaries (SUID/SGID) */
/**********************************/\n\n"
#TODO Find SUID/SGID executables on the system
#find / -type f -executable \( -perm -4000 -o -perm -2000 \) -exec ls -lah {} \; 2>/dev/null | grep -v "/usr | grep -v "/root/bu" | grep -v "/bin" | grep -v "/sbin"

#TODO Check for services in /etc/init.d

#TODO Check user's .bashrc files

#TODO List recent commands executed by sudo

#TODO Check Bash history

#TODO Show third party log files in /var/log

#TODO Tail the syslog
