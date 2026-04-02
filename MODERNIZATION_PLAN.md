# NFS-Ganesha Container Modernization Plan

**Project:** NFS-Ganesha Docker Container  
**Current State:** CentOS 7 (EOL), no tests, no CI/CD  
**Target State:** CentOS Stream 10, tested, automated CI/CD  
**Created:** 2026-04-02

---

## Executive Summary

This plan outlines the modernization of the NFS-Ganesha container project from an EOL CentOS 7 base to CentOS Stream 10, with comprehensive testing and CI/CD automation.

**Key Principles:**
- Test first, migrate second
- Minimal development dependencies (Docker + docker-compose only)
- No docker.sock mounting in containers
- Security scanning in CI only
- Incremental, reversible changes

---

## Current State Analysis

**Files:**
- `Dockerfile` - CentOS 7 base, Tini v0.18.0, broken GPG keyserver
- `start_nfs.sh` - Service initialization script

**Problems:**
- ❌ CentOS 7 is EOL (since June 2024)
- ❌ No tests of any kind
- ❌ No CI/CD
- ❌ No documentation
- ❌ Outdated dependencies
- ❌ No version pinning
- ❌ No security scanning

---

## Key Architectural Decisions

### Decision 1: Base Image
**Choice:** CentOS Stream 10  
**Rationale:** Rolling release, upstream of RHEL 10, latest packages  
**Alternative Rejected:** AlmaLinux 9 (more stable but older packages)

### Decision 2: Test Strategy
**Choice:** Single-layer functional testing only  
**Rationale:** Simpler, tests what matters (does NFS work?)  
**Rejected:** Multi-layer testing (structure + integration) - unnecessary complexity

### Decision 3: Test Tools
**Choice:** Plain shell scripts with docker-compose  
**Rationale:** Zero dependencies beyond Docker, simple, maintainable  
**Rejected:** bats, container-structure-test - external dependencies

### Decision 4: Development Dependencies
**Choice:** Docker + docker-compose ONLY  
**Rationale:** Minimize setup friction, works everywhere  
**Rejected:** Installing test tools locally

### Decision 5: Security Scanning
**Choice:** Anchore Grype/Syft in CI only  
**Rationale:** No local dependencies, industry standard tooling  
**Rejected:** Trivy (user preference for Anchore tools)

### Decision 6: docker.sock Mounting
**Choice:** Never mount docker.sock in containers  
**Rationale:** Security - don't trust external container images  
**Rejected:** Running test tools in containers with docker.sock access

### Decision 7: CI/CD Platform
**Choice:** GitHub Actions with GitHub Container Registry  
**Rationale:** Free, integrated, zero-config authentication  
**Alternative:** GitLab CI if using GitLab

### Decision 8: Package Management
**Choice:** Use EPEL packages, major version pinning  
**Rationale:** Balance security updates with stability  
**Rejected:** Exact version pinning (too rigid), no pinning (unstable)

---

## Phase 1: Testing Foundation

**Timeline:** Week 1  
**Goal:** Set up test infrastructure before making any changes

### Tasks

1. **Create directory structure:**
   ```
   .
   ├── Dockerfile
   ├── start_nfs.sh
   ├── Makefile
   ├── .gitignore
   └── tests/
       ├── docker-compose.test.yml
       ├── run-tests.sh
       └── README.md
   ```

2. **Create `.gitignore`:**
   ```
   # Build artifacts
   *.tar
   
   # Test artifacts
   tests/*.log
   
   # Tools
   .tools/
   
   # Environment
   .env
   
   # SBOM
   *.spdx.json
   ```

