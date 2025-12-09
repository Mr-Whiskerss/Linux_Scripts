#!/bin/bash
# This script sets up essential tools for Linux pentesting and system preparation when on a new build or need to get something up and ready quick. Please run as root.
# Version 4.0

set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Catch errors in pipelines

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_file="/var/log/build_script.log"

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$log_file"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$log_file"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$log_file"
}

log "Welcome to the Build Script v4.0"

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  log_error "Please run this script as root."
  exit 1
fi

log "Root check passed"

# Check if git is installed
if ! command -v git &>/dev/null; then
    log "Git not found, installing..."
    apt-get update
    apt-get install -y git
fi

# Update and upgrade the system
log "==================================="
log "Updating and Upgrading System"
log "==================================="
if apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y; then
    log "System update completed successfully"
else
    log_error "System update failed"
    exit 1
fi

# Install common tools
log "==================================="
log "Installing Common Tools"
log "==================================="
COMMON_TOOLS="htop iftop python3-pip seclists terminator rubygems curl wget"

# Python 2 is EOL, only install if available (might not be in newer distros)
if apt-cache show python2 &>/dev/null; then
    COMMON_TOOLS="$COMMON_TOOLS python2"
    log_warning "Python 2 is deprecated and may not be available in future releases"
fi

if apt-get install -y $COMMON_TOOLS; then
    log "Common tools installed successfully"
else
    log_error "Failed to install some common tools"
    exit 1
fi

# Create tools directory
log "Creating tools directory at /opt/tools"
mkdir -p /opt/tools
cd /opt/tools || exit 1

# Function to clone and check git repositories
git_clone() {
    local repo_url=$1
    local dest_dir
    dest_dir=$(basename "$repo_url" .git)

    if [ ! -d "$dest_dir" ]; then
        log "Cloning $repo_url"
        if git clone --depth 1 "$repo_url" 2>&1 | tee -a "$log_file"; then
            log "Successfully cloned $dest_dir"
            return 0
        else
            log_error "Failed to clone $repo_url"
            return 1
        fi
    else
        log_warning "$dest_dir already exists, skipping clone"
        return 0
    fi
}

# Function to download files safely
download_file() {
    local url=$1
    local filename
    filename=$(basename "$url")

    if [ ! -f "$filename" ]; then
        log "Downloading $filename from $url"
        if wget "$url" -q --show-progress 2>&1 | tee -a "$log_file"; then
            log "Successfully downloaded $filename"
            return 0
        else
            log_error "Failed to download $filename"
            return 1
        fi
    else
        log_warning "$filename already exists, skipping download"
        return 0
    fi
}

# Function to safely install pip packages
pip_install() {
    local package=$1
    log "Installing Python package: $package"
    # Use --break-system-packages for newer systems that require it
    if python3 -m pip install "$package" 2>&1 | tee -a "$log_file"; then
        log "Successfully installed $package"
        return 0
    else
        log_warning "Trying with --break-system-packages flag"
        if python3 -m pip install --break-system-packages "$package" 2>&1 | tee -a "$log_file"; then
            log "Successfully installed $package"
            return 0
        else
            log_error "Failed to install $package"
            return 1
        fi
    fi
}

# Install pentest tools
log "==================================="
log "Installing Pentest Tools"
log "==================================="

# Enum4linux-NG
log "Installing Enum4linux-NG dependencies and tool"
apt-get install -y smbclient python3-ldap3 python3-yaml python3-impacket 2>&1 | tee -a "$log_file" || log_warning "Some enum4linux-ng dependencies may have failed"
git_clone https://github.com/cddmp/enum4linux-ng.git

# Testssl
log "Installing testssl"
git_clone https://github.com/drwetter/testssl.sh.git

# PowerSploit
log "Installing PowerSploit"
git_clone https://github.com/PowerShellMafia/PowerSploit.git

# Impacket (using updated fortra repository)
log "Installing Impacket"
if git_clone https://github.com/fortra/impacket.git; then
    cd impacket || exit 1
    if pip_install .; then
        log "Impacket installed successfully"
    else
        log_error "Impacket installation failed"
    fi
    cd ..
else
    log_error "Failed to clone Impacket repository"
fi

# WinPEAS and LinPEAS (clone repo instead of downloading specific versions)
log "Installing PEASS-ng suite"
if git_clone https://github.com/peass-ng/PEASS-ng.git; then
    log "PEASS-ng cloned - you can find the latest releases in /opt/tools/PEASS-ng"
else
    log_error "Failed to clone PEASS-ng"
fi

# LinEnum
log "Installing LinEnum"
git_clone https://github.com/rebootuser/LinEnum.git

# Responder
log "Installing Responder"
git_clone https://github.com/lgandx/Responder.git

# DNScan
log "Installing dnscan"
if git_clone https://github.com/rbsec/dnscan.git; then
    if [ -f dnscan/requirements.txt ]; then
        cd dnscan || exit 1
        pip_install -r requirements.txt || log_warning "Failed to install dnscan requirements"
        cd ..
    fi
fi

# Evil-WinRM
log "Installing evil-winrm"
if gem install evil-winrm 2>&1 | tee -a "$log_file"; then
    log "evil-winrm installed successfully"
else
    log_error "Failed to install evil-winrm"
fi

# Wifite2
log "Installing Wifite2"
if git_clone https://github.com/kimocoder/wifite2.git; then
    if [ -f wifite2/requirements.txt ]; then
        cd wifite2 || exit 1
        pip_install -r requirements.txt || log_warning "Failed to install wifite2 requirements"
        cd ..
    fi
fi

# AutoRecon
log "Installing AutoRecon"
pip_install "git+https://github.com/Tib3rius/AutoRecon.git" || log_warning "AutoRecon installation failed"

# CrackMapExec
log "Installing CrackMapExec"
if apt-get install -y crackmapexec 2>&1 | tee -a "$log_file"; then
    log "CrackMapExec installed successfully"
else
    log_warning "CrackMapExec not available in apt, you may need to install it manually"
fi

# SecLists (may already be installed via apt)
log "Installing SecLists"
if [ ! -d "/usr/share/seclists" ] && [ ! -d "SecLists" ]; then
    git_clone https://github.com/danielmiessler/SecLists.git
else
    log "SecLists already available"
fi

# Fierce
log "Installing Fierce"
if apt-get install -y fierce 2>&1 | tee -a "$log_file"; then
    log "Fierce installed successfully"
else
    log_warning "Fierce installation failed"
fi

# FinalRecon
log "Installing FinalRecon"
if git_clone https://github.com/thewhiteh4t/FinalRecon.git; then
    if [ -f FinalRecon/requirements.txt ]; then
        cd FinalRecon || exit 1
        pip_install -r requirements.txt || log_warning "Failed to install FinalRecon requirements"
        cd ..
    fi
fi

log "==================================="
log "Build Script Complete!"
log "==================================="
log "All tools have been installed to /opt/tools"
log "Check the log file for details: $log_file"
