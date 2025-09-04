#!/bin/bash
validRules=$(< /etc/gemini/iptablesrules.bak)
echo "$validRules" > /tmp/iptables_valid
echo "" > /tmp/iptables_ack
while true; do
    iptables -L -v -n > /tmp/iptables_current
    if ! diff /tmp/iptables_valid /tmp/iptables_current > /dev/null; then
		if ! diff /tmp/iptables_ack /tmp/iptables_current > /dev/null; then
			current_time=$(date +"%H:%M:%S")
			log="[ $current_time ] - Changes to iptables were detected."
			echo $log >> /var/log/gemini.log
			echo "$(< /tmp/iptables_current)" > /tmp/iptables_ack
		fi
    fi
    sleep 5
done