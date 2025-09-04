#!/bin/bash
LISTEN_PORT=18965
processCommand() # Usage: processCommand {command}
{
	IS_PREDEFINED_CMD=$false
	input="$1"
	
	IFS="-" read -ra inputSplit <<< "$input"
	case "${inputSplit[0]}" in
		"B45")
			IS_PREDEFINED_CMD=$true
			firewall -ba "${inputSplit[1]}"
			current_time=$(date +"%H:%M:%S")
			echo "[$current_time] - Accepted blacklist command for IP: ${inputSplit[1]}" >> /var/log/manticore.log
		;;
		*)
			
		;;
	esac
}
while true; do
	recievedMsg="$(nc -l -p $LISTEN_PORT)"
	processCommand "$recievedMsg"
	if ! $IS_PREDEFINED_CMD; then
		#Code to process playbook input
	fi
done