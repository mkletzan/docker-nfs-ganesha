# Claude Code Project Context

This document contains important context about this project that isn't visible from the code itself but is essential for understanding and maintaining it.

## GitHub Settings & Configuration

### Branch Protection Rules (master)

The `master` branch has protection rules configured in GitHub UI:

- **Require pull request before merging**: Yes
- **Require status checks to pass**: Yes
  - Required checks: Test (amd64), Test (arm64)
- **Require branches to be up to date**: Yes
- **Require conversation resolution**: Yes
- **Include administrators**: Yes

### GitHub Actions Permissions

Configured in Settings → Actions → General:

- **Workflow permissions**: Read and write permissions
- **Allow GitHub Actions to create and approve pull requests**: Disabled

### Environments

**Production environment** (used by release workflow):
- Required for: Release workflow when pushing tags
- Protection rules: None currently configured
- Secrets: None (uses GITHUB_TOKEN)

### Secrets

No custom secrets required. The project uses only:
- `GITHUB_TOKEN` - Automatically provided by GitHub Actions

## Security Policies

### Action Version Pinning

**Policy**: All GitHub Actions MUST be pinned to specific commit SHAs (not version tags).

**Rationale**: Prevents supply chain attacks where action maintainers could push malicious code to a version tag.

**Format**: 
```yaml
uses: owner/action@<40-char-sha> # vX.Y.Z
```

**Finding correct SHAs**:
1. Go to the action's GitHub repository
2. Navigate to the Releases page
3. Click on the version tag
4. Copy the commit SHA from the URL or commit details

Example:
- ❌ `uses: actions/checkout@v4`
- ❌ `uses: actions/checkout@v4.1.0`  
- ✅ `uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2`

**Verified action versions (as of 2026-04-21)**:
- actions/checkout: `de0fac2e4500dabe0009e67214ff5f5447ce83dd` (v6.0.2)
- actions/upload-artifact: `ea165f8d65b6e75b540449e92b4886f43607fa02` (v4.6.2)
- actions/download-artifact: `d3f86a106a0bac45b974a628896c90dbdf5c8093` (v4.3.0)
- docker/build-push-action: `bcafcacb16a39f128d818304e6c9c0c18556b85f` (v7.1.0)
- docker/setup-qemu-action: `ce360397dd3f832beb865e1373c09c0e9f86d70a` (v4.0.0)
- docker/setup-buildx-action: `4d04d5d9486b7bd6fa91e7baf45bbb4f8b9deedd` (v4.0.0)
- docker/login-action: `4907a6ddec9925e35a0a9e82d7399ccc52663121` (v4.1.0)
- docker/metadata-action: `030e881283bb7a6894de51c315a6bfe6a94e05cf` (v6.0.0)
- anchore/sbom-action: `e22c389904149dbc22b58101806040fa8d37a610` (v0.24.0)
- anchore/scan-action: `e1165082ffb1fe366ebaf02d8526e7c4989ea9d2` (v7.4.0)
- github/codeql-action/upload-sarif: `ce64ddcb0d8d890d2df4a9d1c04ff297367dea2a` (v3.35.2)

### Dependency Management

**Base Image**: `quay.io/centos/centos:stream10`
- CentOS Stream 10 provides rolling updates
- Weekly rebuilds capture security patches
- Monitor CentOS Stream announcements for breaking changes

**NFS-Ganesha**: Installed from CentOS Stream 10 repositories
- Version: 6.x (as of v1.0.0)
- Package: `nfs-ganesha-vfs`
- Updates: Applied during weekly rebuilds

## CI/CD Pipeline

### Workflow Triggers

**Test Workflow** (`test.yml`):
- Trigger: Push to master, pull requests
- Runs: Multi-arch tests (amd64, arm64) + security scan
- Does NOT push images

**Release Workflow** (`release.yml`):
- Trigger: Push of tags matching `v*`
- Runs: Tests → Build/Push → Security scan
- Pushes to: ghcr.io (GitHub Container Registry)

### Multi-Architecture Support

**Supported architectures**:
- `linux/amd64` (x86_64)
- `linux/arm64` (ARM 64-bit)

**NOT supported**:
- `linux/s390x` (IBM Z) - Reason: No nfs-ganesha-6 packages available for CentOS Stream 10 on s390x

This is documented in:
- `docs/cicd-setup.md`
- GitHub issue or discussion (if created)

## Registry Configuration

### GitHub Container Registry (ghcr.io)

**Current registry**: `ghcr.io/mkletzan/docker-nfs-ganesha`

**Package visibility**: Public
- Set in: GitHub → Repository → Packages → Package settings
- Must be manually changed to public after first push

**Authentication**: Uses `GITHUB_TOKEN`
- Automatically provided by GitHub Actions
- No manual secret configuration needed

### Quay.io Container Registry

**Current registry**: `quay.io/nertpinx/nfs-ganesha`

**Package visibility**: Public

