#!/usr/env/python3
import sys
import os

bindIpPres = False
bindPortPres = False
allowedUsersPres = False
blacklistedUsersPres = False
allowedIpsPres = False
blacklistedServicesPres = False
if not os.path.exists('/etc/vigil.conf'):
    print("Config file not found. Replace or ensure that the config file is located at /etc/vigil.conf", file=sys.stderr, flush=True)
    sys.exit(2)
errors = []
f = open('/etc/vigil.conf', 'r')
contents = f.read()
if len(contents) == 0:
    print("Config file appears to be empty.", file=sys.stderr, flush=True)
    sys.exit(3)
contents = contents.split('\n')
lineNum = 0
for line in contents:
    lineNum = lineNum + 1
    if not len(line) == 0:
        if not line[0] == '#':
            line = line.split('=')
            if line[0] == 'bind_ip':
                bindIpPres = True
                if len(line[1]) == 0:
                    errors.append("Missing value for variable 'bind_ip' on line " + str(lineNum))
                valuesSplit = line[1].split(',')
                if len(valuesSplit) > 1:
                    errors.append("Multiple values for variable 'bind_ip' on line " + str(lineNum))
            if line[0] == 'bind_port':
                bindPortPres = True
                if len(line[1]) == 0:
                    errors.append("Missing value for variable 'bind_port' on line " + str(lineNum))
                elif (int(line[1]) < 1) or (int(line[1]) > 65535):
                    errors.append("value out of range for variable 'bind_port' on line " + str(lineNum))
            if line[0] == 'allowed_users':
                allowedUsersPres = True
                if len(line[1]) == 0:
                    errors.append("Missing value for variable 'allowed_users' on line " + str(lineNum))
                valuesSplit = line[1].split(',')
                for value in valuesSplit:
                    if ' ' in value.split():
                        errors.append("Invalid value '" + value + "' for variable 'allowed_users' on line " + str(lineNum))
            if line[0] == 'blacklisted_users':
                blacklistedUsersPres = True
                if len(line[1]) == 0:
                    errors.append("Missing value for variable 'blacklisted_users' on line " + str(lineNum))
                valuesSplit = line[1].split(',')
                for value in valuesSplit:
                    if ' ' in value.strip():
                        errors.append("Invalid value '" + value + "' for variable 'blacklisted_users' on line " + str(lineNum))
            if line[0] == 'allowed_ips':
                allowedIpsPres = True
                if len(line[1]) == 0:
                    errors.append("Missing value for variable 'allowed_ips' on line " + str(lineNum))
                valuesSplit = line[1].split(',')
                for value in valuesSplit:
                    if len(value.split('.')) != 4:
                        errors.append("Invalid value '" + value + "' for variable 'allowed_ips' on line " + str(lineNum))
                    elif not all(part.isdigit() and 0 <= int(part) <= 255 for part in value.split('.')):
                        errors.append("Invalid value '" + value + "' for variable 'allowed_ips' on line " + str(lineNum))
                    elif ' ' in value.strip():
                        errors.append("Invalid value '" + value + "' for variable 'allowed_ips' on line " + str(lineNum))
            if line[0] == 'blacklisted_services':
                blacklistedServicesPres = True
                if len(line[1]) == 0:
                    errors.append("Missing value for variable 'blacklisted_services' on line " + str(lineNum))
                valuesSplit = line[1].split(',')
                for value in valuesSplit:
                    if ' ' in value.strip():
                        errors.append("Invalid value '" + value + "' for variable 'blacklisted_services' on line " + str(lineNum))

if not bindIpPres:
    errors.append("Missing variable 'bind_ip'")
if not bindPortPres:
    errors.append("Missing variable 'bind_port'")
if not allowedUsersPres:
    errors.append("Missing variable 'allowed_users'")
if not blacklistedUsersPres:
    errors.append("Missing variable 'blacklisted_users'")
if not allowedIpsPres:
    errors.append("Missing variable 'allowed_ips'")
if not blacklistedServicesPres:
    errors.append("Missing variable 'blacklisted_services'")

if not len(errors) == 0:
    for error in errors:
        print(error, file=sys.stderr, flush=True)
    sys.exit(1)