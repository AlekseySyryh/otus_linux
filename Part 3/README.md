# Перенос на RAID 1

## Подготовка

В Vagrantfile создаем диск равный изначальному.



    	:disks => {
    		:sata1 => {
    			:dfile => '../sata1.vdi',
    			:size => 40960,
    			:port => 1
    		}
    	}	


Запускаемся...



    [root@otuslinux vagrant]# lsblk -f
    NAME   FSTYPE LABEL UUID                                 MOUNTPOINT
    sda                                                      
    └─sda1 xfs          8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                      

## Часть 1. Создаем на свободном диске Degraded RAID 1

### Создаем раздел для Raid



    [root@otuslinux vagrant]# parted /dev/sdb
    GNU Parted 3.1
    Using /dev/sdb
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) mklabel msdos
    (parted) mkpart                                                           
    Partition type?  primary/extended? p                                      
    File system type?  [ext2]? 
    Start? 0%                                                                 
    End? 100%                                                                 
    (parted) set                                                              
    Partition number? 1                                                       
    Flag to Invert? raid                                                      
    New state?  [on]/off?                                                     
    (parted) p                                                                
    Model: ATA VBOX HARDDISK (scsi)
    Disk /dev/sdb: 42,9GB
    Sector size (logical/physical): 512B/512B
    Partition Table: msdos
    Disk Flags: 
    
    Number  Start   End     Size    Type     File system  Flags
     1      1049kB  42,9GB  42,9GB  primary               raid
    
    (parted) q                                                                

Проверяем результат



    [root@otuslinux vagrant]# mdadm --create /dev/md0 --metadata=0.90 --level=1 --raid-devices=2 missing /dev/sdb1
    mdadm: array /dev/md0 started.
    
    [root@otuslinux vagrant]# cat /proc/mdstat 
    Personalities : [raid1] 
    md0 : active raid1 sdb1[1]
          41941952 blocks [2/1] [_U]
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md0 
    /dev/md0:
               Version : 0.90
         Creation Time : Sun Feb  9 12:32:58 2020
            Raid Level : raid1
            Array Size : 41941952 (40.00 GiB 42.95 GB)
         Used Dev Size : 41941952 (40.00 GiB 42.95 GB)
          Raid Devices : 2
         Total Devices : 1
       Preferred Minor : 0
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 12:32:58 2020
                 State : clean, degraded 
        Active Devices : 1
       Working Devices : 1
        Failed Devices : 0
         Spare Devices : 0
    
    Consistency Policy : resync
    
                  UUID : de5d9f28:b54ebbf0:8ed4a3a1:9f626544 (local to host otuslinux)
                Events : 0.1
    
        Number   Major   Minor   RaidDevice State
           -       0        0        0      removed
           1       8       17        1      active sync   /dev/sdb1


### Создаем раздел внутри RAID для размещения ОС



    [root@otuslinux vagrant]# parted /dev/md0 
    GNU Parted 3.1
    Using /dev/md0
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) mklabel msdos                                                    
    (parted) mkpart
    Partition type?  primary/extended?                                        
    Partition type?  primary/extended? primary                                
    File system type?  [ext2]? xfs                                            
    Start? 0%                                                                 
    End? 100%                                                                 
    (parted) set                                                              
    Partition number? 1                                                       
    Flag to Invert? boot                                                      
    New state?  [on]/off?                                                     
    (parted) q     

Проверяем

    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      xfs                     8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                                      
    └─sdb1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 

 ### Создаем ФС



    [root@otuslinux vagrant]# mkfs.xfs /dev/md0p1
    meta-data=/dev/md0p1             isize=512    agcount=4, agsize=2621248 blks
             =                       sectsz=512   attr=2, projid32bit=1
             =                       crc=1        finobt=0, sparse=0
    data     =                       bsize=4096   blocks=10484992, imaxpct=25
             =                       sunit=0      swidth=0 blks
    naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
    log      =internal log           bsize=4096   blocks=5119, version=2
             =                       sectsz=512   sunit=0 blks, lazy-count=1
    realtime =none                   extsz=4096   blocks=0, rtextents=0
	
