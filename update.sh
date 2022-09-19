#!/bin/bash

#Checking if script is running at root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#cating source list to ensure kali sources are within the correct repo
cat /etc/apt/sources.list

#Checking if you want to update repos
echo "Do you want to update repos continue?(yes/no)"
read input
if [ "$input" == "yes" ]
then
apt update 
fi
if [ "$input" == "no" ]
then exit 1
echo "continue"
fi
#Checking if you want to upgrade packages
echo "Do you want to upgrade packages continue?(yes/no)"
if [ "$input" == "yes" ]
then
apt upgrade
fi
if [ "$input" == "no" ]
then exit 1
echo "continue"
fi
#checking if you want to remove packages
echo "Do you want to auto remove packages?(yes/no)"
if [ "$input" == "yes" ]
then
apt-get autoremove
fi
if [ "$input" == "no" ]
then exit 1
echo "continue"
fi
done