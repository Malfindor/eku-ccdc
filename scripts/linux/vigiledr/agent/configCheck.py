#!/usr/env/python3
import sys
import os

def checkAgentConfig():
    managerIpPres = False
    managementPortPres = False
    eventPortPres = False
    allowedUsersPres = False
    blacklistedUsersPres = False
    allowedIpsPres = False
    blacklistedServicesPres = False
    if not os.path.exists('/etc/vigil/agent.conf'):
        print("Config file not found. Replace or ensure that the config file is located at /etc/vigil.conf", file=sys.stderr, flush=True)
        sys.exit(2)
    errors = []
    f = open('/etc/vigil/agent.conf', 'r')
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
                if line[0] == 'manager_ip':
                    managerIpPres = True
                    if len(line[1]) == 0:
                        errors.append("Missing value for variable 'manager_ip' on line " + str(lineNum))
                    valuesSplit = line[1].split(',')
                    if len(valuesSplit) > 1:
                        errors.append("Multiple values for variable 'manager_ip' on line " + str(lineNum))
                if line[0] == 'management_port':
                    managementPortPres = True
                    if len(line[1]) == 0:
                        errors.append("Missing value for variable 'management_port' on line " + str(lineNum))
                    elif (int(line[1]) < 1) or (int(line[1]) > 65535):
                        errors.append("value out of range for variable 'management_port' on line " + str(lineNum))
                if line[0] == 'event_port':
                    eventPortPres = True
                    if len(line[1]) == 0:
                        errors.append("Missing value for variable 'event_port' on line " + str(lineNum))
                    elif (int(line[1]) < 1) or (int(line[1]) > 65535):
                        errors.append("value out of range for variable 'event_port' on line " + str(lineNum))
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

    if not managerIpPres:
        errors.append("Missing variable 'manager_ip'")
    if not managementPortPres:
        errors.append("Missing variable 'manager_port'")
    if not eventPortPres:
        errors.append("Missing variable 'event_port'")
    if not allowedUsersPres:
        errors.append("Missing variable 'allowed_users'")
    if not blacklistedUsersPres:
        errors.append("Missing variable 'blacklisted_users'")
    if not allowedIpsPres:
        errors.append("Missing variable 'allowed_ips'")
    if not blacklistedServicesPres:
        errors.append("Missing variable 'blacklisted_services'")
    return errors

errors = checkAgentConfig()

if not len(errors) == 0:
    for error in errors:
        print(error, file=sys.stderr, flush=True)
    sys.exit(1)