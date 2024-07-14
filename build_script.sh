#!/bin/bash
#This script is designed to pull down my most used tools to quickly build out my linux system

echo Welcome to the Build Script

#Checking if script is running at root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
echo Root Checking done 


#Update repo and upgrade system first.

# Update
echo "=================================="
echo "Update"
echo "=================================="
sudo apt-get update


# Upgrade
echo "=================================="
echo "Upgrade"
echo "=================================="
sudo apt-get upgrade

#Remove old software 
echo "=================================="
echo "Remove old software"
echo "=================================="
sudo apt autoremove

# Distribution Upgrade
echo "=================================="
echo "Distribution Upgrade"
echo "=================================="
sudo apt-get dist-upgrade

#The following commands will install common tools used within my personal kali install. More will be updated as I progress (2024)
#Install common global tools please feel free to add or remove tools from here this is personal preference
echo "=================================="
echo "Installing Software"
echo "=================================="
apt-get install htop iftop python3-pip python2 seclists terminator rubygems -y 


#create new tools directory and report directory for kali on first boot
echo Creating Tool directories
mkdir /opt/tools



#cd into new directory 
cd /opt/tools

echo "=================================="
echo "Installing Pentest Tools"
echo "=================================="
#Enum4linux-ng
echo Installing Enum4linix-NG
apt-get install smbclient python3-ldap3 python3-yaml python3-impacket -y
git clone https://github.com/cddmp/enum4linux-ng.git

#testssl
git clone --depth 1 https://github.com/drwetter/testssl.sh.git

#Powersploit 
git clone https://github.com/PowerShellMafia/PowerSploit.git
 
#Impacket
git clone https://github.com/CoreSecurity/impacket.git
python3 opt/tools/impacket/setup.py install
 
#Winpeas and Linpeas
wget https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/linpeas.sh
wget https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx64.exe
wget https://github.com/peass-ng/PEASS-ng/releases/download/20240714-cd435bb2/winPEASx86.exe


#Linenum 
git clone https://github.com/rebootuser/LinEnum.git

#Responder
git clone https://github.com/lgandx/Responder.git

#dnscan
git clone https://github.com/rbsec/dnscan.git
pip3 install -r opt/tools/dnscan/requirements.txt

#winrm
gem install evil-winrm

#wifite (For wireless testing)
git clone https://github.com/kimocoder/wifite2.git 
pip install -r opt/tools/wifite2/requirements.txt

#AutoRecon
python3 -m pip install git+https://github.com/Tib3rius/AutoRecon.git

#NetExce
sudo apt install crackmapexec

#SecLists
git clone https://github.com/danielmiessler/SecLists.git

#Fierce
apt install fierce

#FinalWebRecon
git clone https://github.com/thewhiteh4t/FinalRecon.git
cd FinalRecon
pip3 install -r requirements.txt

