#########################################################################
#
# Copies all package rpms and creates the 128tech-local repo
#
# This is not a standlone bash script, it is intended to be included by
# a kickstart file defining:
# - $INSTALLER_FILES
# - $INSTALLED_ROOT
#
#########################################################################
LOCAL_REPO=/var/lib/install128t/repos/saved/

echo "Create local repo directory"
chroot $INSTALLED_ROOT mkdir -p $LOCAL_REPO

echo "Copy packages to local repo"
cp $INSTALLER_FILES/Packages/*.rpm $INSTALLED_ROOT/$LOCAL_REPO

echo "Create repodata for localrepo"
chroot $INSTALLED_ROOT bash -c "createrepo_c ${LOCAL_REPO}"
if [ $? -ne 0 ] ; then
    printf "Failed to create local repo data"
    exit 1
fi
