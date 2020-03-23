#!/bin/bash

sudo yum install bzip2 -y
sudo mkdir cd
sudo mount /home/vagrant/VBoxGuestAdditions.iso cd
cd cd
sudo ./VBoxLinuxAdditions.run
