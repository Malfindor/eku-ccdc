#!/bin/bash
# tyr.sh
# This script monitors files or directories defined in a configuration file.
# It creates necessary directories for configuration, a hidden backup storage (accessible only to root),
# and a log file. If a monitored item is changed or deleted, the script restores it from its backup,
# logs the event, and notifies the user.
#
# Additionally, this script supports mode commands:
#   • mode-update   - Put Tyr into update mode (automatic restoration is disabled),
#                     allowing you to safely modify files.
#   • mode-resume   - Exit update mode, updating backups from current file contents.
#   • help          - Display this help message.
#
# When run without "--daemonized" (and not using a mode or help command), it installs itself:
#   - Copies itself to /etc/Tyr/tyr.sh.
#   - Creates a systemd service file at /etc/systemd/system/tyr.service.
#   - Creates a symlink at /usr/local/bin/Tyr so you can invoke it via the command "Tyr".
#   - Checks for a configuration file in /etc/Tyr/BList.conf.
#       • If not detected, it prompts you to choose your system for a pre-made configuration or to generate a default empty config.
#         The installer searches for preset config files in the local "configs" folder (in the same directory as this script).
#         If a preset is selected and found, it copies that File to /etc/Tyr/BList.conf and deletes all other files in "configs".
#         If the preset is not found or you select "Generate DEfault Empty Config," it creates a default empty config.
#         The default config includes /var/log logging and commeNted-out line that can be uncommented to have Tyr back up its own config.
#   - Reloads systemd, enables, and starts the service.
# Then it exits.
#
# When run with "--daemonized", it runs as the background service using polling exclusively.

#############################
# HELP COMMAND
#############################
if [ "$1" = "help" ]; then
    echo "Tyr - File Protection and Restoration Service"
    echo ""
    echo "Usage:"
    echo "  Tyr [COMMAND]"
    echo ""
    echo "Available Commands (must be run with sudo):"
    echo "  mode-update   : Put Tyr into update mode (disable automatic restoration)"
    echo "  mode-resume   : Resume normal mode and update backups from current file contents"
    echo "  help          : Display this help message"
    echo ""
    echo "Other Usage:"
    echo "  Running 'Tyr' without any command will install Tyr as a system service."
    exit 0
fi

#############################
# MODE COMMANDS
#############################
if [[ "$1" == "mode-update" || "$1" == "mode-resume" ]]; then
    if [ "$EUID" -ne 0 ]; then
        echo "Insufficient permissions. Please run this command with sudo."
        exit 1
    fi
fi

if [ "$1" = "mode-update" ]; then
    touch /var/lib/.tyr_update_mode
    systemctl restart tyr.service
    echo "Tyr is now in update mode (automatic restoration disabled)."
    echo "If the service does not restart automatically, please run: sudo systemctl restart tyr.service"
    exit 0
fi

if [ "$1" = "mode-resume" ]; then
    rm -f /var/lib/.tyr_update_mode
    echo "Tyr is resuming normal mode. Updating backups from current file contents..."
    if [ -f "/etc/Tyr/BList.conf" ]; then
        while IFS= read -r line; do
            trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
            if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
                continue
            fi
            if [[ "$trimmed" == *"="* ]]; then
                IFS="=" read -ra parts <<< "$trimmed"
                file="${parts[1]}"
            else
                file="$trimmed"
            fi
            if [ -e "$file" ]; then
                abs_path=$(realpath "$file")
                rel_path=$(echo "$abs_path" | sed 's|^/||')
                backup_path="/var/lib/.tyr/$rel_path"
                mkdir -p "$(dirname "$backup_path")"
                cp -r "$abs_path" "$backup_path"
                echo "Updated backup for $abs_path"
            fi
        done < /etc/Tyr/BList.conf
    fi
    systemctl restart tyr.service
    echo "Tyr has resumed normal mode. Backups have been updated."
    exit 0
fi