Проверяем
	


    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      xfs                     8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                                      
    └─sdb1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 xfs                     00390fe5-05a5-4bcf-9956-053d5856ca24 

### Копируем данные



    [root@otuslinux vagrant]# mount /dev/md0p1 /mnt
    [root@otuslinux vagrant]# cp -rxa / /mnt

### Переключаемся на новый диск



    [root@otuslinux vagrant]# mount --bind /proc /mnt/proc
    [root@otuslinux vagrant]# mount --bind /dev /mnt/dev
    [root@otuslinux vagrant]# mount --bind /sys /mnt/sys
    [root@otuslinux vagrant]# mount --bind /run /mnt/run
    [root@otuslinux vagrant]# chroot /mnt/

### Правим /etc/fstab


    [root@otuslinux /]# cat /etc/fstab 
    #
    # /etc/fstab
    # Created by anaconda on Sat Jun  1 17:13:31 2019
    #
    # Accessible filesystems, by reference, are maintained under '/dev/disk'
    # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
    #
    UUID=8ac075e3-1124-4bb6-bef7-a6811bf8b870 /                       xfs     defaults        0 0
    /swapfile none swap defaults 0 0
    [root@otuslinux /]# vi /etc/fstab 
    [root@otuslinux /]# cat /etc/fstab 
    #
    # /etc/fstab
    # Created by anaconda on Sat Jun  1 17:13:31 2019
    #
    # Accessible filesystems, by reference, are maintained under '/dev/disk'
    # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
    #
    UUID=00390fe5-05a5-4bcf-9956-053d5856ca24 /                       xfs     defaults        0 0
    /swapfile none swap defaults 0 0

### Модифицируем загрузчик



    [root@otuslinux /]# mdadm --detail --scan > /etc/mdadm.conf
    [root@otuslinux /]# cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bck
    [root@otuslinux /]# dracut --mdadmconf --fstab --add="mdraid" --filesystems "xfs" --add-drivers="raid1" --force /boot/initramfs-$(uname -r).img $(uname -r) -M
    bash
    nss-softokn
    i18n
    kernel-modules
    mdraid
    qemu
    rootfs-block
    terminfo
    udev-rules
    biosdevname
    systemd
    usrmount
    base
    fs-lib
    shutdown
    [root@otuslinux /]# echo 'GRUB_CMDLINE_LINUX="rd.auto rd.auto=1 rhgb quiet"' >> /etc/default/grub 
    [root@otuslinux /]# echo 'GRUB_PRELOAD_MODULES="mdraid1x"' >> /etc/default/grub
    [root@otuslinux /]# grub2-mkconfig -o /boot/grub2/grub.cfg
    Generating grub configuration file ...
    /usr/sbin/grub2-probe: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    Found linux image: /boot/vmlinuz-3.10.0-957.12.2.el7.x86_64
    Found initrd image: /boot/initramfs-3.10.0-957.12.2.el7.x86_64.img
    /usr/sbin/grub2-probe: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    /usr/sbin/grub2-probe: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    /usr/sbin/grub2-probe: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    /usr/sbin/grub2-probe: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    done
    [root@otuslinux /]# grub2-install /dev/sdb
    Installing for i386-pc platform.
    grub2-install: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    grub2-install: warning: Couldn't find physical volume `(null)'. Some modules may be missing from core image..
    Installation finished. No error reported.

### Перезагружаемся во вновь созданный раздел


    [root@otuslinux /]# exit
    [root@otuslinux vagrant]# reboot
    В Virtualbox F12->AHCI controller->2) Hard disk

## Часть 2. Добиваем старый раздел/делаем нормальный RAID


    [root@otuslinux vagrant]# lsblk -fb
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      xfs                     8ac075e3-1124-4bb6-bef7-a6811bf8b870 
    sdb                                                                      
    └─sdb1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 xfs                     00390fe5-05a5-4bcf-9956-053d5856ca24 /

### Говорим что у нас в /dev/sda1 теперь RAID

    [root@otuslinux vagrant]# parted /dev/sda
    GNU Parted 3.1
    Using /dev/sda
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) set                                                              
    Partition number? 1                                                       
    Flag to Invert? raid                                                      
    New state?  [on]/off?                                                     
    (parted) q 

