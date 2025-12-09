#!/bin/bash

# System update and upgrade script with user prompts
# Safely updates repositories, upgrades packages, and cleans up unused packages

set -e  # Exit on error

# Enable case-insensitive matching for user inputs
shopt -s nocasematch

# Checking if script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root."
    exit 1
fi

# Display the current sources list
echo "=================================="
echo "System Update Script"
echo "=================================="
echo
echo "Current sources list:"
cat /etc/apt/sources.list 2>/dev/null || echo "Could not read sources.list"
echo

# Function to prompt user for confirmation and execute a command if confirmed
prompt_and_execute() {
    local message="$1"
    local command="$2"
    local input

    while true; do
        read -p "$message (y/n): " input

        case "$input" in
            y|Y|yes|Yes|YES)
                echo "Executing: $command"
                if $command; then
                    echo "Success!"
                else
                    echo "ERROR: Command failed with exit code $?"
                    return 1
                fi
                return 0
                ;;
            n|N|no|No|NO)
                echo "Skipping..."
                return 0
                ;;
            *)
                echo "Invalid input. Please enter 'y' or 'n'."
                ;;
        esac
    done
}

# Check if you want to update repos
echo
prompt_and_execute "Do you want to update the repositories?" "apt-get update"

# Check if you want to upgrade packages
echo
prompt_and_execute "Do you want to upgrade installed packages?" "apt-get upgrade -y"

# Check if you want to perform a distribution upgrade
echo
prompt_and_execute "Do you want to perform a distribution upgrade?" "apt-get dist-upgrade -y"

# Checking if you want to remove unused packages
echo
prompt_and_execute "Do you want to auto-remove unused packages?" "apt-get autoremove -y"

# Check if you want to clean apt cache
echo
prompt_and_execute "Do you want to clean apt cache?" "apt-get clean"

echo
echo "=================================="
echo "Update process completed!"
echo "=================================="
