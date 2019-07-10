#!/bin/sh

. /lib/dracut-lib.sh


local IMAGE_URL='http://192.168.122.1:8080/fedora-coreos-30-metal.raw.gz'
if [ ! -z "$IMAGE_URL" ]
then
    echo "preset image_url to $IMAGE_URL" >> /tmp/debug
    echo $IMAGE_URL >> /tmp/image_url
fi

local DEST_DEV='sda'
if [ ! -z "$DEST_DEV" ]
then
    echo "preset install dev to $DEST_DEV" >> /tmp/debug
    echo $DEST_DEV >> /tmp/selected_dev
fi

local IGNITION_URL='http://192.168.122.1:8080/base.ign'
if [ ! -z "$IGNITION_URL" ]
then
    echo "preset ignition url to $IGNITION_URL" >> /tmp/debug
    echo $IGNITION_URL >> /tmp/ignition_url
fi


# Kernel networking args
# Currently only persisting `ipv6.disable`, but additional options may be added
# in the future
# https://github.com/torvalds/linux/blob/master/Documentation/networking/ipv6.txt
declare -a KERNEL_NET_ARGS=("ipv6.disable=")
# Dracut networking args
# Parse all args (other than rd.neednet) and persist those into /tmp/networking_opts
# List from https://www.mankier.com/7/dracut.cmdline#Description-Network
local NETWORKING_ARGS="rd.neednet=1"
declare -a DRACUT_NET_ARGS=("ip=" "ifname=" "rd.route=" "bootdev=" "BOOTIF=" "rd.bootif=" "nameserver=" "rd.peerdns=" "biosdevname=" "vlan=" "bond=" "team=" "bridge=")
for NET_ARG in "${KERNEL_NET_ARGS[@]}" "${DRACUT_NET_ARGS[@]}"
do
    NET_OPT=$(getarg $NET_ARG)
    if [ ! -z "$NET_OPT" ]
    then
        echo "persist $NET_ARG to $NET_OPT" >> /tmp/debug
        NETWORKING_ARGS+=" ${NET_ARG}${NET_OPT}"
    fi
done
# only write /tmp/networking_opts if additional networking options have been specified
# as the default in ignition-dracut specifies `rd.neednet=1 ip=dhcp` when no options are persisted
if [ "${NETWORKING_ARGS}" != "rd.neednet=1" ]
then
    echo "persisting network options: ${NETWORKING_ARGS}" >> /tmp/debug
    echo "${NETWORKING_ARGS}" >> /tmp/networking_opts
fi

if getargbool 0 coreos.inst.skip_media_check
then
    echo "Asserting skip of media check" >> /tmp/debug
    echo 1 > /tmp/skip_media_check
fi

# This one is not consumed by the CLI but actually by the
# coreos-installer.service systemd unit that is run in the
# initramfs. We don't default to rebooting from the CLI.
if getargbool 0 coreos.inst.skip_reboot
then
    echo "Asserting reboot skip" >> /tmp/debug
    echo 1 > /tmp/skip_reboot
fi

if [ "$(getarg coreos.inst=)" = "yes" ]; then
    # Suppress initrd-switch-root.service from starting
    rm -f /etc/initrd-release
    # Suppress most console messages for the installer to run without interference
    dmesg -n 1
fi
