import os
import sys
import argparse
from git import Repo, InvalidGitRepositoryError
from pathlib import Path

def printHelp():
    print("""
Vigil Installer
----------------
Usage: install.py [option]
          
Options:
    -h, --help      Show this help message and exit
    -c, --client    Install only Vigil agent to the system
    -s, --server    Install Vigil manager and agent to the system
""")

def beginClientInstall():
    print("Beginning Vigil agent installation", flush=True)
    if os.path.exists('/usr/local/vigil'):
        print("Vigil appears to already be installed. If this is an error, remove /usr/local/vigil, then try again.", flush=True)
        exit(1)
    print("Installing dependences", flush=True)
    if os.path.exists('/usr/bin/apt'):
        os.system('apt install -y python3 python3-pip')
    elif os.path.exists('/usr/bin/yum'):
        os.system('yum install -y python3 python3-pip')
    os.system('mkdir -p /usr/local/vigil')
    os.system('mkdir -p /root/quarantined_services')
    os.system("touch /var/log/vigil.log")
    os.system("mkdir /etc/vigil")
    os.rename(f'{repo_root}/agent/agent.conf', '/etc/vigil/agent.conf')
    os.rename(f'{repo_root}/agent/core.py', '/usr/local/vigil/core.py')
    os.rename(f'{repo_root}/agent/manager.py', '/usr/local/vigil/manager.py')
    os.rename(f'{repo_root}/agent/agent-listener.py', '/usr/local/vigil/listener.py')
    os.rename(f'{repo_root}/agent/configCheck.py', '/usr/local/vigil/configCheck.py')
    os.rename(f'{repo_root}/agent/vigil-agent.service', '/etc/systemd/system/vigil.service')
    os.system('systemctl daemon-reload')
    #os.system('systemctl enable vigil.service')
    #os.system('systemctl start vigil.service')

def beginServerInstall():
    print("Beginning Vigil manager installation", flush=True)
    print("Installing dependences", flush=True)
    if os.path.exists('/usr/bin/apt'):
        os.system('apt install -y mariadb-server')
    elif os.path.exists('/usr/bin/yum'):
        os.system('yum install -y mariadb-server')
    os.system('systemctl enable mariadb')
    os.system('systemctl start mariadb')
    print("Please enter the MariaDB root password when prompted to set up the Vigil database.", flush=True)
    os.system('mysql -u root < ./server/db_setup.sql')
    print("Installing local client", flush=True)
    if os.path.exists('/usr/local/vigil'):
        print("Vigil appears to already be installed. If this is an error, remove /usr/local/vigil, then try again.", flush=True)
        exit(1)
    print("Installing dependences", flush=True)
    if os.path.exists('/usr/bin/apt'):
        os.system('apt install -y python3 python3-pip')
    elif os.path.exists('/usr/bin/yum'):
        os.system('yum install -y python3 python3-pip')
    os.system('pip3 install mysql-connector-python')
    print("Setting up Vigil files", flush=True)
    os.system('mkdir -p /usr/local/vigil')
    os.system('mkdir -p /root/quarantined_services')
    os.system("touch /var/log/vigil.log")
    os.system("touch /var/log/vigil_server.log")
    os.system("mkdir /etc/vigil")
    os.rename(f'{repo_root}/agent/agent.conf', '/etc/vigil/agent.conf')
    os.rename(f'{repo_root}/server/server.conf', '/etc/vigil/server.conf')
    os.rename(f'{repo_root}/agent/core.py', '/usr/local/vigil/core.py')
    os.rename(f'{repo_root}/server/server-config-check.py', '/usr/local/vigil/configCheck.py')
    os.rename(f'{repo_root}/server/agent-handler.py', '/usr/local/vigil/agentHandler.py')
    os.rename(f'{repo_root}/server/manager.py', '/usr/local/vigil/manager.py')
    os.rename(f'{repo_root}/server/listener.py', '/usr/local/vigil/listener.py')
    os.rename(f'{repo_root}/server/event-viewer.py', '/bin/vigil')
    os.system('chmod +x /bin/vigil')
    os.rename(f'{repo_root}/server/control-panel.py', '/bin/vigilAdmin')
    os.system('chmod +x /bin/vigilAdmin')
    os.rename(f'{repo_root}/server/vigil-manager.service', '/etc/systemd/system/vigil.service')
    os.system('restorecon -v /etc/systemd/system/vigil.service') # SELinux support
    os.system('systemctl daemon-reload')

if not os.geteuid() == 0:
    print("This script must be run as root.", flush=True)
    exit(1)

if (len(sys.argv) == 1):
    printHelp()
    exit(0)

global repo_root
try:
    repo_root = Path(
        Repo(search_parent_directories=True).working_tree_dir
    )
except InvalidGitRepositoryError:
    repo_root = None

parser = argparse.ArgumentParser(add_help=False)
parser.add_argument('-h', '--help', action='store_true')
parser.add_argument('-c', '--client', action='store_true')
parser.add_argument('-s', '--server', action='store_true')
parser.add_argument('--repo-root', type=str, default=repo_root)
args = parser.parse_args()
repo_root = args.repo_root
if args.help:
    printHelp()
    exit(0)
if args.client and args.server:
    print("Please specify only one of --client or --server.", flush=True)
    exit(1)
if not args.client and not args.server:
    print("Please specify one of --client or --server.", flush=True)
    exit(1)
if args.client:
    beginClientInstall()
elif args.server:
    beginServerInstall()