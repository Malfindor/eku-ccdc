#!/bin/bash
repo_root=$(git rev-parse --show-toplevel)
mkdir /etc/Arbiter
mv $repo_root/scripts/linux/Arbiter/arbiter.serivce /etc/systemd/system/arbiter.service
systemctl daemon-reload
mv $repo_root/scripts/linux/Arbiter/listener /etc/Arbiter/listener
chmod +x /etc/Arbiter/listener
systemctl enable arbiter
systemctl start arbiter