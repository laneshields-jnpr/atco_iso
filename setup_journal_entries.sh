# Journal entries should persist accross reboots
echo "Persist Journal entries accross reboots..."

JOURNAL_CONF_DIR=/usr/lib/systemd/journald.conf.d
JOURNAL_CONF_FILE=$JOURNAL_CONF_DIR'/10-journald-defaults.conf'

chroot $INSTALLED_ROOT bash -c "mkdir -p $JOURNAL_CONF_DIR && \
echo -e '# Persist journal store across system reboots\n[Journal]\nStorage=persistent\n' >> $JOURNAL_CONF_FILE"
if [ $? -ne 0 ] ; then
     "Persist Journal entries FAILED!!!..."
fi
