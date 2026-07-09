#!/bin/bash
# This script sets up essential tools for Linux pentesting and system preparation when on a new build or need to get something up and ready quick. Please run as root.
# Version 5.0
#
# v5.0 changelog (tools added to match an internal/AD + web pentest workflow):
#   * New helpers: pipx_install_tracked, install_github_release_bin, apt_install_many
#   * Active Directory / internal: BloodHound CE ingestor, Certipy, kerbrute,
#     ldapdomaindump, mitm6, Coercer, PCredz, adidnsdump, targetedKerberoast,
#     DonPAPI, gMSADumper, pywerview
#   * Recon / content discovery: ffuf, feroxbuster, gobuster, nuclei, httpx,
#     subfinder, dnsx, katana, gowitness, amass, masscan, rustscan
#   * Web: sqlmap, nikto, whatweb, wpscan, dalfox, arjun
#   * Credentials / cracking: hashcat, john, hcxtools, hcxdumptool
#   * Pivoting / tunnelling: chisel, ligolo-ng, sshuttle, proxychains4, socat
#   * Quality-of-life: tmux, jq, ripgrep, fzf, bat, golang-go, pipx, net tooling

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

log "Welcome to the Build Script v5.0"

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  log_error "Please run this script as root."
  exit 1
fi

log "Root check passed"

# The user who invoked sudo, so pipx installs land in a real user profile
# instead of root's. Falls back to root if the script is run as root directly.
TARGET_USER="${SUDO_USER:-root}"
TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
[ -z "$TARGET_HOME" ] && TARGET_HOME="/root"

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

# Convenience wrapper for installing a flat list of apt packages where the
# package name and the command/check name are identical. Each gets its own
# checklist line and already-present ones are skipped.
# usage: apt_install_many pkg1 pkg2 pkg3 ...
apt_install_many() {
    local pkg
    for pkg in "$@"; do
        apt_install_tracked "$pkg" "$pkg" "$pkg" || true
    done
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

# Install a Python CLI tool in its own isolated environment with pipx.
# This is the project-recommended method for most modern AD/pentest tooling
# (impacket-based tools, certipy, coercer, etc.) and avoids polluting the
# system Python. Tools are installed for $TARGET_USER so they land on that
# user's PATH rather than root's.
# usage: pipx_install_tracked "Display Name" "spec" [check_cmd]
#   spec      : anything pipx accepts, e.g. "certipy-ad" or "git+https://..."
#   check_cmd : optional command name used to detect an existing install
pipx_install_tracked() {
    local name=$1 spec=$2 check=$3

    if [ -n "$check" ] && have_cmd "$check"; then
        log_warning "$name already present, skipping install"
        record_status "$name" "present"
        return 0
    fi

    # Make sure pipx itself is available.
    if ! have_cmd pipx; then
        log "pipx not found, installing prerequisite"
        apt-get install -y pipx 2>&1 | tee -a "$log_file" || log_warning "Failed to install pipx"
    fi

    log "Installing $name via pipx ($spec)"
    # Run pipx as the invoking user so the venv/bin live in their home.
    if sudo -u "$TARGET_USER" -H bash -lc "pipx install '$spec'" 2>&1 | tee -a "$log_file"; then
        sudo -u "$TARGET_USER" -H bash -lc "pipx ensurepath" 2>&1 | tee -a "$log_file" || true
        log "$name installed successfully (via pipx)"
        record_status "$name" "installed"
        return 0
    else
        log_error "Failed to install $name via pipx"
        record_status "$name" "failed"
        return 1
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

# Install a single static binary from a GitHub project's latest release.
# Finds the first asset matching <pattern>, downloads it, extracts it if it is
# a tar/zip, then drops the resulting executable into /usr/local/bin/<binname>.
# Great for Go tools that ship a single static binary (kerbrute, chisel, ligolo).
# usage: install_github_release_bin <repo> <pattern> <name> <binname> [inner_match]
#   pattern     : regex matching the release asset (e.g. 'linux_amd64\.tar\.gz$')
#   binname     : final command name to place in /usr/local/bin
#   inner_match : optional substring to pick the right file out of an archive
install_github_release_bin() {
    local repo=$1 pattern=$2 name=$3 binname=$4 inner_match=$5

    if have_cmd "$binname"; then
        log_warning "$name already present, skipping install"
        record_status "$name" "present"
        return 0
    fi

    log "Fetching latest release info for $name ($repo)"
    local api_url="https://api.github.com/repos/${repo}/releases/latest"
    local asset_url
    asset_url=$(curl -fsSL "$api_url" \
        | grep -oP '"browser_download_url"\s*:\s*"\K[^"]*' \
        | grep -E "$pattern" \
        | head -n1)

    if [ -z "$asset_url" ]; then
        log_error "Could not find a release asset for $name matching /$pattern/"
        record_status "$name" "failed"
        return 1
    fi

    local tmp
    tmp=$(mktemp -d)
    local asset_file="$tmp/$(basename "$asset_url")"

    if ! wget -q --show-progress -O "$asset_file" "$asset_url" 2>&1 | tee -a "$log_file"; then
        log_error "Failed to download $name"
        record_status "$name" "failed"
        rm -rf "$tmp"
        return 1
    fi

    local bin_src=""
    case "$asset_file" in
        *.tar.gz|*.tgz) tar -xzf "$asset_file" -C "$tmp" ;;
        *.zip)          unzip -o -q "$asset_file" -d "$tmp" ;;
        *)              bin_src="$asset_file" ;;  # raw binary
    esac

    # Locate the executable inside the extracted tree.
    if [ -z "$bin_src" ]; then
        if [ -n "$inner_match" ]; then
            bin_src=$(find "$tmp" -type f -name "*$inner_match*" ! -name "*.tar*" ! -name "*.zip" | head -n1)
        else
            # Prefer a file whose name looks like the binary; else first executable.
            bin_src=$(find "$tmp" -type f \( -name "$binname" -o -name "${binname}*" \) ! -name "*.tar*" ! -name "*.zip" | head -n1)
            [ -z "$bin_src" ] && bin_src=$(find "$tmp" -maxdepth 2 -type f -perm -u+x ! -name "*.tar*" ! -name "*.zip" | head -n1)
        fi
    fi

    if [ -z "$bin_src" ] || [ ! -f "$bin_src" ]; then
        log_error "Could not locate the $binname binary inside the $name release asset"
        record_status "$name" "failed"
        rm -rf "$tmp"
        return 1
    fi

    install -m 0755 "$bin_src" "/usr/local/bin/$binname"
    log "$name installed successfully to /usr/local/bin/$binname"
    record_status "$name" "installed"
    rm -rf "$tmp"
    return 0
}

