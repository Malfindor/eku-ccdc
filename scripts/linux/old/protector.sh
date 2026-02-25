#!/bin/bash

# Author: <author(s)>
# script_name.sh
#
# Description: A template for bash scripts created by Raven Dean. NOTE that there are special
#  commands in ../../config_files/ekurc to output log messages to the terminal. These include
#  info, debug, warn, error, and success.
#
# Dependencies: N/A
# Created: MM/DD/YYYY
# Usage: <./script_name.sh <args>>

# Edit these as required.
script_name="script_name.sh"
usage="./$script_name <args>"

# Get the path of the repository root
repo_root=$(git rev-parse --show-toplevel)

# Check repository security requirement
check_security

# Import environment variables
. $repo_root/config_files/ekurc

if [ "$EUID" -ne 0 ] # Superuser requirement.
then error "This script must be ran as root!"
    exit 1
fi

# Check for the correct number of arguments
if [ "$#" -lt 1 ]
then error $usage
    exit 1
fi

# Main script here...


# Example logging message functions
info "Send a general information message to stdout."
debug "Send a debug message to stdout."
warn "Send a warning message to stdout."
error "Send an error message to stderr."
success "Send a success message to stdout."

exit 0 # Script ended successfully