3. **Create `Makefile`:**
   ```makefile
   .PHONY: build test clean
   
   IMAGE_NAME ?= nfs-ganesha
   IMAGE_TAG ?= latest
   
   build:
   	docker build -t $(IMAGE_NAME):$(IMAGE_TAG) .
   
   test: build
   	docker-compose -f tests/docker-compose.test.yml up --build --abort-on-container-exit --exit-code-from test-runner
   	docker-compose -f tests/docker-compose.test.yml down -v
   
   clean:
   	docker-compose -f tests/docker-compose.test.yml down -v || true
   	docker rmi $(IMAGE_NAME):$(IMAGE_TAG) || true
   ```

4. **Create `tests/README.md`:**
   - Document test structure
   - How to run tests locally
   - Prerequisites (Docker, docker-compose)
   - What is being tested

### Dependencies

**Required on developer machine:**
- Docker
- docker-compose (or `docker compose` plugin)

**That's it!**

### Success Criteria

- [ ] Directory structure created
- [ ] Makefile works (`make build` succeeds)
- [ ] Documentation explains test structure
- [ ] `.gitignore` prevents committing artifacts

---

## Phase 2: Initial Tests

**Timeline:** Weeks 2-3  
**Goal:** Write comprehensive functional tests for current system

### Tasks

1. **Create `tests/docker-compose.test.yml`:**
   ```yaml
   version: '3.8'
   
   services:
     nfs-ganesha:
       build:
         context: ..
       privileged: true
       environment:
         - EXPORT_PATH=/data/nfs
         - VERBOSITY=NIV_DEBUG
       volumes:
         - nfs-data:/data/nfs
       networks:
         - test-network
   
     test-runner:
       image: centos:stream10
       depends_on:
         - nfs-ganesha
       privileged: true
       volumes:
         - ./run-tests.sh:/run-tests.sh:ro
       networks:
         - test-network
       command: /run-tests.sh
   
   volumes:
     nfs-data:
   
   networks:
     test-network:
   ```

2. **Create `tests/run-tests.sh`:**
   ```bash
   #!/bin/bash
   set -e
   
   echo "==================================="
   echo "NFS-Ganesha Container Tests"
   echo "==================================="
   
   # Install NFS client utilities
   echo "→ Installing NFS client..."
   dnf install -y nfs-utils > /dev/null 2>&1
   
   # Wait for services to start
   echo "→ Waiting for NFS server startup..."
   sleep 10
   
   # Test 1: Services are running
   echo "→ Testing service availability..."
   if ! showmount -e nfs-ganesha; then
       echo "❌ showmount failed!"
       exit 1
   fi
   
   # Test 2: Mount NFS export
   echo "→ Testing NFS mount..."
   mkdir -p /mnt/nfs
   if ! mount -t nfs4 nfs-ganesha:/ /mnt/nfs; then
       echo "❌ NFS mount failed!"
       exit 1
   fi
   
   # Test 3: Write operation
   echo "→ Testing write operation..."
   echo "test content" > /mnt/nfs/testfile.txt
   if [ ! -f /mnt/nfs/testfile.txt ]; then
       echo "❌ File write failed!"
       exit 1
   fi
   
   # Test 4: Read operation
   echo "→ Testing read operation..."
   content=$(cat /mnt/nfs/testfile.txt)
   if [ "$content" != "test content" ]; then
       echo "❌ Content mismatch! Got: $content"
       exit 1
   fi
   
   # Test 5: File permissions
   echo "→ Testing file operations..."
   chmod 755 /mnt/nfs/testfile.txt
   rm /mnt/nfs/testfile.txt
   
   echo ""
   echo "✅ All tests passed!"
   ```

3. **Make test script executable:**
   ```bash
   chmod +x tests/run-tests.sh
   ```

4. **Test against current CentOS 7 image:**
   ```bash
   make build
   make test
   ```

5. **Fix any issues found**

6. **Add environment variable tests:**
   - Create variants of docker-compose.test.yml with different env vars
   - Test EXPORT_PATH, PROTOCOLS, SQUASH_MODE, etc.

### What Gets Tested