**Authentication**: Uses robot account
- Secret name: `QUAY_IO_USERNAME`
- Secret name: `QUAY_IO_TOKEN`
- Set in: GitHub → Settings → Secrets and variables → Actions

**Features**:
- Server-side security scanning with Clair
- Continuous vulnerability monitoring
- Automatic rescanning when new CVEs published
- Web UI for viewing scan results

**Setup**: See [docs/quay-setup.md](docs/quay-setup.md) for complete configuration guide

### Image Tags

Tag pattern for release `v1.2.3`:
- `1.2.3` (exact version)
- `1.2` (minor version)
- `1` (major version)
- `latest` (only if on default branch)

All tags point to the same multi-arch manifest.

## Version Strategy

### Semantic Versioning

Format: `vMAJOR.MINOR.PATCH`

**v0.x.x** - Pre-release (CentOS 7 base):
- CentOS 7 base image
- NFS-Ganesha 3.0
- NFSv4.0 and NFSv4.1 support
- NFSv4.2 NOT supported

**v1.x.x** - Stable (CentOS Stream 10 base):
- CentOS Stream 10 base image
- NFS-Ganesha 6.x
- NFSv4.0, NFSv4.1, and NFSv4.2 support
- Modern security features

### Release Process

1. Update `CHANGELOG.md`
2. Run tests locally: `make test`
3. Create annotated tag: `git tag -a v1.x.x -m "Description"`
4. Push tag: `git push origin v1.x.x`
5. Monitor GitHub Actions for build/push
6. Verify published image and security scan results
7. Make package public (if first release)

## Security Scanning

### Tools

- **Syft**: SBOM generation (SPDX format)
- **Grype**: Vulnerability scanning (CVE detection)

### Results Locations

**Vulnerability findings**:
- GitHub UI: Security → Code scanning
- Format: SARIF (GitHub native)
- Retention: Indefinite (GitHub managed)

**SBOM artifacts**:
- GitHub UI: Actions → Workflow run → Artifacts
- Format: SPDX 2.3 JSON
- Retention: 90 days

### Configuration

Current settings (in `.github/workflows/security-scan.yml`):
- **Severity cutoff**: `medium`
- **Fail build**: `false`
- **SBOM retention**: 90 days

## Development Workflow

### Local Testing

```bash
# Build
make build

# Run tests
make test

# Verbose test output
make test-verbose

# Clean up
make clean
```

### Docker Compose vs docker compose

The project supports both:
- `docker-compose` (standalone tool, older)
- `docker compose` (plugin, newer)

Makefile auto-detects which is available.

## Known Issues & Workarounds

### NFSv4.2 Support (v0.x.x only)

**Issue**: Mounting with NFSv4.2 fails with I/O error in v0.x.x
**Reason**: CentOS 7's NFS-Ganesha 3.0 doesn't fully support NFSv4.2
**Workaround**: Use NFSv4.1 instead: `mount -t nfs4 -o vers=4.1 server:/ /mnt`
**Status**: Fixed in v1.0.0+ (CentOS Stream 10 / NFS-Ganesha 6.x)

### SELinux with Podman

**Issue**: Permission denied when using volumes with Podman
**Reason**: SELinux prevents container from accessing host files
**Workaround**: Add `:z` flag to volume mounts
```bash
podman run -v /path/to/data:/data/nfs:z ...
```

## Primary Consumers

### kubevirtci

**Repository**: https://github.com/kubevirt/kubevirt/kubevirtci

**Usage**: Provides NFS storage for Kubernetes testing environments

**Requirements**:
- Must run in unprivileged containers (no `--privileged`)
- Minimal capabilities only (DAC_OVERRIDE, DAC_READ_SEARCH)
- Multi-architecture support (amd64, arm64)

**Contact**: KubeVirt community (if breaking changes needed)

## Future Plans

### Quay.io Registry (Planned - Phase 2)

**Goal**: Push images to both ghcr.io and quay.io

**Benefits**:
- Quay.io provides server-side security scanning
- Container Security scanning UI
- Additional vulnerability detection

**Implementation**: Requires secrets configuration in GitHub

### Documentation Improvements (Planned - Phase 3)

**Goal**: Audit and fix any inconsistencies across documentation

**Files to review**:
- README.md
- docs/*.md
- CHANGELOG.md

## Maintenance Notes

### Weekly Rebuilds

Currently: Manual
Planned: Automated weekly rebuilds via GitHub Actions scheduled workflow

Purpose: Pick up security updates from base image and packages

### Monitoring

Watch for:
- CentOS Stream 10 breaking changes
- NFS-Ganesha updates
- Security vulnerabilities in scan results
- Issues from kubevirtci consumers

## Questions?

For questions about:
- **Usage**: See README.md
- **Contributing**: See tests/README.md
- **Security**: See docs/security-scanning.md
- **CI/CD**: See docs/cicd-setup.md
- **Issues**: https://github.com/mkletzan/docker-nfs-ganesha/issues
