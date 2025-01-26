#!/bin/bash
# This script sets up essential tools for Linux pentesting and system preparation

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

# Install pentest tools
echo "==================================" | tee -a "$log_file"
echo "Installing Pentest Tools" | tee -a "$log_file"
echo "==================================" | tee -a "$log_file"

# Function to clone and check git repositories
git_clone() {
  local repo_url=$1
  local dest_dir=$(basename "$repo_url" .git)
  if [ ! -d "$dest_dir" ]; then
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
    wget "$url" -q --show-progress | tee -a "$log_file"
  else
    echo "$filename already exists, skipping download." | tee -a "$log_file"
  fi
}

# Install tools
echo "Installing Enum4linux-NG"
apt-get install -y smbclient python3-ldap3 python3-yaml python3-impacket | tee -a "$log_file"
git_clone https://github.com/cddmp/enum4linux-ng.git

echo "Installing testssl"
git_clone https://github.com/drwetter/testssl.sh.git

echo "Installing PowerSploit"
git_clone https://github.com/PowerShellMafia/PowerSploit.git

echo "Installing Impacket"
git_clone https://github.com/CoreSecurity/impacket.git
cd impacket
python3 setup.py install | tee -a "$log_file"
cd ..

echo "Installing WinPEAS and LinPEAS"
download_file https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/linpeas.sh
download_file https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx64.exe
download_file https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx86.exe

echo "Installing LinEnum"
git_clone https://github.com/rebootuser/LinEnum.git

echo "Installing Responder"
git_clone https://github.com/lgandx/Responder.git

echo "Installing dnscan"
git_clone https://github.com/rbsec/dnscan.git
pip3 install -r dnscan/requirements.txt | tee -a "$log_file"

echo "Installing evil-winrm"
gem install evil-winrm | tee -a "$log_file"

echo "Installing Wifite2"
git_clone https://github.com/kimocoder/wifite2.git
pip3 install -r wifite2/requirements.txt | tee -a "$log_file"

echo "Installing AutoRecon"
python3 -m pip install git+https://github.com/Tib3rius/AutoRecon.git | tee -a "$log_file"

echo "Installing CrackMapExec"
apt-get install -y crackmapexec | tee -a "$log_file"

echo "Installing SecLists"
git_clone https://github.com/danielmiessler/SecLists.git

echo "Installing Fierce"
apt-get install -y fierce | tee -a "$log_file"

echo "Installing FinalRecon"
git_clone https://github.com/thewhiteh4t/FinalRecon.git
cd FinalRecon
pip3 install -r requirements.txt | tee -a "$log_file"
cd ..

echo "Build Script Complete" | tee -a "$log_file"
