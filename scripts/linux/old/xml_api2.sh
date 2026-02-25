#!/bin/bash

# Author: Logan Jackson
# Stolen from: Raven Dean
# xml_api2.sh
#
# Description: A bash script that configures the firewall automatically using Palo Alto's XML API
# UPDATE VARIABLES BELOW

# Created 11/14/2024
# Usage: <./xml_api2.sh>

# Edit variables as required:
host="172.20.242.150" # CHANGEME! - Palo Alto host IP addr
management_subnet="172.20.242.0/24" # CHANGEME! - Palo Alto management subnet
team_number=0 # CHANGEME! - CCDC Team Number
user="admin" # - Admin username
password="1234" # CHANGEME! - Admin default/current password

# Do not touch these variables unless you know what you are doing:
third_octet=$((20+$team_number))
pan_device="localhost.localdomain"
pan_vsys="vsys1"
device_xpath="/config/devices/entry[@name='$pan_device']"
vsys_xpath="/vsys/entry[@name='$pan_vsys']"
script_name="xml_api.sh"
usage="./$script_name"
repo_root=$(git rev-parse --show-toplevel)
api="https://$host/api/" # api baseurl
job_status_poll_speed=3 # Speed (in seconds) that the script checks for the commit status

# Define xpaths for quick access
full_xpath="$device_xpath$vsys_xpath"
mgmt_profile_xpath="$device_xpath/network/profiles/interface-management-profile/entry"
eth_interface_xpath="$device_xpath/network/interface/ethernet/entry"
app_group_xpath="$full_xpath/application-group/entry"
addr_object_xpath="$full_xpath/address/entry"
addr_group_xpath="$full_xpath/address-group/entry"
srvc_object_xpath="$full_xpath/service/entry"
srvc_group_xpath="$full_xpath/service-group/entry"
log_profiles_xpath="$full_xpath/log-settings/profiles/entry"
srvc_route_xpath="$device_xpath/deviceconfig/system/route"
sec_policy_xpath="$full_xpath/rulebase/security/rules/entry"
dsec_policy_xpath="$full_xpath/rulebase/default-security-rules/rules/entry"
tag_object_xpath="$full_xpath/tag/entry"

# Import environment variables (ekurc)
. $repo_root/config_files/ekurc

# Updating and upgrading apt
apt update -y && apt upgrade -y

# Install dependencies
apt install -y libxml-xpath-perl libxml2-utils jq findutils curl

# FUNCTIONS:

# Action function for calling the Palo Alto API and recieving response codes
action() { # action <action> <description> <xpath>/<cmd> <element>
    api_call="action_$1($2)"
    if [ "$1" == "set" ] || [ "$1" == "edit" ]
    then
        url_encoded_element="$(echo $4 | jq -sRr @uri)"
        response=$(curl --location --globoff --insecure --request POST --header "$header" "$api?type=config&action=$1&xpath=$3&element=$url_encoded_element")
    elif [ "$1" == "op" ]
    then
        url_encoded_cmd="$(echo $3 | jq -sRr @uri)"
        response=$(curl --location --globoff --insecure --request POST --header "$header" "https://$host/api/?type=op&cmd=$url_encoded_cmd")
    else
        response=$(curl --location --globoff --insecure --request POST --header "$header" "$api?type=config&action=delete&xpath=$3")
    fi

    response_code=$(echo $response | xmllint --xpath 'string(/response/@code)' -)
    response_status=$(echo $response | xmllint --xpath 'string(/response/@status)' -)
    message=$(echo $response | xmllint --xpath 'string(/response/msg)' -)
    echo $response

    if [ ! -z "$response_code" ] # If the response contains a response code
    then
        if [ "$response_code" == "20" ] # Success
        then
            success $api_call
        elif [ "$response_code" == "7" ] # Object not found
        then
            warn "$api_call failed with reason: $message"
        else # Some other error
            error "$api_call failed with reason: $message"
        fi
    else # If the response does not contain a response code
        if [ "$response_status" == "success" ]
        then
            success $api_call
        else
            error "$api_call failed with reason: $message"
        fi
    fi
}

check_job_status() {
    # Check the commit status for the job in $1 and echo the result.
    response=$(curl --location --globoff --insecure --silent --request GET --header "$header" "$api?type=op&cmd=<show><jobs><id>$1</id></jobs></show>")
    echo $(echo $response | xpath -e '/response/result/job/status/text()' 2>/dev/null)
}

commit() { #commit <description>
    info "Starting Job: $1"
    job_id=$(curl --location --globoff --insecure --silent --request POST --header "$header" "$api?type=commit&cmd=<commit></commit>" | xpath -q -e '/response/result/job/text()')

    if [ ! -z "$job_id" ]
    then
        status=$(check_job_status $job_id)
        while [ "$status" != "FIN" ]
        do
            info "Waiting for job $job_id ($1) to complete..."
            sleep $job_status_poll_speed
            status=$(check_job_status $job_id)
        done
        success "Job $job_id: '$1' complete!"
    else
        warn "Job $job_id: Nothing to do!"
    fi
}

waits() { # waits <pid_array> <command>
    for pid in $1
    do
        while [ -e "/proc/$pid" ]
        do
            sleep 0.1
        done
    done
    shift
    "$@" &
}

