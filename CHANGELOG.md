# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Planned for v1.0.0
- Migrate to CentOS Stream 10 base image
- Update NFS-Ganesha to version 5.x
- NFSv4.2 support (expected fix)
- Modern package versions
- Enhanced security scanning
- CI/CD automation with GitHub Actions

## [0.1.0] - 2026-04-07

### Added
- Initial pre-release version
- CentOS 7 base image with vault.centos.org mirrors
- NFS-Ganesha 3.0 from CentOS SIG Storage
- NFSv4.1 and NFSv4.0 support
- Minimal capabilities (DAC_OVERRIDE, DAC_READ_SEARCH)
- Environment variable configuration
- Docker and Podman support
- Comprehensive functional tests
- Makefile for build/test automation
- Test infrastructure with docker-compose
- Quiet and verbose test modes
- Documentation for Docker, Podman, Kubernetes deployments

### Tested
- ✅ NFSv4.1 - Fully supported (recommended)
- ✅ NFSv4.0 - Fully supported
- ✅ Service discovery (showmount)
- ✅ Mount/unmount operations
- ✅ File write operations
- ✅ File read operations
- ✅ Permission changes
- ✅ File deletion

### Known Issues
- ❌ NFSv4.2 not supported (mount fails with I/O error)
  - Expected to be fixed in v1.0.0 with newer NFS-Ganesha and kernel
- CentOS 7 is EOL (June 2024)
  - Using vault.centos.org archived repositories
  - Migrating to CentOS Stream 10 in v1.0.0

### Technical Details
- Base image: `centos:7`
- NFS-Ganesha: 3.0 (centos-release-nfs-ganesha30)
- Tini: v0.18.0
- Image size: ~540MB

### Security
- Minimal Linux capabilities (no privileged mode)
- Manual security scanning recommended
- Automated scanning coming in v1.0.0

## Version History

- **v0.x.x** - Pre-release versions (CentOS 7)
- **v1.x.x** - Stable releases (CentOS Stream 10+)

## Migration Guides

### Upgrading from v0.1.0 to v1.0.0 (when released)

**Breaking changes expected:**
- Different base OS (CentOS 7 → Stream 10)
- NFS-Ganesha 3.0 → 5.x
- Different package versions

**Migration steps:**
1. **Backup data** - Ensure your NFS exports are backed up
2. **Stop old container:**
   ```bash
   docker stop nfs-server
   docker rm nfs-server
   ```
3. **Pull new image:**
   ```bash
   docker pull ghcr.io/USER/nfs-ganesha:1.0.0
   ```
4. **Start new container** with same configuration:
   ```bash
   docker run -d \
     --name nfs-server \
     --cap-add DAC_OVERRIDE \
     --cap-add DAC_READ_SEARCH \
     -v /path/to/data:/data/nfs \
     -p 2049:2049 \
     -p 111:111 \
     -p 111:111/udp \
     ghcr.io/USER/nfs-ganesha:1.0.0
   ```
5. **Verify mount** from clients

**Downtime:** Expected and acceptable (NFS clients will reconnect)

**Rollback:** Old images remain in ghcr.io - simply revert to v0.1.0 if needed

**Configuration:** No changes to environment variables or volume mounts

## Links

- [GitHub Repository](https://github.com/USER/nfs-ganesha)
- [Container Registry](https://github.com/USER/nfs-ganesha/pkgs/container/nfs-ganesha)
- [Issue Tracker](https://github.com/USER/nfs-ganesha/issues)
- [NFS-Ganesha Upstream](https://github.com/nfs-ganesha/nfs-ganesha)

---

**Note:** Replace `USER` with actual GitHub username.
