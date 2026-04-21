# CI/CD Setup Guide

This document explains how to set up the automated build and publish workflow for the NFS-Ganesha container.

## Overview

The CI/CD pipeline automatically:
1. Runs the full test suite
2. Builds multi-architecture container images (amd64, arm64)
3. Publishes to GitHub Container Registry (ghcr.io)
4. Publishes to Quay.io Container Registry (quay.io)
5. Tags images with semantic versioning
6. Runs security scans with Syft/Grype

**Note:** s390x is not supported due to lack of nfs-ganesha-6 packages for CentOS Stream 10.

**Triggers:** Push to version tags (e.g., `v1.0.0`, `v1.0.1`)

## Prerequisites

### 1. Enable GitHub Container Registry

GitHub Container Registry (GHCR) is automatically available for all GitHub repositories. No additional configuration needed.

### 2. Configure Package Permissions

After the first image is published, you may need to make the package public:

1. Go to your repository on GitHub
2. Navigate to "Packages" (right sidebar)
3. Click on the `docker-nfs-ganesha` package
4. Go to "Package settings"
5. Scroll to "Danger Zone"
6. Click "Change visibility" → "Public"

## How It Works

### Workflow File

Location: `.github/workflows/release.yml`

The workflow consists of two jobs:

#### Job 1: Test
- Runs on: `ubuntu-latest`
- Steps:
  1. Checkout code
  2. Run `make test` (full test suite)

#### Job 2: Build and Push
- Runs on: `ubuntu-latest`
- Requires: Test job passes
- Permissions: Read contents, write packages
- Steps:
  1. Checkout code
  2. Set up QEMU (for cross-platform emulation)
  3. Set up Docker Buildx (for multi-arch builds)
  4. Login to ghcr.io using `GITHUB_TOKEN`
  5. Login to quay.io using robot account credentials
  6. Extract metadata (tags, labels)
  7. Build and push multi-arch images to both registries

### Image Tags

When you push tag `v1.2.3`, the workflow creates these image tags on both registries:

**GitHub Container Registry:**
- `ghcr.io/mkletzan/docker-nfs-ganesha:1.2.3`
- `ghcr.io/mkletzan/docker-nfs-ganesha:1.2`
- `ghcr.io/mkletzan/docker-nfs-ganesha:1`
- `ghcr.io/mkletzan/docker-nfs-ganesha:latest` (only if on default branch)

**Quay.io:**
- `quay.io/nertpinx/nfs-ganesha:1.2.3`
- `quay.io/nertpinx/nfs-ganesha:1.2`
- `quay.io/nertpinx/nfs-ganesha:1`
- `quay.io/nertpinx/nfs-ganesha:latest` (only if on default branch)

### Supported Architectures

- `linux/amd64` (x86_64)
- `linux/arm64` (ARM 64-bit)

**Not supported:**
- `linux/s390x` (IBM Z) - nfs-ganesha-6 packages unavailable for CentOS Stream 10

## Publishing a Release

### Step 1: Create and Push a Tag

```bash
# Create annotated tag
git tag -a v1.0.0 -m "Release v1.0.0: Description"

# Push tag to GitHub
git push origin v1.0.0
```

### Step 2: Monitor Workflow

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Watch the "Build and Publish Release" workflow
4. Build typically takes 15-30 minutes (multi-arch build)

### Step 3: Verify Published Image

```bash
# Pull the image
docker pull ghcr.io/mkletzan/docker-nfs-ganesha:v1.0.0

# Inspect architectures
docker buildx imagetools inspect ghcr.io/mkletzan/docker-nfs-ganesha:v1.0.0
```

## Authentication

### For CI/CD (GitHub Actions)

No setup required. The workflow uses `GITHUB_TOKEN` which is automatically provided by GitHub Actions with the necessary permissions.

### For Local Pulling (Public Images)

No authentication needed for public images:
```bash
# From GitHub Container Registry
docker pull ghcr.io/mkletzan/docker-nfs-ganesha:latest

# From Quay.io
docker pull quay.io/nertpinx/nfs-ganesha:latest
```