#############################
# AUTO-INSTALLATION (if not daemonized)
#############################
if [ "$1" != "--daemonized" ]; then
    if [ "$EUID" -ne 0 ]; then
        echo "This script must be run as root for auto installation."
        exit 1
    fi

    # Copy the script to /etc/Tyr if not already present.
    if [ ! -f "/etc/Tyr/tyr.sh" ]; then
        mkdir -p /etc/Tyr
        cp "$0" /etc/Tyr/tyr.sh
        chmod +x /etc/Tyr/tyr.sh
        echo "Copied script to /etc/Tyr/tyr.sh"
    else
        echo "Script already installed at /etc/Tyr/tyr.sh"
    fi

    # Determine configuration file to use.
    CONFIG_DEST="/etc/Tyr/BList.conf"
    if [ ! -f "$CONFIG_DEST" ]; then
        echo "No configuration file detected in /etc/Tyr."
        echo "Please select your system for a pre-made configuration or choose to generate a default empty config:"
        echo "1) Debian"
        echo "2) CentOS"
        echo "3) Ubuntu"
        echo "4) Fedora"
        echo "5) Generate Default Empty Config"
        echo "6) Splunk"
        read -p "Enter the number of your system or option: " system_choice
        case $system_choice in
            1)
                CONFIG_FILE_NAME="Debian-BList.conf"
                ;;
            2)
                echo "CentOS selected. Choose configuration type:"
                echo "1) CentOS-Ecomm-BList.conf"
                echo "2) CentOS-Palo-BList.conf"
                echo "3) CentOS-Cisco-BList.conf"
                read -p "Enter 1, 2, or 3: " centos_choice
                case $centos_choice in
                    1)
                        CONFIG_FILE_NAME="CentOS-Ecomm-BList.conf"
                        ;;
                    2)
                        CONFIG_FILE_NAME="CentOS-Palo-BList.conf"
                        ;;
                    3)
                        CONFIG_FILE_NAME="CentOS-Cisco-BList.conf"
                        ;;
                    *)
                        echo "Invalid choice. Defaulting to CentOS-Ecomm-BList.conf."
                        CONFIG_FILE_NAME="CentOS-Ecomm-BList.conf"
                        ;;
                esac
                ;;
            3)
                echo "Ubuntu selected. Choose configuration type:"
                echo "1) Ubuntu-Web-BList.conf"
                echo "2) Ubuntu-Snipe-BList.conf"
                echo "3) Ubuntu-Wkst-BList.conf"
                read -p "Enter 1, 2, or 3: " ubuntu_choice
                case $ubuntu_choice in
                    1)
                        CONFIG_FILE_NAME="Ubuntu-Web-BList.conf"
                        ;;
                    2)
                        CONFIG_FILE_NAME="Ubuntu-Snipe-BList.conf"
                        ;;
                    3)
                        CONFIG_FILE_NAME="Ubuntu-Wkst-BList.conf"
                        ;;
                    *)
                        echo "Invalid choice. Defaulting to Ubuntu-Wkst-BList.conf."
                        CONFIG_FILE_NAME="Ubuntu-Wkst-BList.conf"
                        ;;
                esac
                ;;
            4)
                CONFIG_FILE_NAME="Fedora-BList.conf"
                ;;
            5)
                CONFIG_FILE_NAME=""
                ;;
            6)
                CONFIG_FILE_NAME="Splunk-BList.conf"
                ;;
            *)
                echo "Invalid selection."
                CONFIG_FILE_NAME=""
                ;;
        esac

        SCRIPT_DIR=$(dirname "$0")
        if [ -n "$CONFIG_FILE_NAME" ] && [ -f "$SCRIPT_DIR/configs/$CONFIG_FILE_NAME" ]; then
            sudo cp "$SCRIPT_DIR/configs/$CONFIG_FILE_NAME" "$CONFIG_DEST"
            echo "Copied pre-made configuration $SCRIPT_DIR/configs/$CONFIG_FILE_NAME to /etc/Tyr/BList.conf"
        else
            echo "Config not detected. Creating default empty config file."
            sudo bash -c "cat <<EOF > $CONFIG_DEST
