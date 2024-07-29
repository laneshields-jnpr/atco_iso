#########################################################################
#
# Installs the repo.rpm package which must be available in
# $CHROOT_REPO_DIR/repo.rpm
#
# This is not a standlone bash script, it is intended to be included by
# a kickstart file defining:
# - $INSTALLER_FILES
# - $INSTALLED_ROOT
#
#########################################################################
CHROOT_REPO_DIR=$INSTALLED_ROOT/tmp
PKGMGR="dnf"
# default package manager to yum if template variable not populated
TEMPLATE_MATCH="{{"
TEMPLATE_MATCH="${TEMPLATE_MATCH} ISO_PKGMGR }}"
if [ "${PKGMGR}" == "${TEMPLATE_MATCH}" ] ; then
    PKGMGR="yum"
fi

# process saltstack public key
echo "Install 128T package: repo.rpm"
cp -f $INSTALLER_FILES/downloads/repo.rpm $CHROOT_REPO_DIR/repo.rpm
chroot $INSTALLED_ROOT bash -c "${PKGMGR} -y install /tmp/repo.rpm"
if [ $? -ne 0 ] ; then
    printf "Failed to install repo.rpm to target disk!"
    exit 1
fi
