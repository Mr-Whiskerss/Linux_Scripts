#!/bin/bash

shopt -s nocasematch

#Checking if script is running at root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#cating source list to ensure kali sources are within the correct repo
cat /etc/apt/sources.list

#Checking if you want to update repos
echo "Do you want to update repos continue?(Y/N)"
read input
if [[ "{$input}" == *"y"* ]]
then
apt update 
fi
if [[ "{$input}" == *"n"* ]]
then exit 1
echo "continue"
fi
#Checking if you want to upgrade packages
echo "Do you want to upgrade packages continue?(Y/N)"
read input
if [[ "{$input}" == *"y"* ]]
then
apt -y upgrade
fi
if [[ "{$input}" == *"n"* ]]
then exit 1
echo "continue"
fi
#Checking if you want to upgrade the distribution?
echo "Do you want to upgrade packages continue?(Y/N)"
read input
if [[ "{$input}" == *"y"* ]]
then
apt -y dist-upgrade
fi
if [[ "{$input}" == *"n"* ]]
then exit 1
echo "continue"
fi
#checking if you want to remove packages
echo "Do you want to auto remove packages?(Y/N)"
read input
if [[ "{$input}" == *"y"* ]]
then
apt-get -y autoremove
fi
if [[ "{$input}" == *"n"* ]]
then exit 1
echo "continue"
fi
done
