# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-04-08

### Major Release: CentOS Stream 10 Migration

**Breaking Changes:**
- Base image: CentOS 7 → CentOS Stream 10
- NFS-Ganesha: 3.0 → 6.5 (LTS)
- Tini: v0.18.0 → v0.19.0
- Security: TCP-only transport by default (UDP disabled)

### Added
- CI/CD automation with GitHub Actions
- Multi-architecture support (amd64, arm64, s390x)
- Multi-stage Docker build for smaller images
- GPG verification of Tini binary
- Comprehensive CI/CD documentation
- Automated publishing to ghcr.io on version tags

### Changed
- Migrated to CentOS Stream 10 base image
- Updated NFS-Ganesha to 6.5 (stable LTS version)
- Security hardening: TCP-only by default, root squashing enabled
- Minimal dependencies: Only essential runtime packages
- Image optimization: 750MB → 627MB (16% reduction)
- Updated all documentation with correct repository URLs

### Fixed
- Repository metalink 404 errors (direct buildlogs.centos.org mirror)
- Healthcheck now uses `rpcinfo` instead of `showmount`

### Technical Details
- Base image: `quay.io/centos/centos:stream10`
- NFS-Ganesha: 6.5 (centos-release-nfs-ganesha6)
- Tini: v0.19.0 (GPG verified)
- Image size: ~627MB
- Runtime packages: nfs-ganesha, nfs-ganesha-vfs, rpcbind
- Build-only packages: gnupg2 (multi-stage build)

### Security
- TCP-only transport (UDP disabled by default)
- Root squashing enabled by default
- Minimal capabilities required (DAC_OVERRIDE, DAC_READ_SEARCH)
- No weak dependencies installed
- Multi-stage build isolates build-time dependencies

### Known Issues
- NFSv4.2 support: Not yet tested (was broken in v0.1.x)
  - Will be verified in subsequent patch release

## [0.1.2] - 2026-04-08

### Added
- Comprehensive documentation (README, CHANGELOG, examples)
- Kubernetes deployment examples (Deployment, StatefulSet, DaemonSet)
- Docker Compose production example
- Architecture documentation
- Environment variable reference

## [0.1.1] - 2026-04-08

### Added
- Testing foundation and build infrastructure
- Functional tests with NFSv4.1
- Makefile for build/test automation
- Multi-container test setup with docker-compose

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
   docker pull ghcr.io/mkletzan/docker-nfs-ganesha:1.0.0
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
     ghcr.io/mkletzan/docker-nfs-ganesha:1.0.0
   ```
5. **Verify mount** from clients

**Downtime:** Expected and acceptable (NFS clients will reconnect)

**Rollback:** Old images remain in ghcr.io - simply revert to v0.1.0 if needed

**Configuration:** No changes to environment variables or volume mounts

## Links

- [GitHub Repository](https://github.com/mkletzan/docker-nfs-ganesha)
- [Container Registry](https://github.com/mkletzan/docker-nfs-ganesha/pkgs/container/nfs-ganesha)
- [Issue Tracker](https://github.com/mkletzan/docker-nfs-ganesha/issues)
- [NFS-Ganesha Upstream](https://github.com/nfs-ganesha/nfs-ganesha)
