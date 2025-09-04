#!/usr/bin/env python3
import os
import subprocess
import sys
import argparse
from datetime import datetime

def main():
    if(len(sys.argv) == 3 and (sys.argv[1] == '-ba' or sys.argv[1] == 'br')):
        if(sys.argv[1] == '-ba'):
            print(addToBlackList(sys.argv[2]))
        elif(sys.argv[1] == '-br'):
            print(removeFromBlackList(sys.argv[2]))
    elif ("SSH_CONNECTION" in os.environ) or ("SSH_CLIENT" in os.environ) or ("SSH_TTY" in os.environ):
        print("\033[32;1m[RED]\033[0m")
        print("Unable to be run remotely.")
        print("Cheers RedTeam")
        print("- Malfindor")
        return
    elif(os.getuid() != 0):
        print("Access Denied. Must be run as root.")
    else:
        if(len(sys.argv) == 2):
            if(sys.argv[1].lower() in ('-h', '--help', 'help')):
                printHelp()
            elif(sys.argv[1].lower() == "-e"):
                x = True
                while(x):
                    option = input("[Command@Core]# ")
                    if(option.lower() == ''):
                        pass
                    elif(option.lower() == 'table'):
                        tableList = getTableList()
                        print("List of tables: ")
                        for table in tableList:
                            print(table)
                        y = True
                        while(y):
                            option = input("Which table would you like to move to? ")
                            for table in tableList:
                                if(table == option):
                                    y = False
                            if(y):
                                print("Invalid selection.")
                        if(tableCommand(option) == "quit"):
                            return
                    elif(option.lower() == 'add'):
                        print("Adding a table...")
                        y = True
                        while(y):
                            name = input("Enter table name: ")
                            if spacePresent(name):
                                print("Invalid name, spaces not permitted.")
                            else:
                                y = False
                        os.system("nft add table "+name)
                    elif(option.lower() == 'delete'):
                        tableList = getTableList()
                        for table in tableList:
                            print(table)
                        y = True
                        while(y):
                            option = input("Enter table to remove: ")
                            if(isInList(option, tableList)):
                                y = False
                            else:
                                print("Invalid selection")
                        os.system("nft delete table "+option)
                        if(isInList(option, tableList)):
                            print(f"Error removing {option}")
                        else:
                            print(f"Successfully removed {option}")
                    elif(option.lower() == 'panic'):
                        dam()
                    elif(option.lower() == 'blacklist'):
                        if(blackList() == "quit"):
                            return
                    elif(option.lower() == 'exit' or option.lower() == 'quit'):
                        return
                    else:
                        printHelp()
            elif(sys.argv[1].lower() == "-k"):
                otherTablePres = False
                tableList = getAdvTableList()
                for table in tableList:
                    if(table[0] == "firewall"):
                        firewallPres = True
                    elif(table[0] == "blacklist"):
                        blacklistPres = True
                    else:
                        if(len(table[0]) == 0 or table[0] == "PANIC"):
                            pass
                        else:
                            otherTablePres = True
                if(otherTablePres):
                    print("Other tables detected. Beginning kill process.")
                    for table in tableList:
                        if(table[0] == "firewall" or table[0] == "blacklist" or table[0] == "PANIC"):
                            pass
                        elif(len(table[0]) != 0):
                            option = input("Table " + table[0] + " found. Would you like to delete this table? ").lower()
                            if(option == "y" or option == "yes"):
                                os.system("nft delete table " + table[1] + " " + table[0])
                else:
                    print("No other tables detected. Exiting.")
                    return
            elif(sys.argv[1].lower() == "-kf"):
                tableList = getAdvTableList()
                for table in tableList:
                    if(table[0] == "firewall"):
                        firewallPres = True
                    elif(table[0] == "blacklist"):
                        blacklistPres = True
                    else:
                        if(len(table[0]) == 0 or table[0] == "PANIC"):
                            pass
                        else:
                            otherTablePres = True
                if(otherTablePres):
                    print("Other tables detected. Beginning kill process.")
                    for table in tableList:
                        if(table[0] == "firewall" or table[0] == "blacklist" or table[0] == "PANIC"):
                            pass
                        elif(len(table[0]) != 0):
                            os.system("nft delete table " + table[1] + " " + table[0])
                else:
                    print("No other tables detected. Exiting.")
                    return
            elif(sys.argv[1].lower() == "-i"):
                print("Checking integrity of firewall tables.")
                firewallPres = False
                firewallInteg = False
                blacklistPres = False
                blacklistInteg = False
                tableList = getTableList()
                for table in tableList:
                    if(table == "firewall"):
                        inPres = False
                        outPres = False
                        firewallPres = True
                        chainList = getChainList("firewall")
                        for chain in chainList:
                            if(chain == "input"):
                                inPres = True
                            if(chain == "output"):
                                outPres = True
                        if(inPres and outPres):
                            firewallInteg = True
                            print("Firewall tables verified.")
                    elif(table == "blacklist"):
                        inPres = False
                        outPres = False
                        blacklistPres = True
                        chainList = getChainList("blacklist")
                        for chain in chainList:
                            if(chain == "blockIn"):
                                inPres = True
                            if(chain == "blockOut"):
                                outPres = True
                        if(inPres and outPres):
                            blacklistInteg = True
                            print("Blacklist tables verified.")
                if(firewallPres and firewallInteg and blacklistPres and blacklistInteg):
                    print("Firewall integrity verified. Exiting.")
                else:
                    flagRaw = getFileCont("/etc/firewall/machinePreset.flag")
                    flag = flagRaw[:len(flagRaw)-2]
                    if(not firewallInteg):
                        print("Core firewall tables failed verification. Repairing.")
                        inPres = False
                        outPres = False
                        if(not firewallPres):
                            os.system("nft add table firewall")
                        chainList = getChainList("firewall")
                        for chain in chainList:
                            if(chain == "input"):
                                inPres = True
                            if(chain == "output"):
                                outPres = True
                        if(not inPres):
                            os.system("nft add chain firewall input \{ type filter hook input priority 0 \; policy drop\; \}")
                        if(not outPres):
                            os.system("nft add chain firewall output \{ type filter hook output priority 0 \; policy drop\; \}")
                        restoreRuleInteg(flag)
                        print("Firewall tables repaired using preset: " + flag)
                    if(not blacklistInteg):
                        print("Blacklist tables failed verification. Repairing.")
                        inPres = False
                        outPres = False
                        if(not blacklistPres):
                            os.system("nft add table blacklist")
                        chainList = getChainList("blacklist")
                        for chain in chainList:
                            if(chain == "blockIn"):
                                inPres = True
                            if(chain == "blockOut"):
                                outPres = True
                        if(not inPres):
                            os.system("nft add chain blacklist blockIn \{ type filter hook input priority -99 \; policy accept\; \}")
                        if(not outPres):
                            os.system("nft add chain blacklist blockOut \{ type filter hook output priority -99 \; policy accept\; \}")
                        print("Blacklist tables repaired.")
        elif(len(sys.argv) == 3 and sys.argv[1] == '-s'):
            if(os.path.exists('/etc/firewall/configs/' + sys.argv[2] + '.config')):
                print("Config named " + sys.argv[2] + " already exists.")
            else:
                saveConfig(sys.argv[2])
        elif(len(sys.argv) == 3 and sys.argv[1] == '-l'):
            if(os.path.exists('/etc/firewall/configs/' + sys.argv[2] + '.config')):
                loadConfig(sys.argv[2])
            else:
                print("No config named " + sys.argv[2] + " found.")
        else:
            if(standMenu()):
                return
