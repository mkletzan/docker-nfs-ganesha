# NFS-Ganesha Container Architecture

This document explains how the NFS-Ganesha container works internally.

## Overview

NFS-Ganesha is a **user-space NFS server** implementation. Unlike kernel-based NFS servers, it doesn't require kernel modules or privileged mode to operate.

```
┌─────────────────────────────────────────────────┐
│              Container (User Space)             │
│                                                 │
│  ┌───────────────────────────────────────────┐ │
│  │         ganesha.nfsd (main process)       │ │
│  │  - Handles NFS protocol (v3, v4.0, v4.1)  │ │
│  │  - File operations via VFS FSAL           │ │
│  │  - No kernel modules needed               │ │
│  └───────────────────────────────────────────┘ │
│           ▲              ▲                      │
│           │              │                      │
│  ┌────────┴────┐  ┌──────┴──────┐             │
│  │   rpcbind   │  │    dbus     │             │
│  │  (port 111) │  │  (IPC bus)  │             │
│  └─────────────┘  └─────────────┘             │
│                                                 │
│  Volume Mount: /data/nfs                        │
│  ├── (exported files)                          │
│  └── (user data)                               │
└─────────────────────────────────────────────────┘
         │                    │
         │                    │
    [Port 2049]          [Port 111]
    NFS Protocol       RPC Portmapper
         │                    │
         ▼                    ▼
    ┌────────────────────────────┐
    │      NFS Clients           │
    │  (mount -t nfs4 ...)       │
    └────────────────────────────┘
```

## Startup Sequence

The container follows this initialization sequence:

### 1. Tini Init (PID 1)

```
ENTRYPOINT ["/tini", "--"]
CMD ["/start_nfs.sh"]
```

