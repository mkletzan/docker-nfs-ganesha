# NFS-Ganesha Docker Container

[![Test](https://github.com/mkletzan/docker-nfs-ganesha/workflows/Test/badge.svg)](https://github.com/mkletzan/docker-nfs-ganesha/actions)
[![Container](https://ghcr-badge.egpl.dev/mkletzan/docker-nfs-ganesha/latest_tag?color=%2344cc11&ignore=latest&label=version&trim=)](https://github.com/mkletzan/docker-nfs-ganesha/pkgs/container/nfs-ganesha)

Containerized [NFS-Ganesha](https://github.com/nfs-ganesha/nfs-ganesha) server - a user-space NFS server implementation.

**Primary consumer:** [kubevirtci](https://github.com/kubevirt/kubevirtci) and other Kubernetes testing environments.

## Features

- 🚀 **User-space NFS** - No kernel modules required
- 🔒 **Minimal privileges** - Runs with capabilities only (DAC_OVERRIDE, DAC_READ_SEARCH)
- 📦 **Multiple platforms** - Docker, Podman, Kubernetes
- 🧪 **Fully tested** - Comprehensive functional tests
- 🛡️ **Security scanned** - Anchore Grype + SBOM generation

## Quick Start

### Docker

```bash
docker run -d \
  --name nfs-server \
  --cap-add DAC_OVERRIDE \
  --cap-add DAC_READ_SEARCH \
  -v /path/to/data:/data/nfs \
  -p 2049:2049 \
  -p 111:111 \
  -p 111:111/udp \
  ghcr.io/mkletzan/docker-nfs-ganesha:latest
```

### Podman

```bash
podman run -d \
  --name nfs-server \
  --cap-add DAC_OVERRIDE \
  --cap-add DAC_READ_SEARCH \
  -v /path/to/data:/data/nfs:z \
  -p 2049:2049 \
  -p 111:111 \
  -p 111:111/udp \
  ghcr.io/mkletzan/docker-nfs-ganesha:latest
```

### Kubernetes

```bash
kubectl apply -f https://raw.githubusercontent.com/mkletzan/docker-nfs-ganesha/main/docs/kubernetes.yaml
```

See [docs/kubernetes.yaml](docs/kubernetes.yaml) for full example.

## Configuration

Configure via environment variables:

| Variable | Default | Description |
|----------|---------|-------------|
| `EXPORT_PATH` | `/data/nfs` | Path to export via NFS |
| `PSEUDO_PATH` | `/` | NFSv4 pseudo path |
| `EXPORT_ID` | `0` | Numeric export ID |
| `PROTOCOLS` | `4` | NFS protocols (3, 4, or "3,4") |
| `TRANSPORTS` | `"UDP, TCP"` | Network transports |
| `SEC_TYPE` | `sys` | Security type |
| `SQUASH_MODE` | `No_Root_Squash` | Root squash mode |
| `GRACELESS` | `true` | Graceless recovery |
| `VERBOSITY` | `NIV_EVENT` | Log level (NIV_DEBUG, NIV_EVENT, NIV_WARN) |

Example with custom configuration:

```bash
docker run -d \
  --cap-add DAC_OVERRIDE \
  --cap-add DAC_READ_SEARCH \
  -e EXPORT_PATH=/exports \
  -e PROTOCOLS=4 \
  -e VERBOSITY=NIV_DEBUG \
  -v /my/data:/exports \
  -p 2049:2049 \
  ghcr.io/mkletzan/docker-nfs-ganesha:latest
```

## Mounting from Clients

### NFSv4.1 (Recommended)

```bash
# Linux
mount -t nfs4 -o vers=4.1 server-ip:/ /mnt/nfs

# macOS
mount -t nfs -o vers=4.1 server-ip:/ /mnt/nfs
```

### NFSv4.0

```bash
mount -t nfs4 -o vers=4.0 server-ip:/ /mnt/nfs
```

### NFSv4 Version Compatibility

| Version | Status | Notes |
|---------|--------|-------|
| NFSv4.1 | ✅ Supported | **Recommended** - Best feature set |
| NFSv4.0 | ✅ Supported | Works well |
| NFSv4.2 | ❌ Not supported | Mount fails with I/O error (v0.1.0) |
| NFSv3 | ⚠️ Limited | Available but not recommended |

**Note:** NFSv4.2 support is planned for v1.0.0 (CentOS Stream 10 migration).

## Networking

### Required Ports

| Port | Protocol | Purpose |
|------|----------|---------|
| 2049 | TCP/UDP | NFS |
| 111 | TCP/UDP | Portmapper (rpcbind) |
| 662 | TCP/UDP | Statd |
| 38465-38467 | TCP | Ganesha dynamic ports |

### Firewall Example

```bash
# UFW
ufw allow 2049/tcp
ufw allow 111/tcp
ufw allow 111/udp

# firewalld
firewall-cmd --permanent --add-service=nfs
firewall-cmd --permanent --add-service=rpc-bind
firewall-cmd --reload
```

## Examples

### Docker Compose

See [docker-compose.yml](docker-compose.yml) for a complete example.

```bash
# Start
docker-compose up -d

# View logs
docker-compose logs -f

# Stop
docker-compose down
```

### Kubernetes StatefulSet

For persistent NFS servers in Kubernetes, use a StatefulSet with persistent volumes:

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: nfs-ganesha
spec:
  serviceName: nfs-ganesha
  replicas: 1
  selector:
    matchLabels:
      app: nfs-ganesha
  template:
    metadata:
      labels:
        app: nfs-ganesha
    spec:
      containers:
      - name: nfs-ganesha
        image: ghcr.io/mkletzan/docker-nfs-ganesha:latest
        securityContext:
          capabilities:
            add:
            - DAC_OVERRIDE
            - DAC_READ_SEARCH
        volumeMounts:
        - name: nfs-data
          mountPath: /data/nfs
        ports:
        - containerPort: 2049
          name: nfs
        - containerPort: 111
          name: rpcbind
  volumeClaimTemplates:
  - metadata:
      name: nfs-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 10Gi
```

See [docs/kubernetes.yaml](docs/kubernetes.yaml) for complete examples.

## Building from Source

### Prerequisites

- Docker or Podman
- docker-compose (for tests)

### Build

```bash
# Clone repository
git clone https://github.com/mkletzan/docker-nfs-ganesha.git
cd nfs-ganesha

# Install build dependencies (Fedora)
make install-build-deps

# Build image
make build

# Run tests
make install-test-deps
make test

# Verbose test output
make test-verbose
```

### Build with Podman

```bash
podman build -t nfs-ganesha:latest .
```

## Testing

This project includes comprehensive functional tests:

- Service availability (showmount)
- NFSv4 mount operations
- File write operations
- File read operations
- Permission changes
- File deletion

Run tests:

```bash
make test
```

See [tests/README.md](tests/README.md) for details.

## Troubleshooting

### Container doesn't start

**Check logs:**
```bash
docker logs nfs-server
```

**Common issues:**
- Port 2049 already in use (another NFS server running)
- Insufficient capabilities (need DAC_OVERRIDE and DAC_READ_SEARCH)
- SELinux denials (Podman: use `:z` or `:Z` volume flags)

### Cannot mount from client

**Verify server is running:**
```bash
# Should show export list
showmount -e server-ip
```

**Check firewall:**
```bash
# From client
nc -zv server-ip 2049
nc -zv server-ip 111
```

**Try explicit version:**
```bash
# Force NFSv4.1
mount -t nfs4 -o vers=4.1 server-ip:/ /mnt/nfs
```

### Permission denied on mount

**Check export configuration:**
```bash
docker exec nfs-server cat /etc/ganesha/ganesha.conf
```

**Verify squash mode:**
- `No_Root_Squash` - Root on client = root on server (default)
- `Root_Squash` - Root on client = nobody on server
- `All_Squash` - All users = nobody on server

### SELinux issues (Podman)

**Relabel volumes:**
```bash
# Private relabel (recommended)
podman run -v /path/to/data:/data/nfs:z ...

# Shared relabel (multiple containers)
podman run -v /path/to/data:/data/nfs:Z ...
```

**Check denials:**
```bash
sudo ausearch -m avc -ts recent
```

## Versioning

This project uses [Semantic Versioning](https://semver.org/).

- **v0.x.x** - Pre-release versions (CentOS 7 base)
- **v1.x.x** - Stable releases (CentOS Stream 10+)

### Current Version: v0.1.0

- Base: CentOS 7
- NFS-Ganesha: 3.0
- NFSv4.1 and NFSv4.0 supported
- NFSv4.2 not supported

### Upcoming: v1.0.0

- Base: CentOS Stream 10
- NFS-Ganesha: Latest (5.x)
- Expected: NFSv4.2 support
- Modern packages and security updates

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Security

### Vulnerability Scanning

All images are scanned with [Anchore Grype](https://github.com/anchore/grype):
- Scan results in [GitHub Security](https://github.com/mkletzan/docker-nfs-ganesha/security)
- SBOM generated with [Syft](https://github.com/anchore/syft)
- Weekly automated rebuilds

### Required Capabilities

This container requires minimal Linux capabilities:
- `DAC_OVERRIDE` - Override file read/write/execute permissions
- `DAC_READ_SEARCH` - Override file/directory read and execute permissions

**No privileged mode required** - NFS-Ganesha is a user-space implementation.

### Reporting Vulnerabilities

Report security issues via [GitHub Security Advisories](https://github.com/mkletzan/docker-nfs-ganesha/security/advisories).

## Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run tests: `make test`
5. Submit a pull request

See [tests/README.md](tests/README.md) for testing guidelines.

## License

[MIT License](LICENSE)

## Related Projects

- [NFS-Ganesha](https://github.com/nfs-ganesha/nfs-ganesha) - Upstream project
- [kubevirtci](https://github.com/kubevirt/kubevirtci) - Primary consumer
- [KubeVirt](https://github.com/kubevirt/kubevirt) - Kubernetes virtualization

## Acknowledgments

- Built for [kubevirtci](https://github.com/kubevirt/kubevirtci)
- Powered by [NFS-Ganesha](https://nfs-ganesha.github.io/)
- Container maintained by the community