def standMenu():
    x = True
    message = ""
    while(x):
        firewallPres = False
        firewallInteg = False
        blacklistPres = False
        blacklistInteg = False
        otherTablePres = False
        os.system("clear")
        tableList = getTableList()
        for table in tableList:
            if(table == "firewall"):
                inPres = False
                outPres = False
                firewallPres = True
                chainList = getChainList("firewall")
                for chain in chainList:
                    if(chain == "input"):
                        inPres = True
                    if(chain == "output"):
                        outPres = True
                if(inPres and outPres):
                    firewallInteg = True
            elif(table == "blacklist"):
                inPres = False
                outPres = False
                blacklistPres = True
                chainList = getChainList("blacklist")
                for chain in chainList:
                    if(chain == "blockIn"):
                        inPres = True
                    if(chain == "blockOut"):
                        outPres = True
                if(inPres and outPres):
                    blacklistInteg = True
            else:
                if(len(table) == 0 or table == "PANIC"):
                    pass
                else:
                    otherTablePres = True
        print("EKU CCDC System Firewall Manager")
        if(firewallPres):
            print("Firewall Status: \033[32;1m[GREEN]\033[0m")
            if(not firewallInteg):
                print("\033[33;1m[Caution: Firewall is active, however is missing a chain. Address this issue immediately.]\033[0m")
        else:
            print("Firewall Status: \033[31;1m[INACTIVE]\033[0m")
        if(blacklistPres):
            print("Blacklist Status: \033[32;1m[GREEN]\033[0m")
            if(not blacklistInteg):
                print("\033[33;1m[Caution: Blacklist is active, however is missing a chain. Address this issue immediately.]\033[0m")
        else:
            print("Blacklist Status: "+"\033[31;1m[INACTIVE]\033[0m")
        if(otherTablePres):
            print('\033[33;1m[Caution: Other tables detected present in nfTables. Run the firewall with the "-k" flag to remove all excess tables.]\033[0m')
        if(firewallPres and firewallInteg and blacklistPres and blacklistInteg):
            if(panicOn()):
                print("\n")
                print("\033[31;1m[Panic mode currently activated. All traffic is being blocked.]\033[0m")
            else:
                print("\n")
                ports = []
                ipList = []
                bIpList = []
                blackListArray = getBlackList()
                inputPorts = []
                outputPorts = []
                inputChain = getRuleList("firewall", "input")
                outputChain = getRuleList("firewall", "output")
                for array in inputChain:
                    item = array[0]
                    itemArray = item.split(" ")
                    protocol = itemArray[0]
                    if(itemArray[1] == "sport" or itemArray[1] == "dport"):
                        portNum = itemArray[2]
                        if(portNum in inputPorts):
                            pass
                        else:
                            port = protocol + " " + portNum + " " + portDefault(protocol, portNum)
                            inputPorts.append(port)
                    elif(itemArray[1] == "saddr" or itemArray[1] == "daddr"):
                        if(not itemArray[2] in ipList):
                            ipList.append(itemArray[2])
                for array in outputChain:
                    item = array[0]
                    itemArray = item.split(" ")
                    protocol = itemArray[0]
                    if(itemArray[1] == "sport" or itemArray[1] == "dport"):
                        portNum = itemArray[2]
                        if(portNum in outputPorts):
                            pass
                        else:
                            port = protocol + " " + portNum + " " + portDefault(protocol, portNum)
                            outputPorts.append(port)
                    elif(itemArray[1] == "saddr" or itemArray[1] == "daddr"):
                        if(not itemArray[2] in ipList):
                            ipList.append(itemArray[2])
                for entry in blackListArray:
                    bIpList.append(entry[0])
                print("Port Rules:")
                print("\n")
                for port in inputPorts:
                    if(not port in ports):
                        ports.append(port)
                for port in outputPorts:
                    if(not port in ports):
                        ports.append(port)
                ports = addOtherPorts(ports)
                for port in ports:
                    if(port in inputPorts and port in outputPorts):
                        state = "both"
                    elif(port in inputPorts):
                        state = "in"
                    elif(port in outputPorts):
                        state = "out"
                    else:
                        state = "closed"
                    if(state == "both"):
                        print(port + ": \033[32;1m[OPEN]\033[0m")
                    if(state == "in"):
                        print(port + ": \033[33;1m[IN ONLY]\033[0m")
                    if(state == "out"):
                        print(port + ": \033[33;1m[OUT ONLY]\033[0m")
                    if(state == "closed"):
                        print(port + ": \033[31;1m[CLOSED]\033[0m")
                print("\n")
                if(len(ipList) == 0):
                    print("No whitelisted IP Addresses.")
                    print("\n")
                else:
                    whiteListIP = "Whitelisted IP Addresses: "
                    for ip in ipList:
                        whiteListIP = whiteListIP + ip + ", "
                    value = len(whiteListIP)-2
                    whiteListIP = whiteListIP[:value]
                    print(whiteListIP)
                if(len(bIpList) == 0):
                    print("No blacklisted IP Addresses.")
                    print("\n")
                else:
                    bIpListIP = "Blacklisted IP Addresses: "
                    for ip in bIpList:
                        bIpListIP = bIpListIP + ip + ", "
                    value = len(bIpListIP)-2
                    bIpListIP = bIpListIP[:value]
                    print(bIpListIP)
            print("\n")
            print(message)
            print("\n")
            option = input("Enter command: ")
            if(option.lower() == "whitelist"):
                y = True
                while(y):
                    address = input("Enter IPv4 address to whitelist: ")
                    length = len(address.split("."))
                    if(address.lower() == "exit" or length == 4):
                        y = False
                    if(not y):
                        print("Invalid address. Please re-enter the address or type 'exit' to exit.")
                if(length == 4):
                    os.system("nft add rule firewall input ip saddr { "+address+" } accept")
                    os.system("nft add rule firewall output ip daddr { "+address+" } accept")
                    saveRules()
                    message = (address + " successfully added to whitelist.")
            elif(option.lower() == "blacklist"):
                y = True
                while(y):
                    address = input("Enter IPv4 address to blacklist: ")
                    length = len(address.split("."))
                    if(address.lower() == "exit" or length == 4):
                        y = False
                    if(not y):
                        print("Invalid address. Please re-enter the address or type 'exit' to exit.")
                if(length == 4):
                    addToBlackList(address)
                    saveRules()
                    message = address + " successfully added to blacklist."
            elif(option.lower() == "open"):
                y = True
                z = False
                while(y):
                    type = input("Open port for input, output, or both?(Type 'exit' to cancel) ").lower()
                    if(not (type == "input" or type == "output" or type == "both")):
                        print("Invalid entry, enter 'input', 'output', or 'both' to determine what openings the port needs.")
                    elif(type == "cancel"):
                        z = True
                    else:
                        y = False
                    if(z):
                        y = False
                    else:
                        protocol = input("Enter port protocol(TCP/UDP): ").lower()
                        service = input("Enter port number to open: ")
                        if(protocol == "tcp"):
                            if(type == "input"):
                                os.system("nft add rule firewall input tcp dport { "+service+" } accept")
                            elif(type == "output"):
                                os.system("nft add rule firewall output tcp dport { "+service+" } accept")
                            elif(type == "both"):
                                os.system("nft add rule firewall input tcp dport { "+service+" } accept")
                                os.system("nft add rule firewall output tcp dport { "+service+" } accept")
                                os.system("nft add rule firewall output tcp sport { "+service+" } accept")
                        elif(protocol == "udp"):
                            if(type == "input"):
                                os.system("nft add rule firewall input udp dport { "+service+" } accept")
                            elif(type == "output"):
                                os.system("nft add rule firewall output udp dport { "+service+" } accept")
                            elif(type == "both"):
                                os.system("nft add rule firewall input udp dport { "+service+" } accept")
                                os.system("nft add rule firewall output udp dport { "+service+" } accept")
                                os.system("nft add rule firewall output udp sport { "+service+" } accept")
                    saveRules()
            elif(option.lower() == "delete"):
                e = True
                p = True
                while(p):
                    newOpt = input("Would you like to delete a rule, a whitelisted IP, or blacklisted IP? (enter rule, whitelist, or blacklist) ").lower()
                    if(newOpt == "rule" or newOpt == "whitelist" or newOpt == "blacklist" or newOpt == "exit"):
                        p = False
                    if(newOpt == "exit"):
                        e = False
                    else:
                        if(p):
                            print("Invalid selection. (enter exit to cancel)")
                if(e):
                    if(newOpt == "rule"):
                        inList = getRuleList("firewall", "input")
                        outList = getRuleList("firewall", "output")
                        if(len(ports) == 0):
                            print("No open ports to close.")
                        else:
                            p = True
                            while(p):
                                z = False
                                c = False
                                m = ""
                                b = 0
                                option = input("Enter port number to close: ").lower()
                                if(option == "exit"):
                                    p = False
                                for port in ports:
                                    portList = port.split(" ")
                                    if(portList[1] == option):
                                        if(port in inputPorts):
                                            b = b + 1
                                            m = "in"
                                        if(port in outputPorts):
                                            b = b + 1
                                            m = "out"
                                if(b == 0):
                                    print("Port " + option + " not open. Enter exit to cancel.")
                                elif(b == 1):
                                    z = True
                                    if(m == "in"):
                                        conf = input("Port " + option + " found open as 'In Only'. Would you like to close it? ").lower()
                                        if(conf == 'y' or conf == 'yes'):
                                            c = True
                                    if(m == "out"):
                                        conf = input("Port " + option + " found open as 'Out Only'. Would you like to close it? ").lower()
                                        if(conf == 'y' or conf == 'yes'):
                                            c = True
                                elif(b == 2):
                                    z = True
                                    conf = input("Port " + option + " found open. Would you like to close it? ").lower()
                                    if(conf == 'y' or conf == 'yes'):
                                        c = True
                                if(z):
                                    p = False
                            if(c):
                                protocol = ""
                                targetPort = option
                                if(b == 1):
                                    if(m == "in"):
                                        rules = getRuleList("firewall", "input")
                                        for port in inputPorts:
                                            portList = port.split(" ")
                                            if(portList[1] == targetPort):
                                                protocol = portList[0]
                                        queryOne = protocol + " sport " + targetPort + " accept"
                                        queryTwo = protocol + " dport " + targetPort + " accept"
                                        for rule in rules:
                                            if(rule[0] == queryOne or rule[0] == queryTwo):
                                                os.system("nft delete rule firewall input handle " + rule[1])
                                                message = "Port " + targetport + " successfully closed."
                                    if(m == "out"):
                                        rules = getRuleList("firewall", "output")
                                        for port in outputPorts:
                                            portList = port.split(" ")
                                            if(portList[1] == targetPort):
                                                protocol = portList[0]
                                        queryOne = protocol + " sport " + targetPort + " accept"
                                        queryTwo = protocol + " dport " + targetPort + " accept"
                                        for rule in rules:
                                            if(rule[0] == queryOne or rule[0] == queryTwo):
                                                os.system("nft delete rule firewall output handle " + rule[1])
                                                message = "Port " + targetport + " successfully closed."
                                elif(b == 2):
                                    rules = getRuleList("firewall", "input")
                                    for port in inputPorts:
                                        portList = port.split(" ")
                                        if(portList[1] == targetPort):
                                            protocol = portList[0]
                                    queryOne = protocol + " sport " + targetPort + " accept"
                                    queryTwo = protocol + " dport " + targetPort + " accept"
                                    for rule in rules:
                                        if(rule[0] == queryOne or rule[0] == queryTwo):
                                            os.system("nft delete rule firewall input handle " + rule[1])
                                     
                                    rules = getRuleList("firewall", "output")
                                    for port in outputPorts:
                                        portList = port.split(" ")
                                        if(portList[1] == targetPort):
                                            protocol = portList[0]
                                    queryOne = protocol + " sport " + targetPort + " accept"
                                    queryTwo = protocol + " dport " + targetPort + " accept"
                                    for rule in rules:
                                        if(rule[0] == queryOne or rule[0] == queryTwo):
                                            os.system("nft delete rule firewall output handle " + rule[1])
                                    
                                    message = "Port " + targetPort + " successfully closed."
                    elif(newOpt == "whitelist"):
                        if(len(ipList) == 0):
                            print("No whitelisted IPs to remove.")
                        else:
                            p = True
                            while(p):
                                o = True
                                address = input("Enter IP to remove from whitelist: ").lower()
                                if(address == "exit"):
                                    p = False
                                elif(len(address.split('.')) != 4):
                                    print("Invalid address entered. Enter exit to cancel.")
                                for ip in ipList:
                                    if(ip == address):
                                        o = False
                                if(o):
                                    print("Address not found in whitelist. Enter exit to cancel.")
                                else:
                                    p = False
                            if(address != "exit"):
                                inputChain = getRuleList("firewall", "input")
                                outputChain = getRuleList("firewall", "output")
                                inTarget = "ip saddr " + address + " accept"
                                outTarget = "ip daddr " + address + " accept"
                                for rule in inputChain:
                                    if(rule[0] == inTarget):
                                        os.system("nft delete rule firewall input handle " + rule[1])
                                for rule in outputChain:
                                    if(rule[0] == outTarget):
                                        os.system("nft delete rule firewall output handle " + rule[1])
                                message = address + " successfully removed from whitelist."
                    elif(newOpt == "blacklist"):
                        blackList = getBlackList()
                        if(len(blackList) == 0):
                            message = ("No IPs in blacklist to remove.")
                        else:
                            p = True
                            while(p):
                                o = True
                                address = input("Enter IP to remove from blacklist: ").lower()
                                if(address == "exit"):
                                    p = False
                                elif(len(address.split('.')) != 4):
                                    print("Invalid address entered. Enter exit to cancel.")
                                for ip in blackList:
                                    if(ip[0] == address):
                                        o = False
                                if(o):
                                    print("Address not found in blacklist. Enter exit to cancel.")
                                else:
                                    p = False
                            removeFromBlackList(address)
                            if(address != "exit"):
                                message = address + " successfully removed from blacklist."
                saveRules()
            elif(option.lower() == "panic"):
                currentPan = False
                p = False
                tableList = getTableList()
                for table in tableList:
                    if(table == "PANIC"):
                        currentPan = True
                dam()
                tableList = getTableList()
                for table in tableList:
                    if(table == "PANIC" and currentPan == False):
                        message = "Panic mode successfully activated."
                    elif(table == "PANIC"):
                        p = True
                if(currentPan == True and not p):
                    message = "Panic mode successfully deactivated."
            elif(option.lower() == "quit"):
                return True
            else:
                message = NormHelp()
                                
        else:
            print('Terminating to avoid crashes due to missing structure. Run firewall with the "-i" flag to verify integrity.')
            return