configure_interfaces() { # configure_interfaces
    # Set ethernet1/1 (Public) Management Profile
    action "edit" "Set Ethernet1/1 (Public) Management Profile" "$eth_interface_xpath[@name='ethernet1/1']" "<entry name=\"ethernet1/1\"><layer3><ndp-proxy><enabled>no</enabled></ndp-proxy><sdwan-link-settings><upstream-nat><enable>no</enable><static-ip/></upstream-nat><enable>no</enable></sdwan-link-settings><ip><entry name=\"172.20.241.254/24\"/></ip><lldp><enable>no</enable></lldp><interface-management-profile>Allow-Ping</interface-management-profile></layer3><comment>Public</comment></entry>" &

    # Set ethernet1/2 (Internal) Management Profile
    action "edit" "Set Ethernet1/2 (Internal) Management Profile" "$eth_interface_xpath[@name='ethernet1/2']" "<entry name=\"ethernet1/2\"><layer3><ndp-proxy><enabled>no</enabled></ndp-proxy><sdwan-link-settings><upstream-nat><enable>no</enable><static-ip/></upstream-nat><enable>no</enable></sdwan-link-settings><ip><entry name=\"172.20.240.254/24\"/></ip><lldp><enable>no</enable></lldp><interface-management-profile>Allow-Ping</interface-management-profile></layer3><comment>Internal</comment></entry>" &

    # Set ethernet1/3 (External) Management Profile
    action "edit" "Set Ethernet1/3 (External) Management Profile" "$eth_interface_xpath[@name='ethernet1/3']" "<entry name=\"ethernet1/3\"><layer3><ndp-proxy><enabled>no</enabled></ndp-proxy><sdwan-link-settings><upstream-nat><enable>no</enable><static-ip/></upstream-nat><enable>no</enable></sdwan-link-settings><ip><entry name=\"172.31.$third_octet.2/29\"/></ip><lldp><enable>no</enable></lldp><interface-management-profile>Nothing</interface-management-profile></layer3><comment>External</comment></entry>" &

    # Set ethernet1/4 (User)
    action "edit" "Set Ethernet1/4 (User) Management Profile" "$eth_interface_xpath[@name='ethernet1/4']" "<entry name=\"ethernet1/4\"><layer3><ndp-proxy><enabled>no</enabled></ndp-proxy><sdwan-link-settings><upstream-nat><enable>no</enable><static-ip/></upstream-nat><enable>no</enable></sdwan-link-settings><ip><entry name=\"172.20.242.254/24\"/></ip><lldp><enable>no</enable></lldp><interface-management-profile>Allow-HTTPS-Ping</interface-management-profile></layer3><comment>User</comment></entry>" &
    wait # wait to finish the function until the actions are complete
}

create_security_policies() { # create_security_policies
    # Drop Blacklisted IPs Egress
    action "set" "Security Policy 'Block Outbound Blacklisted'" "$sec_policy_xpath[@name='deny-blacklist-egress']" "<to><member>External</member></to><from><member>Internal</member><member>Public</member><member>User</member></from><source><member>any</member></source><destination><member>blacklist</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>any</member></application><service><member>any</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>drop</action><icmp-unreachable>yes</icmp-unreachable><description>Drop traffic with a blacklisted destination address from leaving the network perimeter.</description><log-setting>Splunk</log-setting>" &

    # Drop Blacklisted IPs Ingress
    action "set" "Security Policy 'Block Inbound Blacklisted'" "$sec_policy_xpath[@name='deny-blacklist-ingress']" "<to><member>Internal</member><member>User</member><member>Public</member></to><from><member>External</member></from><source><member>blacklist</member></source><destination><member>any</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>any</member></application><service><member>any</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>drop</action><icmp-unreachable>yes</icmp-unreachable><description>Drop traffic with a blacklisted source address from entering the network.</description><log-setting>Splunk</log-setting>" &

    # Wait for blacklist rules to complete before moving on
    wait

    # Outbound Company Traffic
    action "set" "Security Policy 'Outbound Company Traffic'" "$sec_policy_xpath[@name='company-egress']" "<to><member>External</member></to><from><member>Internal</member><member>Public</member><member>User</member></from><source><member>any</member></source><destination><member>any</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>dns</member><member>icmp-ping</member><member>linux-updates</member><member>ntp</member><member>web-traffic</member><member>webmail</member><member>windows-updates</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Controls which company traffic is permitted to exit the network perimeter.</description><log-setting>Splunk</log-setting>"

    # External to Public
    action "set" "Security Policy 'External to Public'" "$sec_policy_xpath[@name='external-to-public']" "<to><member>Public</member></to><from><member>External</member></from><source><member>any</member></source><destination><member>public-network-servers-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>icmp-ping</member><member>linux-updates</member><member>web-traffic</member><member>webmail</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Controls which traffic is permitted to enter the public network from the external network.</description><log-setting>Splunk</log-setting>" &

    # External to Splunk
    action "set" "Security Policy 'External to Splunk'" "$sec_policy_xpath[@name='external-to-splunk']" "<to><member>Public</member></to><from><member>External</member></from><source><member>any</member></source><destination><member>splunk-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>web-browsing</member></application><service><member>splunk-web-service</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allows external web-browsing to Splunk.</description><log-setting>Splunk</log-setting>" &

    # External to User
    action "set" "Security Policy 'External to User'" "$sec_policy_xpath[@name='external-to-user']" "<to><member>User</member></to><from><member>External</member></from><source><member>any</member></source><destination><member>user-network-nat-address</member><member>user-network-servers-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>dns</member><member>icmp-ping</member><member>linux-updates</member><member>web-traffic</member><member>windows-updates</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Controls which traffic is permitted to access the user network from the external network.</description><log-setting>Splunk</log-setting>" &

    # External to Internal
    action "set" "Security Policy 'External to Internal'" "$sec_policy_xpath[@name='external-to-internal']" "<to><member>Internal</member></to><from><member>External</member></from><source><member>any</member></source><destination><member>internal-network-servers-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>dns</member><member>icmp-ping</member><member>linux-updates</member><member>ntp</member><member>web-traffic</member><member>windows-updates</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Controls which traffic is permitted to access the internal network from the external network.</description><log-setting>Splunk</log-setting>" &
 
    # Wait for external ingress rules to complete before moving on
    wait

    # Internal Servers to Splunk
    action "set" "Security Policy 'Internal Servers to Splunk'" "$sec_policy_xpath[@name='internal-servers-to-splunk']" "<to><member>Public</member></to><from><member>Internal</member><member>Public</member><member>User</member></from><source><member>all-company-servers</member></source><destination><member>splunk</member><member>splunk-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>any</member></application><service><member>splunk-indexing-service</member><member>splunk-syslog-service</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allow all company servers to communicate with Splunk.</description>" &

    #action "set" "Security Policy 'Internal Servers to DNS/NTP'" "$sec_policy_xpath[@name='bidir-servers-to-dns_ntp']" "<to><member>Internal</member><member>Public</member><member>User</member></to><from><member>Internal</member><member>Public</member><member>User</member></from><source><member>all-company-servers</member><member>dns-servers</member><member>dns-servers-nat</member><member>ntp-servers</member><member>ntp-servers-nat</member></source><destination><member>all-company-servers</member><member>dns-servers</member><member>dns-servers-nat</member><member>ntp-servers</member><member>ntp-servers-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>dns</member><member>ntp</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allow all company servers to communicate with internal DNS and NTP servers bi-directionally.</description><log-setting>Splunk</log-setting>" &

    # Internal Servers to DNS/NTP (TODO: NEW RULE)
    action "set" "Security Policy 'Internal Servers to DNS/NTP'" "$sec_policy_xpath[@name='servers-to-dns_ntp']" "<to><member>Internal</member><member>User</member></to><from><member>Internal</member><member>Public</member><member>User</member></from><source><member>all-company-servers</member></source><destination><member>dns-servers</member><member>dns-servers-nat</member><member>ntp-servers</member><member>ntp-servers-nat</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>dns</member><member>ntp</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allow all servers to communicate with the dns and ntp servers.</description><log-setting>Splunk</log-setting>" &


    # Webmail to Active Directory (TODO: NEW RULE)
    action "set" "Security Policy 'Webmail to Active Directory'" "$sec_policy_xpath[@name='webmail-to-active-directory']" "<to><member>User</member></to><from><member>Public</member></from><source><member>fedora-webmail</member></source><destination><member>windows-server-2019</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>windows-active-directory</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allow the webmail server to communicate with the active directory server.</description><log-setting>Splunk</log-setting>" &

    #action "set" "Security Policy 'Webmail to Active Directory'" "$sec_policy_xpath[@name='bidir-active-directory-to-webmail']" "<to><member>Public</member><member>User</member></to><from><member>Public</member><member>User</member></from><source><member>fedora-webmail</member><member>windows-server-2019</member></source><destination><member>fedora-webmail</member><member>windows-server-2019</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>windows-active-directory</member></application><service><member>application-default</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allow the active directory server to communicate with the mailserver bi-directionally.</description><log-setting>Splunk</log-setting>" &

    # GUIs to Splunk
    action "set" "Security Policy 'GUIs to Splunk'" "$sec_policy_xpath[@name='guis-to-splunk']" "<to><member>Public</member></to><from><member>Internal</member><member>Public</member><member>User</member></from><source><member>all-company-servers</member></source><destination><member>splunk</member></destination><source-user><member>any</member></source-user><category><member>any</member></category><application><member>web-browsing</member></application><service><member>splunk-web-service</member></service><source-hip><member>any</member></source-hip><destination-hip><member>any</member></destination-hip><action>allow</action><description>Allow all company machines with a GUI to access the Splunk server's web UI.</description>" &

    wait # wait to finish the function until the actions are complete
}

