#!/bin/bash
whitelistUsers=()
suspiciousServices=()
revShellFlags=()
getFileContAsArray() #usage: "getFileCont {file name} {array variable name}"
{
	local fileName="$1"
	local -n arr="$2"
	if [[ ! -f "$fileName" ]]; then
		return 1
	fi
	mapfile -t arr < "$fileName"
}
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
userInWhitelist() 
{
    local user="$1"
	local -n result="$2"
	result="4"
    for entry in "${whitelistUsers[@]}"; do
        if [[ "$entry" == "$user" ]]; then
            result="2"
        fi
    done
    if [[ ! $result == "2" ]]; then
		result="3"
	fi
}
processConfFile()
{
	mapfile -t confList < "/etc/gemini/gemini.conf"
	for line in "${confList[@]}"; do
		if ! [[ "${line:0:1}" == "#" ]]; then
			IFS="=" read -ra lineSplit <<< "$line"
			case "${lineSplit[0]}" in
				"remote_logging_server")
					logServer="${lineSplit[1]}"
					;;
				"remote_logging_port")
					logPort="${lineSplit[1]}"
					;;
				"user_whitelist")
					whitelist="${lineSplit[1]}"
					rawWhitelist="${whitelist:1:-1}"
					IFS="," read -ra whiteSplit <<< "$rawWhitelist"
					for entry in "${whiteSplit[@]}"; do
						whitelistUsers+=("$entry")
					done
					;;
				"max_uid_gid")
					UID_GID_LIMIT="${lineSplit[1]}"
					;;
				"suspicious_services")
					servicelist="${lineSplit[1]}"
					rawServicelist="${servicelist:1:-1}"
					IFS="," read -ra serviceSplit <<< "$rawServicelist"
					for entry in "${serviceSplit[@]}"; do
						suspiciousServices+=("$entry")
					done
					;;
				"reverse_shell_flags")
					flagList="${lineSplit[1]}"
					rawFlagList="${flagList:1:-1}"
					IFS="," read -ra flagSplit <<< "$rawFlagList"
					for entry in "${flagSplit[@]}"; do
						revShellFlags+=("$entry")
					done
					;;
				*)
					;;
			esac
		fi
	done
}
getFileContAsStr /etc/gemini/machine.name machineName
while true; do
processConfFile
#Checking for unknown users
getFileContAsArray "/etc/passwd" passwdConts
for line in "${passwdConts[@]}"; do
	IFS=":" read -ra userInfo <<< "$line"
	username=${userInfo[0]}
    declare -i uid=${userInfo[2]}
    declare -i gid=${userInfo[3]}
	userInWhitelist $username isInWhitelist
	if [[ $uid -gt $UID_GID_LIMIT || $gid -gt $UID_GID_LIMIT ]] && [[ $isInWhitelist == "3" ]]; then
		userdel -f $username
		current_time=$(date +"%H:%M:%S")
		log="[ $current_time ] - An unknown user with UID/GID above $UID_GID_LIMIT was found and removed: $username"
		echo $log >> /var/log/gemini.log
	fi
isInWhitelist=""
done
#Checking for malicious services
mapfile -t serviceList < <(systemctl list-unit-files)
for line in "${serviceList[@]}"; do
	for maliciousService in "${suspiciousServices[@]}"; do
		if [[ "$line" == *"$maliciousService"* ]]; then
			systemctl stop "$maliciousService"
            systemctl disable "$maliciousService"
            mkdir /.quarantine/Q-S-"$maliciousService"
            mv /etc/systemd/system/"$maliciousService".service /.quarantine/Q-S-"$maliciousService"
            mv /usr/lib/systemd/system/"$maliciousService".service /.quarantine/Q-S-"$maliciousService"
            systemctl daemon-reload
            systemctl reset-failed
			current_time=$(date +"%H:%M:%S")
            log = "[ $current_time ] - A suspicious service was found and quarintined: $maliciousService"
            echo "$log" >> /var/log/gemini.log
		fi
	done
done
#Checking for crontab changes
getFileContAsStr "/etc/crontab" crontabCont
if [[ ! "${#crontabCont}" == 0 ]]; then
	if [[ ! "$crontabCont" == "\n" ]]; then
		echo "" > /etc/crontab
		current_time=$(date +"%H:%M:%S")
		log="[ $current_time ] - Changes were detected in /etc/crontab and removed: $crontabCont"
		echo $log >> /var/log/gemini.log
	fi
fi
#Checking for common reverse shell practices
mapfile -t processList < <(ps -ef)
for process in "${processList[@]}"; do
	flagFound=$false
	for flag in "${revShellFlags[@]}"; do
		if [[ "$process" == *"$flag"* ]]; then
			flagFound=$true
		fi
		if [[ $flagFound ]]; then
			current_time=$(date +"%H:%M:%S")
			log="[ $current_time ] - Reverse shell flags were detected in current running processes."
			echo $log >> /var/log/gemini.log
		fi
	done
done
#Checking for remote logins
mapfile -t loginList < <(who)
for login in "${loginList[@]}"; do
	IFS=" " read -ra loginSplit <<< "$login"
	if [[ "${#loginSplit[@]}" == 5 ]]; then
		IFS="." read -ra ipList <<< "${loginSplit[4]}"
		if [[ "${#ipList[@]}" == 4 ]]; then
			user="${loginSplit[0]}"
			seat="${loginSplit[1]}"
			echo "These are not the machines you are looking for." | write $user $seat
			pkill -KILL -t $seat
			date="${loginSplit[2]}"
			time="${loginSplit[3]}"
			remoteIP="${loginSplit[4]}"
			current_time=$(date +"%H:%M:%S")
			log="[ $current_time ] - A remote login was detected. User: $user was logged into at $date : $time from address: $remoteIP using seat: $seat"
			echo $log >> /var/log/gemini.log
		fi
	fi
done
sleep 30
done