def tableCommand(table):
    x = True
    while(x):
        option = input(f"[Command@{table}]# ")
        if(option.lower() == ''):
            pass
        elif(option.lower() == 'exit'):
            return
        elif(option.lower() == 'add'):
            print(f"Adding chain to {table}")
            y = True
            while(y):
                name = input("Enter name for new chain: ")
                if spacePresent(name):
                    print("Invalid name, spaces not permitted.")
                else:
                    y = False
            hook = input("Enter chain hook(ingress, preroute, input, forward, output, postroute): ")
            type = input("Enter chain type(nat, route, filter): ")
            y = True
            while(y):
                priority = input("Enter chain priority: ")
                priorityNum = int(priority)
                if(priorityNum < -99):
                    option("Adding this chain would override the blacklist(priority -99) and/or panic mode(priority -100). Are you sure?")
                    if(option.lower() in ('y', 'yes')):
                        y = False
            os.system("nft add chain "+table+" "+name+" \{ type "+type+" hook "+hook+" priority "+priority+" \; policy drop\; \}")
            print(f"Chain {name} added to {table}")
        elif(option.lower() == 'chain'):
            chainList = getChainList(table)
            print(f"List of chains in {table}:")
            for chain in chainList:
                print(chain)
            y = True
            while(y):
                option = input("Which chain would you like to move to? ")
                for chain in chainList:
                    if(chain == option):
                        y = False
                if(y):
                    print("Invalid selection.")
            if(chainCommand(table, option) == "quit"):
                return "quit"
        elif(option.lower() == 'clear'):
            print(f"Please note, this will remove all rules in the table {table}. Doing so could result in a loss of firewall function if this table contains firewall rules.")
            option = input(f"Are you sure you would like to clear {table}? ")
            if(option.lower() in ('y', 'yes')):
                os.system("nft flush table "+table)
                chainList = getChainList(table)
                for chain in chainList:
                    os.system("nft delete chain "+table+" "+chain)
                print(f"{table} cleared.")
        elif(option.lower() == 'delete'):
            chainList = getChainList(table)
            for chain in chainList:
                print(chain)
            option = input("What chain would you like to remove? ")
            os.system("nft flush chain "+table+" "+chain)
            os.system("nft delete chain "+table+" "+chain)
            chainList = getChainList(table)
            z = False
            for chain in chainList:
                if(chain == option):
                    z = True
            if(z):
                print(f"{option} deleted.")
            else:
                print(f"Error removing {option}.")
        elif(option.lower() == 'quit'):
            return "quit"
        elif(option.lower() == 'list'):
            chainList = getChainList(table)
            for chain in chainList:
                print(chain)
        elif(option.lower() == 'panic'):
            dam()
        elif(option.lower() == 'blacklist'):
            if(blackList() == "quit"):
                return "quit"
        else:
            printHelp()
