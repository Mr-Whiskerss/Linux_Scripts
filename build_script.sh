#!/bin/bash
# This script is designed to pull down my most used tools to quickly build out my Linux system

echo "Welcome to the Build Script"

# Checking if script is running as root.
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi
echo "Root check passed"

# Update and upgrade the system
echo "=================================="
echo "Updating and Upgrading System"
echo "=================================="
sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get dist-upgrade -y && sudo apt autoremove -y

# Install common tools
echo "=================================="
echo "Installing Common Tools"
echo "=================================="
sudo apt-get install -y htop iftop python3-pip python2 seclists terminator rubygems

# Create tools directory
echo "Creating tool directories"
mkdir -p /opt/tools
cd /opt/tools

# Install pentest tools
echo "=================================="
echo "Installing Pentest Tools"
echo "=================================="

# Enum4linux-ng
echo "Installing Enum4linux-NG"
sudo apt-get install -y smbclient python3-ldap3 python3-yaml python3-impacket
git clone https://github.com/cddmp/enum4linux-ng.git

# testssl
echo "Installing testssl"
git clone --depth 1 https://github.com/drwetter/testssl.sh.git

# PowerSploit
echo "Installing PowerSploit"
git clone https://github.com/PowerShellMafia/PowerSploit.git

# Impacket
echo "Installing Impacket"
git clone https://github.com/CoreSecurity/impacket.git
cd impacket
python3 setup.py install
cd ..

# WinPEAS and LinPEAS
echo "Installing WinPEAS and LinPEAS"
wget https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/linpeas.sh
wget https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx64.exe
wget https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx86.exe

# LinEnum
echo "Installing LinEnum"
git clone https://github.com/rebootuser/LinEnum.git

# Responder
echo "Installing Responder"
git clone https://github.com/lgandx/Responder.git

# dnscan
echo "Installing dnscan"
git clone https://github.com/rbsec/dnscan.git
pip3 install -r dnscan/requirements.txt

# evil-winrm
echo "Installing evil-winrm"
gem install evil-winrm

# Wifite2
echo "Installing Wifite2"
git clone https://github.com/kimocoder/wifite2.git
pip3 install -r wifite2/requirements.txt

# AutoRecon
echo "Installing AutoRecon"
python3 -m pip install git+https://github.com/Tib3rius/AutoRecon.git

# CrackMapExec
echo "Installing CrackMapExec"
sudo apt install -y crackmapexec

# SecLists
echo "Installing SecLists"
git clone https://github.com/danielmiessler/SecLists.git

# Fierce
echo "Installing Fierce"
sudo apt install -y fierce

# FinalRecon
echo "Installing FinalRecon"
git clone https://github.com/thewhiteh4t/FinalRecon.git
cd FinalRecon
pip3 install -r requirements.txt

echo "Build Script Complete"
