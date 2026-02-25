#!/bin/bash

if [ "$EUID" -ne 0 ]
then echo "This script must be ran as root!"
	exit
fi

userlist="$(cut -d : -f 1 /etc/passwd | grep -v root)"

echo "Currently connected users:"
w

for user in $userlist
do
	usershell=$(cat /etc/passwd | grep $user | cut -d : -f 7)
	for shell in $(cat /etc/shells)
	do
		if [ "$usershell" = "$shell" ]
		then 
			echo "Attempting to kill user $user..."
			pkill -KILL -u $user
		fi
	done
done

echo "Waiting for processes to end..."
sleep 5
echo "Connected users after kick:"
w

exit 1
