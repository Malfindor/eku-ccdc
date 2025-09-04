#!/bin/bash
TARGET_FILES=()
TARGET_FILE_STR=""
processConfFile()
{
	mapfile -t confList < "/etc/Arbiter/arbiter.conf"
	for line in "${confList[@]}"; do
		if ! [[ "${line:0:1}" == "#" ]]; then
			IFS="=" read -ra lineSplit <<< "$line"
			case "${lineSplit[0]}" in
				"LOG_SERVER")
						LOG_SERVER="${lineSplit[1]}"
					;;
				"LOG_PORT")
						LOG_PORT="${lineSplit[1]}"
					;;
				"MONITORED_FILES")
						fileList="${lineSplit[1]}"
						rawFileList="${whitelist:1:-1}"
						IFS="," read -ra fileSplit <<< "$rawFileList"
						for entry in "${fileSplit[@]}"; do
							TARGET_FILES+=("$entry")
						done
					;;
				*)
					;;
			esac
		fi
	done
}
while true; do
	processConfFile
	for file in "${TARGET_FILES[@]}"; do
		TARGET_FILE_STR="$TARGET_FILE_STR $file"
	done
	tail -F $TARGET_FILE_STR | while read line; do
		echo "$line" | nc $LOG_SERVER $LOG_PORT
	done
done