#!/bin/bash
if [ $EUID -ne 0 ]; then
    echo "Must be run as root"
	exit
fi
BLACKLIST_SIGNATURE=("DROP" "all" "--" "source" "destination")
WHITELIST_SIGNATURE=("ACCEPT" "all" "--" "source" "destination")
addToBlacklist() #Usage: addToBlacklist {ip}
{
	local blacklistIP="$1"
	
	iptables -A INPUT -s $blacklistIP -j DROP
	iptables -A OUTPUT -d $blacklistIP -j DROP
}
removeFromBlacklist() #Usage: removeFromBlacklist {ip}
{
	local blacklistIP="$1"
	getChainList input inputInfo
	getChainList output outputInfo
	local inputNum=$((-1))
	local outputNum=$((-1))
	
	for entry in "${inputInfo[@]}"; do
		IFS=" " read -ra entrySplit <<< "$entry"
		
		if [[ "${entrySplit[1]}" -eq "${BLACKLIST_SIGNATURE[1]}" ]] && [[ "${entrySplit[2]}" -eq "${BLACKLIST_SIGNATURE[2]}" ]] && [[ "${entrySplit[3]}" -eq "${BLACKLIST_SIGNATURE[3]}" ]] && [[ "${entrySplit[5]}" -eq "${BLACKLIST_SIGNATURE[5]}" ]] && [[ "${entrySplit[4]}" -eq "$blacklistIP" ]]; then
			inputNum=$((${entrySplit[0]}))
		fi
	done
	
	for entry in "${outputInfo[@]}"; do
		IFS=" " read -ra entrySplit <<< "$entry"
		
		if [[ "${entrySplit[1]}" -eq "${BLACKLIST_SIGNATURE[1]}" ]] && [[ "${entrySplit[2]}" -eq "${BLACKLIST_SIGNATURE[2]}" ]] && [[ "${entrySplit[3]}" -eq "${BLACKLIST_SIGNATURE[3]}" ]] && [[ "${entrySplit[4]}" -eq "${BLACKLIST_SIGNATURE[4]}" ]] && [[ "${entrySplit[5]}" -eq "$blacklistIP" ]]; then
			outputNum=$((${entrySplit[0]}))
		fi
	done
	
	if [[ $inputNum -gt 0 ]] && [[ $outputNum -gt 0 ]]; then
		iptables -D INPUT $inputNum
		iptables -D OUTPUT $outputNum
	else
		echo "Entered IP is not in the blacklist."
	fi
}
addToWhitelist() #Usage: addToWhitelist {ip}
{
	local whitelistIP="$1"
	
	iptables -A INPUT -s $whitelistIP -j ACCEPT
	iptables -A OUTPUT -d $whitelistIP -j ACCEPT
}
removeFromWhitelist() #Usage: removeFromWhitelist {ip} NOT DONE
{
	local whitelistIP="$1"
}
getChainList() #Usage: getChainList {chain} {variable name to save array to}
{
	local validChains=("INPUT" "OUTPUT" "FORWARD" "input" "output" "forward")
	local chainName="$1"
	local isValid="false"
	for chain in "${validChains[@]}"; do
		if [[ "$chainName" == "$chain" ]]; then
			isValid="true"
		fi
	done
	if [[ "isValid" == "false" ]]; then
		echo "Invalid chain entry"
		exit
	fi
	case "$chainName" in
		"INPUT")
			chainName="INPUT"
		;;
		"input")
			chainName="INPUT"
		;;
		"OUTPUT")
			chainName="OUTPUT"
		;;
		"output")
			chainName="OUTPUT"
		;;
		"FORWARD")
			chainName="FORWARD"
		;;
		"forward")
			chainName="FORWARD"
		;;
		*)
			echo "An error occured in chain name translation."
			exit
		;;
	esac
	local targetChainStartIndex=$((-1))
	local fullChainList=$(iptables -L --line-numbers)
	mapfile -t fullChainListSplit <<< "$fullChainList"
	local num=$((0))
	local currentLine=""
	while [ "$num" -lt "${#fullChainListSplit[@]}" ]; do
		currentLine="${fullChainListSplit[$num]}"
		if ! [[ ${#currentLine} -eq 0 ]]; then
			IFS=" " read -ra currentLineSplit <<< "$currentLine"
			if [[ "${currentLineSplit[0]}" == "Chain" ]] && [[ "${currentLineSplit[1]}" == "$chainName" ]]; then
				targetChainStartIndex=$num
			fi
		fi
		((num=$num+1))
	done
	num=$(($targetChainStartIndex+1))
	local targetChainEndIndex=$((0))
	while [ "$num" -lt "${#fullChainListSplit[@]}" ]; do
		currentLine="${fullChainListSplit[$num]}"
		if ! [[ ${#currentLine} -eq 0 ]]; then
			IFS=" " read -ra currentLineSplit <<< "$currentLine"
			if [[ "${currentLineSplit[0]}" -eq "Chain" ]] && [[ $targetChainEndIndex -eq 0 ]]; then
				targetChainEndIndex=$(($num-1))
			fi
		fi
		((num=$num+1))
	done
	if ! [[ $targetChainEndIndex -gt 0 ]]; then
		targetChainEndIndex=$((${#fullChainListSplit[@]}))
	fi
	if [[ $targetChainEndIndex -lt $targetChainStartIndex ]]; then
		echo "An error occured in finding the selected chain's boundaries"
		exit
	fi
	num=$targetChainStartIndex
	local -n returnArray="$2"
	returnArray=()
	while [ $num -lt $targetChainEndIndex ]; do
		currentLine="${fullChainListSplit[$num]}"
		if ! [[ ${#currentLine} -eq 0 ]]; then
			returnArray+=("$currentLine")
		fi
		((num=$num+1))
	done
}
getPortTranslationTCP() #Usage: getPortTranslationTCP {port} {variable to save to}         ||| This function will convert TCP ports from default protocol name -> port number, or port number -> default protocol name
{
	local input="$1"
	local -n returnString="$2"
	returnString=""
	
	case "$input" in
	"http")
		returnString="80"
	;;
	"https")
		returnString="443"
	;;
	"domain")
		returnString="53"
	;;
	"elad")
		returnString="1893"
	;;
	"dlsrap")
		returnString="1973"
	;;
	"smtp")
		returnString="25"
	;;
	"pop3")
		returnString="110"
	;;
	"irdmi")
		returnString="8000"
	;;
	"webcache")
		returnString="8080"
	;;	
	"8089")
		returnString="8089"
	;;
	*)	
	;;
	esac
}
verifyIntegrity() #Usage: verifyIntegrity
{
	VERIFIED=$false
}
saveRules()
{
	iptables-save > /etc/iptables/rules.v4
}
if [[ -z "$1" ]]; then
	mainCont="true"
	while [ "$mainCont" -eq "true" ]; do
		verifyIntegrity
		clear
		if ! $VERIFIED; then
			echo "Firewall Status: \033[31;1m[INACTIVE]\033[0m"
			echo "\033[33;1m[Terminating to avoid crashes due to missing structure. Run firewall with the '-i' flag to verify integrity.]\033[0m"
			exit
		else
			echo "Firewall Status: \033[32;1m[ACTIVE]\033[0m"
		fi
		getChainList input inputInfoRaw
		getChainList forward forwardInfoRaw
		getChainList output outputInfoRaw
		

	done
else
	case "$1" in
	"-ba")
		if [[ -z "$2" ]]; then
			echo "No IP provided to blacklist."
			exit
		else
			ip="$2"
			addToBlacklist "$ip"
		fi
	;;
	"-br")
		if [[ -z "$2" ]]; then
			echo "No IP provided to remove."
			exit
		else
		fi
	;;
	*)
		echo "Unknown argument."
		exit
	;;
fi