def chainCommand(table, chain):
    x = True
    while(x):
        option = input(f"[Command@{table}:{chain}]# ")
        if(option.lower() == ''):
            pass
        elif(option.lower() == 'exit'):
            return
        elif(option.lower() == 'quit'):
            return "quit"
        elif(option.lower() == 'add'):
            print(f"Adding exclusion to chain {chain}.")
            y = True
            while(y):
                option = input("Exclude IP or Port? ")
                if(option.lower() in ('ip', 'port')):
                    y = False
            y = True
            while(y):
                stance = input(f"Filter by source or destination {option}? ")
                if(stance.lower() in ('source', 'destination')):
                    y = False
            if(option.lower() in ('ip')):
                ips = input("Enter list of IPs to exclude seperated by spaces: ")
                list = ips.split(" ")
                exclude = list[0]
                del list[0]
                for ip in list:
                    exclude = exclude + ", "+ip
                if(stance.lower() in ('source')):
                    os.system("nft add rule "+table+" "+chain+" ip saddr { "+exclude+" } accept")
                elif(stance.lower() in ('destination')):
                    os.system("nft add rule "+table+" "+chain+" ip daddr { "+exclude+" } accept")
            elif(option.lower() in ('port')):
                y = True
                while(y):
                    type = input("tcp or udp? ")
                    if(type.lower() in ('tcp', 'udp')):
                        y = False
                ports = input("Enter list of ports/services(http/https/ssh) to exclude seperated by spaces: ")
                list = ports.split(" ")
                exclude = list[0]
                del list[0]
                for port in list:
                    exclude = exclude + ", "+port
                if(stance.lower() in ('source')):
                    os.system("nft add rule "+table+" "+chain+" "+type+" sport { "+exclude+" } accept")
                elif(stance.lower() in ('destination')):
                    os.system("nft add rule "+table+" "+chain+" "+type+" dport { "+exclude+" } accept")
            print(f"New rule added to {chain}.")
        elif(option.lower() == 'delete'):
            ruleList = getRuleList(table, chain)
            print(f"List of rules in {chain}:")
            for rule in ruleList:
                if(len(rule[2]) != 0):
                    print(rule[0] + " ("+rule[1]+")  ["+rule[2]+"]") 
                else:
                    print(rule[0] + " ("+rule[1]+")")
            y = True
            while(y):
                handle = input("Enter handle of rule you would like to remove: ")
                for rule in ruleList:
                    if(rule[1] == handle):
                        ruleName = rule[0]
                        y = False
                if(y):
                    print("Invalid selection.")
            verification = input(f"Confirmation: Removing rule {ruleName} from chain {chain}? ")
            if(verification.lower() == "y" or verification.lower() == "yes"):
                command = f"nft delete rule {table} {chain} handle {handle}"
                os.system(command)
        elif(option.lower() == 'list'):
            ruleList = getRuleList(table, chain)
            for rule in ruleList:
                if(len(rule[2]) != 0):
                    print(rule[0] + " ("+rule[1]+")  ["+rule[2]+"]") 
                else:
                    print(rule[0] + " ("+rule[1]+")")
        elif(option.lower() == 'panic'):
            dam()
        elif(option.lower() == 'blacklist'):
            if(blackList() == "quit"):
                return "quit"
        else:
            printHelp()
