import subprocess
from time import sleep
import os
import threading
import signal
from datetime import datetime
import socket
import re
from xml.dom.minicompat import StringTypes

allowedUsers = []
blacklistedUsers = []
allowedIPs = []
blacklistedServices = []
reverseShellFlags = [r"python3?\s+-c\b", r"/bin/(ba)?sh\s+-i\b", r"nc\s+.*-e\b", r"ncat\s+.*-e\b", r"socat\s+.*EXEC\b"]

stop = False

def handle_sigterm(signum, frame):
    global stop; stop = True

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

def sendAlert(alert, managerIP, eventPort):
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((managerIP, int(eventPort)))
        sock.sendall(alert.encode())
        sock.close()
    except:
        f = open("/var/log/vigil.log", "a")
        f.write('[' + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + '] - ' + "Failed to send alert to manager\n")
        f.close()

def run():
    processConfigFile()
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.connect((managerIP, int(eventPort)))
        sock.sendall("checkin".encode())
        sock.close()
    except:
        f = open("/var/log/vigil.log", "a")
        f.write('[' + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + '] - ' + "Failed to check in with manager\n")
        f.close()
    while not stop:
        checkUsers()
        checkProcesses()
        checkIPs()
        checkCrontab()
        checkServices()
        sleep(10)

def checkUsers():
    f = open("/etc/passwd", "r")
    users = f.readlines()
    f.close()
    for user in users:
        userSplit = user.split(":")
        if (not userSplit[0] in allowedUsers):
            if (userSplit[0] in blacklistedUsers) or ((userSplit[2] == '0') or (userSplit[3] == '0')):
                os.system("userdel " + userSplit[0])
                triggerAlert(datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S') + " - Blacklisted user was found and removed: '" + userSplit[0] + "'")
            elif (int(userSplit[2]) >= 1000):
                os.system("userdel " + userSplit[0])
                triggerAlert(datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S') + " - Unrecognized user was found and removed: '" + userSplit[0] + "'")

def checkProcesses():
    processes = getOutputOf("ps aux")
    processesSplit = processes.split("\n")
    for process in processesSplit:
        for flag in reverseShellFlags:
            if re.search(flag, process):
                processConts = process.split()
                pid = processConts[1]
                os.kill(int(pid), signal.SIGKILL)
                triggerAlert(datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S') + " - Potential reverse shell detected and killed: " + process)

def checkIPs():
    connections = getOutputOf("who")
    connectionsSplit = connections.split("\n")
    for connection in connectionsSplit:
        connection = connection.split()
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
                triggerAlert(datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S') + " - Unrecognized IP address '" + remoteIP + "' connected to the system as user '" + user + "' on " + date + " at " + time)

def checkCrontab():
    f = open("/etc/crontab", "r")
    contents = f.read()
    f.close()
    if len(contents) > 0:
        if (contents != "\n"):
            triggerAlert(datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S') + " - Contents found in /etc/crontab:" + contents)
            f = open("/etc/crontab", "w")
            f.write("\n")
            f.close()

def checkServices():
    services = getOutputOf("systemctl list-units --type=service --state=running")
    servicesSplit = services.split("\n")
    for service in servicesSplit:
        for blacklistedService in blacklistedServices:
            if blacklistedService in service:
                triggerAlert(datetime.strftime(datetime.now(), '%Y-%m-%d %H:%M:%S') + " - Blacklisted service found and stopped: " + service)
                serviceName = service.split()[0]
                os.system("systemctl stop " + serviceName)
                os.system("systemctl disable " + serviceName)
                os.system("mv /etc/systemd/system/" + serviceName + " /root/quarantined_services/")
                os.system("systemctl daemon-reload")

def triggerAlert(alert):
    f = open("/var/log/vigil.log", "a")
    f.write('[' + datetime.now().strftime("%Y-%m-%d %H:%M:%S") + '] - ' + alert + "\n")
    f.close()
    threading.Thread(target=sendAlert, args=(alert, managerIP, eventPort), daemon=True).start()

def getOutputOf(command):
    """
    Run a command and return stdout (or stderr if the command fails).
    Accepts either a shell string or a list argv.
    """
    # shell=True if a single shell string; False if a list/tuple argv
    shell = isinstance(command, StringTypes)

    try:
        proc = subprocess.Popen(
            command,
            shell=shell,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            universal_newlines=True  # text mode; works on Py2/3
        )
        out, err = proc.communicate()

        if proc.returncode != 0:
            return (err or "").strip()
        return (out or "").strip()

    except OSError as e:
        # e.g., command not found
        return str(e).strip()

def processConfigFile():
    f = open("/etc/vigil/agent.conf", "r")
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
            elif lineSplit[0] == "manager_ip":
                global managerIP; managerIP = lineSplit[1].strip()
            elif lineSplit[0] == "event_port":
                global eventPort; eventPort = int(lineSplit[1].strip())
run()