# Install common tools
log "==================================="
log "Installing Common Tools"
log "==================================="
COMMON_TOOLS="htop iftop python3-pip pipx seclists terminator rubygems curl wget unzip jq git tmux ripgrep fzf bat golang-go net-tools dnsutils socat"

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

# NetExec (nxc) - maintained successor to the now-abandoned CrackMapExec.
log "Installing NetExec (nxc)"
if have_cmd nxc || have_cmd netexec; then
    log_warning "NetExec already present, skipping"
    record_status "NetExec (nxc)" "present"
elif apt-get install -y netexec 2>&1 | tee -a "$log_file"; then
    # Available natively in Kali and some other security distros
    log "NetExec installed successfully (via apt)"
    record_status "NetExec (nxc)" "installed"
else
    # Project-recommended method: pipx install from the GitHub repo
    log_warning "netexec not available via apt, falling back to pipx (recommended method)"
    apt-get install -y pipx git 2>&1 | tee -a "$log_file" || log_warning "Failed to install pipx prerequisite"
    pipx ensurepath 2>&1 | tee -a "$log_file" || true
    if pipx install git+https://github.com/Pennyw0rth/NetExec 2>&1 | tee -a "$log_file"; then
        log "NetExec installed successfully (via pipx) - open a new shell to pick up the PATH change"
        record_status "NetExec (nxc)" "installed"
    else
        log_error "Failed to install NetExec"
        record_status "NetExec (nxc)" "failed"
    fi
fi

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
# Active Directory / Internal network tooling
# =====================================================================
# Rounds out the AD kill-chain that your Active_Directory_Attack_Checker /
# NXC_Host_Gen workflow already leans on: enumeration -> coercion/relay ->
# AD CS abuse -> BloodHound analysis.
log "==================================="
log "Installing Active Directory / Internal Tools"
log "==================================="
cd /opt/tools || exit 1

# Prefer Kali's packaged versions where they exist; fall back to pipx/git.
apt_install_many ldapdomaindump mitm6 bloodhound.py smbmap

# Certipy - AD Certificate Services (ADCS) enumeration & ESC1-ESC16 abuse.
if ! apt_install_tracked "Certipy" "certipy" certipy-ad; then
    pipx_install_tracked "Certipy" "certipy-ad" "certipy" || true
fi

