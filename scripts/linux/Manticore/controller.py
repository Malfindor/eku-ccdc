#!/usr/bin/env python3
import os
import file
import subprocess
import sys

CONF_FILE_LOCATION = "/etc/manticore/hostlist.conf"
HOST_LIST = []
LIVE_HOSTS = []
DEAD_HOSTS = []
def main():
    processConfFile()
    checkHeartbeat()
    liveHostList = LIVE_HOSTS.join(", ")
    deadHostList = DEAD_HOSTS.join(", ")
    while true:
        os.system("clear")
        print(f"""Manticore Automation System
Successfully connected to: {liveHostList}
The following hosts failed the heartbeat check: {deadHostList}""")
        
def checkHeartbeat:
    for host in HOST_LIST:
        try:
            heartbeat = subprocess.run(["nc", "-zv", host, "18965"], stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            if heartbeat.returncode == 0:
                LIVE_HOSTS.append(host)
            else:
                DEAD_HOSTS.append(host)
        except Exception as e:
            print(f"An error occurred: {e}")
def processConfFile:
    confFile = open("/etc/manticore/hostlist.conf", "r")
    confFileContents = confFile.read()
    confContentsSplit = confFileContents.splitlines()
    for line in confContentsSplit:
        if (line[0] != "#"):
            lineSplit = line.split("=")
            if (lineSplit[0] == "HOST_LIST"):
                HOST_LIST.append(lineSplit[1])
main()