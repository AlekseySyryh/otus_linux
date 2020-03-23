# Перенос на RAID 1

## Подготовка

В Vagrantfile создаем диск равный по размеру изначальному.

    	:disks => {
    		:sata1 => {
    			:dfile => '../sata1.vdi',
    			:size => 40960,
    			:port => 1
    		}
    	}	

Выносим файл с диском за пределы папки с Vagrantfile, т.к. при инициализации будет делаться rsync этой папки в образ машины, что нам явно не нужно...

Запускаемся...

    [root@otuslinux vagrant]# lsblk -f
    NAME   FSTYPE LABEL UUID                                 MOUNTPOINT
    sda                                                      
    └─sda1 xfs          8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                      
    [root@otuslinux vagrant]# cat /etc/fstab 
    
    #
    # /etc/fstab
    # Created by anaconda on Sat Jun  1 17:13:31 2019
    #
    # Accessible filesystems, by reference, are maintained under '/dev/disk'
    # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
    #
    UUID=8ac075e3-1124-4bb6-bef7-a6811bf8b870 /                       xfs     defaults        0 0
    /swapfile none swap defaults 0 0


Мне не нравится, что swap реализован в виде файла в основной ФС. Получается что этот файл также будет перенесен, на RAID1, что звучит как плохая идея. Для swap нам нужна скорость, пусть даже ценой надежности, а не наоборот. Пусть он будет в RAID0



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
    End? -1GB                                                                 
    (parted) set                                                              
    Partition number? 1                                                       
    Flag to Invert? raid                                                      
    New state?  [on]/off?                                                     
    (parted) mkpart                                                           
    Partition type?  primary/extended? p                                      
    File system type?  [ext2]?                                                
    Start? -1GB                                                               
    End? 100%                                                                 
    (parted) set                                                              
    Partition number? 2                                                       
    Flag to Invert? raid                                                      
    New state?  [on]/off?                                                     
    (parted) p                                                                
    Model: ATA VBOX HARDDISK (scsi)
    Disk /dev/sdb: 42,9GB
    Sector size (logical/physical): 512B/512B
    Partition Table: msdos
    Disk Flags: 
    
    Number  Start   End     Size    Type     File system  Flags
     1      1049kB  41,9GB  41,9GB  primary               raid
     2      41,9GB  42,9GB  1000MB  primary               raid
    
    (parted) q                                                                
    Information: You may need to update /etc/fstab.

Проверяем результат

    [root@otuslinux vagrant]# lsblk -f
    NAME   FSTYPE LABEL UUID                                 MOUNTPOINT
    sda                                                      
    └─sda1 xfs          8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                      
    ├─sdb1                                                   
    └─sdb2   

### Создаем RAID 1 для основного раздела

Используем --metadata=0.90, т.к. mdadm предупреждает что в противном случае могут быть проблемы с загрузкой...

    [root@otuslinux vagrant]# mdadm --create /dev/md0 --metadata=0.90 --level=1 --raid-devices=2 /dev/sdb1 missing
    mdadm: array /dev/md0 started.
    [root@otuslinux vagrant]# cat /proc/mdstat 
    Personalities : [raid1] 
    md0 : active raid1 sdb1[0]
          40965056 blocks [2/1] [U_]
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md0
    /dev/md0:
               Version : 0.90
         Creation Time : Sun Feb  9 18:23:38 2020
            Raid Level : raid1
            Array Size : 40965056 (39.07 GiB 41.95 GB)
         Used Dev Size : 40965056 (39.07 GiB 41.95 GB)
          Raid Devices : 2
         Total Devices : 1
       Preferred Minor : 0
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 18:23:38 2020
                 State : clean, degraded 
        Active Devices : 1
       Working Devices : 1
        Failed Devices : 0
         Spare Devices : 0
    
    Consistency Policy : resync
    
                  UUID : 85877555:cfe0bf1b:8ed4a3a1:9f626544 (local to host otuslinux)
                Events : 0.1
    
        Number   Major   Minor   RaidDevice State
           0       8       17        0      active sync   /dev/sdb1
           -       0        0        1      removed

