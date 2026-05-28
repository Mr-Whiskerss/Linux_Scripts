#!/bin/bash
# This script sets up essential tools for Linux pentesting and system preparation when on a new build or need to get something up and ready quick. Please run as root.
# Version 4.2

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

log "Welcome to the Build Script v4.2"

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  log_error "Please run this script as root."
  exit 1
fi

log "Root check passed"

# =====================================================================
# Installation status tracking
# =====================================================================
# INSTALL_STATUS maps a tool's display name to one of:
#   installed | present | failed
# INSTALL_ORDER preserves the order tools were processed so the final
# checklist reads top-to-bottom in the same order as the script runs.
declare -A INSTALL_STATUS
INSTALL_ORDER=()

record_status() {
    local name=$1 status=$2
    if [ -z "${INSTALL_STATUS[$name]+x}" ]; then
        INSTALL_ORDER+=("$name")
    fi
    INSTALL_STATUS["$name"]="$status"
}

# Return 0 if a command exists on PATH
have_cmd() { command -v "$1" &>/dev/null; }

# Return 0 if a dpkg package is installed
have_pkg() { dpkg -s "$1" &>/dev/null; }

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

# =====================================================================
# Helper functions
# =====================================================================

# Install an apt package (or set of packages) with a pre-check and status tracking.
# usage: apt_install_tracked "Display Name" "check_pkg_or_cmd" pkg1 [pkg2 ...]
# The second argument is the package/command used to decide if it's already present.
apt_install_tracked() {
    local name=$1; shift
    local check=$1; shift

    if have_pkg "$check" || have_cmd "$check"; then
        log_warning "$name already present, skipping install"
        record_status "$name" "present"
        return 0
    fi

    log "Installing $name"
    if apt-get install -y "$@" 2>&1 | tee -a "$log_file"; then
        log "$name installed successfully"
        record_status "$name" "installed"
        return 0
    else
        log_error "Failed to install $name"
        record_status "$name" "failed"
        return 1
    fi
}

