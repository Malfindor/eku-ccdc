#!/bin/bash

declare -A machines
machines[debian]="https://download.splunk.com/products/universalforwarder/#releases/10.0.1/linux/splunkforwarder-10.0.1-c486717c322b-linux-amd64.deb"

machines[ubuntu]="https://download.splunk.com/products/universalforwarder/#releases/10.0.1/linux/splunkforwarder-10.0.1-c486717c322b-linux-amd64.deb"

machines[centOS]="https://download.splunk.com/products/universalforwarder/#releases/10.0.1/linux/splunkforwarder-10.0.1-c486717c322b-linux-amd64.deb"

machines[fedora]="https://download.splunk.com/products/universalforwarder/releases/#10.0.1/linux/splunkforwarder-10.0.1-c486717c322b.x86_64.rpm"

machines[windows]="https://download.splunk.com/products/universalforwarder/#releases/10.0.1/windows/splunkforwarder-10.0.1-c486717c322b-windows-x64.msi"


echo "Machine Types:"
for key in "${machines[@]}"; do
    echo "-","$key"
done

read -p "What Machine Are You Using: " machine_type

if [[ -v machines[$machine_type] ]]; then
    echo "Getting Splunk Forwarder For $machine_type"
    splunk_forwarder=${machines[input]}
    wget -O splunkforwarder.tgz $splunk_forwarder
    tar -xvzf splunkforwarder.tgz -C /opt/
    cd /opt/splunkforwarder/bin
    ./splunk start --accept-license
    read -p "What Is The Machines IP Server?: " server_ip
    ./splunk add forward-server $server_ip:9997
    ./splunk add monitor /var/log
    ./splunk add monitor /etc/crontab
    ./splunk add monitor /etc/passwd
    ./splunk add monitor /etc/systemd/system
    ./splunk add monitor /usr/lib/systemd/system
    ./splunk enable boot-start
