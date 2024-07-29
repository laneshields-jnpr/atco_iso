#!/bin/bash
##########################################################################
#
# This wrapper file controls how often initialize128t is run on startup
# and alters the tty1 getty service to resume normal logins thereafter
# (currently regardless of the success or failure).
#
# This cannot be directly invoked as a bash script as it requires the
# template variable, 1 to be populated first
#
# WARNING!!!!!!!!!
# This file is as a mkiso.sh template.  The Bash escape character must be
# doubled -- '\\' instead of `\` for it to be effective.
#
##########################################################################
POST_INSTALL_LOG_PATH="/var/log/128T-iso"
TEMPLATE_MATCH="{{"
TEMPLATE_MATCH="${TEMPLATE_MATCH} POST_INSTALL_LOG_PATH }}"
if [ "${POST_INSTALL_LOG_PATH}" == "${TEMPLATE_MATCH}" ] ; then
    POST_INSTALL_LOG_PATH="/var/log/128T-iso"
fi
if [ "${POST_INSTALL_LOG_PATH:0:1}" == "/" ] ; then
    POST_INSTALL_LOG_PATH="${INSTALLED_ROOT}${POST_INSTALL_LOG_PATH}"
else
    POST_INSTALL_LOG_PATH="${INSTALLED_ROOT}/${POST_INSTALL_LOG_PATH}"
fi
LOGFILE="${POST_INSTALL_LOG_PATH}/first_boot.log"
if [ ! -d "${POST_INSTALL_LOG_PATH}" ] ; then
    mkdir -p "${POST_INSTALL_LOG_PATH}"
fi
printf "%s: starting...\n" >> "$0" "${LOGFILE}"

GETTY_TYPE='getty'
LOCAL_REPO_DIR=/etc/128technology/Packages
YUM_CERT_FILE=/etc/pki/128technology/release.pem
OVERRIDE_TTY="1"
if [ -z "$OVERRIDE_TTY" ] ; then
    OVERRIDE_TTY="1"
fi
# if the tty device is /dev/ttySN (SN since the tty prefix is not passed)
# use the serial systemd servies template
if [ ${OVERRIDE_TTY:0:1} == "S" ] ; then
    GETTY_TYPE='serial-getty'
fi
# This directory may benefit from being an mkiso.sh template variable,
# similar to ISO_OVERRIDE_TTY...
OVERRIDE_SOURCE_DIR="/usr/lib/systemd/system/${GETTY_TYPE}@tty${OVERRIDE_TTY}.service.d"

YUM_CONFIG_MANAGER=$(which yum-config-manager)
DISABLE_REPO_LIST=(base updates extras centosplus cr base-debuginfo fasttrack c7-media C7.* epel epel-debuginfo epel-testing*)

# Disable the specified repositories
if [ ${#DISABLE_REPO_LIST[@]} -ge 1 ] &&\
   [ "${DISABLE_REPO_LIST[0]}" == "{{" ] ; then
    DISABLE_REPO_LIST=()
fi
if [ ! -z "$YUM_CONFIG_MANAGER" ] ; then
    for repo in "${DISABLE_REPO_LIST[@]}" ; do
        # printf "$YUM_CONFIG_MANAGER --save --disable $repo\n"
        echo "$YUM_CONFIG_MANAGER --save --disable $repo" >> "${LOGFILE}"
        $YUM_CONFIG_MANAGER --save --disable "$repo" &> /dev/null
    done
fi

# Initializing the 2nd node in an HA paire requires that the 'HA/Management/Control'
# Interface be configured and active before initializing 128T...
stty sane
printf "run nmtui dialog...\n" >> "${LOGFILE}"
dialog --no-collapse --cr-wrap --colors --title "128T Installer" --yesno \
       "\\n      \\Zb\\Z0Configure Linux Networking\\n\\n      Before 128T SetUp?\\Z0\\ZB" 9 40
config_nw=$?
if [ $config_nw -eq 0 ] ; then
    printf "entering nmtui...\n" >> "${LOGFILE}"
    nmtui
    printf "nmtui exited...\n" >> "${LOGFILE}"
fi

if [ -d ${LOCAL_REPO_DIR} ] ; then
    # yum-config-manager --save --setopt=\*.skip_if_unavailable=True &> /dev/null
    printf "running 128T installer...\n" >> "${LOGFILE}"
    /usr/bin/install128t -a
else
    printf "running 128T initializer...\n" >> "${LOGFILE}"
    /usr/bin/initialize128t
fi
status=$?
printf "returned status: %s\n" "$status" >> "${LOGFILE}"

start_sw=1
if [ $status -eq 0 ] ; then
    printf "run start 128T dialog...\n" >> "${LOGFILE}"
    dialog --no-collapse --cr-wrap --colors --title "128T Installer Status" --yesno \
           "\\n      \\Zb\\Z2Install SUCCESS\\Z0\\ZB\\n\\n    Start 128T Router\\n    before proceeding to\\n    login prompt?" \
           10 32
    start_sw=$?
    echo "exit start 128T dialog, status=$start_sw" >> "${LOGFILE}"
else
    printf "run install failed dialog...\n" >> "${LOGFILE}"
    dialog --cr-wrap --no-collapse --colors --title "\\Z1 128T Installer Status" \\
           --msgbox "\\n\\n\\Z1  \\Zb\\Zr Install Failure Code=$status \\ZR\\ZB\\n\\n Enter OK for Login Prompt" \
           9 3
    printf "exit install failed dialog\n" >> "${LOGFILE}"
fi

# Enable retries for all repos if install128t was used
if [ -d ${LOCAL_REPO_DIR} ] ; then
    printf "cleanup after install128t...\n" >> "${LOGFILE}"
    #yum-config-manager --save --setopt=\*.skip_if_unavailable=False
    rm -f $YUM_CERT_FILE
fi

# clear any leftover kruft from dialog
clear

# start 128T if so desired...
if [ $start_sw -eq 0 ] ; then
    systemctl enable 128T &> /dev/null
    echo "enable service 128T, status=$?" >> "${LOGFILE}"
    systemctl start 128T &> /dev/null
    echo "start service 128T, status=$?" >> "${LOGFILE}"
fi

# restore original tty/console behavior
printf "disabling login override...\n" >> "${LOGFILE}"
rm -f ${OVERRIDE_SOURCE_DIR}/override.conf
systemctl daemon-reload
# systemctl stop followed by start[serial-]getty@tty$OVERRIDE_TTY.service
# does not work, systemctl restart [serial-]getty@tty$OVERRIDE_TTY.service
# is required instead.
systemctl restart ${GETTY_TYPE}@tty${OVERRIDE_TTY}.service
printf "%s: completed...\n" >> "$0" "${LOGFILE}"