### Добавляем раздел в RAID



    [root@otuslinux vagrant]# mdadm /dev/md0 --add /dev/sda1
    mdadm: hot added /dev/sda1

Смотрим результат



    [root@otuslinux vagrant]# cat /proc/mdstat 
    Personalities : [raid1] 
    md0 : active raid1 sda1[2] sdb1[1]
          41941952 blocks [2/1] [_U]
          [>....................]  recovery =  3.6% (1524608/41941952) finish=8.3min speed=80242K/sec
          
    unused devices: <none>
    
    [root@otuslinux vagrant]# lsblk -fb                                 
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 xfs                     00390fe5-05a5-4bcf-9956-053d5856ca24 /
    sdb                                                                      
    └─sdb1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 xfs                     00390fe5-05a5-4bcf-9956-053d5856ca24 /

Все в порядке, RAID чинится... Некоторое время спустя...



    [root@otuslinux vagrant]# cat /proc/mdstat 
    Personalities : [raid1] 
    md0 : active raid1 sda1[2] sdb1[1]
          41941952 blocks [2/1] [_U]
          [==========>..........]  recovery = 51.6% (21658240/41941952) finish=1.8min speed=185872K/sec
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md0
    /dev/md0:
               Version : 0.90
         Creation Time : Sun Feb  9 12:32:58 2020
            Raid Level : raid1
            Array Size : 41941952 (40.00 GiB 42.95 GB)
         Used Dev Size : 41941952 (40.00 GiB 42.95 GB)
          Raid Devices : 2
         Total Devices : 2
       Preferred Minor : 0
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 12:58:51 2020
                 State : clean, degraded, recovering 
        Active Devices : 1
       Working Devices : 2
        Failed Devices : 0
         Spare Devices : 1
    
    Consistency Policy : resync
    
        Rebuild Status : 73% complete
    
                  UUID : de5d9f28:b54ebbf0:8ed4a3a1:9f626544 (local to host otuslinux)
                Events : 0.188
    
        Number   Major   Minor   RaidDevice State
           2       8        1        0      spare rebuilding   /dev/sda1
           1       8       17        1      active sync   /dev/sdb1
		   
Еще чинится...



    [root@otuslinux vagrant]# cat /proc/mdstat 
    Personalities : [raid1] 
    md0 : active raid1 sda1[0] sdb1[1]
          41941952 blocks [2/2] [UU]
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md0
    /dev/md0:
               Version : 0.90
         Creation Time : Sun Feb  9 12:32:58 2020
            Raid Level : raid1
            Array Size : 41941952 (40.00 GiB 42.95 GB)
         Used Dev Size : 41941952 (40.00 GiB 42.95 GB)
          Raid Devices : 2
         Total Devices : 2
       Preferred Minor : 0
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 12:59:51 2020
                 State : clean 
        Active Devices : 2
       Working Devices : 2
        Failed Devices : 0
         Spare Devices : 0
    
    Consistency Policy : resync
    
                  UUID : de5d9f28:b54ebbf0:8ed4a3a1:9f626544 (local to host otuslinux)
                Events : 0.196
    
        Number   Major   Minor   RaidDevice State
           0       8        1        0      active sync   /dev/sda1
           1       8       17        1      active sync   /dev/sdb1
    
    [root@otuslinux vagrant]# lsblk -fb
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 xfs                     00390fe5-05a5-4bcf-9956-053d5856ca24 /
    sdb                                                                      
    └─sdb1      linux_raid_member       de5d9f28-b54e-bbf0-8ed4-a3a19f626544 
      └─md0                                                                  
        └─md0p1 xfs                     00390fe5-05a5-4bcf-9956-053d5856ca24 /
    
Починился.

### Правим загрузчик на /dev/sda



    [root@otuslinux vagrant]# grub2-install /dev/sda
    Installing for i386-pc platform.
    Installation finished. No error reported.
    
    [root@otuslinux vagrant]# reboot

После перезагрузки все продолжает работать.

