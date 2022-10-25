#!/bin/bash

#Python 2 and 3 enviroment installer.

#Checking if script is running at root.
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

#Installing python
sudo apt install python2

#Printing Python installed version for visual check.
python2 --version
python3 --version


#Creating new executable python packages.
sudo update-alternatives --install /usr/bin/python python /usr/bin/python2 1
sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 2

#Command to select python version. Please take this command and add it to an alias for easy switching.
sudo update-alternatives --config python

