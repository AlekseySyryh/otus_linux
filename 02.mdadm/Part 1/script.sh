#!/bin/bash
mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
mdadm --create /dev/md0 -l 10 -n 5 /dev/sd{b,c,d,e,f}
parted -s /dev/md0 mklabel gpt
parted /dev/md0 mkpart xfs 0% 20%
parted /dev/md0 mkpart xfs 20% 40%
parted /dev/md0 mkpart xfs 40% 60%
parted /dev/md0 mkpart xfs 60% 80%
parted /dev/md0 mkpart xfs 80% 100%
for i in $(seq 1 5); do mkfs.xfs /dev/md0p$i; done
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do echo "/dev/md0p$i /raid/part$i xfs defaults 0 1" >> /etc/fstab; done
mount -a
mdadm --detail --scan > /etc/mdadm.conf