def getTableList(): #Returns list of table names as strings
    tableList = []
    tableOutput = subprocess.check_output(["nft", "list tables"])
    tableListRaw = tableOutput.decode("utf-8").split("\n")
    for line in tableListRaw:
        lineList = line.split(" ")
        tableList.append(lineList[-1])
    del(tableList[-1])
    return tableList
def getAdvTableList(): #Returns list of objects in this format: [TableName, TableFamily] with these types: [String, String]
    tableList = [[]]
    tableOutput = subprocess.check_output(["nft", "list tables"])
    tableListRaw = tableOutput.decode("utf-8").split("\n")
    for line in tableListRaw:
        if(len(line) == 0):
            pass
        else:
            lineTableList = []
            lineList = line.split(" ")
            lineTableList.append(lineList[-1])
            lineTableList.append(lineList[1])
            tableList.append(lineTableList)
    del(tableList[0])
    return tableList
def getChainList(table):    #Returns list of chains as strings
    chainList = []
    command = f"list table {table}"
    chainOutput = subprocess.check_output(["nft", command])
    chainListRaw = chainOutput.decode('utf-8').split("chain")
    del chainListRaw[0]
    for line in chainListRaw:
        lineList = line.split(" ")
        chainList.append(lineList[1])
    return chainList
def getRuleList(table, chain):  #Returns list of objects in this format: [ruleName, ruleHandle, portDefault]  with these types: [String, String, String(May be length 0 string if no default is listed]
    ruleList = [[]]
    command = f"nft -a list table {table}"
    ruleListOutput = subprocess.check_output([command], shell=True)
    splitter = f"chain {chain}" + " {"
    ruleListRaw = ruleListOutput.decode("utf-8").split(splitter)
    del(ruleListRaw[0])
    ruleListRawStr = ruleListRaw[0]
    ruleListRaw = ruleListRawStr.split("}")
    ruleListRawStr = ruleListRaw[0]
    ruleListRaw = ruleListRawStr.split("\n")
    del(ruleListRaw[0])
    del(ruleListRaw[0])
    del(ruleListRaw[len(ruleListRaw)-1])
    for line in ruleListRaw:
        ruleInfo = line.split(" # handle ")
        ruleName = ruleInfo[0]
        ruleNameList = ruleName.split("\t")
        ruleName = ruleNameList[2]
        itemList = ruleName.split(" ")
        port = itemList[2]
        protocol = itemList[0]
        ruleHandle = ruleInfo[1]
        rule = [ruleName, ruleHandle]
        rule.append(portDefault(protocol, port))
        ruleList.append(rule)
    del(ruleList[0])
    return ruleList
