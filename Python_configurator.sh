#!/bin/bash

# Python 2 and 3 environment installer and switcher.
# NOTE: Python 2 reached end-of-life on January 1, 2020 and is no longer maintained.
# Use Python 2 only if absolutely necessary for legacy applications.

set -e  # Exit on error

# Checking if script is running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Please run as root"
    exit 1
fi

echo "=================================="
echo "Python Environment Configurator"
echo "=================================="
echo

# Check if Python 3 is installed
if command -v python3 &>/dev/null; then
    echo "Python 3 is already installed:"
    python3 --version
else
    echo "Installing Python 3..."
    apt-get update
    apt-get install -y python3 python3-pip
    python3 --version
fi

echo

# Warn about Python 2
echo "WARNING: Python 2 reached end-of-life in 2020 and is no longer supported."
echo "It is strongly recommended to use Python 3 for all new projects."
read -p "Do you still want to install Python 2? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Check if Python 2 is available in repositories
    if apt-cache show python2 &>/dev/null; then
        echo "Installing Python 2..."
        apt-get install -y python2

        if command -v python2 &>/dev/null; then
            python2 --version
        else
            echo "ERROR: Python 2 installation failed"
            exit 1
        fi
    else
        echo "ERROR: Python 2 is not available in your distribution's repositories."
        echo "Consider using Python 3 or installing Python 2 from source if absolutely necessary."
        exit 1
    fi

    echo
    echo "Creating python alternatives for version switching..."

    # Remove existing alternatives to avoid conflicts
    update-alternatives --remove-all python &>/dev/null || true

    # Creating new executable python packages
    update-alternatives --install /usr/bin/python python /usr/bin/python2 1
    update-alternatives --install /usr/bin/python python /usr/bin/python3 2

    echo
    echo "Python alternatives configured successfully!"
    echo "To switch between Python versions, use: update-alternatives --config python"
    echo
    echo "Current python version:"
    python --version
else
    echo "Skipping Python 2 installation."

    # Set up python to point to python3
    if ! command -v python &>/dev/null; then
        echo "Creating python symlink to python3..."
        update-alternatives --install /usr/bin/python python /usr/bin/python3 1
    fi
fi

echo
echo "Configuration complete!"