**Critical functionality:**
- ✅ NFS server responds to `showmount`
- ✅ Client can mount the export
- ✅ Client can write files to export
- ✅ Client can read files from export
- ✅ Client can modify permissions
- ✅ Client can delete files
- ✅ Environment variables configure correctly

**Non-tested (acceptable):**
- Container structure (binaries exist, etc.) - verified by runtime tests
- Image size, build time - not critical
- Performance - future enhancement

### Success Criteria

- [ ] Tests run successfully against current CentOS 7 image
- [ ] All critical NFS functionality covered
- [ ] Tests complete in < 2 minutes
- [ ] Clear pass/fail output
- [ ] Documentation updated with test coverage

---

## Phase 3: Discovery & Documentation

**Timeline:** Week 4  
**Goal:** Answer key questions and create comprehensive documentation

### Questions to Answer

Before migration, decide:

1. **Deployment target?**
   - Kubernetes? Docker Swarm? Plain Docker?
   - Single host or cluster?
   - Impact: May need k8s manifests, Helm charts

2. **Users?**
   - Internal only or public?
   - Impact: Documentation depth

3. **Versioning strategy?**
   - Semantic versioning (recommended: 2.0.0 for OS migration)
   - Tag strategy: latest, stable, semver

4. **Container registry?**
   - GitHub Container Registry (ghcr.io) - recommended
   - Docker Hub - for public visibility
   - Private registry

5. **Upgrade requirements?**
   - Downtime acceptable?
   - Rollback strategy?

6. **Compliance?**
   - Security scanning required? (yes - Grype)
   - SBOM needed? (yes - Syft)
   - Image signing? (optional - Cosign)

### Documentation to Create

1. **`README.md`:**
   ```markdown
   # NFS-Ganesha Docker Container
   
   ## Overview
   User-space NFS server in a container using NFS-Ganesha.
   
   ## Quick Start
   ```bash
   docker run -d --privileged \
     -v /path/to/data:/data/nfs \
     -p 2049:2049 \
     ghcr.io/username/nfs-ganesha:latest
   ```
   
   ## Configuration
   Environment variables, volumes, ports...
   
   ## Building
   ```bash
   make build
   make test
   ```
   
   ## Testing
   Requirements, how to run...
   
   ## Deployment
   Production considerations...
   
   ## Troubleshooting
   Common issues...
   
   ## License
   ```

2. **`CHANGELOG.md`:**
   ```markdown
   # Changelog
   
   ## [Unreleased]
   
   ## [1.0.0] - 2026-04-XX
   - Initial release with CentOS 7
   ```

3. **`docker-compose.yml` (example):**
   ```yaml
   version: '3.8'
   
   services:
     nfs-ganesha:
       image: ghcr.io/username/nfs-ganesha:latest
       privileged: true
       environment:
         - EXPORT_PATH=/data/nfs
         - PROTOCOLS=4
       volumes:
         - ./data:/data/nfs
       ports:
         - "2049:2049"
         - "111:111"
         - "111:111/udp"
   ```

4. **`.env.example`:**
   ```bash
   # NFS-Ganesha Configuration
   
   # Export path inside container
   EXPORT_PATH=/data/nfs
   
   # NFS pseudo path
   PSEUDO_PATH=/
   
   # Export ID
   EXPORT_ID=0
   
   # NFS protocols (3, 4, or "3,4")
   PROTOCOLS=4
   
   # Transports
   TRANSPORTS="UDP, TCP"
   
   # Security type
   SEC_TYPE=sys
   
   # Squash mode (No_Root_Squash, Root_Squash, All_Squash)
   SQUASH_MODE=No_Root_Squash
   
   # Graceless recovery
   GRACELESS=true
   
   # Log verbosity (NIV_DEBUG, NIV_EVENT, NIV_WARN)
   VERBOSITY=NIV_EVENT
   ```

5. **`.dockerignore`:**
   ```
   .git
   .github
   tests
   *.md
   .gitignore
   Makefile
   .env
   *.tar
   *.spdx.json
   ```