def getChainInfo(table, chain):
    command = f"nft -a list table {table}"
    ruleListOutput = subprocess.check_output([command], shell=True)
    splitter = f"chain {chain}" + " {"
    ruleListRaw = ruleListOutput.decode("utf-8").split(splitter)
    del(ruleListRaw[0])
    ruleListRaw = ruleListRaw.split("\n")
    return ruleListRaw[1]
def dam():
    tableList = getTableList()
    x = False
    for table in tableList:
        if(table == "PANIC"):
            x = True
    if(x):
        option = input("Panic mode is currently enabled. Would you like to disable it? ")
        if(option.lower() in ('y', 'yes')):
            os.system("nft flush table PANIC")
            os.system("nft delete table PANIC")
            print("Panic mode deactivated.")
        else:
            print("Panic mode remaining on.")
    else:
        print("Enabling panic mode...")
        os.system("nft add table PANIC")
        os.system("nft add chain PANIC panicChainIn \{ type filter hook input priority -100 \; policy drop\; \}")
        os.system("nft add chain PANIC panicChainOut \{ type filter hook output priority -100 \; policy drop\; \}")
        print("Panic mode activated. All traffic in and out blocked.")
def panicOn():
    tableList = getTableList()
    for table in tableList:
        if(table == "PANIC"):
            return True
    return False
def blackList():
    z = True
    while(z):
        blackList = getBlackList()
        if(len(blackList) == 0):
            print("No IPs in blacklist.")
        else:
            print("Current list of blacklisted IPs:")
            for ip in blackList:
                print(ip[0] + " ("+ip[1]+")")
        option = input("[Command@Blacklist]# ")
        if(option.lower() == ''):
            pass
        elif(option.lower() == 'add'):
            ip = input("Enter IP to add to blacklist: ")
            option = input(f"Confirmation: Adding {ip} to blacklist: ")
            if(option.lower() in ('y', 'yes')):
                os.system("nft add rule blacklist blockIn ip saddr { "+ip+" } drop")
                os.system("nft add rule blacklist blockOut ip daddr { "+ip+" } drop")
                blackList = getBlackList()
                y = False
                for heldIP in blackList:
                    if(heldIP[0] == ip):
                        y = True
                if(y):
                    print(f"IP {ip} successfully added to blacklist.")
                else:
                    print(f"Error adding {ip} to blacklist.")
        elif(option.lower() == 'delete'):
            x = True
            if(len(blackList) == 0):
                x = False
                print("Cannot remove from blacklist. No IPs present.")
            while(x):
                index = 0
                option = input("Enter IP or handle to remove from blacklist: ")
                for ip in blackList:
                    if(ip[0] == option):
                        x = False
                    if(ip[1] == option):
                        x = False
                    if(x):
                        index = index+1
                if(x):
                    optionList = option.split(".")
                    if(len(optionList) == 1):
                        print(f"{option} not in blacklist.")
                    else:
                        print(f"No IP connecting to handle {option}")
            confirm = input(f"Confirmation: Removing {blackList[index][0]} from blacklist: ")
            ip = blackList[index][0]
            if(confirm.lower() in ('y', 'yes')):
                os.system("nft delete rule blacklist blockIn handle "+str(blackList[index][1]))
                os.system("nft delete rule blacklist blockOut handle "+str(int(blackList[index][1])+1))
            blackList = getBlackList()
            y = True
            for heldIP in blackList:
                if(heldIP[0] == option or heldIP[1] == option):
                    y = False
            if(y):
                print(f"{ip} successfully removed from blacklist.")
            else:
                print(f"Error removing {ip} from blacklist.")
        elif(option.lower() == 'exit'):
            return
        elif(option.lower() == 'quit'):
            return "quit"
        elif(option.lower() == 'panic'):
            panic()
        else:
            printHelp()
