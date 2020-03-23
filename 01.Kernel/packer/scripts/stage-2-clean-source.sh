#!/bin/bash

# clean all
yum clean all

# Install vagrant default key
mkdir -pm 700 /home/vagrant/.ssh
curl -sL https://raw.githubusercontent.com/mitchellh/vagrant/master/keys/vagrant.pub -o /home/vagrant/.ssh/authorized_keys
chmod 0600 /home/vagrant/.ssh/authorized_keys
chown -R vagrant:vagrant /home/vagrant/.ssh


# Remove temporary files
sudo rm -rf linux-4.19.101
sudo rm linux-4.19.101.tar.xz
sudo rm -rf /tmp/*
sudo rm  -f /var/log/wtmp /var/log/btmp
sudo rm -rf /var/cache/* /usr/share/doc/*
sudo rm -rf /var/cache/yum
sudo rm -rf /vagrant/home/*.iso
sudo rm  -f ~/.bash_history
sudo rm -rf /root/rpmbuild/
history -c

sudo rm -rf /run/log/journal/*

# Fill zeros all empty space
sudo dd if=/dev/zero of=/EMPTY bs=1M
sudo rm -f /EMPTY
sync
echo "###   Hi from secone stage" >> /boot/grub2/grub.cfg