Итак у нас есть дерградировавший RAID1 раздел. Пора его заполнять.

### Создаем раздел внутри RAID для размещения ОС

    [root@otuslinux vagrant]# parted /dev/md0
    GNU Parted 3.1
    Using /dev/md0
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) mklabel msdos                                                    
    (parted) mkpart
    Partition type?  primary/extended? p                                      
    File system type?  [ext2]? xfs                                            
    Start? 0%                                                                 
    End? 100%                                                                 
    (parted) set                                                              
    Partition number? 1                                                       
    Flag to Invert? boot                                                      
    New state?  [on]/off?                                                     
    (parted) p                                                                
    Model: Linux Software RAID Array (md)
    Disk /dev/md0: 41,9GB
    Sector size (logical/physical): 512B/512B
    Partition Table: msdos
    Disk Flags: 
    
    Number  Start   End     Size    Type     File system  Flags
     1      1049kB  41,9GB  41,9GB  primary               boot
    
    (parted) q                                                                
    Information: You may need to update /etc/fstab.

Проверяем

    [root@otuslinux vagrant]# lsblk -f                                        
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      xfs                     8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                                      
    ├─sdb1      linux_raid_member       85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                  
    │   └─md0p1                                                              
    └─sdb2                                                                   
    

### Создаем ФС

    [root@otuslinux vagrant]# mkfs.xfs /dev/md0p1
    meta-data=/dev/md0p1             isize=512    agcount=4, agsize=2560192 blks
             =                       sectsz=512   attr=2, projid32bit=1
             =                       crc=1        finobt=0, sparse=0
    data     =                       bsize=4096   blocks=10240768, imaxpct=25
             =                       sunit=0      swidth=0 blks
    naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
    log      =internal log           bsize=4096   blocks=5000, version=2
             =                       sectsz=512   sunit=0 blks, lazy-count=1
    realtime =none                   extsz=4096   blocks=0, rtextents=0
    

Проверяем

    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      xfs                     8ac075e3-1124-4bb6-bef7-a6811bf8b870 /
    sdb                                                                      
    ├─sdb1      linux_raid_member       85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                  
    │   └─md0p1 xfs                     26fa185a-1062-448f-a5c3-3f01733d28d1 
    └─sdb2                                                                   

### Копируем данные

    [root@otuslinux vagrant]# swapoff /swapfile
    [root@otuslinux vagrant]# rm -f /swapfile 
    [root@otuslinux vagrant]# mount /dev/md0p1 /mnt
    [root@otuslinux vagrant]# cp -rxa / /mnt

### Переключаемся на новый диск

    [root@otuslinux vagrant]# mount --bind /proc /mnt/proc
    [root@otuslinux vagrant]# mount --bind /dev /mnt/dev
    [root@otuslinux vagrant]# mount --bind /sys /mnt/sys
    [root@otuslinux vagrant]# mount --bind /run /mnt/run
    [root@otuslinux vagrant]# chroot /mnt/

### Правим /etc/fstab

    [root@otuslinux /]# vi /etc/fstab
    [root@otuslinux /]# cat /etc/fstab 
    
    #
    # /etc/fstab
    # Created by anaconda on Sat Jun  1 17:13:31 2019
    #
    # Accessible filesystems, by reference, are maintained under '/dev/disk'
    # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
    #
    UUID=26fa185a-1062-448f-a5c3-3f01733d28d1	/	xfs	defaults	0 0
    
### Сохраним конфиг RAID

    [root@otuslinux /]# mdadm --detail --scan > /etc/mdadm.conf

### Модифицируем загрузчик

    [root@otuslinux /]# cp /boot/initramfs-$(uname -r).img /boot/initramfs-$(uname -r).img.bck
    [root@otuslinux /]# dracut --mdadmconf --fstab --add="mdraid" --filesystems "xfs" --add-drivers="raid0 raid1" --force /boot/initramfs-$(uname -r).img $(uname -r) -M
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

