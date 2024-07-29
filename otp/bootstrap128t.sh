#!/bin/bash

set -x

echo "Begin 128T bootstrapping"
/usr/bin/bootstrap128t run

systemctl disable 128T-bootstrap

echo "Rebooting after 128T bootstrapping"
reboot
