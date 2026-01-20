import os
import threading
import signal
from systemd.daemon import notify
from time import sleep
import subprocess

wd_usec = os.getenv("WATCHDOG_USEC")
interval = max(int(int(wd_usec)/2000000), 1) if wd_usec else None
stop = False

def handle_sigterm(signum, frame):
    global stop; stop = True

signal.signal(signal.SIGTERM, handle_sigterm)
signal.signal(signal.SIGINT, handle_sigterm)

notify("STATUS=Starting Vigil Server Manager…")

def pump():
    while not stop and interval:
        notify("WATCHDOG=1")
        sleep(interval)

threading.Thread(target=pump, daemon=True).start()

notify("STATUS=Starting event listener...")
p = subprocess.Popen(["python3", "/usr/local/vigil/listener.py"])
sleep(2)
notify("STATUS=Event listener started with PID: {}".format(p.pid))

notify("STATUS=Starting agent handler...")
q = subprocess.Popen(["python3", "/usr/local/vigil/agentHandler.py"])
sleep(2)
notify("STATUS=Agent handler started with PID: {}".format(q.pid))

notify("STATUS=Starting local agent...")
r = subprocess.Popen(["python3", "/usr/local/vigil/core.py"])
sleep(2)
notify("STATUS=Local agent started with PID: {}".format(r.pid))

notify("STATUS=Vigil Server Manager is running.")
notify("READY=1")

while not stop:
    sleep(1)