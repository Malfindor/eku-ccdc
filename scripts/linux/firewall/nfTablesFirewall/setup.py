import os
import sys

requiredServicesTCP = []
requiredServicesUDP = []
inOnlyServicesUDP = []
outOnlyServicesUDP = []
requiredIPs = []
inOnlyIPs = []
outOnlyIPs = []

def main():
    if(len(sys.argv) == 2):
        install(sys.argv[1])
    else:
        machine = input("Enter machine name to install as(centos, fedora, splunk, debian, ubuntu): ").lower()
        if(machine in ["centos", "splunk", "fedora", "ubuntu", "debian"]):
            print("Installing firewall as " + machine + ".")
            install(machine)
        else:
            print("Entered machine name not found. Installing with default rules.")
            install("default")
def install(machine):
    os.system("mkdir /etc/firewall")
    os.system("mkdir /etc/firewall/configs")
    os.system("touch /etc/firewall/machinePreset.flag")
    if(machine in ["centos", "splunk", "fedora", "ubuntu", "debian"]):
        os.system('echo "' + machine + '" > /etc/firewall/machinePreset.flag')
    else:
        os.system('echo "default" > /etc/firewall/machinePreset.flag')
    if(machine == "splunk"):
        requiredServicesTCP = ["53", "http", "https", "8000", "8089"]
        requiredServicesUDP = ["53", "123"]
        inOnlyServicesUDP = []
        outOnlyServicesUDP = []
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"]
        inOnlyIPs = []
        outOnlyIPs = []
    elif(machine == "centos"):
        requiredServicesTCP = ["53", "http", "https"]
        requiredServicesUDP = ["53", "123"]
        inOnlyServicesUDP = []
        outOnlyServicesUDP = []
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"]
        inOnlyIPs = []
        outOnlyIPs = []
    elif(machine == "fedora"):
        requiredServicesTCP = ["53", "http", "https", "25", "110"]
        requiredServicesUDP = ["53", "123"]
        inOnlyServicesUDP = []
        outOnlyServicesUDP = []
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"]
        inOnlyIPs = []
        outOnlyIPs = []
    else:
        requiredServicesTCP = ["53", "http", "https"] #ports/services allowed to freely talk both ways
        requiredServicesUDP = ["53"] #ports/services allowed to freely talk both ways
        inOnlyServicesUDP = [] #ports/services only allowed to recieve traffic, not send
        outOnlyServicesUDP = [] #ports/services only allowed to send traffic, not recieve
        requiredIPs = ["127.0.0.1", "8.8.8.8", "8.8.4.4"] #IPs allowed to send traffic to and recieve trafic from this machine
        inOnlyIPs = [] #IPs only allowed to send traffic to this machine.
        outOnlyIPs = [] #IPs only allowed to recieve traffic from this machine.
        
    os.system("nft add table firewall")
    os.system("nft add table blacklist")
    os.system("nft add chain firewall input \{ type filter hook input priority 0 \; policy drop\; \}")
    os.system("nft add chain firewall output \{ type filter hook output priority 0 \; policy drop\; \}")
    os.system("nft add chain blacklist blockIn \{ type filter hook input priority -99 \; policy accept\; \}")
    os.system("nft add chain blacklist blockOut \{ type filter hook output priority -99 \; policy accept\; \}")
    for service in requiredServicesTCP:
        os.system("nft add rule firewall input tcp dport { "+service+" } accept")
        os.system("nft add rule firewall input tcp sport { "+service+" } accept")
        os.system("nft add rule firewall output tcp dport { "+service+" } accept")
        os.system("nft add rule firewall output tcp sport { "+service+" } accept")
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
    
    os.system("nft list ruleset > /etc/nftables.conf")
    os.system("systemctl enable nftables")
    os.system("systemctl start nftables")
    
    os.remove(sys.argv[0])
main()