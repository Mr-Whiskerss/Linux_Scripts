#!/bin/bash
# This script sets up essential tools for Linux pentesting and system preparation when on a new build or need to get something up and ready quick. Please run as root. 
# Version 3.0

set -e  # Exit immediately if a command exits with a non-zero status

log_file="/var/log/build_script.log"
echo "Welcome to the Build Script" | tee -a "$log_file"

# Check if the script is running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root." | tee -a "$log_file"
  exit 1
fi

echo "Root check passed" | tee -a "$log_file"

# Update and upgrade the system
echo "==================================" | tee -a "$log_file"
echo "Updating and Upgrading System" | tee -a "$log_file"
echo "==================================" | tee -a "$log_file"
apt-get update && apt-get upgrade -y && apt-get dist-upgrade -y && apt-get autoremove -y | tee -a "$log_file"

# Install common tools
echo "==================================" | tee -a "$log_file"
echo "Installing Common Tools" | tee -a "$log_file"
echo "==================================" | tee -a "$log_file"
apt-get install -y htop iftop python3-pip python2 seclists terminator rubygems | tee -a "$log_file"

# Create tools directory
echo "Creating tools directory" | tee -a "$log_file"
mkdir -p /opt/tools
cd /opt/tools || exit

# Function to clone and check git repositories
git_clone() {
  local repo_url=$1
  local dest_dir=$(basename "$repo_url" .git)
  if [ ! -d "$dest_dir" ]; then
    echo "Cloning $repo_url" | tee -a "$log_file"
    git clone "$repo_url" | tee -a "$log_file"
  else
    echo "$dest_dir already exists, skipping clone." | tee -a "$log_file"
  fi
}

# Function to download files safely
download_file() {
  local url=$1
  local filename=$(basename "$url")
  if [ ! -f "$filename" ]; then
    echo "Downloading $url" | tee -a "$log_file"
    wget "$url" -q --show-progress | tee -a "$log_file"
  else
    echo "$filename already exists, skipping download." | tee -a "$log_file"
  fi
}

# Install pentest tools
echo "==================================" | tee -a "$log_file"
echo "Installing Pentest Tools" | tee -a "$log_file"
echo "==================================" | tee -a "$log_file"

# Enum4linux-NG
echo "Installing Enum4linux-NG" | tee -a "$log_file"
apt-get install -y smbclient python3-ldap3 python3-yaml python3-impacket | tee -a "$log_file"
git_clone https://github.com/cddmp/enum4linux-ng.git

# Testssl
echo "Installing testssl" | tee -a "$log_file"
git_clone https://github.com/drwetter/testssl.sh.git

# PowerSploit
echo "Installing PowerSploit" | tee -a "$log_file"
git_clone https://github.com/PowerShellMafia/PowerSploit.git

# Impacket
echo "Installing Impacket" | tee -a "$log_file"
git_clone https://github.com/CoreSecurity/impacket.git
cd impacket
python3 setup.py install | tee -a "$log_file"
cd ..

# WinPEAS and LinPEAS
echo "Installing WinPEAS and LinPEAS" | tee -a "$log_file"
download_file https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/linpeas.sh
download_file https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx64.exe
download_file https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx86.exe

# LinEnum
echo "Installing LinEnum" | tee -a "$log_file"
git_clone https://github.com/rebootuser/LinEnum.git

# Responder
echo "Installing Responder" | tee -a "$log_file"
git_clone https://github.com/lgandx/Responder.git

# DNScan
echo "Installing dnscan" | tee -a "$log_file"
git_clone https://github.com/rbsec/dnscan.git
pip3 install -r dnscan/requirements.txt | tee -a "$log_file"

# Evil-WinRM
echo "Installing evil-winrm" | tee -a "$log_file"
gem install evil-winrm | tee -a "$log_file"

# Wifite2
echo "Installing Wifite2" | tee -a "$log_file"
git_clone https://github.com/kimocoder/wifite2.git
pip3 install -r wifite2/requirements.txt | tee -a "$log_file"

# AutoRecon
echo "Installing AutoRecon" | tee -a "$log_file"
python3 -m pip install git+https://github.com/Tib3rius/AutoRecon.git | tee -a "$log_file"

# CrackMapExec
echo "Installing CrackMapExec" | tee -a "$log_file"
apt-get install -y crackmapexec | tee -a "$log_file"

# SecLists
echo "Installing SecLists" | tee -a "$log_file"
git_clone https://github.com/danielmiessler/SecLists.git

# Fierce
echo "Installing Fierce" | tee -a "$log_file"
apt-get install -y fierce | tee -a "$log_file"

# FinalRecon
echo "Installing FinalRecon" | tee -a "$log_file"
git_clone https://github.com/thewhiteh4t/FinalRecon.git
cd FinalRecon
pip3 install -r requirements.txt | tee -a "$log_file"
cd ..

echo "Build Script Complete" | tee -a "$log_file"
