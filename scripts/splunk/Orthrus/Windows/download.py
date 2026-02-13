import requests
import subprocess
import os

forwarder = "splunkforwarder-10.0.1-c486717c322b-windows-x64.msi"
url = "https://download.splunk.com/products/universalforwarder/releases/10.0.1/windows/" + forwarder

try:
    with requests.get(url, stream=True) as response:
        response.raise_for_status()
        with open(forwarder, "wb") as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
    print("Download Complete")
except requests.exceptions.RequestException as e:
    print(f"Download failed: {e}")
    exit()

try:
    subprocess.run(["msiexec", "/i", forwarder], check=True)
    print("Installer launched successfully")
except subprocess.CalledProcessError as e:
    print(f"Failed to launch installer: {e}")