6. **`docs/architecture.md`:**
   - How the container works
   - Service startup sequence
   - Configuration generation
   - Port requirements
   - Security considerations

### Files to Create

- [ ] `README.md`
- [ ] `CHANGELOG.md`
- [ ] `docker-compose.yml`
- [ ] `.env.example`
- [ ] `.dockerignore`
- [ ] `docs/architecture.md`

### Success Criteria

- [ ] All discovery questions answered
- [ ] Comprehensive README
- [ ] Example configurations provided
- [ ] Architecture documented
- [ ] Deployment strategy clear

---

## Phase 4: OS & Package Modernization

**Timeline:** Weeks 5-6  
**Goal:** Migrate from CentOS 7 to CentOS Stream 10

### Preparation

1. **Verify package availability:**
   ```bash
   # Spin up CentOS Stream 10 container
   docker run -it centos:stream10 bash
   
   # Check for packages
   dnf search nfs-ganesha
   dnf info nfs-ganesha
   ```

2. **Create feature branch:**
   ```bash
   git checkout -b migrate-centos-stream10
   ```

### Dockerfile Migration

**New Dockerfile:**

```dockerfile
# Modern base image
FROM centos:stream10

# Metadata
LABEL org.opencontainers.image.title="NFS-Ganesha Server"
LABEL org.opencontainers.image.description="User-space NFS server using NFS-Ganesha"
LABEL org.opencontainers.image.source="https://github.com/username/nfs-ganesha"
LABEL org.opencontainers.image.version="2.0.0"
LABEL org.opencontainers.image.licenses="MIT"

# Install EPEL repository
RUN dnf install -y epel-release && \
    dnf config-manager --set-enabled crb

# Install NFS-Ganesha and dependencies
RUN dnf install -y \
    nfs-ganesha \
    nfs-ganesha-vfs \
    nfs-utils \
    rpcbind \
    dbus \
    tini && \
    dnf clean all

# Add health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=10s --retries=3 \
    CMD showmount -e localhost || exit 1

# Copy startup script
COPY start_nfs.sh /
RUN chmod +x /start_nfs.sh

# Volume for NFS export
VOLUME ["/data/nfs"]

# NFS ports
EXPOSE 111 111/udp 662 2049 38465-38467

# Use tini as init system
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/start_nfs.sh"]
```

### Key Changes

1. **Base image:** `centos:7` → `centos:stream10`
2. **Package manager:** `yum` → `dnf` (yum is aliased, but use dnf)
3. **Repository setup:**
   - Remove: `centos-release-gluster7`, `centos-release-nfs-ganesha30`
   - Add: `epel-release` + CRB (CodeReady Builder, replaces PowerTools)
4. **Tini installation:**
   - Remove: Manual download + GPG verification
   - Add: `dnf install tini`
   - Update ENTRYPOINT: `/tini` → `/usr/bin/tini`
5. **Add:**
   - OCI labels for metadata
   - HEALTHCHECK directive
6. **Security:**
   - No GPG keyserver issues
   - All packages from trusted repos
   - Version pinning (optional, add if needed)

### start_nfs.sh Compatibility

**Expected:** No changes needed (verify with tests)

**Potential issues to check:**
- Service binary paths (likely unchanged)
- Configuration file locations (likely unchanged)
- User/group IDs for rpcbind, dbus (may differ)

**If issues found:**
- Adjust paths in script
- Update user/group creation
- Verify with tests

### Testing Migration

```bash
# Build new image
make build

# Run tests (should pass!)
make test

# If tests fail:
# - Check logs: docker-compose -f tests/docker-compose.test.yml logs
# - Debug: docker run -it nfs-ganesha:latest bash
# - Fix issues in Dockerfile or start_nfs.sh
# - Repeat
```

### Version Bump

Update version to 2.0.0 (major version bump):
- Breaking change: Different OS, different package versions
- Update CHANGELOG.md
- Update Dockerfile LABEL
- Tag release: `v2.0.0`