create_address_groups() { # create_address_groups
    # Create Blacklist Group
    action "set" "Blacklist Address Group" "$addr_group_xpath[@name='blacklist']" "<static><member>placeholder</member></static>" &

    # Create GUI Address Group
    action "set" "GUI Address Group" "$addr_group_xpath[@name='guis']" "<static><member>windows-server-2019</member><member>debian-dns-ntp</member><member>docker-remote</member></static>" &

    # Create SNMP Server Address Group
    action "set" "SNMP Server Address Group" "$addr_group_xpath[@name='snmp-server']" "<static><member>placeholder</member></static>" &

    # Create All Company Servers Address Group
    action "set" "All Company Servers Address Group" "$addr_group_xpath[@name='all-company-servers']" "<static><member>docker-remote</member><member>debian-dns-ntp</member><member>ubuntu-web</member><member>windows-server-2019</member><member>splunk</member><member>centos-ecomm</member><member>fedora-webmail</member><member>user-network-segment</member></static>" &

    # Create Internal Network Servers Address Group
    action "set" "Internal Network Servers Address Group" "$addr_group_xpath[@name='internal-network-servers']" "<static><member>docker-remote</member><member>debian-dns-ntp</member></static>" &

    # Create Internal Network Servers NAT Address Group
    action "set" "Internal Network Servers NAT Address Group" "$addr_group_xpath[@name='internal-network-servers-nat']" "<static><member>docker-remote-nat</member><member>debian-dns-ntp-nat</member></static>" &

    # Create User Network Servers Address Group
    action "set" "User Network Servers Address Group" "$addr_group_xpath[@name='user-network-servers']" "<static><member>ubuntu-web</member><member>windows-server-2019</member></static>" &

    # Create User Network Servers NAT Address Group
    action "set" "User Network Servers NAT Address Group" "$addr_group_xpath[@name='user-network-servers-nat']" "<static><member>ubuntu-web-nat</member><member>windows-server-2019-nat</member></static>" &

    # Create Public Network Servers Address Group
    action "set" "Public Network Servers Address Group" "$addr_group_xpath[@name='public-network-servers']" "<static><member>splunk</member><member>centos-ecomm</member><member>fedora-webmail</member></static>" &

    # Create Public Network Servers NAT Address Group
    action "set" "Public Network Servers NAT Address Group" "$addr_group_xpath[@name='public-network-servers-nat']" "<static><member>splunk-nat</member><member>centos-ecomm-nat</member><member>fedora-webmail-nat</member></static>" &

    # Create DNS Servers Address Group
    action "set" "DNS Servers Address Group" "$addr_group_xpath[@name='dns-servers']" "<static><member>debian-dns-ntp</member><member>windows-server-2019</member></static>" &

    # Create DNS Servers NAT Address Group
    action "set" "DNS Servers NAT Address Group" "$addr_group_xpath[@name='dns-servers-nat']" "<static><member>debian-dns-ntp-nat</member><member>windows-server-2019-nat</member></static>" &

    # Create NTP Servers Address Group
    action "set" "NTP Servers Address Group" "$addr_group_xpath[@name='ntp-servers']" "<static><member>debian-dns-ntp</member></static>" &

    # Create NTP Servers NAT Address Group 
    action "set" "NTP Servers NAT Address Group" "$addr_group_xpath[@name='ntp-servers-nat']" "<static><member>debian-dns-ntp-nat</member></static>" &

    # Wait to complete the function until the actions are done
    wait
}

