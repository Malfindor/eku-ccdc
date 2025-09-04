#!/bin/bash
repo_root=$(git rev-parse --show-toplevel)
mkdir /etc/Arbiter
mkdir /var/Arbiter
touch /var/Arbiter/buffer.log
touch /var/Arbiter/read.log
touch /var/Arbiter/active.log
touch /var/log/masterArbiter.log
mv $repo_root/scripts/linux/Arbiter/Server_Files/listener.conf /etc/Arbiter/listener.conf
mv $repo_root/scripts/linux/Arbiter/Server_Files/terminal.py /bin/arbiter
chmod +x /bin/arbiter