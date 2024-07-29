#!/bin/sh

#
# Replicate initial state that anaconda would create on a native host install
# Required for image-based target install of Juniper SSR
#

# Based on sysconfig-ifcfg-scripts-gen from https://gist.github.com/mjf/a6a719a48eb496c97ae7
# Copyright (C) 2014 Matous J. Fialka, <http://mjf.cz/> Released under the terms of The MIT License

for ifdir in /sys/devices/pci*/*/*/net/*
do
   ifname=${ifdir##*/}
   ifuuid=$(< /proc/sys/kernel/random/uuid)
   ifcfg=/etc/sysconfig/network-scripts/ifcfg-$ifname

   if [ ! -e $ifcfg ]
   then
      cat > $ifcfg <<- EOT
TYPE=Ethernet
PROXY_METHOD=none
BROWSER_ONLY=no
BOOTPROTO=dhcp
DEFROUTE=yes
IPV4_FAILURE_FATAL=no
IPV6INIT=yes
IPV6_AUTOCONF=yes
IPV6_DEFROUTE=yes
IPV6_FAILURE_FATAL=no
IPV6_ADDR_GEN_MODE=stable-privacy
NAME=$ifname
UUID=$ifuuid
DEVICE=$ifname
ONBOOT=yes
EOT
   fi
done

# network file must be present, else ifcfg are not parsed by /etc/init.d/network
if [ ! -e /etc/sysconfig/network ]
then
   echo "# created by 128T-firstboot-setup" >> /etc/sysconfig/network
fi

# set up other misc network stub files
if [ ! -e /etc/hostname ]
then
   echo "localhost.localdomain" > /etc/hostname
fi
touch /etc/resolv.conf

# auto reserve memory for crash kernel
/usr/bin/enableCrashKernel

# root partition expansion
/usr/libexec/grow_root_part_128t.sh --force