После перезагрузки 

    [vagrant@otuslinux ~]$ lsblk -f
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    └─sda1      xfs                     8ac075e3-1124-4bb6-bef7-a6811bf8b870 
    sdb                                                                      
    ├─sdb1      linux_raid_member       85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                  
    │   └─md0p1 xfs                     26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2                                                                   

Корневая ФС смонтирована в /dev/md0p1. Все идет по плану.


### Переразмечаем /dev/sda по новому.

    [root@otuslinux vagrant]# parted /dev/sda
    GNU Parted 3.1
    Using /dev/sda
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) mklabel msdos                                                    
    (parted) mkpart                                                           
    Partition type?  primary/extended? p                                      
    File system type?  [ext2]?                                                
    Start? 0%                                                                 
    End? -1GB                                                                 
    (parted) set                                                              
    Partition number? 1                                                       
    Flag to Invert? raid                                                      
    New state?  [on]/off?                                                     
    (parted) mkpart                                                           
    Partition type?  primary/extended? p                                      
    File system type?  [ext2]?                                                
    Start? -1GB                                                               
    End? 100%                                                                 
    (parted) set                                                              
    Partition number? 2                                                       
    Flag to Invert? raid                                                      
    New state?  [on]/off?                                                     
    (parted) p                                                                
    Model: ATA VBOX HARDDISK (scsi)
    Disk /dev/sda: 42,9GB
    Sector size (logical/physical): 512B/512B
    Partition Table: msdos
    Disk Flags: 
    
    Number  Start   End     Size    Type     File system  Flags
     1      1049kB  41,9GB  41,9GB  primary               raid
     2      41,9GB  42,9GB  1000MB  primary               raid
    
    (parted) q                                                                
    Information: You may need to update /etc/fstab.

Проверяем

    [root@otuslinux vagrant]# lsblk -f                                        
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    ├─sda1                                                                   
    └─sda2                                                                   
    sdb                                                                      
    ├─sdb1      linux_raid_member       85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                  
    │   └─md0p1 xfs                     26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2                                                                   
    
### Добавляем раздел в RAID

    [root@otuslinux vagrant]# mdadm /dev/md0 --add /dev/sda1
    mdadm: hot added /dev/sda1

Смотрим результат

    [root@otuslinux vagrant]# cat /proc/mdstat
    Personalities : [raid1] 
    md0 : active raid1 sda1[2] sdb1[0]
          40965056 blocks [2/1] [U_]
          [>....................]  recovery =  1.1% (464256/40965056) finish=13.0min speed=51584K/sec
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md0
    /dev/md0:
               Version : 0.90
         Creation Time : Sun Feb  9 18:23:38 2020
            Raid Level : raid1
            Array Size : 40965056 (39.07 GiB 41.95 GB)
         Used Dev Size : 40965056 (39.07 GiB 41.95 GB)
          Raid Devices : 2
         Total Devices : 2
       Preferred Minor : 0
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 18:39:10 2020
                 State : clean, degraded, recovering 
        Active Devices : 1
       Working Devices : 2
        Failed Devices : 0
         Spare Devices : 1
    
    Consistency Policy : resync
    
        Rebuild Status : 9% complete
    
                  UUID : 85877555:cfe0bf1b:8ed4a3a1:9f626544 (local to host otuslinux)
                Events : 0.124
    
        Number   Major   Minor   RaidDevice State
           0       8       17        0      active sync   /dev/sdb1
           2       8        1        1      spare rebuilding   /dev/sda1
    