# Empty configuration file for Tyr
# List one file or directory per line. CASE SENSITIVE.
# Lines starting with '#' are ignored.
# Alternatively, you can use key-value format, e.g.:
# PATH=/path/to/file_or_directory
#
# Default entries:
/var/log
# To backup Tyr's own configuration file, uncomment the line below:
# /etc/Tyr/BList.conf
EOF"
        fi
        # Delete all files in the local presets directory.
        sudo rm -f "$SCRIPT_DIR"/configs/*
    fi

    # Create systemd service file if it does not already exist.
    SERVICE_FILE="/etc/systemd/system/tyr.service"
    if [ ! -f "$SERVICE_FILE" ]; then
        sudo bash -c "cat <<EOF > $SERVICE_FILE
[Unit]
Description=Tyr Service - Monitors and restores files from backup if changed or deleted
After=network.target

[Service]
Type=simple
ExecStart=/etc/Tyr/tyr.sh --daemonized
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF"
        echo "Created systemd service file at $SERVICE_FILE"
    else
        echo "Systemd service file already exists at $SERVICE_FILE"
    fi

    # Create a symlink so you can invoke "Tyr" anywhere.
    if [ ! -L "/usr/local/bin/Tyr" ]; then
        sudo ln -s /etc/Tyr/tyr.sh /usr/local/bin/Tyr
        echo "Created symlink /usr/local/bin/Tyr"
    else
        echo "Symlink /usr/local/bin/Tyr already exists."
    fi

    sudo systemctl daemon-reload
    sudo systemctl enable tyr.service
    sudo systemctl start tyr.service

    echo "Tyr service installed and started. Exiting installation."
    echo "PLEASE READ:"
    echo "  - Modify BList.conf in /etc/Tyr/ to suit your needs."
    echo "  - Tyr uses polling-based monitoring to detect file changes, including deletions."
    echo "  - To switch monitoring modes or enter update mode, use the commands:"
    echo "       sudo Tyr mode-update   (to disable automatic restoration)"
    echo "       sudo Tyr mode-resume    (to resume normal operation and update backups)"
    echo "       sudo Tyr help         (to display this help message)"
    exit 0
fi

#############################
# DAEMONIZED SERVICE CODE BELOW
#############################

# Configuration variables
CONFIG_DIR="/etc/Tyr"
CONFIG_FILE="$CONFIG_DIR/BList.conf"        # Config file (plain paths or key-value lines)
BACKUP_DIR="/var/lib/.tyr"                   # Hidden backup folder (accessible only to root)
LOG_FILE="/var/log/tyr.log"                  # Log file for service events
SLEEP_INTERVAL=10                          # Polling interval in seconds

# Replacement tracking thresholds
THRESHOLD_REPLACEMENTS=8
THRESHOLD_TIME=70  # seconds

# Global array for monitored items
files_to_backup=()

# Declare associative arrays (requires Bash 4+)
declare -A replacement_count
declare -A replacement_last_time

#############################
# Logging Functions
#############################
log_event() {
    local msg="$1"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] $msg" >> "$LOG_FILE"
    logger "Tyr: $msg"
}

rotate_log() {
    if [ -f "$LOG_FILE" ]; then
        local ts
        ts=$(date '+%Y-%m-%d_%H-%M-%S')
        mv "$LOG_FILE" "${LOG_FILE}.${ts}"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log file rotated; previous log saved as ${LOG_FILE}.${ts}" >> "$LOG_FILE"
    fi
}

#############################
# Environment Initialization
#############################
init_environment() {
    if [ ! -d "$CONFIG_DIR" ]; then
        sudo mkdir -p "$CONFIG_DIR"
        log_event "Created config directory $CONFIG_DIR"
    else
        log_event "Config directory $CONFIG_DIR already exists."
    fi

    if [ ! -f "$CONFIG_FILE" ]; then
        sudo bash -c "cat <<EOF > $CONFIG_FILE
# Config file for Tyr
# List one file or directory per line. CASE SENSITIVE.
# Lines starting with '#' are ignored.
# Alternatively, you can use key-value format, e.g.:
# PATH=/path/to/file_or_directory
#
# Default entries:
/var/log
# To backup Tyr's own configuration file, uncomment the line below:
# /etc/Tyr/BList.conf
EOF"
        log_event "Created sample config file $CONFIG_FILE. Please edit it with your desired paths."
    else
        log_event "Config file $CONFIG_FILE already exists. Not overwriting."
    fi

    if [ ! -d "$BACKUP_DIR" ]; then
        sudo mkdir -p "$BACKUP_DIR"
        sudo chmod 700 "$BACKUP_DIR"
        log_event "Created hidden backup directory $BACKUP_DIR with permissions 700"
    else
        log_event "Backup directory $BACKUP_DIR already exists. Not overwriting."
    fi

    rotate_log
    if [ ! -f "$LOG_FILE" ]; then
        sudo touch "$LOG_FILE"
        log_event "Created log file $LOG_FILE"
    fi
}

#############################
# Configuration Processing
#############################
processConfFile() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_event "Configuration file $CONFIG_FILE not found!"
        exit 1
    fi

    mapfile -t confList < "$CONFIG_FILE"
    for line in "${confList[@]}"; do
        trimmed=$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        if [[ -z "$trimmed" || "$trimmed" == \#* ]]; then
            continue
        fi
        if [[ "$trimmed" == *"="* ]]; then
            IFS="=" read -ra parts <<< "$trimmed"
            key="${parts[0]}"
            value="${parts[1]}"
            case "$key" in
                PATH)
                    files_to_backup+=("$value")
                    ;;
                *)
                    log_event "Unrecognized config key: $key"
                    ;;
            esac
        else
            files_to_backup+=("$trimmed")
        fi
    done
}

#############################
# Backup and Restore Functions
#############################
backup_item() {
    local item="$1"
    local abs_path
    if [ -e "$item" ]; then
        abs_path=$(realpath "$item")
    else
        abs_path="$item"
    fi
    local rel_path
    rel_path=$(echo "$abs_path" | sed 's|^/||')
    local backup_path="$BACKUP_DIR/$rel_path"
    sudo mkdir -p "$(dirname "$backup_path")"
    cp -r "$abs_path" "$backup_path"
    if [ $? -eq 0 ]; then
        log_event "Created backup for $abs_path"
    else
        log_event "Failed to create backup for $abs_path"
    fi
}

restore_item() {
    local item="$1"
    local abs_path
    if [ -e "$item" ]; then
        abs_path=$(realpath "$item")
    else
        abs_path="$item"
    fi
    local rel_path
    rel_path=$(echo "$abs_path" | sed 's|^/||')
    local backup_path="$BACKUP_DIR/$rel_path"
    if [ -e "$backup_path" ]; then
        cp -r "$backup_path" "$abs_path"
        if [ $? -eq 0 ]; then
            log_event "Restored backup for $abs_path"
            echo "Restored backup for $abs_path"
        else
            log_event "Failed to restore backup for $abs_path"
            echo "Failed to restore backup for $abs_path"
        fi
    else
        log_event "Backup not found for $abs_path"
        echo "Backup not found for $abs_path"
    fi
}

#############################
# Replacement Tracking
#############################
record_replacement() {
    local file="$1"
    local now
    now=$(date +%s)
    local last=${replacement_last_time["$file"]}
    if [[ -z "$last" || $((now - last)) -gt $THRESHOLD_TIME ]]; then
        replacement_count["$file"]=1
        replacement_last_time["$file"]=$now
    else
        replacement_count["$file"]=$((replacement_count["$file"] + 1))
        replacement_last_time["$file"]=$now
    fi
    if [[ ${replacement_count["$file"]} -ge $THRESHOLD_REPLACEMENTS ]]; then
        chattr +i "$file"
        log_event "File $file has been replaced ${replacement_count["$file"]} times within $THRESHOLD_TIME seconds. Marked as immutable."
        replacement_count["$file"]=0
    fi
}

initialize_backups() {
    for item in "${files_to_backup[@]}"; do
        if [ -e "$item" ]; then
            backup_item "$item"
        else
            log_event "Warning: $item does not exist"
        fi
    done
}

#############################
# Check-and-Restore (or Backup-Only) Function
#############################
check_and_restore() {
    local item="$1"
    local abs_path
    if [ -e "$item" ]; then
        abs_path=$(realpath "$item")
    else
        abs_path="$item"
    fi

    # If update mode is active, skip restoration.
    if [ -f "/var/lib/.tyr_update_mode" ]; then
        log_event "Update mode active; skipping restoration for $abs_path"
        return
    fi

    # For items under /var/log, update backup only.
    if [[ "$abs_path" == /var/log* ]]; then
        backup_item "$item"
        return
    fi

    # If the item is missing, attempt restoration.
    if [ ! -e "$item" ]; then
        local rel_path
        rel_path=$(echo "$item" | sed 's|^/||')
        local backup_path="$BACKUP_DIR/$rel_path"
        if [ -e "$backup_path" ]; then
            log_event "Detected deletion of $abs_path. Attempting restoration from backup."
            restore_item "$item"
            if [ $? -ne 0 ]; then
                log_event "Restoration attempt for $abs_path failed."
            fi
            record_replacement "$abs_path"
        else
            log_event "Backup not available for missing file $abs_path"
        fi
        return
    fi

    local rel_path
    rel_path=$(echo "$abs_path" | sed 's|^/||')
    local backup_path="$BACKUP_DIR/$rel_path"
    if [ -e "$backup_path" ]; then
        if [ -f "$abs_path" ]; then
            local orig_md5 backup_md5
            orig_md5=$(md5sum "$abs_path" | awk '{print $1}')
            backup_md5=$(md5sum "$backup_path" | awk '{print $1}')
            if [ "$orig_md5" != "$backup_md5" ]; then
                log_event "Detected change in file $abs_path"
                restore_item "$item"
                record_replacement "$abs_path"
            fi
        elif [ -d "$abs_path" ]; then
            diff -r "$abs_path" "$backup_path" > /dev/null 2>&1
            if [ $? -ne 0 ]; then
                log_event "Detected change in directory $abs_path"
                restore_item "$item"
                record_replacement "$abs_path"
            fi
        fi
    else
        log_event "No backup available for $abs_path"
    fi
}

#############################
# Monitoring Function (Polling Only)
#############################
polling_monitor() {
    while true; do
        log_event "Starting service check cycle (polling)."
        for item in "${files_to_backup[@]}"; do
            check_and_restore "$item"
        done
        log_event "Service check cycle (polling) completed."
        sleep "$SLEEP_INTERVAL"
    done
}

#############################
# Main Execution
#############################
init_environment
processConfFile
initialize_backups

log_event "Tyr service started."

echo "Using polling-based monitoring."
polling_monitor

