#!/bin/bash
getFileContAsStr()
{
	local fileName="$1"
	local -n fileCont="$2"
	if [[ ! -f "$fileName" ]]; then
        fileCont=""
	else
		fileCont=$(<"$fileName")
    fi
}
mkdir /var/log/warning.log
mkdir /etc/backups
listOfFiles=("/etc/sysctl.conf","/etc/security/limits.conf","/etc/syslog.conf","/etc/network/interfaces","/etc/resolv.conf","/etc/passwd","/etc/group","/etc/shadow","/etc/fstab","/etc/mtab")
for file in "${listOfFiles[@]}"; do
	getFileContAsStr "$file" fileCont
	touch /etc/backups/"$file".backup
	echo "$fileCont" > /etc/backups/"$file".backup
done
values="true"
while [ "$values" -eq "true" ]; do
	for file in "${listOfFiles[@]}"; do
		getFileContAsStr "$file" fileCont
		getFileContAsStr /etc/backups/"$file".backup fileContBackup
		if ! [[ "$fileCont" -eq "$fileContBackup" ]]; then
			echo "$fileContBackup" > "$file"
			current_time=$(date +"%H:%M:%S")
			log="[$current_time] - A file was detected as changed - $file"
			echo "$log" >> /var/log/warning.log
		fi
	done
done