### Files to Modify

- [ ] `Dockerfile` - Complete rewrite
- [ ] `start_nfs.sh` - Verify compatibility (likely no changes)
- [ ] `CHANGELOG.md` - Document migration
- [ ] `README.md` - Update base image info

### Success Criteria

- [ ] Image builds successfully
- [ ] All tests pass
- [ ] Health check works
- [ ] No security vulnerabilities (will verify in Phase 5)
- [ ] Image size reasonable (< 500MB)
- [ ] Documentation updated

### Risks & Mitigation

**Risk 1: Package unavailability**
- Verify EPEL 9/10 has nfs-ganesha before starting
- Fallback: Build from source (not recommended)

**Risk 2: Configuration incompatibility**
- NFS-Ganesha 5.x may have different config syntax
- Mitigation: Read changelog, test thoroughly
- Fallback: Pin to older version

**Risk 3: Service startup failures**
- Different systemd/service manager behavior
- Mitigation: Test in container, adjust start_nfs.sh

**Risk 4: Performance regression**
- Newer kernel, newer NFS stack
- Mitigation: Add performance testing (future)

---

## Phase 5: CI/CD Automation

**Timeline:** Weeks 7-8  
**Goal:** Automate building, testing, scanning, and publishing

### GitHub Actions Workflow

**File: `.github/workflows/ci.yml`**

```yaml
name: CI/CD

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:
    branches: [ main ]
  schedule:
    - cron: '0 2 * * 1'  # Weekly rebuild on Monday 2am UTC
  workflow_dispatch:  # Manual trigger

env:
  IMAGE_NAME: ghcr.io/${{ github.repository }}

jobs:
  test:
    name: Build and Test
    runs-on: ubuntu-latest
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Build image
        uses: docker/build-push-action@v5
        with:
          context: .
          load: true
          tags: nfs-ganesha:latest
          cache-from: type=gha
          cache-to: type=gha,mode=max
      
      - name: Run tests
        run: make test
      
      - name: Generate SBOM with Syft
        uses: anchore/sbom-action@v0
        with:
          image: nfs-ganesha:latest
          artifact-name: sbom.spdx.json
          output-file: sbom.spdx.json
      
      - name: Scan for vulnerabilities with Grype
        uses: anchore/scan-action@v3
        id: scan
        with:
          image: nfs-ganesha:latest
          fail-build: true
          severity-cutoff: high
          output-format: sarif
      
      - name: Upload vulnerability results to GitHub Security
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: ${{ steps.scan.outputs.sarif }}
      
      - name: Upload SBOM as artifact
        uses: actions/upload-artifact@v4
        if: always()
        with:
          name: sbom
          path: sbom.spdx.json
          retention-days: 90

  publish:
    name: Publish Image
    needs: test
    if: github.event_name != 'pull_request'
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      
      - name: Login to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha,prefix={{branch}}-
            type=raw,value=latest,enable={{is_default_branch}}
      
      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
      
      - name: Generate SBOM for published image
        uses: anchore/sbom-action@v0
        with:
          image: ${{ env.IMAGE_NAME }}:latest
          artifact-name: sbom-published.spdx.json
          output-file: sbom-published.spdx.json
          registry-username: ${{ github.actor }}
          registry-password: ${{ secrets.GITHUB_TOKEN }}
      
      - name: Upload SBOM artifact
        uses: actions/upload-artifact@v4
        with:
          name: sbom-published
          path: sbom-published.spdx.json
          retention-days: 90

  release:
    name: Create Release
    needs: publish
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest
    permissions:
      contents: write
    
    steps:
      - name: Checkout code
        uses: actions/checkout@v4
      
      - name: Download SBOM
        uses: actions/download-artifact@v4
        with:
          name: sbom-published
      
      - name: Create GitHub Release
        uses: softprops/action-gh-release@v1
        with:
          generate_release_notes: true
          files: |
            sbom-published.spdx.json
          draft: false
          prerelease: false
```

