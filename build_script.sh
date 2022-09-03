#!/bin/bash

#Checking if script is running at root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

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


# Distribution Upgrade
echo "=================================="
echo "Distribution Upgrade"
echo "=================================="
sudo apt-get dist-upgrade

#The following commands will install common tools used within my personal kali install. More will be updated as I progress (2022)
#Install common global tools please feel free to add or remove tools from here this is personal preference
apt-get install htop iftop python3-pip python2 seclists terminator -y 

#create new tools directory and report directory for kali on first boot
mkdir /opt/tools
mkdir /home/kali/Documents/Reports
mkdir /home/kali/Documents/Reports/Reports_in_progress


#cd into new directory 
cd /opt/tools

#Enum4linux-ng
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
git clone https://github.com/carlospolop/privilege-escalation-awesome-scripts-suite.git

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
pip3 install -r opt/tools/wifite2/requirements.txt



