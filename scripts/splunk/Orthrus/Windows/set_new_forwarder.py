import subprocess
import getpass
import time
import os

path = r"C:\Program Files\SplunkUniversalForwarder\bin\splunk.exe"
server = input("What is the Server IP?: ")
port = input("What is the Server Receiving Port?: ")
indexer = f"{server}:{port}"
username = input("Splunk Username: ")
password = getpass.getpass("Enter Splunk Password: ")
login = f"{username}:{password}"
hostname = input("Enter a hostname for this client: ")

def run(cmd):
    subprocess.run(cmd, check=True)

def set_hostname():

    inputs_path = r"C:\Program Files\SplunkUniversalForwarder\etc\system\local\server.conf"

    os.makedirs(os.path.dirname(inputs_path), exist_ok=True)

    config = f"""[general]
    severName = {hostname}
    """

    with open(inputs_path, "w") as f:
        f.write(config)

    print(f"Hostname set to '{hostname}' in inputs.conf")

def add_forward_server():
    print("Removing Any Existing Forward-Server...")
    run([path, "remove", "forward-server", indexer])
    print("Adding New Forward-Server...")
    run([path, "add", "forward-server", indexer, "-auth", login])

def add_monitors():
    red = '\033[91m'
    print("Adding IIS logs monitor...")
    iis_path = r"C:\inetpub\logs\LogFiles\W3SVC1"
    if os.path.isdir(iis_path):
        run([
            path, "add", "monitor",
            iis_path,
            "-index", "main",
            "-sourcetype", "iis"
        ])
    else:
        print(red + "Error: IIS logs path does not exist")
        time.sleep(3)

    # Windows Event Logs
    event_path = r"C:\Windows\System32\winevt\Logs"
    if os.path.isdir(event_path):
        print("Adding Windows Event Logs...")
        run([
            path, "add", "monitor",
            r"C:\Windows\System32\winevt\Logs\*.evtx",
            "-index", "main",
            "-sourcetype", "WinEventLog"
        ])
    else:
        print(red + "Error: Windows Event Logs directory does not exist")
        time.sleep(3)

def restart_splunk():
    print("Restarting Splunk Universal Forwarder...")
    run([path, "restart"])

def show_status():
    print("Waiting 15 seconds for Splunk UF to reconnect...")
    time.sleep(15)
    run([path, "list", "forward-server"])
    run([path, "list", "monitor"])

if __name__ == "__main__":
    add_forward_server()
    set_hostname()
    restart_splunk()
    add_monitors()
    restart_splunk()
    show_status()