# Function to clone and check git repositories (with status tracking).
git_clone() {
    local repo_url=$1
    local dest_dir
    dest_dir=$(basename "$repo_url" .git)

    if [ -d "$dest_dir" ]; then
        log_warning "$dest_dir already exists, skipping clone"
        record_status "$dest_dir" "present"
        return 0
    fi

    log "Cloning $repo_url"
    if git clone --depth 1 "$repo_url" 2>&1 | tee -a "$log_file"; then
        log "Successfully cloned $dest_dir"
        record_status "$dest_dir" "installed"
        return 0
    else
        log_error "Failed to clone $repo_url"
        record_status "$dest_dir" "failed"
        return 1
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

# Install a .deb package from a GitHub project's latest release.
# Queries the GitHub API for the newest release, finds the first asset matching
# the supplied pattern (regex), downloads it, and installs it with dependency
# resolution. Falls back to dpkg + apt-get -f if the direct apt install fails.
# usage: install_github_deb <repo> <pattern> <name> [check_cmd_or_pkg]
install_github_deb() {
    local repo=$1       # e.g. obsidianmd/obsidian-releases
    local pattern=$2    # regex to match the desired asset, e.g. '_amd64\.deb$'
    local name=$3       # friendly name for logging / checklist
    local check=$4      # optional: command or package to test if already installed

    # Skip if already present
    if [ -n "$check" ] && { have_cmd "$check" || have_pkg "$check"; }; then
        log_warning "$name already present, skipping install"
        record_status "$name" "present"
        return 0
    fi

    log "Fetching latest release info for $name ($repo)"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local deb_url
    # Pull the matching browser_download_url from the release metadata.
    # (Unauthenticated GitHub API allows ~60 requests/hour, which is plenty here.)
    deb_url=$(curl -fsSL "$api_url" \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]*' \
        | grep -E "$pattern" \
        | head -n1)

    if [ -z "$deb_url" ]; then
        log_error "Could not find a .deb asset for $name matching /$pattern/"
        record_status "$name" "failed"
        return 1
    fi

    local deb_file
    deb_file=$(basename "$deb_url")

    if download_file "$deb_url"; then
        log "Installing $name from $deb_file"
        if apt-get install -y "./$deb_file" 2>&1 | tee -a "$log_file"; then
            log "$name installed successfully"
            record_status "$name" "installed"
            return 0
        else
            log_warning "apt install failed for $name, trying dpkg + apt-get -f"
            dpkg -i "$deb_file" 2>&1 | tee -a "$log_file" || true
            if apt-get install -f -y 2>&1 | tee -a "$log_file"; then
                log "$name installed successfully (after dependency fix-up)"
                record_status "$name" "installed"
                return 0
            else
                log_error "Failed to install $name"
                record_status "$name" "failed"
                return 1
            fi
        fi
    else
        log_error "Failed to download $name"
        record_status "$name" "failed"
        return 1
    fi
}

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

# Install each common tool individually so already-present ones are skipped
# and every tool gets its own line in the final checklist.
for pkg in $COMMON_TOOLS; do
    apt_install_tracked "$pkg" "$pkg" "$pkg" || true
done

# Create tools directory
log "Creating tools directory at /opt/tools"
mkdir -p /opt/tools
cd /opt/tools || exit 1

# Install pentest tools
log "==================================="
log "Installing Pentest Tools"
log "==================================="

# Enum4linux-NG
log "Installing Enum4linux-NG dependencies and tool"
apt-get install -y smbclient python3-ldap3 python3-yaml python3-impacket 2>&1 | tee -a "$log_file" || log_warning "Some enum4linux-ng dependencies may have failed"
git_clone https://github.com/cddmp/enum4linux-ng.git || true

# Testssl
log "Installing testssl"
git_clone https://github.com/drwetter/testssl.sh.git || true

# PowerSploit
log "Installing PowerSploit"
git_clone https://github.com/PowerShellMafia/PowerSploit.git || true

# Impacket (using updated fortra repository)
log "Installing Impacket"
if have_cmd impacket-secretsdump; then
    log_warning "Impacket already present, skipping"
    record_status "impacket" "present"
elif git_clone https://github.com/fortra/impacket.git; then
    cd impacket || exit 1
    if pip_install .; then
        log "Impacket installed successfully"
        record_status "impacket" "installed"
    else
        log_error "Impacket installation failed"
        record_status "impacket" "failed"
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
git_clone https://github.com/rebootuser/LinEnum.git || true

# Responder
log "Installing Responder"
git_clone https://github.com/lgandx/Responder.git || true

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
if have_cmd evil-winrm; then
    log_warning "evil-winrm already present, skipping"
    record_status "evil-winrm" "present"
elif gem install evil-winrm 2>&1 | tee -a "$log_file"; then
    log "evil-winrm installed successfully"
    record_status "evil-winrm" "installed"
else
    log_error "Failed to install evil-winrm"
    record_status "evil-winrm" "failed"
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
if have_cmd autorecon; then
    log_warning "AutoRecon already present, skipping"
    record_status "AutoRecon" "present"
elif pip_install "git+https://github.com/Tib3rius/AutoRecon.git"; then
    record_status "AutoRecon" "installed"
else
    log_warning "AutoRecon installation failed"
    record_status "AutoRecon" "failed"
fi

# CrackMapExec
apt_install_tracked "crackmapexec" "crackmapexec" "crackmapexec" \
    || log_warning "CrackMapExec not available in apt, you may need to install it manually"

# SecLists (may already be installed via apt or cloned here)
log "Installing SecLists"
if [ -d "/usr/share/seclists" ] || [ -d "SecLists" ]; then
    log "SecLists already available"
    record_status "SecLists" "present"
else
    git_clone https://github.com/danielmiessler/SecLists.git || true
fi

# Fierce
apt_install_tracked "fierce" "fierce" "fierce" || log_warning "Fierce installation failed"

# FinalRecon
log "Installing FinalRecon"
if git_clone https://github.com/thewhiteh4t/FinalRecon.git; then
    if [ -f FinalRecon/requirements.txt ]; then
        cd FinalRecon || exit 1
        pip_install -r requirements.txt || log_warning "Failed to install FinalRecon requirements"
        cd ..
    fi
fi

# =====================================================================
# GUI / Productivity Tools
# =====================================================================
log "==================================="
log "Installing GUI / Productivity Tools"
log "==================================="

# Make sure we are back in the tools directory for any .deb downloads
cd /opt/tools || exit 1

# Remmina (remote desktop client) + common protocol plugins
apt_install_tracked "Remmina" "remmina" remmina remmina-plugin-rdp remmina-plugin-vnc remmina-plugin-secret \
    || log_warning "Remmina installation failed (some plugins may not exist on this distro)"

# Terminator is already handled in the Common Tools section above (it is part
# of COMMON_TOOLS), so it is checked / tracked there - nothing to do here.

# Geany (lightweight native Linux editor/IDE, used in place of Notepad++).
# NOTE: Notepad++ itself is Windows-only software. Geany is a well-maintained
# native alternative. If you specifically need the real Notepad++, it runs
# under Wine or via snap (snap install notepad-plus-plus).
apt_install_tracked "Geany" "geany" geany || log_warning "Geany installation failed"

# Obsidian (notes / knowledge base) - installed from the latest GitHub release .deb
install_github_deb "obsidianmd/obsidian-releases" '_amd64\.deb$' "Obsidian" "obsidian" \
    || log_warning "Obsidian installation failed - grab the .deb/AppImage manually from https://obsidian.md/download"

# Teams for Linux (unofficial MS Teams client by Ismael Martinez).
# Preferred method: the project's official apt repository, which keeps it
# updated via normal 'apt upgrade' runs. Falls back to the latest release .deb.
if have_cmd teams-for-linux || have_pkg teams-for-linux; then
    log_warning "Teams for Linux already present, skipping"
    record_status "Teams for Linux" "present"
else
    log "Installing Teams for Linux (via official apt repository)"
    if mkdir -p /etc/apt/keyrings \
        && wget -qO /etc/apt/keyrings/teams-for-linux.asc https://repo.teamsforlinux.de/teams-for-linux.asc \
        && echo "deb [signed-by=/etc/apt/keyrings/teams-for-linux.asc arch=amd64] https://repo.teamsforlinux.de/debian/ stable main" > /etc/apt/sources.list.d/teams-for-linux-packages.list \
        && apt-get update 2>&1 | tee -a "$log_file" \
        && apt-get install -y teams-for-linux 2>&1 | tee -a "$log_file"; then
        log "Teams for Linux installed successfully (via apt repo)"
        record_status "Teams for Linux" "installed"
    else
        log_warning "apt-repo install failed, falling back to latest GitHub release .deb"
        install_github_deb "IsmaelMartinez/teams-for-linux" '_amd64\.deb$' "Teams for Linux" \
            || log_warning "Teams for Linux installation failed - see https://github.com/IsmaelMartinez/teams-for-linux/releases"
    fi
fi

# =====================================================================
# Final summary / checklist
# =====================================================================
print_summary() {
    local installed=() present=() failed=()
    local name
    for name in "${INSTALL_ORDER[@]}"; do
        case "${INSTALL_STATUS[$name]}" in
            installed) installed+=("$name") ;;
            present)   present+=("$name") ;;
            failed)    failed+=("$name") ;;
        esac
    done

    log "==================================="
    log "Installation Summary"
    log "==================================="

    echo -e "\n${GREEN}Newly installed (${#installed[@]}):${NC}" | tee -a "$log_file"
    if [ ${#installed[@]} -eq 0 ]; then
        echo "  (none)" | tee -a "$log_file"
    else
        for name in "${installed[@]}"; do echo -e "  [${GREEN}+${NC}] $name" | tee -a "$log_file"; done
    fi

    echo -e "\n${YELLOW}Already present - skipped (${#present[@]}):${NC}" | tee -a "$log_file"
    if [ ${#present[@]} -eq 0 ]; then
        echo "  (none)" | tee -a "$log_file"
    else
        for name in "${present[@]}"; do echo -e "  [${YELLOW}=${NC}] $name" | tee -a "$log_file"; done
    fi

    echo -e "\n${RED}Failed - needs attention (${#failed[@]}):${NC}" | tee -a "$log_file"
    if [ ${#failed[@]} -eq 0 ]; then
        echo "  (none)" | tee -a "$log_file"
    else
        for name in "${failed[@]}"; do echo -e "  [${RED}x${NC}] $name" | tee -a "$log_file"; done
    fi
    echo "" | tee -a "$log_file"
}

log "==================================="
log "Build Script Complete!"
log "==================================="
log "All tools have been installed to /opt/tools"
log "Check the log file for details: $log_file"

print_summary