Все в порядке, RAID чинится... Некоторое время спустя...

    [root@otuslinux vagrant]# cat /proc/mdstat
    Personalities : [raid1] 
    md0 : active raid1 sda1[1] sdb1[0]
          40965056 blocks [2/2] [UU]
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md0
    /dev/md0:
               Version : 0.90
         Creation Time : Sun Feb  9 18:23:38 2020
            Raid Level : raid1
            Array Size : 40965056 (39.07 GiB 41.95 GB)
         Used Dev Size : 40965056 (39.07 GiB 41.95 GB)
          Raid Devices : 2
         Total Devices : 2
       Preferred Minor : 0
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 18:42:35 2020
                 State : clean 
        Active Devices : 2
       Working Devices : 2
        Failed Devices : 0
         Spare Devices : 0
    
    Consistency Policy : resync
    
                  UUID : 85877555:cfe0bf1b:8ed4a3a1:9f626544 (local to host otuslinux)
                Events : 0.156
    
        Number   Major   Minor   RaidDevice State
           0       8       17        0      active sync   /dev/sdb1
           1       8        1        1      active sync   /dev/sda1
    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL UUID                                 MOUNTPOINT
    sda                                                                      
    ├─sda1                                                                   
    │ └─md0                                                                  
    │   └─md0p1 xfs                     26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sda2                                                                   
    sdb                                                                      
    ├─sdb1      linux_raid_member       85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                  
    │   └─md0p1 xfs                     26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2                                                                   
    
    
Починился.

### Правим загрузчик на /dev/sda

    [root@otuslinux vagrant]# grub2-install /dev/sda
    Installing for i386-pc platform.
    Installation finished. No error reported.

### Чиним swap.

Делаем RAID0

    [root@otuslinux vagrant]# mdadm --create /dev/md1 --level=0 --raid-devices=2 /dev/sda2 /dev/sdb2
    mdadm: Defaulting to version 1.2 metadata
    mdadm: array /dev/md1 started.

Проверяем

    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL       UUID                                 MOUNTPOINT
    sda                                                                            
    ├─sda1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sda2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
    sdb                                                                            
    ├─sdb1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
    [root@otuslinux vagrant]# cat /proc/mdstat
    Personalities : [raid1] [raid0] 
    md1 : active raid0 sdb2[1] sda2[0]
          1949696 blocks super 1.2 512k chunks
          
    md0 : active raid1 sda1[1] sdb1[0]
          40965056 blocks [2/2] [UU]
          
    unused devices: <none>
    [root@otuslinux vagrant]# mdadm -D /dev/md1
    /dev/md1:
               Version : 1.2
         Creation Time : Sun Feb  9 18:44:10 2020
            Raid Level : raid0
            Array Size : 1949696 (1904.00 MiB 1996.49 MB)
          Raid Devices : 2
         Total Devices : 2
           Persistence : Superblock is persistent
    
           Update Time : Sun Feb  9 18:44:10 2020
                 State : clean 
        Active Devices : 2
       Working Devices : 2
        Failed Devices : 0
         Spare Devices : 0
    
            Chunk Size : 512K
    
    Consistency Policy : none
    
                  Name : otuslinux:1  (local to host otuslinux)
                  UUID : 808bbfad:6f044e99:be95114a:c8c6f564
                Events : 0
    
        Number   Major   Minor   RaidDevice State
           0       8        2        0      active sync   /dev/sda2
           1       8       18        1      active sync   /dev/sdb2
    

Обновим конфигурацию RAID

    [root@otuslinux vagrant]# mdadm --detail --scan > /etc/mdadm.conf
    [root@otuslinux vagrant]# cat /etc/mdadm.conf 
    ARRAY /dev/md0 metadata=0.90 UUID=79772435:2bc33578:8ed4a3a1:9f626544
    ARRAY /dev/md1 metadata=1.2 name=otuslinux:1 UUID=39145ad8:da9a8757:47940798:532e81d2