# BloodHound.py ingestor (collects AD data for the BloodHound GUI/CE).
if ! have_cmd bloodhound-python; then
    pipx_install_tracked "BloodHound.py ingestor" "bloodhound" "bloodhound-python" || true
fi

# Coercer - automated authentication coercion (PetitPotam/PrinterBug/etc.).
pipx_install_tracked "Coercer" "coercer" "coercer" || true

# adidnsdump - AD-integrated DNS zone dumping over LDAP.
pipx_install_tracked "adidnsdump" "adidnsdump" "adidnsdump" || true

# DonPAPI - remote DPAPI secret harvesting (creds, cookies, certs).
pipx_install_tracked "DonPAPI" "donpapi" "donpapi" || true

# pywerview - Python PowerView for LDAP-based AD recon.
pipx_install_tracked "pywerview" "pywerview" "pywerview" || true

# kerbrute - fast Kerberos user enumeration & password spraying.
install_github_release_bin "ropnop/kerbrute" 'linux_amd64$' "kerbrute" "kerbrute" || \
    log_warning "kerbrute install failed - grab it from https://github.com/ropnop/kerbrute/releases"

# PCredz - credential extraction from live traffic / pcap (pairs with Responder).
log "Installing PCredz"
apt-get install -y libpcap-dev python3-pip 2>&1 | tee -a "$log_file" || true
if git_clone https://github.com/lgandx/PCredz.git; then
    pip_install Cython || true
    pip_install python-libpcap || log_warning "PCredz dependency python-libpcap failed"
fi

# targetedKerberoast - roast accounts you can write to (RBCD/shadow creds combos).
git_clone https://github.com/ShutdownRepo/targetedKerberoast.git || true

# gMSADumper - dump gMSA managed passwords.
git_clone https://github.com/micahvandeusen/gMSADumper.git || true

# =====================================================================
# Recon / content discovery
# =====================================================================
# Modern web + infra recon to back your Web-Application-Enumeration workflow.
# Almost all of these are packaged in Kali; apt-first keeps them upgradable.
log "==================================="
log "Installing Recon / Content Discovery Tools"
log "==================================="
cd /opt/tools || exit 1

apt_install_many nmap masscan gobuster ffuf feroxbuster nikto whatweb wpscan \
    amass dnsrecon sqlmap dirb

# ProjectDiscovery suite (nuclei is the big one; templates auto-update on first run).
# Kali packages httpx as "httpx-toolkit" to avoid clashing with the python httpx lib.
apt_install_tracked "nuclei" "nuclei" nuclei || true
apt_install_tracked "httpx (ProjectDiscovery)" "httpx" httpx-toolkit || true
apt_install_tracked "subfinder" "subfinder" subfinder || true
apt_install_tracked "dnsx" "dnsx" dnsx || true
apt_install_tracked "katana" "katana" katana || true
apt_install_tracked "gowitness" "gowitness" gowitness || true
apt_install_tracked "dalfox" "dalfox" dalfox || true

# Arjun - HTTP parameter discovery.
pipx_install_tracked "Arjun" "arjun" "arjun" || true

# rustscan - very fast port scanner that hands off to nmap.
if ! have_cmd rustscan; then
    install_github_deb "bee-san/RustScan" 'amd64.*\.deb$' "RustScan" "rustscan" || \
        log_warning "RustScan install failed - see https://github.com/bee-san/RustScan/releases"
fi

# =====================================================================
# Credentials / password cracking
# =====================================================================
log "==================================="
log "Installing Credential / Cracking Tools"
log "==================================="

apt_install_many hashcat john hydra hcxtools hcxdumptool

# =====================================================================
# Pivoting / tunnelling
# =====================================================================
log "==================================="
log "Installing Pivoting / Tunnelling Tools"
log "==================================="
cd /opt/tools || exit 1

apt_install_many proxychains4 sshuttle chisel

# ligolo-ng - modern tunnelling/pivoting (agent + proxy). Grab both binaries.
install_github_release_bin "nicocha30/ligolo-ng" 'proxy.*linux_amd64\.tar\.gz$' \
    "ligolo-ng (proxy)" "ligolo-proxy" "proxy" || \
    log_warning "ligolo-ng proxy install failed - see https://github.com/nicocha30/ligolo-ng/releases"
install_github_release_bin "nicocha30/ligolo-ng" 'agent.*linux_amd64\.tar\.gz$' \
    "ligolo-ng (agent)" "ligolo-agent" "agent" || \
    log_warning "ligolo-ng agent install failed (Windows/target agent can be built as needed)"

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
