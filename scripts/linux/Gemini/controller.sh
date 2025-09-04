#!/bin/bash
service_running=$false
module_list=("gemini-core" "gemini-firewatch")
while true; do
	for module in "${module_list[@]}"; do
		if ! systemctl is-active --quiet "$module"; then
			current_time=$(date +"%H:%M:%S")
			log="[ $current_time ] - The following Gemini module was found to be disabled and was re-enabled: $module"
			echo $log >> /var/log/gemini.log
		fi
	done
sleep 10
done