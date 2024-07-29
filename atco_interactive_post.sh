# Stage vSRX image
mkdir -p $INSTALLED_ROOT/var/lib/128technology/plugins/vsrx-sfc
cp -f $INSTALLER_FILES/junos-vsrx3-x86-64-20.4R3-S1.3.qcow2 $INSTALLED_ROOT/var/lib/128technology/plugins/vsrx-sfc/

LOGFILE=$INSTALLED_ROOT/root/atco_initializer_post.log

# State initializer preferences
cpu_cores=`nproc --all`
if [[ $cpu_cores -eq 8 ]]; then
    echo "This system is considered as Medium Site, has $cpu_cores cpu cores" 2>&1  >> $LOGFILE
    cp $INSTALLER_FILES/initializer-preferences-medium.json $INSTALLED_ROOT/etc/128technology/initializer-preferences.json
else
    echo "System has $cpu_cores cpu cores, will use default values for huge pages" 2>&1  >> $LOGFILE
    cp $INSTALLER_FILES/initializer-preferences.json $INSTALLED_ROOT/etc/128technology/initializer-preferences.json
fi

ip l show enp0s20f0 2>&1 >> $LOGFILE
if [ $? -eq 0 ]; then
  TEST7573=1
else
  TEST7573=0
fi

ip l show enp8s0f0 2>&1 >> $LOGFILE
if [ $? -eq 0 ]; then
  TEST1515_128T=1
else
  TEST1515_128T=0
fi

ip l show em4 2>&1 > /dev/null
if [ $? -eq 0 ]; then
  TESTVEP1400=1
else
  TESTVEP1400=0
fi

ip l show enp0s0f2 2>&1 > /dev/null
if [ $? -eq 0 ]; then
  TESTVEP4600=1
else
  TESTVEP4600=0
fi

ip l show ens3f0 2>&1 > /dev/null
if [ $? -eq 0 ]; then
  TESTHPDL380=1
else
  TESTHPDL380=0
fi

ip l show enp0s3 2>&1 > /dev/null
if [ $? -eq 0 ]; then
  TESTVM=1
else
  TESTVM=0
fi

echo "TEST7573=$TEST7573" >> $LOGFILE
echo "TEST1515_128T=$TEST1515_128T" >> $LOGFILE
echo "TESTVEP1400=$TESTVEP1400" >> $LOGFILE
echo "TESTVEP4600=$TESTVEP4600" >> $LOGFILE
echo "TESTHPDL380=$TESTHPDL380" >> $LOGFILE
echo "TESTVM=$TESTVM" >> $LOGFILE

if [[ $(($TEST7573 + $TEST1515_128T + $TESTVEP1400 + $TESTVEP4600 + $TESTHPDL380 + $TESTVM)) -eq 0 ]]; then
    echo "This system didn't register as a known system, exiting" >> $LOGFILE
    exit 1
fi

if [[ $(($TEST7573 + $TEST1515_128T + $TESTVEP1400 + $TESTVEP4600 + $TESTHPDL380 + $TESTVM)) -gt 1 ]]; then
    echo "Somehow this system registered more than one known system, exiting" >> $LOGFILE
    exit 1
fi

if [[ $TEST7573 -eq 1 ]]; then
    echo "This system appears to be a Lanner 7573" >> $LOGFILE
    # port 2, wan is port 1
    export STAGING_INT=enp0s20f1
fi

if [[ $TEST1515_128T -eq 1 ]]; then
    echo "This system appears to be a Lanner 1515 with 128T BIOS" >> $LOGFILE
    # port 4
    export STAGING_INT=enp2s0f3
fi

if [[ $TESTVEP1400 -eq 1 ]]; then
    echo "This system appears to be a Dell VEP14xx" >> $LOGFILE
    # port 5
    export STAGING_INT=em5
fi

if [[ $TESTHPDL380 -eq 1 ]]; then
    echo "This system appears to be an HP DL380" >> $LOGFILE
    export STAGING_INT=ens3f0
fi

echo "Disabling DHCP for all interfaces..." >> $LOGFILE
sed -i 's/BOOTPROTO=dhcp/BOOTPROTO=none/' $INSTALLED_ROOT/etc/sysconfig/network-scripts/ifcfg-* 2>&1 >> $LOGFILE

echo "Re-Enabling DHCP for staging interface..." >> $LOGFILE
sed -i 's/BOOTPROTO=none/BOOTPROTO=dhcp/' $INSTALLED_ROOT/etc/sysconfig/network-scripts/ifcfg-$STAGING_INT 2>&1 >> $LOGFILE

echo "Disabling ONBOOT for all interfaces..." >> $LOGFILE
sed -i 's/ONBOOT=yes/ONBOOT=no/' $INSTALLED_ROOT/etc/sysconfig/network-scripts/ifcfg-* 2>&1 >> $LOGFILE

echo "Re-Enabling ONBOOT for staging interface..." >> $LOGFILE
sed -i 's/ONBOOT=no/ONBOOT=yes/' $INSTALLED_ROOT/etc/sysconfig/network-scripts/ifcfg-$STAGING_INT 2>&1 >> $LOGFILE

echo "Setting metric on staging interface lower than kni254 metric" >> $LOGFILE
cat >> $INSTALLED_ROOT/etc/NetworkManager/conf.d/default-metrics.conf << EOF
[connection-$STAGING_INT]
match-device=$STAGING_INT
ipv4.route-metric=5
EOF

echo "Customizing bash history settings" >> $LOGFIE
cat >> $INSTALLED_ROOT/etc/profile << EOF
#Bash history customization
PROMPT_COMMAND="history -a;$PROMPT_COMMAND"
HISTSIZE=20000
HISTTIMEFORMAT='%F %T '
EOF

echo "Staging rc.local to finish installation on next boot" >> $LOGFILE
########################################################################
cat 2>> $LOGFILE 1>> $INSTALLED_ROOT/etc/rc.d/rc.local << _EOF_
###128T_POST_INSTALL_ADDED###
export LOGFILE=/root/first_boot.log
echo "Running rc.local on first boot after bootstrap rebooted" >> \$LOGFILE

serial_number=`dmidecode --string system-serial-number` 2>&1 >> \$LOGFILE
echo "Setting hostname and minion_id to \${serial_number^^}" >> \$LOGFILE
hostnamectl set-hostname \${serial_number^^} 2>&1 >> \$LOGFILE
echo \${serial_number^^} > /etc/salt/minion_id 

initialize128t -p /etc/128technology/initializer-preferences.json 2>&1 >> \$LOGFILE

systemctl enable 128T 2>&1 >> \$LOGFILE
systemctl disable rc-local 2>&1 >> \$LOGFILE
chmod a-x /etc/rc.d/rc.local 2>&1 >> \$LOGFILE
sed -i '/###128T_POST_INSTALL_ADDED###/,\$d' /etc/rc.d/rc.local 2>&1 >> \$LOGFILE

sync;sync
reboot
reboot -f
_EOF_
########################################################################
chmod +x $INSTALLED_ROOT/etc/rc.d/rc.local 2>&1 >> $LOGFILE
echo "post installer script finished" >> $LOGFILE
