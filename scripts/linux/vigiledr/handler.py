#!/usr/env/python3
import subprocess
import sys
import os

if not len(sys.argv) == 3:
    print("Invalid usage. Usage: handler.py {ip of agent} {message}")
    exit()
if not len(sys.argv[1].split('.')) == 4:
    print("Invalid IP address. Use a valid ipv4 address for agents.")
    exit()