def restoreRuleInteg(machine):
    if(machine == "splunk"):
        requiredServicesTCP = ["53", "http", "https", "8000"]
        inOnlyServicesTCP = ["1894"]
        outOnlyServicesTCP = ["1893"]
        requiredServicesUDP = ["53", "123"]
        inOnlyServicesUDP = []
        outOnlyServicesUDP = []
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"]
        inOnlyIPs = []
        outOnlyIPs = []
    elif(machine == "centos"):
        requiredServicesTCP = ["53", "http", "https"]
        inOnlyServicesTCP = ["1893"]
        outOnlyServicesTCP = ["1894"]
        requiredServicesUDP = ["53", "123"]
        inOnlyServicesUDP = []
        outOnlyServicesUDP = []
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"]
        inOnlyIPs = []
        outOnlyIPs = []
    elif(machine == "fedora"):
        requiredServicesTCP = ["53", "http", "https", "25", "110"]
        inOnlyServicesTCP = ["1893"]
        outOnlyServicesTCP = ["1894"]
        requiredServicesUDP = ["53", "123"]
        inOnlyServicesUDP = []
        outOnlyServicesUDP = []
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"]
        inOnlyIPs = []
        outOnlyIPs = []
    else:
        requiredServicesTCP = ["53", "http", "https"] 
        inOnlyServicesTCP = [] 
        outOnlyServicesTCP = [] 
        requiredServicesUDP = ["53"] 
        inOnlyServicesUDP = [] 
        outOnlyServicesUDP = [] 
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"] 
        inOnlyIPs = [] 
        outOnlyIPs = [] 
    for service in requiredServicesTCP:
        os.system("nft add rule firewall input tcp dport { "+service+" } accept")
        os.system("nft add rule firewall input tcp sport { "+service+" } accept")
        os.system("nft add rule firewall output tcp dport { "+service+" } accept")
        os.system("nft add rule firewall output tcp sport { "+service+" } accept")
        if(service == "1893" or service == "1894"):
            os.system("nft add rule firewall output tcp dport { "+service+" } accept")
    for service in inOnlyServicesTCP:
        os.system("nft add rule firewall input tcp dport { "+service+" } accept")
    for service in outOnlyServicesTCP:
        os.system("nft add rule firewall output tcp dport { "+service+" } accept")
    for service in requiredServicesUDP:
        os.system("nft add rule firewall input udp dport { "+service+" } accept")
        os.system("nft add rule firewall input udp sport { "+service+" } accept")
        os.system("nft add rule firewall output udp dport { "+service+" } accept")
        os.system("nft add rule firewall output udp sport { "+service+" } accept")
    for service in inOnlyServicesUDP:
        os.system("nft add rule firewall input udp dport { "+service+" } accept")
    for service in outOnlyServicesUDP:
        os.system("nft add rule firewall output udp dport { "+service+" } accept")
    for ip in requiredIPs:
        os.system("nft add rule firewall input ip saddr { "+ip+" } accept")
        os.system("nft add rule firewall output ip daddr { "+ip+" } accept")
    for ip in inOnlyIPs:
        os.system("nft add rule firewall input ip saddr { "+ip+" } accept")
    for ip in outOnlyIPs:
        os.system("nft add rule firewall output ip daddr { "+ip+" } accept")
def getBlackList():     #Returns list of entities in following format: [ip, handle]
    blackList = [[]]
    blackListOutput = subprocess.check_output(["nft -a list table blacklist"], shell=True)
    blackListRaw = blackListOutput.decode("utf-8").split("saddr ")
    del(blackListRaw[0])
    for line in blackListRaw:
        ipSplit = line.split(" ")
        itemList = []
        itemList.append(ipSplit[0])
        handleList = ipSplit[4].split("\n")
        handle = handleList[0]
        itemList.append(handle)
        blackList.append(itemList)
    del(blackList[0])
    return blackList
def addToBlackList(ip):
    tableList = getTableList()
    x = True
    for table in tableList:
        if(table == "blacklist"):
            x = False
    if(x):
        return "Blacklist table does not exist."
    os.system("nft add rule blacklist blockIn ip saddr { "+ip+" } drop")
    os.system("nft add rule blacklist blockOut ip daddr { "+ip+" } drop")
    blackList = getBlackList()
    x = True
    for entry in blackList:
        if(entry[0] == ip): 
            x = False
    if(x):
        return f"Error adding {ip} to blacklist"
    else:
        return f"{ip} successfully added to blacklist."
def removeFromBlackList(ip):
    blackList = getBlackList()
    x = True
    index = 0
    for entry in blackList:
        if(entry[0] == ip): 
            x = False
        if(x):
            index = index+1
    if(x):
        return "IP not found in blacklist."
    os.system("nft delete rule blacklist blockIn handle "+str(blackList[index][1]))
    os.system("nft delete rule blacklist blockOut handle "+str(int(blackList[index][1])+1))
    x = True
    for entry in blackList:
        if(entry[0] == ip): 
            x = False
    if(x):
        return f"{ip} successfully removed from blacklist."
    else:
        return f"Error removing {ip} from blacklist."
def spacePresent(input):
    inputList = input.split(" ")
    if(len(inputList) != 1):
        return True
    else:
        return False
def isInList(value, list):
    for thing in list:
        if(thing == value):
            return True
    return False
def portDefault(protocol, port):
    if(protocol == "tcp"):
        return {
            '20': 'FTP',
            '22': 'SSH',
            '25': 'SMTP',
            '53': 'DNS',
            '80': 'HTTP',
            '110': 'POP3',
            '143': 'IMAP',
            '443': 'HTTPS'
        }.get(port, "")
    elif(protocol == "udp"):
        return {
            '53': 'DNS',
            '123': 'NTP',
        }.get(port, "")
    else:
        return ""
def addOtherPorts(inputArray):
    portArray = inputArray
    commonTCP = ["20", "22", "25", "53", "80", "110", "143", "443"]
    commonUDP = ["53", "123"]
    for port in commonTCP:
        value = "tcp " + port + " " + portDefault("tcp", port)
        if(not value in portArray):
            portArray.append(value)
    for port in commonUDP:
        value = "udp " + port + " " + portDefault("udp", port)
        if(not value in portArray):
            portArray.append(value)
    return portArray