[Tini](https://github.com/krallin/tini) is a minimal init system that:
- Reaps zombie processes
- Forwards signals properly
- Ensures clean shutdown

### 2. Start Script (`/start_nfs.sh`)

The startup script executes in this order:

```bash
1. init_rpc()
   ├── Create /run/rpcbind directory
   ├── Start rpcbind (portmapper)
   ├── Start rpc.statd (NFS lock state)
   └── Start rpc.idmapd (NFSv4 ID mapping)

2. init_dbus()
   ├── Create /var/run/dbus directory
   ├── Generate D-Bus UUID
   └── Start dbus-daemon (for Ganesha IPC)

3. bootstrap_config()
   ├── Create /etc/ganesha directory
   └── Generate /etc/ganesha/ganesha.conf from env vars

4. Launch NFS-Ganesha
   └── exec ganesha.nfsd -F -L /dev/stdout -f /etc/ganesha/ganesha.conf
```

### 3. Service Dependencies

```
rpcbind (port 111)
    │
    ├─→ Required for NFS protocol
    └─→ Maps RPC program numbers to ports

dbus-daemon
    │
    ├─→ Required for Ganesha admin interface
    └─→ IPC between Ganesha components

ganesha.nfsd
    │
    ├─→ Main NFS server process
    ├─→ Binds to port 2049 (NFS)
    ├─→ Reads /etc/ganesha/ganesha.conf
    └─→ Exports /data/nfs via VFS FSAL
```

## Configuration

### Environment Variables

Configuration is dynamic, generated at startup from environment variables:

```bash
EXPORT_PATH=${EXPORT_PATH:-/data/nfs}
PSEUDO_PATH=${PSEUDO_PATH:-/}
PROTOCOLS=${PROTOCOLS:-4}
SQUASH_MODE=${SQUASH_MODE:-No_Root_Squash}
VERBOSITY=${VERBOSITY:-NIV_EVENT}
```

### Generated Config File

`/etc/ganesha/ganesha.conf` is generated on each container start:

```
NFSV4 {
    Graceless = true;
}

EXPORT {
    Export_Id = 0;
    Path = "/data/nfs";
    Pseudo = "/";
    
    FSAL {
        name = VFS;
    }
    
    Access_type = RW;
    Disable_ACL = true;
    Squash = No_Root_Squash;
    Protocols = 4;
}

EXPORT_DEFAULTS {
    Transports = UDP, TCP;
    SecType = sys;
}
```

## FSAL (Filesystem Abstraction Layer)

NFS-Ganesha uses **VFS FSAL** (Virtual File System):

```
┌──────────────────────────────────────┐
│         NFS-Ganesha                  │
│  ┌────────────────────────────────┐  │
│  │     VFS FSAL Plugin            │  │
│  │  (libfsalvfs.so)               │  │
│  │                                │  │
│  │  Maps NFS operations to:       │  │
│  │  - open(), read(), write()     │  │
│  │  - stat(), chmod(), chown()    │  │
│  │  - mkdir(), rmdir(), unlink()  │  │
│  └────────────────────────────────┘  │
│              │                        │
│              ▼                        │
│     Linux VFS (kernel)                │
│              │                        │
│              ▼                        │
│       Filesystem (ext4, xfs, etc)    │
│              │                        │
│              ▼                        │
│       /data/nfs (volume mount)       │
└──────────────────────────────────────┘
```

**Why VFS FSAL?**
- Works with any Linux filesystem (ext4, xfs, btrfs, etc.)
- Simple and reliable
- No special storage backend needed
- Direct filesystem operations

**Alternatives not used:**
- GPFS FSAL - IBM Spectrum Scale
- Ceph FSAL - Ceph storage
- Gluster FSAL - GlusterFS
- RGW FSAL - Ceph RADOS Gateway

## Security Model

### Capabilities vs Privileged Mode

**This container does NOT use `--privileged`**

Instead, it uses minimal Linux capabilities:

```yaml
cap_add:
  - DAC_OVERRIDE     # Override read/write/execute permission checks
  - DAC_READ_SEARCH  # Override read and execute permission checks
```

**Why these capabilities?**
- NFS servers need to access files on behalf of clients
- Client UID/GID may not match server filesystem permissions
- These capabilities allow NFS-Ganesha to bypass permission checks

**Security benefits:**
- No full privileged access
- No access to kernel modules
- No access to host devices
- Minimal attack surface

### Root Squashing

Controls how root (UID 0) on clients is treated:

```
Client          Server Filesystem
------          -----------------

No_Root_Squash:
root (0)   →    root (0)        [Less secure, more convenient]

Root_Squash:
root (0)   →    nobody (65534)  [More secure, recommended]
user (1000) →   user (1000)

All_Squash:
root (0)   →    nobody (65534)  [Most secure, read-only use]
user (1000) →   nobody (65534)
```

## Networking

### Port Mapping

```
Container Port    Protocol    Purpose
--------------    --------    -------
111              TCP/UDP      RPC Portmapper (rpcbind)
2049             TCP/UDP      NFS protocol
662              TCP/UDP      NFS statd (locking)
38465-38467      TCP          Ganesha dynamic ports
```

### NFSv4 vs NFSv3

**NFSv4 advantages:**
- Single port (2049) - easier firewalls
- Better performance
- Built-in locking (no separate lockd)
- Pseudo filesystem (clean mount points)

**NFSv3 considerations:**
- Multiple ports (need portmapper)
- Separate statd/lockd processes
- Less efficient
- Legacy compatibility

**This container defaults to NFSv4 only.**

## File Handle Management

```
Client Request           NFS-Ganesha              Filesystem
--------------          ------------              ----------

1. LOOKUP /data/file
                    →   VFS FSAL stat()
                    ←   inode 12345
                    
2. Generate file handle
                        [Export ID | Inode | Device]
                    ←   FH: 0x00:0001e240:0x0801
                    
3. Return to client
    ←               

4. Client caches FH

5. READ FH 0x00:...
                    →   Resolve FH to inode
                    →   VFS FSAL read()
                    ←   data
    ←
```

**File handles persist across:**
- Container restarts (if using same filesystem)
- NFS-Ganesha restarts
- Client reconnections

**File handles break if:**
- Filesystem changes (different device)
- Export path changes
- Export ID changes

## Health Checks

### Docker Health Check

```bash
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD showmount -e localhost || exit 1
```

Verifies:
- ✅ NFS-Ganesha is running
- ✅ rpcbind is responding
- ✅ Exports are accessible

### Kubernetes Probes

```yaml
livenessProbe:
  exec:
    command: ["showmount", "-e", "localhost"]
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  exec:
    command: ["showmount", "-e", "localhost"]
  initialDelaySeconds: 5
  periodSeconds: 10
```

## Volume Management

### Docker Volume

```bash
docker run -v /host/data:/data/nfs ...
```

```
Host FS: /host/data
    │
    ├── file1.txt
    └── dir/
        └── file2.txt

Container: /data/nfs
    │
    ├── file1.txt (bind mount)
    └── dir/
        └── file2.txt

NFS Export: server:/
    │
    ├── file1.txt (via NFS)
    └── dir/
        └── file2.txt
```

### Kubernetes PersistentVolume

```yaml
volumeClaimTemplates:
  - metadata:
      name: nfs-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

Data persists across pod restarts on the same node.

## Performance Considerations

### I/O Path

```
NFS Client
    ↓ (network)
NFS-Ganesha (user space)
    ↓ (syscalls: read/write)
Linux VFS
    ↓
Filesystem (ext4/xfs)
    ↓
Block Device
    ↓
Storage (disk/SSD)
```

**Bottlenecks:**
1. Network bandwidth
2. User-space overhead (vs kernel NFS)
3. Filesystem performance
4. Storage I/O

**Optimizations:**
- Use local SSD for volumes
- NFSv4.1 for better caching
- TCP transport for large files
- Tune `VERBOSITY` (less logging = better performance)

## Troubleshooting

### Check Ganesha is running

```bash
docker exec nfs-server ps aux | grep ganesha
```

### View configuration

```bash
docker exec nfs-server cat /etc/ganesha/ganesha.conf
```

### Check RPC registration

```bash
docker exec nfs-server rpcinfo -p localhost
```

Should show:
- portmapper (100000)
- nfs (100003)
- mountd (100005)
- nlockmgr (100021)

### Debug logs

```bash
# Start with debug logging
docker run -e VERBOSITY=NIV_DEBUG ...

# View logs
docker logs -f nfs-server
```

## Limitations

### Current (v0.1.0)

- ❌ NFSv4.2 not supported (I/O error on mount)
- ❌ Single export per container
- ❌ No Kerberos authentication
- ❌ No pNFS (parallel NFS)
- ❌ No NFS over RDMA

### Planned (v1.0.0+)

- ✅ NFSv4.2 support (expected with newer Ganesha)
- ⚠️ Multi-export (possible but complex)
- ⚠️ Kerberos (requires KDC configuration)

## References

- [NFS-Ganesha Documentation](https://github.com/nfs-ganesha/nfs-ganesha/wiki)
- [NFS-Ganesha FSAL Documentation](https://github.com/nfs-ganesha/nfs-ganesha/wiki/FSAL)
- [Linux Capabilities](https://man7.org/linux/man-pages/man7/capabilities.7.html)
- [NFSv4 RFC](https://datatracker.ietf.org/doc/html/rfc7530)