Делаем раздел swap

    [root@otuslinux vagrant]# parted /dev/md1
    GNU Parted 3.1
    Using /dev/md1
    Welcome to GNU Parted! Type 'help' to view a list of commands.
    (parted) mklabel msdos
    (parted) mkpart                                                           
    Partition type?  primary/extended? p                                      
    File system type?  [ext2]? linux-swap                                     
    Start? 0%                                                                 
    End? 100%                                                                 
    (parted) p                                                                
    Model: Linux Software RAID Array (md)
    Disk /dev/md1: 1996MB
    Sector size (logical/physical): 512B/512B
    Partition Table: msdos
    Disk Flags: 
    
    Number  Start   End     Size    Type     File system  Flags
     1      1049kB  1996MB  1995MB  primary
    
    (parted) q                                                                
    Information: You may need to update /etc/fstab.
    
    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL       UUID                                 MOUNTPOINT
    sda                                                                            
    ├─sda1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sda2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1                                                                    
    sdb                                                                            
    ├─sdb1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1                                                                    

Делаем swap

    [root@otuslinux vagrant]# mkswap /dev/md1p1
    Setting up swapspace version 1, size = 1948668 KiB
    no label, UUID=2e8ac389-1e4a-4557-81c1-9373d427aa2c
    [root@otuslinux vagrant]# lsblf -f
    bash: lsblf: command not found
    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL       UUID                                 MOUNTPOINT
    sda                                                                            
    ├─sda1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sda2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1 swap                          2e8ac389-1e4a-4557-81c1-9373d427aa2c 
    sdb                                                                            
    ├─sdb1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1 swap                          2e8ac389-1e4a-4557-81c1-9373d427aa2c 

        
Правим /etc/fstab

    [root@otuslinux vagrant]# vi /etc/fstab 
    [root@otuslinux vagrant]# cat /etc/fstab 
    
    #
    # /etc/fstab
    # Created by anaconda on Sat Jun  1 17:13:31 2019
    #
    # Accessible filesystems, by reference, are maintained under '/dev/disk'
    # See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
    #
    UUID=26fa185a-1062-448f-a5c3-3f01733d28d1	/	xfs	defaults	0 0
    UUID=2e8ac389-1e4a-4557-81c1-9373d427aa2c	none	swap	defaults	0 0
    
Включаем swap

    [root@otuslinux vagrant]# swapon /dev/md1p1
    
Проверяем

                  total        used        free      shared  buff/cache   available
    Mem:           991M         85M        791M        6,7M        113M        763M
    Swap:          1,9G          0B        1,9G
    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL       UUID                                 MOUNTPOINT
    sda                                                                            
    ├─sda1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sda2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1 swap                          2e8ac389-1e4a-4557-81c1-9373d427aa2c [SWAP]
    sdb                                                                            
    ├─sdb1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1 swap                          2e8ac389-1e4a-4557-81c1-9373d427aa2c [SWAP]
    
Перезагружаемся

    [root@otuslinux vagrant]# reboot
    
После перезагрузки все продолжает работать.

    [root@otuslinux vagrant]# free -h
                  total        used        free      shared  buff/cache   available
    Mem:           991M         86M        723M        6,7M        181M        738M
    Swap:          1,9G          0B        1,9G
    [root@otuslinux vagrant]# lsblk -f
    NAME        FSTYPE            LABEL       UUID                                 MOUNTPOINT
    sda                                                                            
    ├─sda1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sda2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1 swap                          2e8ac389-1e4a-4557-81c1-9373d427aa2c [SWAP]
    sdb                                                                            
    ├─sdb1      linux_raid_member             85877555-cfe0-bf1b-8ed4-a3a19f626544 
    │ └─md0                                                                        
    │   └─md0p1 xfs                           26fa185a-1062-448f-a5c3-3f01733d28d1 /
    └─sdb2      linux_raid_member otuslinux:1 808bbfad-6f04-4e99-be95-114ac8c6f564 
      └─md1                                                                        
        └─md1p1 swap                          2e8ac389-1e4a-4557-81c1-9373d427aa2c [SWAP]
    [root@otuslinux vagrant]# cat /proc/mdstat
    Personalities : [raid1] [raid0] 
    md1 : active raid0 sdb2[1] sda2[0]
          1949696 blocks super 1.2 512k chunks
          
    md0 : active raid1 sdb1[0] sda1[1]
          40965056 blocks [2/2] [UU]
          
    unused devices: <none>
    