### For Local Pulling (Private Images)

If the package is private, create a Personal Access Token (PAT):

1. Go to GitHub Settings → Developer settings → Personal access tokens → Tokens (classic)
2. Generate new token with `read:packages` scope
3. Login:
   ```bash
   echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
   ```

## Troubleshooting

### Build Fails: "permission denied"

**Cause:** Workflow doesn't have package write permission.

**Fix:** The workflow already requests `packages: write` permission. Ensure repository settings allow GitHub Actions to create packages.

### Build Fails: Tests Don't Pass

**Cause:** The test suite must pass before building.

**Fix:** Run `make test` locally to debug, fix issues, then commit and re-tag.

### Image Not Visible in Packages

**Cause:** Package may be private by default.

**Fix:** Follow "Configure Package Permissions" section above.

### Multi-arch Build Takes Too Long

**Expected:** Multi-arch builds (especially arm64 emulation) can take 15-20 minutes.

**Optimization:** GitHub Actions provides build cache (`type=gha`) which speeds up subsequent builds.

## Security

### Image Scanning

All container images are automatically scanned for vulnerabilities using:
- **Syft** - Generates Software Bill of Materials (SBOM) in SPDX format
- **Grype** - Scans for known vulnerabilities (CVEs)

#### Scanning Schedule

Security scans run:
- On every pull request (test workflow)
- On every push to master branch (test workflow)
- On every release tag (release workflow)

#### Where to Find Results

**Vulnerability Scan Results:**
1. Go to your repository on GitHub
2. Click the **"Security"** tab
3. Click **"Code scanning"** in the left sidebar
4. View Grype vulnerability findings

Direct link: `https://github.com/mkletzan/docker-nfs-ganesha/security/code-scanning`

**SBOM (Software Bill of Materials):**
1. Go to the **"Actions"** tab
2. Click on a workflow run (Test or Release)
3. Scroll to **"Artifacts"** section
4. Download the `sbom-spdx` artifact

The SBOM is a JSON file listing all software components and their versions in the container image.

#### Severity Cutoff

Current configuration:
- **Severity cutoff**: Medium (reports medium, high, and critical vulnerabilities)
- **Fail build**: No (vulnerabilities are reported but don't block builds)

To make builds fail on vulnerabilities, edit `.github/workflows/security-scan.yml` and set `fail-build: true`.

### Secrets

The workflow uses these secrets:

**`GITHUB_TOKEN`** (automatic):
- Automatically provided by GitHub Actions
- Used for ghcr.io authentication
- Scoped to the repository
- No manual configuration needed

**`QUAY_IO_USERNAME`** (manual):
- Quay.io robot account username
- Format: `<quay-username>+<robot-name>`
- Must be added in GitHub Settings → Secrets

**`QUAY_IO_TOKEN`** (manual):
- Quay.io robot account token
- Generated when creating robot account
- Must be added in GitHub Settings → Secrets

For Quay.io setup instructions, see [docs/quay-setup.md](quay-setup.md).

## Local Multi-arch Builds

To build multi-arch locally (for testing):

```bash
# Create buildx builder
docker buildx create --name multiarch --use

# Build for all platforms
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t ghcr.io/mkletzan/docker-nfs-ganesha:test \
  --load \
  .
```

**Note:** `--load` only works with single platform. For multi-platform local testing, use `--push` to push to a test registry.

## Version Strategy

- **v0.x.x** - Pre-release (CentOS 7)
- **v1.x.x** - Stable (CentOS Stream 10+)
- Tags are immutable (never force-push tags)
- Follow semantic versioning
- Update CHANGELOG.md before tagging

## References

- [GitHub Container Registry Docs](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry)
- [Docker Buildx Documentation](https://docs.docker.com/buildx/working-with-buildx/)
- [GitHub Actions: Publishing Images](https://docs.github.com/en/actions/publishing-packages/publishing-docker-images)
