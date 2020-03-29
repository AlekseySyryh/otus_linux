#!/bin/bash

mount -o remount,rw /sysroot
cat > /sysroot/penguin <<'msgend'
Hello! You are in dracut module!
 ___________________
< I'm dracut module >
 -------------------
   \
    \
        .--.
       |o_o |
       |:_/ |
      //   \ \
     (|     | )
    /'\_   _/`\
    \___)=(___/
msgend
mount -o remount,ro /sysroot
