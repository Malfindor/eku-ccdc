#!/bin/bash

# Author: Raven Dean
# prestashop.sh
#
# Description: Script to harden weak installs of prestashop.
#
# Dependencies: $repo_root/config_files/ekurc
# Created: 02/06/2024
# Usage: <./prestashop.sh>

# Edit these as required.
script_name="prestashop.sh"
usage="./$script_name"

# Get the path of the repository root
repo_root=$(git rev-parse --show-toplevel)

# Import environment variables
. $repo_root/config_files/ekurc

# Check repository security requirement
check_security

if [ "$EUID" -ne 0 ] # Superuser requirement. Echo the error to stderr and return exit code 1.
then error "This script must be ran as root!"
    exit 1
fi

# Check for the correct number of arguments
if [ "$EUID" -gt 0 ]
then error $usage
    exit 1
fi

# Secure the mysql installation
query="CREATE USER 'sysadmin'@'localhost' IDENTIFIED BY '$prestashop_new_db_user_password';"
info "Creating new DB user"
mysql -u"root" -e"$query" --verbose

info "Granting perms to new user"
query="GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, ALTER, INDEX, LOCK TABLES ON prestashop.* TO 'sysadmin'@'localhost'; FLUSH PRIVILEGES;"
mysql -u"root" -e"$query" --verbose

info "Starting the MySQL secure installation script..."
mysql_secure_installation

# The password of prestashop users is salted with the cookie key. Save the cookie key to a variable and change the password.
key_path="/var/www/html/prestashop/config/settings.inc.php"
key="$(cat $key_path | grep "_COOKIE_KEY_" | cut -d ',' -f2 | tr -d " ,');")"
query="UPDATE ps_employee SET passwd = MD5('$key$prestashop_admin_password') WHERE firstname = 'Greg';"

info "Resetting prestashop DB_USER and DB_PASSWD"
sed -i "/_DB_USER_/c\define('_DB_USER_', 'sysadmin');" $key_path
sed -i "/_DB_PASSWD_/c\define('_DB_PASSWD_', '$prestashop_new_db_user_password');" $key_path

info "Changing prestashop admin password"
mysql -u"sysadmin" -p"$prestashop_new_db_user_password" -D"prestashop" -e"$query" --verbose

prestashop_dir="/var/www/html/prestashop"
info "Fixing file permissions"
find $prestashop_dir -type f -exec chmod 644 -- {} +
find $prestashop_dir -type d -exec chmod 755 -- {} +

info "Remove dangerous files and folders"
mv $prestashop_dir/admin3258 $prestashop_dir/.131011
rm -rf $prestashop_dir/install.tar $prestashop_dir/install_bkp $prestashop_dir/docs $prestashop_dir/README.md

exit 0 # Script ended successfully

