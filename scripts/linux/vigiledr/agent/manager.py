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

notify("STATUS=Starting Vigil Client Manager…")

def pump():
    while not stop and interval:
        notify("WATCHDOG=1")
        sleep(interval)

threading.Thread(target=pump, daemon=True).start()

notify("STATUS=Starting local agent...")
r = subprocess.Popen(["python3", "/usr/local/vigil/core.py"])
sleep(2)
notify("STATUS=Local agent started with PID: {}".format(r.pid))

notify("STATUS=Starting agent listener...")
r2 = subprocess.Popen(["python3", "/usr/local/vigil/listener.py"])
sleep(2)
notify("STATUS=Agent listener started with PID: {}".format(r2.pid))

notify("STATUS=Vigil Client Manager is running.")
notify("READY=1")

while not stop:
    sleep(1)