### Dependabot Configuration

**File: `.github/dependabot.yml`**

```yaml
version: 2

updates:
  # Docker base image updates
  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "docker"
  
  # GitHub Actions updates
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    open-pull-requests-limit: 5
    labels:
      - "dependencies"
      - "github-actions"
```

### Branch Protection Rules

**Configure on GitHub:**

1. **Require status checks:**
   - `test` job must pass
   - Status checks must be up to date

2. **Require pull request reviews:**
   - Optional: depends on team size
   - 1 approval recommended

3. **Require signed commits:**
   - Optional: for compliance

4. **Restrictions:**
   - No force push to main
   - No deletion of main branch

### Pipeline Features

**On every PR:**
- ✅ Build image
- ✅ Run functional tests
- ✅ Generate SBOM
- ✅ Scan for vulnerabilities (fail on HIGH/CRITICAL)
- ✅ Upload results to GitHub Security tab

**On merge to main:**
- ✅ All of the above, plus:
- ✅ Push image to ghcr.io with tags:
  - `latest`
  - `main-<sha>`

**On tag (e.g., `v2.0.0`):**
- ✅ All of the above, plus:
- ✅ Push image with semver tags:
  - `2.0.0`
  - `2.0`
  - `latest`
- ✅ Create GitHub Release with:
  - Auto-generated release notes
  - SBOM attachment

**Weekly (scheduled):**
- ✅ Rebuild image (picks up base image updates)
- ✅ Run tests
- ✅ Security scan
- ✅ Publish if tests pass

### Container Registry Setup

**GitHub Container Registry (ghcr.io):**

1. **Make package public:**
   - Go to package settings on GitHub
   - Change visibility to public

2. **Link to repository:**
   - Automatically linked by workflow

3. **Image URL:**
   ```
   ghcr.io/username/nfs-ganesha:latest
   ghcr.io/username/nfs-ganesha:2.0.0
   ```

### Files to Create

- [ ] `.github/workflows/ci.yml`
- [ ] `.github/dependabot.yml`
- [ ] Update README with CI badge

### Success Criteria

- [ ] CI runs on every PR
- [ ] Tests must pass before merge
- [ ] Security scans integrated
- [ ] Images published automatically
- [ ] Releases automated
- [ ] Weekly rebuilds working
- [ ] Dependabot creating PRs

### CI/CD Best Practices

**Secrets management:**
- Use GitHub secrets for registry credentials
- `GITHUB_TOKEN` auto-provided by Actions

**Caching:**
- Use GitHub Actions cache for Docker layers
- Speeds up builds significantly

**Security:**
- Fail build on high/critical vulnerabilities
- Upload SARIF to GitHub Security tab
- Generate SBOM for supply chain transparency

**Notifications:**
- GitHub Actions sends notifications on failure
- Optional: Slack/Discord webhooks

---

## Implementation Roadmap

### Week 1: Testing Foundation
- [x] Plan finalized
- [ ] Create directory structure
- [ ] Create Makefile
- [ ] Create `.gitignore`
- [ ] Document test approach

### Week 2-3: Initial Tests
- [ ] Create `docker-compose.test.yml`
- [ ] Create `run-tests.sh`
- [ ] Test against current CentOS 7 image
- [ ] Fix any issues
- [ ] Verify 100% test pass rate

### Week 4: Documentation
- [ ] Answer discovery questions
- [ ] Create README.md
- [ ] Create CHANGELOG.md
- [ ] Create docker-compose.yml example
- [ ] Create .env.example
- [ ] Create architecture docs

### Week 5-6: OS Migration
- [ ] Verify package availability
- [ ] Create feature branch
- [ ] Update Dockerfile
- [ ] Test migration
- [ ] Fix compatibility issues
- [ ] Update documentation
- [ ] Bump version to 2.0.0

