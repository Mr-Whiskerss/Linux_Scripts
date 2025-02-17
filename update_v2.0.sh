#!/bin/bash

# Enable case-insensitive matching for user inputs
shopt -s nocasematch

# Checking if script is running at root.
if [ "$EUID" -ne 0 ]; then
    echo "Please run as root."
    exit 1
fi

# Display the current sources list
echo "Current sources list:"
cat /etc/apt/sources.list
echo

# Function to prompt user for confirmation and execute a command if confirmed
prompt_and_execute() {
    local message="$1"
    local command="$2"

    echo "$message (Y/N)"
    read input

    if [[ "$input" == *"y"* ]]; then
        eval "$command"
    elif [[ "$input" == *"n"* ]]; then
        echo "Skipping..."
    else
        echo "Invalid input. Please enter Y or N."
    fi
}

# Check if you want to update repos
prompt_and_execute "Do you want to update the repositories?" "apt update"

# Check if you want to upgrade packages
prompt_and_execute "Do you want to upgrade installed packages?" "apt -y upgrade"

# Check if you want to perform a distribution upgrade
prompt_and_execute "Do you want to perform a distribution upgrade?" "apt -y dist-upgrade"

# Checking if you want to remove unused packages
prompt_and_execute "Do you want to auto-remove unused packages?" "apt-get -y autoremove"

echo "Update process completed."
