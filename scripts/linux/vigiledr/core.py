import subprocess
from time import sleep
import os
import threading
import signal
from typing import Union, Sequence
from systemd.daemon import notify
from datetime import datetime

wd_usec = os.getenv("WATCHDOG_USEC")
interval = max(int(int(wd_usec)/2/1_000_000), 1) if wd_usec else None
stop = False
allowedUsers = []
blacklistedUsers = []
allowedIPs = []
blacklistedServices = []
reverseShellFlags = ["python -c", "python3 -c", "/bin/sh -i", "/bin/bash -i", "nc * -e", "ncat * -e", "socat * EXEC"]

def handle_sigterm(signum, frame):
    global stop; stop = True

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

notify("READY=1")
notify("STATUS=Initializing…")

def pump():
    while not stop and interval:
        notify("WATCHDOG=1")
        sleep(interval)

threading.Thread(target=pump, daemon=True).start()

def run():
    processConfigFile()
    while not stop:
        checkUsers()
        checkProcesses()
        checkIPs()
        checkCrontab()
        checkServices()
        sleep(10)
    notify("STOPPING=1")

def checkUsers():
    f = open("/etc/passwd", "r")
    users = f.readlines()
    f.close()
    for user in users:
        userSplit = user.split(":")
        if (not userSplit[0] in allowedUsers):
            if (userSplit[0] in blacklistedUsers) or ((userSplit[2] == '0') or (userSplit[3] == '0')):
                os.system("userdel " + userSplit[0])
                triggerAlert("Blacklisted user was found and removed: '" + userSplit[0] + "'")
            elif (int(userSplit[2]) >= 1000):
                os.system("userdel " + userSplit[0])
                triggerAlert("Unrecognized user was found and removed: '" + userSplit[0] + "'")

def checkProcesses():
    processes = getOutputOf("ps aux")
    processesSplit = processes.split("\n")
    for process in processesSplit:
        for flag in reverseShellFlags:
            if flag in process:
                processConts = process.split(" ")
                pid = int(processConts[1])
                os.kill(pid, signal.SIGTERM)
                triggerAlert("Potential reverse shell detected and killed: " + process)

def checkIPs():
    connections = getOutputOf("who")
    connectionsSplit = connections.split("\n")
    for connection in connectionsSplit:
        if len(connection) >= 5:
            ipSplit = connection[4].split('.')
            if (len(ipSplit) == 4) and (connection[4] not in allowedIPs):
                user = connection[0]
                seat = connection[1]
                os.system('echo "These are not the machines you are looking for." | write ' + user + " " + seat)
                os.system("pkill -KILL -t " + seat)
                date = connection[2]
                time = connection[3]
                remoteIP = connection[4]
                triggerAlert("Unrecognized IP address '" + remoteIP + "' connected to the system as user '" + user + "' on " + date + " at " + time)

def checkCrontab():
    f = open("/etc/crontab", "r")
    contents = f.read()
    f.close()
    if len(contents) > 0:
        if (contents != "\n"):
            triggerAlert("Contents found in /etc/crontab:" + contents)
            f = open("/etc/crontab", "w")
            f.write("\n")
            f.close()

def checkServices():
    services = getOutputOf("systemctl list-units --type=service --state=running")
    servicesSplit = services.split("\n")
    for service in servicesSplit:
        for blacklistedService in blacklistedServices:
            if blacklistedService in service:
                triggerAlert("Blacklisted service found and stopped: " + service)
                serviceName = service.split(" ")[0]
                os.system("systemctl stop " + serviceName)
                os.system("systemctl disable " + serviceName)
                os.system("mv /etc/systemd/system/" + serviceName + " /root/quarantined_services/")
                os.system("systemctl daemon-reload")

def triggerAlert(alert):
    f = open("/var/log/vigil.log", "a")
    f.write('[' + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + '] - ' + alert + "\n")
    f.close()

def getOutputOf(command: Union[str, Sequence[str]]) -> str:
    """
    Run a command and return stdout (or stderr if the command fails).
    Accepts either a shell string or a list argv.
    """
    try:
        if isinstance(command, str):
            result = subprocess.run(
                command,
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                check=True,
            )
        else:
            result = subprocess.run(
                command,
                shell=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                universal_newlines=True,
                check=True,
            )
        return result.stdout.strip()
    except subprocess.CalledProcessError as e:
        return (e.stdout or e.stderr or "").strip()

def processConfigFile():
    f = open("/etc/vigil.conf", "r")
    lines = f.readlines()
    f.close()
    for line in lines:
        if not line.startswith("#") or line.strip() == "":
            lineSplit = line.split("=")
            if lineSplit[0] == "allowed_users":
                usersSplit = lineSplit[1].split(",")
                for user in usersSplit:
                    allowedUsers.append(user.strip()) 
            elif lineSplit[0] == "blacklisted_users":
                usersSplit = lineSplit[1].split(",")
                for user in usersSplit:
                    blacklistedUsers.append(user.strip())
            elif lineSplit[0] == "allowed_ips":
                ipsSplit = lineSplit[1].split(",")
                for ip in ipsSplit:
                    allowedIPs.append(ip.strip())
            elif lineSplit[0] == "blacklisted_services":
                servicesSplit = lineSplit[1].split(",")
                for service in servicesSplit:
                    blacklistedServices.append(service.strip())

if __name__ == "__main__":
    run()