### Week 7-8: CI/CD
- [ ] Create GitHub Actions workflow
- [ ] Set up Dependabot
- [ ] Configure branch protection
- [ ] Test CI pipeline
- [ ] Create first release (v2.0.0)
- [ ] Document release process

### Week 9+: Ongoing Maintenance
- [ ] Monitor security scans
- [ ] Review Dependabot PRs
- [ ] Respond to issues
- [ ] Consider enhancements

---

## Dependencies Summary

### Developer Machine
- Docker
- docker-compose

**That's it!**

### CI/CD (GitHub Actions)
- Anchore Syft (SBOM generation)
- Anchore Grype (vulnerability scanning)
- GitHub Container Registry
- Dependabot

**All handled by GitHub Actions, no local installation needed.**

---

## Security Considerations

### Image Security
- Base image from official CentOS
- Packages from trusted repos (EPEL)
- Regular security scanning with Grype
- SBOM generation for transparency

### Runtime Security
- Runs as root (required for NFS)
- Requires `--privileged` flag (required for NFS)
- Document security implications in README
- Consider AppArmor/SELinux profiles (future)

### Supply Chain Security
- Pin major package versions
- Weekly automated rebuilds
- Dependabot for base image updates
- SBOM attached to releases

### No docker.sock Mounting
- All tests run without docker.sock access
- Security tools run in CI on host
- Reduces attack surface

---

## Risks & Mitigation

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| Package unavailability in Stream 10 | Low | High | Verify before starting, fallback to RHEL repos |
| NFS-Ganesha config incompatibility | Medium | High | Thorough testing, version pinning |
| CI/CD setup complexity | Low | Medium | Use standard GitHub Actions patterns |
| User disruption from OS change | High | Medium | Semver (2.0.0), migration guide, support both versions temporarily |
| Security vulnerabilities | Medium | High | Automated Grype scanning, weekly rebuilds |
| Performance regression | Low | Medium | Monitor, add perf tests in future |

---

## Success Metrics

### Technical Metrics
- ✅ 100% test pass rate
- ✅ Zero high/critical vulnerabilities
- ✅ Build time < 5 minutes
- ✅ Test time < 2 minutes
- ✅ Image size < 500MB

### Process Metrics
- ✅ CI runs on every PR
- ✅ Automated weekly rebuilds
- ✅ SBOM generated for every release
- ✅ Security scan results in GitHub Security tab

### Documentation Metrics
- ✅ README covers all use cases
- ✅ Examples provided for common scenarios
- ✅ Architecture documented
- ✅ Troubleshooting guide available

---

## Future Enhancements

**Not in scope for initial modernization, but consider:**

1. **Multi-export support:**
   - Support multiple NFS exports
   - Dynamic configuration from env vars or config file

2. **Metrics and monitoring:**
   - Prometheus exporter for NFS metrics
   - Health endpoint beyond HEALTHCHECK

3. **Performance testing:**
   - Benchmark read/write throughput
   - Latency measurements

4. **Advanced configuration:**
   - Support mounting custom ganesha.conf
   - Configuration validation before startup

5. **Multi-architecture builds:**
   - arm64 support
   - Multi-platform images

6. **Helm chart:**
   - For Kubernetes deployments
   - ConfigMap-based configuration

7. **Image signing:**
   - Cosign integration
   - Verify image provenance

---

## References

- [NFS-Ganesha Documentation](https://github.com/nfs-ganesha/nfs-ganesha/wiki)
- [CentOS Stream](https://www.centos.org/centos-stream/)
- [Anchore Grype](https://github.com/anchore/grype)
- [Anchore Syft](https://github.com/anchore/syft)
- [GitHub Actions](https://docs.github.com/en/actions)
- [OCI Image Spec](https://github.com/opencontainers/image-spec)

---

## Changelog

**2026-04-02:**
- Initial plan created
- Key decisions documented
- 5-phase implementation plan defined
