#!/bin/bash
printHelp()
{
	echo "
Gemini - System integrity application

Usage:
		
		gemini start - Starts up gemini services
		gemini stop - Shuts down gemini services
		gemini restart - Restarts all gemini services
		
Arguments:

		-v   |   Verifies integrity of gemini system files ((NOT IMPLEMENTED))
		
Module Arguments:
		
		-f   |   Interact with the Firewatch module
		-w   |   Interact with the Watchdog module

"
}
verifyRunning()
{
	local module="$1"
	local -n isRunning="is_Running"
	if systemctl is-active --quiet "$module"; then
		isRunning=true
	else
		isRunning=false
	fi
}
module_list=("gemini-core" "gemini-firewatch")
if [[ -z $1 ]]; then
	printHelp
	exit
fi
if [[ "$1" == "start" ]]; then
	echo "Starting Gemini..."
	echo "---------------------------------------------------------"
	echo ""
	if [[ -f /etc/gemini/started.flag ]]; then
		echo "First time startup detected, enabling all services to startup on system boot"
		systemctl enable gemini
		for module in "${module_list}"; do
			systemctl enable "$module"
		done
		touch /etc/gemini/started.flag
		echo ""
	fi
	for module in "${module_list[@]}"; do
		systemctl start "$module"
		sleep 1
		verifyRunning "$module"
		if [[ "$is_Running" == "true" ]]; then
			echo "$module status: \033[32;1m[RUNNING]\033[0m"
		else
			echo "$module status: \033[31;1m[FAILED TO START]\033[0m"
		fi
	done
	systemctl start gemini
	sleep 1
	verifyRunning "gemini"
	if [[ "$is_Running" == "true" ]]; then
		echo "Controller status: \033[32;1m[RUNNING]\033[0m"
	else
		echo "Controller status: \033[31;1m[FAILED TO START]\033[0m"
	fi
	exit
fi
if [[ "$1" == "stop" ]]; then
	echo "Stopping Gemini..."
	echo "---------------------------------------------------------"
	echo ""
	systemctl stop gemini
	sleep 1
	verifyRunning "gemini"
	if ! [[ "$is_Running" == "true" ]]; then
		echo "Controller status: \033[32;1m[TERMINATED]\033[0m"
	else
		echo "Controller status: \033[31;1m[FAILED TO TERMINATE]\033[0m"
	fi
	for module in "${module_list[@]}"; do
		systemctl stop "$module"
		sleep 1
		verifyRunning "$module"
		if ! [[ "$is_Running" == "true" ]]; then
			echo "$module status: \033[32;1m[TERMINATED]\033[0m"
		else
			echo "$module status: \033[31;1m[FAILED TO TERMINATE]\033[0m"
		fi
	done
	exit
fi
if [[ "$1" == "restart" ]]; then
	echo "Stopping Gemini..."
	echo "---------------------------------------------------------"
	echo ""
	systemctl stop gemini
	sleep 1
	verifyRunning "gemini"
	if ! [[ "$is_Running" == "true" ]]; then
		echo "Controller status: \033[32;1m[TERMINATED]\033[0m"
	else
		echo "Controller status: \033[31;1m[FAILED TO TERMINATE]\033[0m"
	fi
	for module in "${module_list[@]}"; do
		systemctl stop "$module"
		sleep 1
		verifyRunning "$module"
		if ! [[ "$is_Running" == "true" ]]; then
			echo "$module status: \033[32;1m[TERMINATED]\033[0m"
		else
			echo "$module status: \033[31;1m[FAILED TO TERMINATE]\033[0m"
		fi
	done
	echo ""
	echo ""
	echo "Starting Gemini..."
	echo "---------------------------------------------------------"
	echo ""
	for module in "${module_list[@]}"; do
		systemctl start "$module"
		sleep 1
		verifyRunning "$module"
		if [[ "$is_Running" == "true" ]]; then
			echo "$module status: \033[32;1m[RUNNING]\033[0m"
		else
			echo "$module status: \033[31;1m[FAILED TO START]\033[0m"
		fi
	done
	systemctl start gemini
	sleep 1
	verifyRunning "gemini"
	if [[ "$is_Running" == "true" ]]; then
		echo "Controller status: \033[32;1m[RUNNING]\033[0m"
	else
		echo "Controller status: \033[31;1m[FAILED TO START]\033[0m"
	fi
	exit
fi