#!/bin/bash

echo "Cronjobs are commands that are set to execute periodically"
echo "They can be useful, but frequently run malicious commands in CCDC"
echo "Check if any of the jobs (commands) listed look suspicious"
echo "Navigate to the file, screenshot for evidence and remove"
echo "-----------------------------------------------------------------"
echo

files=(/etc/crontab)
directories=(/etc/cron.d /var/spool/cron/crontabs)

for file in ${files[@]}; do
    echo "Cronjobs from the $file file:"
    cat $file | grep -E '^[0-9]|^\*' | awk '{ORS=" "; print "\t"; for (i=7; i<=NF; i++) print $i; print "\n"}'
    echo
done

for dir in ${directories[@]}; do
    echo "Searching in $dir directory"
    for file in $dir/*; do
        echo "    Cronjobs from $file:"
        cat $file | grep -E '^[0-9]|^\*' | awk '{ORS=" "; print "\t"; for (i=7; i<=NF; i++) print $i; print "\n"}'
        echo
    done
done