def saveConfig(saveName):
    chainList = getChainList("firewall")
    blacklistAddresses = getBlackList()
    blacklistStr = ""
    for address in blacklistAddresses:
        blacklistStr = blacklistStr + str(address) + "??" #Joins into format: "['(address)', '(handle)']??['(address)', '(handle)']??['(address)', '(handle)']?? ........"
    blacklistStr = blacklistStr[:len(blacklistStr)-2]
    saveContent = blacklistStr
    for chain in chainList:
        chainStr = chain + "\n"
        listofChain = []
        listofChain.append(getRuleList("firewall", chain))
        for ruleChain in listofChain:
            for rule in ruleChain:
                if(len(rule) == 3):
                    del(rule[2])
        for rule in listofChain:
            chainStr = chainStr + str(rule) + "??" #Joins into format: "['(rule)', '(handle)']??['(rule)', '(handle)']??['(rule)', '(handle)']?? ........"
        chainStr = chainStr[:len(chainStr)-2]
        saveContent = saveContent + "\nxxxxx\n" + chainStr
    os.system('echo "' + saveContent + '" >> /etc/firewall/configs/' + saveName + '.config')
def loadConfig(saveName):
    tableList = getTableList()
    firewallPres = False
    for table in tableList:
        if(table == "firewall"):
            firewallPres = True
    if(not firewallPres):
        os.system("nft add table firewall")
    chainList = getChainList("firewall")
    inPres = False
    outPres = False
    for chain in chainList:
        if(chain == "input"):
            inPres = True
        if(chain == "output"):
            outPres = True
    if(not inPres):
        os.system("nft add chain firewall input \{ type filter hook input priority 0 \; policy drop\; \}")
    if(not outPres):
        os.system("nft add chain firewall output \{ type filter hook output priority 0 \; policy drop\; \}")
    os.system("nft flush chain firewall input")
    os.system("nft flush chain firewall output")
    configContents = getFileCont("/etc/firewall/configs/" + saveName + ".config")
    configList = configContents.split("\nxxxxx\n")
    blacklist = configList[0]
    blacklistList = blacklist.split("??")
    for entry in blacklistList:
        entry = entry[2:len(entry)-2]
        entryList = entry.split("', '")
        blacklistIP = entryList[0]
        blacklistHandle = str(int(entryList[1]) + 1)
        os.system("nft insert rule blacklist blockIn \[position " + blacklistHandle + "\] ip saddr " + blacklistIP + " drop")
        os.system("nft insert rule blacklist blockOut \[position " + blacklistHandle + "\] ip daddr " + blacklistIP + " drop")
    del(configList[0])
    for chain in configList:
        chainSplit = chain.split("\n")
        chainName = chainSplit[0]
        chainRules = chainSplit[1]
        chainRules = chainRules[3:len(chainRules)-3]
        chainRuleList = chainRules.split("'], ['")
        for rule in chainRuleList:
            ruleSplit = rule.split("', '")
            ruleName = ruleSplit[0]
            ruleHandle = str(int(ruleSplit[1]) + 1)
            os.system("nft insert rule firewall " + chain + "\[position " + ruleHandle + "\] " + ruleName)
def getFileCont(file):
    command = "cat " + file
    fileCont = str(subprocess.check_output(command, shell=True))
    return fileCont[2:(len(fileCont)-1)]
def saveRules():
    os.system("nft list ruleset > /etc/nftables.conf")
def NormHelp():
    return("""
Firewall interface for linux machines using nftables. Written for use by EKU's CCDC team in practice and live environments.

Commands:
    
    quit           |     Quits the firewall manager.
    whitelist      |     Adds an IP address to the whitelist.
    blacklist      |     Adds an IP address to the blacklist.
    open           |     Opens a port as defined by user input.
    delete         |     Allows the user to delete a rule, delete an IP from the whitelist, or delete an IP from the blacklist.
    panic          |     Activates/Deactivates panic mode. Will only prompt confirmation when disabling panic mode.
""")
def printHelp():
    print("""
Firewall interface for linux machines using nftables. Written for use by EKU's CCDC team in practice and live environments.


Command line arguments:

    -h , --help    |     Displays this help menu and exits.
    -ba [ip]       |     Adds given IP to blacklist.
    -br [ip]       |     Removes given IP from blacklist.
    -e             |     Enters expert mode, allows for more in-depth customization of nfTables.
    -k(f)          |     Enters kill mode, allowing the user to kill all tables other than firewall and blacklist. (Running with -kf flag will kill all other tables without asking for user confirmation. Use with caution)
    -i             |     Verifies integrity of firewall installation.

In-Program Commands:

    help           |     Displays this help menu.
    exit           |     Exits out of current command focus and returns to the previous layer. (ex. using "exit" while in a specific chain moves the focus to the table that contains the chain)
    quit           |     Quits out of program.
    panic          |     Activates/Deactivates panic mode. Will only prompt confirmation when disabling panic mode.
    blacklist      |     Enters blacklist management menu.

    Core Commands:
    
    table          |     Changes command focus to a specific table.
    add            |     Adds a new table to the ip family.
    delete         |     Removes a table from the ip family.
    
    Table Commands:
    
    chain          |     Changes command focus to a specific chain within the table.
    add            |     Adds a new chain to the selected table.
    clear          |     Clears out the current table. This will remove all rules associated with the current table.
    delete         |     Removes a stated chain from the current table.
    list           |     Displays all chains present within the current table.
    
    Chain Commands:

    add            |     Adds a new rule to the selected chain.
    delete         |     Removes a stated rule from the current chain.
    list           |     Lists all rules present in selected chain, along with their handles.
    
    Blacklist Commands:
    
    add            |     Adds a new IP to the blacklist.
    delete         |     Removes an IP from the blacklist.
    
    
""")
main()