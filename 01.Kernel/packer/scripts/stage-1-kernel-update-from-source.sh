#!/bin/bash

#Намеренно берем longterm ядро чтобы отличаться от прошлого варианта...
curl https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-4.19.101.tar.xz -O
tar xf linux-4.19.101.tar.xz
cd linux-4.19.101/
#Пакеты нужные для сборки
sudo yum update -y
sudo yum install rpm-build gcc bison flex bc elfutils-libelf-devel openssl-devel -y
#Копируем конфиг
sudo cp /boot/config-3.10.0-1062.9.1.el7.x86_64 .config
#Адаптируем
yes "" | make oldconfig
#Собираем пакеты
make rpm-pkg
#Ставим пакеты
sudo rpm -iUv ~/rpmbuild/RPMS/x86_64/*.rpm
# Remove older kernels (Only for demo! Not Production!)
rm -f /boot/*3.10*
# Update GRUB
grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-set-default 0
echo "Grub update done."
# Reboot VM
shutdown -r now
