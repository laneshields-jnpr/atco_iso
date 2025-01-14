###############################################################################
#
# Setup SSH access (disable root logins via SSH)
#
###############################################################################
RESULT=`chroot $INSTALLED_ROOT su - t128 -c "whoami"`
if [ $? -eq 0 ] ; then
    echo "Allow SSH root login: 'yes'"
    chroot $INSTALLED_ROOT sed -E -i  's/^#?PermitRootLogin.*/permitRootLogin yes/g' /etc/ssh/sshd_config
    if [ $? -eq 0 ] ; then
        echo "Disable SUCCESS!"
    else
        echo "Disable FAILED!!!"
    fi
else
    echo "Unable to 'su - t128' SSH root login remains!!!"
fi
