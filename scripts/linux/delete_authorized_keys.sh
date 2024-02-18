#!/bin/bash

# Author: Raven Dean
# delete_authorized_keys.sh
#
# Description: A bash script for scanning a system and removing any ~/.ssh/authorized_keys that it finds. Asks for user confirmation to delete.
#
# Dependencies: N/A
# Created: MM/DD/YYYY
# Usage: <./script_name.sh <args>>

# Edit these as required.
script_name="script_name.sh"
usage="./$script_name <args>"

# Import environment variables
. ../../config_files/ekurc

if [ "$EUID" -ne 0 ] # Superuser requirement.
then error "This script must be ran as root!"
    exit 1
fi

# Check for the correct number of arguments
if [ "$#" -lt 1 ]
then error $usage
    exit 1
fi

# Check repository security requirement
check_security

# Main script here...



# Example logging message functions
info "Send a general information message to stdout."
debug "Send a debug message to stdout."
warn "Send a warning message to stdout."
error "Send an error message to stderr."
success "Send a success message to stdout."

exit 0 # Script ended successfully

