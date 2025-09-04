#!/bin/bash
#TMP_FILE="/tmp/titan.tmp"
#PATTERN="404|DirBuster|Gobuster"
suspiciousFileNames=("shell.php" "template.php")
ADMIN_IP=()
#touch "$TMP_FILE"
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
processConfFile()
{
	mapfile -t confList < "/etc/titan/titan.conf"
	for line in "${confList[@]}"; do
		if ! [[ "${line:0:1}" == "#" ]]; then
			IFS="=" read -ra lineSplit <<< "$line"
			case "${lineSplit[0]}" in
				"WEBSERVER_ACCESS_LOG")
					ACCESS_LOG="${lineSplit[1]}"
					;;
				"ALLOWED_IPS")
					if ! [[ -z "${lineSplit[1]}" ]]; then
						IFS="," read -ra adminSplit <<< "${lineSplit[1]}"
						for entry in "${adminSplit[@]}"; do
						ADMIN_IP+=("$entry")
					done
					fi
					;;
				"ADMIN_PANEL_PATH")
					if ! [[ -z "${lineSplit[1]}" ]]; then
						ADMIN_PATH="${lineSplit[1]}"
					else
						ADMIN_PATH="admin"
					fi
					;;
				*)
					;;
			esac
		fi
	done
}
findFiles() 
{
    local origin="$1"
    fileList=()
    while IFS= read -r file; do
        fileList+=("$file")
    done < <(find "$origin" -type f)
}
getFileContAsStr /etc/gemini/machine.name machineName
processConfFile
tail -F $ACCESS_LOG | while read line; do

    #Admin panel access
	IFS=" " read -ra lineSplit <<< "$line"
		if [[ "$line" == *"$ADMIN_PATH"* ]]; then
			isValid=$false
			IP="${lineSplit[0]}"
			for ip in "${ADMIN_IP[@]}"; do
				if [[ "ip" == *"/"* ]]; then
					IFS="/" read -ra ipSplit <<< "$ip"
					netMask=((${ipSplit[1]}))
					IFS="." read -ra ipProcessed <<< "$ip"
					for entry in "${ipProcessed[@]}"; do
						newIP="$newIP"+"$entry"
					done
					ipSubnet=${ip:0:$netMask}
					if [[ "$IP" == "$ipSubnet"* ]]; then
						isValid=$true
					fi
				else
					if [[ "$IP" == "$ip" ]]; then
						isValid=$true
					fi
				fi
			done
			if ! [[ $isValid ]]; then
				current_time=$(date +"%H:%M:%S")
				log="[ $current_time ] - Potential access of the admin panel from IP: $IP"
				echo $log >> /var/log/gemini.log
			fi
		fi
	
	#Suspicious file monitoring
	findFiles "/var/www/"
	for file in "${fileList[@]}"; do
		for suspiciousFile in "${suspiciousFileNames[@]}"; do
			if [[ "$file" == *"$suspiciousFile"* ]]; then
				mv $file "/.quarantine/$suspiciousFile"
				current_time=$(date +"%H:%M:%S")
				log="[ $current_time ] - A suspicious file was detected in '/var/www' and was quarintined: $file"
				echo $log >> /var/log/gemini.log
			fi
		done
	done
    sleep 5
done


#DIR BUSTING OLD
#NEW_ENTRIES=$(comm -13 <(sort "$TMP_FILE") <(sort "$ACCESS_LOG"))
#
#    echo "$NEW_ENTRIES" | grep -E "$PATTERN" | while read -r line; do
#        echo "$line" >> "$TMP_FILE"
#
#        IP=$(echo "$line" | awk '{print $1}')
#
#        current_time=$(date +"%H:%M:%S")
#		log="[ $current_time ] - Detected potential directory busting from $IP"
#		echo $log >> /var/log/gemini.log
#    done