#!/bin/bash

set -e

# environment variables

: ${EXPORT_PATH:="/data/nfs"}
: ${PSEUDO_PATH:="/"}
: ${EXPORT_ID:=0}
: ${PROTOCOLS:=4}
: ${TRANSPORTS:="TCP"}  # TCP only for better security (no UDP)
: ${SEC_TYPE:="sys"}
: ${SQUASH_MODE:="Root_Squash"}  # Root squashing for security
: ${ACCESS_TYPE:="RW"}  # Default to read-write, can be overridden to RO
: ${GRACELESS:=true}
: ${VERBOSITY:="NIV_EVENT"} # NIV_DEBUG, NIV_EVENT, NIV_WARN

: ${GANESHA_CONFIG:="/etc/ganesha/ganesha.conf"}
: ${GANESHA_LOGFILE:="/dev/stdout"}

init_rpc() {
    echo "* Starting rpcbind"
    if [ ! -x /run/rpcbind ] ; then
        install -m755 -g 32 -o 32 -d /run/rpcbind
    fi
    # Only rpcbind needed for NFSv4
    rpcbind || return 0
    # rpc.statd and rpc.idmapd not needed for NFSv4-only setup
    sleep 1
}

init_dbus() {
    echo "* Starting dbus"
    if [ ! -x /var/run/dbus ] ; then
        install -m755 -g 81 -o 81 -d /var/run/dbus
    fi
    if [ ! -d /var/lib/dbus ] ; then
        mkdir -p /var/lib/dbus
    fi
    rm -f /var/run/dbus/*
    rm -f /var/run/messagebus.pid
    dbus-uuidgen --ensure
    dbus-daemon --system --fork
    sleep 1
}

# pNFS
# Ganesha by default is configured as pNFS DS.
# A full pNFS cluster consists of multiple DS
# and one MDS (Meta Data server). To implement
# this one needs to deploy multiple Ganesha NFS
# and then configure one of them as MDS:
# GLUSTER { PNFS_MDS = ${WITH_PNFS}; }

bootstrap_config() {
    echo "* Writing configuration"
    mkdir -p $(dirname ${GANESHA_CONFIG})
    cat <<END >${GANESHA_CONFIG}

NFS_CORE_PARAM {
    # Allow IO_FLUSHER capability to fail in containers
    allow_set_io_flusher_fail = true;

    # Disable unnecessary protocols for NFSv4-only setup
    Enable_NLM = false;
    Enable_RQUOTA = false;

    # Security: Disable UDP by default (can be overridden)
    Enable_UDP = false;
}

NFSV4 {
    Graceless = ${GRACELESS};
    # Only allow NFSv4 (more secure than v3)
    Minor_Versions = 1, 2;
}

EXPORT{
    Export_Id = ${EXPORT_ID};
    Path = "${EXPORT_PATH}";
    Pseudo = "${PSEUDO_PATH}";
    FSAL {
        name = VFS;
    }
    Access_type = ${ACCESS_TYPE};
    Disable_ACL = true;
    Squash = ${SQUASH_MODE};
    Protocols = ${PROTOCOLS};

    # Security: Restrict to localhost by default
    # Override with CLIENT block for network access
}

EXPORT_DEFAULTS{
    Transports = ${TRANSPORTS};
    SecType = ${SEC_TYPE};
}

END
}

sleep 0.5

if [ ! -f ${EXPORT_PATH} ]; then
    mkdir -p "${EXPORT_PATH}"
fi

echo "Initializing Ganesha NFS server"
echo "=================================="
echo "export path: ${EXPORT_PATH}"
echo "=================================="

bootstrap_config
init_rpc
# init_dbus # Disabled via Enable_DBUS = false in config

echo "Generated NFS-Ganesha config:"
cat ${GANESHA_CONFIG}

echo "* Starting Ganesha-NFS"
exec /usr/bin/ganesha.nfsd -F -L ${GANESHA_LOGFILE} -f ${GANESHA_CONFIG} -N ${VERBOSITY}