# END FUNCTIONS

## CONFIG CHECKS

# From ekurc, check for repository security (perms set correctly to 0750)
check_security

# Superuser requirement.
if [ "$EUID" -ne 0 ]
then error "This script must be ran as root!"
    exit 1
fi

# Check for the correct number of arguments
if [ "$#" -gt 0 ]
then error $usage
    exit 1
fi

# Check for default team number
if [ "$team_number" -eq 0 ]
then error "Team number cannot be set to default!"
    exit 1
fi

# Check for default password
if [ "$password" == "1234" ]
then error "Password cannot be set to default!"
    exit 1
fi

# Display current vars to the user
warn "Ensure all variables are set correctly!\nHost: $host\nManagement Subnet: $management_subnet\nUser: $user\nPassword: $password\nTeam Number: $team_number\nThird Octet: $third_octet\nDevice: $pan_device\nVirtual System: $pan_vsys\n\nProceed running script? (continue with any key or 'n' to quit)\n"
read -n 1 -s yn
if [ "$yn" == "n" ]
then
    error "User quit!"
    exit 1
else
    info "Continuing!"
fi

# Prompt user input to change PA admin password
while : ; do
    printf "\n"
    read -s -p "Enter new password to change Palo Alto Default: " new_password

    # Check if the password meets the requirements
    if [[ ${#new_password} -lt 8 ]]; then
        printf "\nPassword must be at least 8 characters long."
        continue
    elif [[ ! "$new_password" =~ [A-Z] ]]; then
        printf "\nPassword must contain at least one uppercase letter."
        continue
    elif [[ ! "$new_password" =~ [a-z] ]]; then
        printf "\nPassword must contain at least one lowercase letter."
        continue
    elif [[ ! "$new_password" =~ [0-9\W] ]]; then
        printf "\nPassword must contain at least one number or special character."
        continue
    fi

    printf "\n"

    read -s -p "Confirm new password: " confirm_password

    # Check if passwords match
    if [[ $new_password != $confirm_password ]]; then
        echo "Passwords did not match."
        continue
    fi

    # All checks pass, break loop
    break
done

## END CONFIG CHECKS

# Grab API Key
api_key=$(curl --insecure --silent --request GET "$api?type=keygen&user=$user&password=$password" | xpath -q -e '/response/result/key/text()')
header="X-PAN-KEY: $api_key"

# Grab list of users from Palo Alto
user_list=$(curl --insecure --silent --request GET --header "$header" "$api?type=config&action=get&xpath=/config/mgt-config/users" | xpath -q -e '//entry/@name') # Get admin users from palo alto

# Parse the xml and put the names into an array
readarray -t usernames <<< "$(echo $user_list | sed -e 's/name="\([^"]*\)"/\1\n/g')"

# For each username except for 'admin', delete that user.
for username in "${usernames[@]}"
do
    if [ "$username" != "admin" ]
    then
        # Strip username of whitespace
        username=$(echo $username | xargs)
        action "delete" "Management User '$username'" "/config/mgt-config/users/entry[@name='$username']" &
    fi
done

mgmt_profile_pid_array=()

# Create Allow-Ping Management Profile
action "set" "Allow-Ping Management Profile" "$mgmt_profile_xpath[@name='Allow-Ping']" "<permitted-ip><entry name=\"172.20.240.0/24\"/><entry name=\"172.20.241.0/24\"/></permitted-ip><http>yes</http>" & mgmt_profile_pid_array+=($!)

# Create Allow-HTTPS-Ping Management Profile
action "set" "Allow-HTTPS-Ping Management Profile" "$mgmt_profile_xpath[@name='Allow-HTTPS-Ping']" "<permitted-ip><entry name=\"172.20.242.0/24\"/></permitted-ip><ping>yes</ping><https>yes</https>" & mgmt_profile_pid_array+=($!)

# Create Nothing Management Profile
action "set" "Nothing Management Profile" "$mgmt_profile_xpath[@name='Nothing']" "<ping>no</ping>" & mgmt_profile_pid_array+=($!)

# Configure the interfaces with the correct management profiles
waits "${mgmt_profile_pid_array}" configure_interfaces &

# Create Web Traffic Application Group
action "set" "Web Traffic Application Group" "$app_group_xpath[@name='web-traffic']" "<members><member>web-browsing</member><member>ssl</member><member>git</member><member>github</member></members>" &

# Create Windows Updates Application Group
action "set" "Windows Updates Application Group" "$app_group_xpath[@name='windows-updates']" "<members><member>ms-update</member></members>" &

# Create Linux Updates Application Group
action "set" "Linux Updates Application Group" "$app_group_xpath[@name='linux-updates']" "<members><member>apt-get</member><member>yum</member></members>" &

action "set" "Webmail Application Group" "$app_group_xpath[@name='webmail']" "<members><member>smtp</member><member>pop3</member></members>" &

# Create ICMP-Ping Application Group
# TODO: Removed ipv6-icmp
action "set" "ICMP-Ping Application Group" "$app_group_xpath[@name='icmp-ping']" "<members><member>icmp</member><member>ping</member></members>" &

# Create Active Directory Application Group
action "set" "Active Directory Application Group" "$app_group_xpath[@name='windows-active-directory']" "<members><member>active-directory</member><member>ldap</member><member>ms-ds-smb</member><member>kerberos</member></members>" &


# Create Zone Tags
action "set" "External Zone Tag" "$tag_object_xpath[@name='External']" "<color>color14</color><comments>The External zone (ethernet1/3)</comments>" &
action "set" "Public Zone Tag" "$tag_object_xpath[@name='Public']" "<color>color24</color><comments>The Public zone (ethernet1/1)</comments>" & 
action "set" "User Zone Tag" "$tag_object_xpath[@name='User']" "<color>color1</color><comments>The User zone (ethernet1/4)</comments>" & 
action "set" "Internal Zone Tag" "$tag_object_xpath[@name='Internal']" "<color>color13</color><comments>The Internal zone (ethernet1/2)</comments>" & 

address_object_pid_array=()

# Create Placeholder Address Object
action "set" "Placeholder Address Object" "$addr_object_xpath[@name='placeholder']" "<ip-netmask>169.254.74.75/32</ip-netmask><description>Placeholder APIPA address for the blacklist group</description>" & address_object_pid_array+=($!)

# Create Public Network Segment Address Object
action "set" "Public Network Segment Address Object" "$addr_object_xpath[@name='public-network-segment']" "<ip-netmask>172.20.241.0/24</ip-netmask><description>The public subnet</description>" & address_object_pid_array+=($!)

# Create Internal Network Segment Address Object
action "set" "Internal Network Segment Address Object" "$addr_object_xpath[@name='internal-network-segment']" "<ip-netmask>172.20.240.0/24</ip-netmask><description>The internal subnet</description>" & address_object_pid_array+=($!)

# Create User Network Segment Address Object
action "set" "User Network Segment Address Object" "$addr_object_xpath[@name='user-network-segment']" "<ip-netmask>172.20.242.0/24</ip-netmask><description>The user subnet</description>" & address_object_pid_array+=($!)

# Create Public NAT Address Object
action "set" "Public NAT Address Object" "$addr_object_xpath[@name='public-network-nat-address']" "<ip-netmask>172.25.$third_octet.151/24</ip-netmask><description>NAT address for hosts on the public subnet</description>" & address_object_pid_array+=($!)

# Create Internal NAT Address Object
action "set" "Internal NAT Address Object" "$addr_object_xpath[@name='internal-network-nat-address']" "<ip-netmask>172.25.$third_octet.150/24</ip-netmask><description>NAT address for hosts on the internal subnet</description>" & address_object_pid_array+=($!)

# Create User NAT Address Object
action "set" "User NAT Address Object" "$addr_object_xpath[@name='user-network-nat-address']" "<ip-netmask>172.25.$third_octet.152/24</ip-netmask><description>NAT address for hosts on the user subnet</description>" & address_object_pid_array+=($!)

# Create 2019 Docker/Remote Address Object
action "set" "2019 Docker/Remote Address Object" "$addr_object_xpath[@name='docker-remote']" "<ip-netmask>172.20.240.10/24</ip-netmask><description>Private IPv4 address for the '2019 Docker/Remote' server</description>" & address_object_pid_array+=($!)

# Create 2019 Docker/Remote NAT Address Object
action "set" "2019 Docker/Remote NAT Address Object" "$addr_object_xpath[@name='docker-remote-nat']" "<ip-netmask>172.25.$third_octet.97/24</ip-netmask><description>NAT IPv4 address for the '2019 Docker/Remote' server</description>" & address_object_pid_array+=($!)

# Create Debian 10 DNS/NTP Address Object
action "set" "Debian 10 DNS/NTP Address Object" "$addr_object_xpath[@name='debian-dns-ntp']" "<ip-netmask>172.20.240.20/24</ip-netmask><description>IPv4 address for the 'Debian 10 DNS/NTP' server</description>" & address_object_pid_array+=($!)

# Create Debian 10 DNS/NTP NAT Address Object
action "set" "Debian 10 DNS/NTP NAT Address Object" "$addr_object_xpath[@name='debian-dns-ntp-nat']" "<ip-netmask>172.25.$third_octet.20/24</ip-netmask><description>NAT IPv4 address for the 'Debian 10 DNS/NTP' server</description>" & address_object_pid_array+=($!)

# Create 2019 AD/DNS/DHCP Address Object
action "set" "2019 AD/DNS/DHCP Address Object" "$addr_object_xpath[@name='windows-server-2019']" "<ip-netmask>172.20.242.200/24</ip-netmask><description>IPv4 address for the 'Windows Server 2019 AD/DNS/DHCP' server</description>" & address_object_pid_array+=($!)

# Create 2019 AD/DNS/DHCP NAT Address Object
action "set" "2019 AD/DNS/DHCP NAT Address Object" "$addr_object_xpath[@name='windows-server-2019-nat']" "<ip-netmask>172.25.$third_octet.27/24</ip-netmask><description>NAT IPv4 address for the 'Windows Server 2019 AD/DNS/DHCP' server</description>" & address_object_pid_array+=($!)

# Create Fedora 21 Webmail/WebApps Address Object
action "set" "Fedora 21 Webmail/WebApps Address Object" "$addr_object_xpath[@name='fedora-webmail']" "<ip-netmask>172.20.241.40/24</ip-netmask><description>IPv4 address for the 'Fedora 21 Webmail/WebApps' server</description>" & address_object_pid_array+=($!)

# Create Fedora 21 Webmail/WebApps NAT Address Object
action "set" "Fedora 21 Webmail/WebApps NAT Address Object" "$addr_object_xpath[@name='fedora-webmail-nat']" "<ip-netmask>172.25.$third_octet.39/24</ip-netmask><description>NAT IPv4 address for the 'Fedora 21 Webmail/WebApps' server</description>" & address_object_pid_array+=($!)

# Create Splunk 9.1.1 Address Object
action "set" "Splunk 9.1.1 Address Object" "$addr_object_xpath[@name='splunk']" "<ip-netmask>172.20.241.20/24</ip-netmask><description>IPv4 address for the 'Splunk 9.1.1' server</description>" & address_object_pid_array+=($!)

# Create Splunk 9.1.1 NAT Address Object
action "set" "Splunk 9.1.1 NAT Address Object" "$addr_object_xpath[@name='splunk-nat']" "<ip-netmask>172.25.$third_octet.9/24</ip-netmask><description>NAT IPv4 address for the 'Splunk 9.1.1' server</description>" & address_object_pid_array+=($!)

# Create Ubuntu 18 Webserver Address Object
action "set" "Ubuntu 18 Webserver Address Object" "$addr_object_xpath[@name='ubuntu-web']" "<ip-netmask>172.20.242.10/24</ip-netmask><description>IPv4 address for the 'Ubuntu 18 Web' server</description>" & address_object_pid_array+=($!)

# Create Ubuntu 18 Webserver NAT Address Object
action "set" "Ubuntu 18 Webserver NAT Address Object" "$addr_object_xpath[@name='ubuntu-web-nat']" "<ip-netmask>172.25.$third_octet.23/24</ip-netmask><description>NAT IPv4 address for the 'Ubuntu 18 Web' server</description>" & address_object_pid_array+=($!)

# Create CentOS 7 E-Commerce Address Object
action "set" "CentOS 7 E-Commerce Address Object" "$addr_object_xpath[@name='centos-ecomm']" "<ip-netmask>172.20.241.30/24</ip-netmask><description>IPv4 Address for the 'CentOS 7 E-Commerce' server</description>" & address_object_pid_array+=($!)

# Create CentOS 7 E-Commerce NAT Address Object
action "set" "CentOS 7 E-Commerce NAT Address Object" "$addr_object_xpath[@name='centos-ecomm-nat']" "<ip-netmask>172.25.$third_octet.11/24</ip-netmask><description>NAT IPv4 Address for the 'CentOS 7 E-Commerce' server</description>" & address_object_pid_array+=($!)

# Wait for all objects to be created before attempting to assign them to groups
waits "${address_object_pid_array}" create_address_groups & address_groups_pid=$!

splunk_service_pid_array=()

# Create Splunk 'Web Service' Object
action "set" "Splunk 'Web Service' Object" "$srvc_object_xpath[@name='splunk-web-service']" "<protocol><tcp><port>8000</port><override><no/></override></tcp></protocol><description>Splunk Web UI Service</description>" & splunk_service_pid_array+=($!)

# Create Splunk 'Management Service' Object
action "set" "Splunk 'Management Service' Object" "$srvc_object_xpath[@name='splunk-management-service']" "<protocol><tcp><port>8089</port><override><no/></override></tcp></protocol><description>Splunk Management Service</description>" & splunk_service_pid_array+=($!)

# Create Splunk 'Indexing Service' Object
action "set" "Splunk 'Indexing Service' Object" "$srvc_object_xpath[@name='splunk-indexing-service']" "<protocol><tcp><port>9997</port><override><no/></override></tcp></protocol><description>Splunk Indexing Service</description>" & splunk_service_pid_array+=($!)

# Create Splunk 'Index Replication Service' Object
action "set" "Splunk 'Index Replication Service' Object" "$srvc_object_xpath[@name='splunk-index-replication-service']" "<protocol><tcp><port>8080</port><override><no/></override></tcp></protocol><description>Splunk Index Replication Service</description>" & splunk_service_pid_array+=($!)

# Create Splunk 'Syslog Service' Object
action "set" "Splunk 'Syslog Service' Object" "$srvc_object_xpath[@name='splunk-syslog-service']" "<protocol><tcp><port>514</port><override><no/></override></tcp></protocol><description>Splunk Syslog Service</description>" & splunk_service_pid_array+=($!)

# Create Splunk Services Group after the Splunk service objects have been created
waits "${splunk_service_pid_array}" action "set" "Splunk Services Group" "$srvc_group_xpath[@name='splunk-services']" "<members><member>splunk-web-service</member><member>splunk-management-service</member><member>splunk-indexing-service</member><member>splunk-index-replication-service</member><member>splunk-syslog-service</member></members>" &

# Create Splunk Syslog Profile
action "set" "Splunk Syslog Profile" "/config/shared/log-settings/syslog/entry[@name='syslog-server-profile']" "<server><entry name=\"splunk-server\"><transport>TCP</transport><port>1738</port><format>BSD</format><server>172.20.241.20</server><facility>LOG_USER</facility></entry></server>" & syslog_profile_pid=$!

# Create Splunk Log Forwarding Profile after the Splunk syslog profile has been created

# Wait for the syslog profile PID to complete before setting the Splunk log forwarding profile
while [ -e "/proc/$syslog_profile_pid" ]; do
    sleep 0.1
done

# Create Splunk Log Forwarding Profile after the Splunk syslog profile has been created
action "set" "Splunk Log Forwarding Profile" "$log_profiles_xpath[@name='Splunk']" "
<match-list>
    <entry name=\"syslog-traffic\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all traffic logs and forward using syslog</action-desc>
        <log-type>traffic</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-auth\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all auth logs and forward using syslog</action-desc>
        <log-type>auth</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-data\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all data logs and forward using syslog</action-desc>
        <log-type>data</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-decryption\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all decryption logs and forward using syslog</action-desc>
        <log-type>decryption</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-threat\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all threat logs and forward using syslog</action-desc>
        <log-type>threat</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-tunnel\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all tunnel logs and forward using syslog</action-desc>
        <log-type>tunnel</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-url\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all URL logs and forward using syslog</action-desc>
        <log-type>url</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
    <entry name=\"syslog-wildfire\">
        <send-syslog><member>syslog-server-profile</member></send-syslog>
        <action-desc>Match all WildFire logs and forward using syslog</action-desc>
        <log-type>wildfire</log-type>
        <filter>All Logs</filter>
        <send-to-panorama>no</send-to-panorama>
        <quarantine>no</quarantine>
    </entry>
</match-list>
<description>Log profile for Splunk forwarding</description>" & log_forwarding_pid=$!

# Edit Device Default Service Routes
action "edit" "Service Route Configuration" "$srvc_route_xpath" "<route><service><entry name=\"deployments\"><source><address>172.31.$third_octet.2/29</address><interface>ethernet1/3</interface></source></entry><entry name=\"edl-updates\"><source><address>172.31.$third_octet.2/29</address><interface>ethernet1/3</interface></source></entry><entry name=\"paloalto-networks-services\"><source><address>172.31.$third_octet.2/29</address><interface>ethernet1/3</interface></source></entry><entry name=\"syslog\"><source><address>172.20.241.254/24</address><interface>ethernet1/1</interface></source></entry></service></route>" &

# Delete Default Security Policies
action "delete" "Security Policy 'any2any'" "$sec_policy_xpath[@name='any2any']" &
action "delete" "Security Policy 'PUBLIC2INTERNAL'" "$sec_policy_xpath[@name='PUBLIC2INTERNAL']" &
action "delete" "Security Policy 'PUBLIC2EXTERNAL'" "$sec_policy_xpath[@name='PUBLIC2EXTERNAL']" &
action "delete" "Security Policy 'INTERNAL2PUBLIC'" "$sec_policy_xpath[@name='INTERNAL2PUBLIC']" &

# Reconfigure Interzone Default Security Policy after Splunk Log Forwarding Profile
while [ -e "/proc/$log_forwarding_pid" ]; do
    sleep 0.1;
done

action "edit" "Interzone-Default Security Policy" "$dsec_policy_xpath[@name='interzone-default']" "<entry uuid=\"22222222-2222-2222-2222-222222222222\" name=\"interzone-default\"><action>drop</action><log-start>no</log-start><log-end>yes</log-end><icmp-unreachable>yes</icmp-unreachable><log-setting>Splunk</log-setting></entry>" &

# Create Security Policy Rules after address groups have been created
while [ -e "/proc/$address_groups_pid" ] || [ -e "/proc/$log_forwarding_pid" ]; do
    sleep 0.1;
done

create_security_policies & security_policy_pid=$!

while [ -e "/proc/$security_policy_pid" ]; do
    sleep 0.1;
done

# DOS Protection

# Make DoS protection profile object
action "set" "DoS Protection" "$full_xpath/profiles/dos-protection/entry[@name='DoS-Protection']" "
<flood>
  <tcp-syn>
    <red>
      <block><duration>7200</duration></block>
      <alarm-rate>10000</alarm-rate>
      <activate-rate>10000</activate-rate>
      <maximal-rate>40000</maximal-rate>
    </red>
    <enable>yes</enable>
  </tcp-syn>
  <udp>
    <red>
      <block><duration>7200</duration></block>
      <alarm-rate>10000</alarm-rate>
      <activate-rate>10000</activate-rate>
      <maximal-rate>40000</maximal-rate>
    </red>
    <enable>yes</enable>
  </udp>
  <icmp>
    <red>
      <block><duration>7200</duration></block>
      <alarm-rate>10000</alarm-rate>
      <activate-rate>10000</activate-rate>
      <maximal-rate>40000</maximal-rate>
    </red>
    <enable>yes</enable>
  </icmp>
  <icmpv6>
    <red>
      <block><duration>7200</duration></block>
      <alarm-rate>10000</alarm-rate>
      <activate-rate>10000</activate-rate>
      <maximal-rate>40000</maximal-rate>
    </red>
    <enable>yes</enable>
  </icmpv6>
  <other-ip>
    <red>
      <block><duration>7200</duration></block>
      <alarm-rate>10000</alarm-rate>
      <activate-rate>10000</activate-rate>
      <maximal-rate>40000</maximal-rate>
    </red>
    <enable>yes</enable>
  </other-ip>
</flood>
<resource>
  <sessions><enabled>yes</enabled></sessions>
</resource>
<type>classified</type>
"

# Create DOS Policy
action "set" "dos" "$full_xpath/rulebase/dos/rules/entry[@name='dos']" "
<from><zone><member>External</member></zone></from>
<to><zone><member>Internal</member><member>Public</member><member>User</member></zone></to>
<protection>
  <classified>
    <classification-criteria><address>destination-ip-only</address></classification-criteria>
    <profile>DoS-Protection</profile>
  </classified>
</protection>
<source><member>any</member></source>
<destination><member>any</member></destination>
<source-user><member>any</member></source-user>
<service><member>any</member></service>
<action><protect/></action>
"

# Create anti-spyware profile
action "set" "anti-spy" "$full_xpath/profiles/spyware/entry[@name='anti-spy']" '
<botnet-domains>
  <lists>
    <entry name="default-paloalto-dns">
      <action><sinkhole/></action>
      <packet-capture>disable</packet-capture>
    </entry>
  </lists>
  <dns-security-categories>
    <entry name="pan-dns-sec-adtracking"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-cc"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-ddns"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-grayware"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-malware"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-parked"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-phishing"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-proxy"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
    <entry name="pan-dns-sec-recent"><log-level>default</log-level><action>default</action><packet-capture>disable</packet-capture></entry>
  </dns-security-categories>
  <sinkhole>
    <ipv4-address>pan-sinkhole-default-ip</ipv4-address>
    <ipv6-address>::1</ipv6-address>
  </sinkhole>
</botnet-domains>
<rules>
  <entry name="no-spy-alert"><action><alert/></action><severity><member>any</member></severity><threat-name>any</threat-name><category>any</category><packet-capture>extended-capture</packet-capture></entry>
  <entry name="no-spy-drop"><action><drop/></action><severity><member>any</member></severity><threat-name>any</threat-name><category>any</category><packet-capture>extended-capture</packet-capture></entry>
</rules>
<threat-exception><entry name="14984"><action><default/></action></entry></threat-exception>
<mica-engine-spyware-enabled>
  <entry name="HTTP Command and Control detector"><inline-policy-action>alert</inline-policy-action></entry>
  <entry name="HTTP2 Command and Control detector"><inline-policy-action>alert</inline-policy-action></entry>
  <entry name="SSL Command and Control detector"><inline-policy-action>alert</inline-policy-action></entry>
  <entry name="Unknown-TCP Command and Control detector"><inline-policy-action>alert</inline-policy-action></entry>
  <entry name="Unknown-UDP Command and Control detector"><inline-policy-action>alert</inline-policy-action></entry>
</mica-engine-spyware-enabled>
'

# DLP configuration object
action "set" "DLP-Object" "$full_xpath/profiles/data-objects/entry[@name='Confidential']" '
<pattern-type>
  <file-properties>
    <pattern>
      <entry name="Offical-Docs"><file-type>pdf</file-type><file-property>panav-rsp-pdf-dlp-keywords</file-property><property-value>Confidential</property-value></entry>
      <entry name="Office-Docs"><file-type>docx</file-type><file-property>panav-rsp-office-dlp-keywords</file-property><property-value>office</property-value></entry>
    </pattern>
  </file-properties>
</pattern-type>
'

# DLP data-filtering profile
action "set" "DLP-Profile" "$full_xpath/profiles/data-filtering/entry[@name='outbound-dlp-for-offical-docs']" '
<rules>
  <entry name="rule0">
    <application><member>any</member></application>
    <file-type><member>xlsx</member><member>xls</member><member>pptx</member><member>ppt</member><member>docx</member><member>doc</member><member>pdf</member></file-type>
    <direction>both</direction>
    <alert-threshold>1</alert-threshold>
    <block-threshold>1</block-threshold>
    <data-object>Confidential</data-object>
    <log-severity>critical</log-severity>
  </entry>
</rules>
<data-capture>yes</data-capture>
'

# IPS configuration
action "set" "Big-Boy IPS" "$full_xpath/profiles/vulnerability/entry[@name='IPS']" '
<rules>
  <entry name="alert"><action><alert/></action><vendor-id><member>any</member></vendor-id><severity><member>any</member></severity><cve><member>any</member></cve><threat-name>any</threat-name><host>any</host><category>any</category><packet-capture>extended-capture</packet-capture></entry>
  <entry name="drop"><action><drop/></action><vendor-id><member>any</member></vendor-id><severity><member>any</member></severity><cve><member>any</member></cve><threat-name>any</threat-name><host>any</host><category>any</category><packet-capture>extended-capture</packet-capture></entry>
</rules>
<threat-exception><entry name="93031"><action><default/></action></entry></threat-exception>
<mica-engine-vulnerability-enabled>
  <entry name="SQL Injection"><inline-policy-action>alert</inline-policy-action></entry>
  <entry name="Command Injection"><inline-policy-action>alert</inline-policy-action></entry>
</mica-engine-vulnerability-enabled>
'

action "set" "Url filter" "$full_xpath/profiles/url-filtering/entry[@name='url-filter']" '
<credential-enforcement>
  <mode><disabled/></mode>
  <log-severity>medium</log-severity>
  <block>
    <member>abortion</member>
    <member>abused-drugs</member>
    <member>adult</member>
    <member>alcohol-and-tobacco</member>
    <member>command-and-control</member>
    <member>dating</member>
    <member>extremism</member>
    <member>games</member>
    <member>grayware</member>
    <member>hacking</member>
    <member>high-risk</member>
    <member>insufficient-content</member>
    <member>nudity</member>
    <member>phishing</member>
    <member>sex-education</member>
    <member>social-networking</member>
    <member>swimsuits-and-intimate-apparel</member>
    <member>weapons</member>
  </block>
</credential-enforcement>
<log-http-hdr-xff>yes</log-http-hdr-xff>
<log-http-hdr-user-agent>yes</log-http-hdr-user-agent>
<log-http-hdr-referer>yes</log-http-hdr-referer>
<block>
  <member>abortion</member>
  <member>abused-drugs</member>
  <member>adult</member>
  <member>alcohol-and-tobacco</member>
  <member>command-and-control</member>
  <member>dating</member>
  <member>extremism</member>
  <member>games</member>
  <member>grayware</member>
  <member>hacking</member>
  <member>high-risk</member>
  <member>insufficient-content</member>
  <member>nudity</member>
  <member>phishing</member>
  <member>sex-education</member>
  <member>social-networking</member>
  <member>swimsuits-and-intimate-apparel</member>
  <member>weapons</member>
</block>
'

# Grab hash of user-entered password
hash=$(curl --insecure --silent --request GET --header "$header" "$api?type=op&cmd=<request><password-hash><password>$new_password</password></password-hash></request>&key=$api_key" | xmllint --xpath 'string(//phash)' -)

# Using hashed password, change Palo Alto admin password
action "edit" "Change Admin Password" "/config/mgt-config/users/entry[@name='admin']/phash" "<phash>$hash</phash>"

commit "Final commit"

# Kill All Admin Sessions
action "op" "Delete Admin Sessions" "<delete><admin-sessions></admin-sessions></delete>&key=$api_key"

success "Script Complete!"

exit 0