# Quay.io Registry Setup Guide

This document explains how to configure Quay.io as an additional container registry for this project.

## Configuration Required

Before following this guide, you'll need to update `.github/workflows/release.yml`:

```yaml
env:
  QUAY_IMAGE_NAME: <your-quay-username>/<repository-name>  # Update this!
```

Replace `<your-quay-username>` with your Quay.io username and `<repository-name>` with your desired repository name (e.g., `nfs-ganesha`).

## Why Quay.io?

Quay.io provides **server-side security scanning** in addition to our GitHub Actions-based scanning:

- **Clair security scanner** - Built into Quay.io, automatically scans all pushed images
- **Container Security** - Web UI for viewing vulnerabilities
- **Continuous monitoring** - Rescans images as new CVE databases are released
- **Compliance features** - Export reports, track remediation
- **High availability** - Enterprise-grade container registry

This complements our existing Grype/Syft scanning in CI/CD.

## Prerequisites

### 1. Create Quay.io Account

1. Go to [quay.io](https://quay.io/)
2. Sign up for a free account or sign in with GitHub
3. Verify your email address
4. Note your username (you'll need it later): `<your-quay-username>`

### 2. Create Repository

1. Log in to Quay.io
2. Click **"Create New Repository"**
3. Repository details:
   - **Repository Type**: **Empty Repository** (not "Link to GitHub")
   - **Name**: `nfs-ganesha` (or any name you prefer)
   - **Visibility**: Public (recommended for open source)
   - **Description**: "Containerized NFS-Ganesha server - user-space NFS implementation"
4. Click **"Create Public Repository"**

**Important**: Choose "Empty Repository" because:
- GitHub Actions already builds multi-arch images
- We push the same image to both registries (consistency)
- Avoids duplicate builds
- Better control over build process

Your repository will be: `quay.io/<your-quay-username>/<repository-name>`

**Example**: If your username is `johndoe` and you named it `nfs-ganesha`, the full path is `quay.io/johndoe/nfs-ganesha`

### 3. Generate Robot Account (Recommended)

For CI/CD, use a robot account instead of your personal credentials:

1. Go to your Quay.io repository
2. Click **Settings** → **Robot Accounts**
3. Click **"Create Robot Account"**
4. Robot account details:
   - **Name**: `nfs_ganesha_ci` (or any name you prefer)
   - **Description**: "CI/CD automation for GitHub Actions"
5. Permissions: **Write** (allows push)
6. Click **"Create Robot Account"**
7. **Copy the credentials** - you won't see them again!
   - Username format: `<your-quay-username>+<robot-name>`
   - Example: `johndoe+nfs_ganesha_ci`
   - Token will be a long random string

**Save these credentials** - you'll need them for GitHub Secrets in the next step.

### 4. Configure GitHub Secrets

Add Quay.io credentials to GitHub repository secrets:

1. Go to your GitHub repository: `https://github.com/<your-github-username>/<your-repo-name>`
2. Navigate to **Settings** → **Secrets and variables** → **Actions**
3. Click **"New repository secret"**
4. Add two secrets:

**Secret 1:**
- Name: `QUAY_IO_USERNAME`
- Value: `<your-quay-username>+<robot-name>` (your robot account username from step 3)
- Example: `johndoe+nfs_ganesha_ci`

**Secret 2:**
- Name: `QUAY_IO_TOKEN`
- Value: `<paste-the-long-token-from-quay>` (the robot account token from step 3)

5. Click **"Add secret"** for each

**Verification**: After adding, you should see both secrets listed (values are automatically hidden).

## How It Works

### Dual Registry Push

When you push a tag (e.g., `v1.0.3`), the release workflow:

1. ✅ Runs tests (amd64, arm64)
2. ✅ Builds multi-arch image
3. ✅ **Pushes to ghcr.io** (GitHub Container Registry)
4. ✅ **Pushes to quay.io** (Quay.io Container Registry)
5. ✅ Runs security scan (Grype/Syft)
6. ✅ Quay.io automatically scans with Clair

Both registries receive identical multi-arch images with identical tags.

### Image Locations

After release `v1.2.3`, images are available at both registries:

**GitHub Container Registry:**
- `ghcr.io/<github-username>/<repo-name>:1.2.3`
- `ghcr.io/<github-username>/<repo-name>:1.2`
- `ghcr.io/<github-username>/<repo-name>:1`
- `ghcr.io/<github-username>/<repo-name>:latest`

**Quay.io:**
- `quay.io/<quay-username>/<quay-repo>:1.2.3`
- `quay.io/<quay-username>/<quay-repo>:1.2`
- `quay.io/<quay-username>/<quay-repo>:1`
- `quay.io/<quay-username>/<quay-repo>:latest`

Users can pull from either registry:
```bash
# From GitHub Container Registry
docker pull ghcr.io/<your-github-username>/<your-repo>:latest

# From Quay.io
docker pull quay.io/<your-quay-username>/<your-quay-repo>:latest
```

## Accessing Security Scan Results

### Quay.io Container Security

**Location**: `https://quay.io/repository/<your-quay-username>/<your-repo-name>`

**How to access:**
1. Go to [quay.io](https://quay.io/)
2. Navigate to your repository: `quay.io/<your-quay-username>/<your-repo-name>`
3. Click on a specific tag (e.g., `1.0.3`)
4. Click the **"Security Scan"** or **"Security Scanner"** tab

**What you'll see:**
- List of detected vulnerabilities (CVEs)
- Severity levels (Critical, High, Medium, Low, Negligible)
- Affected packages and layers
- Fixed version (if available)
- CVE identifiers with links to NVD details
- Historical scan results

**Features:**
- 🔍 Searchable and filterable vulnerability list
- 📊 Export to CSV
- 📈 Historical scans
- 🔄 Automatic rescanning when new CVEs are published
- 🎯 Filter by severity, fixed/unfixed status

### Comparison: Quay.io vs GitHub Security

| Feature | Quay.io (Clair) | GitHub (Grype) |
|---------|-----------------|----------------|
| **Scanner** | Clair | Grype |
| **Scan trigger** | On push + periodic | On workflow run |
| **Continuous monitoring** | ✅ Yes | ❌ No |
| **Web UI** | ✅ Yes | ✅ Yes |
| **Export reports** | ✅ CSV | ✅ SARIF |
| **SBOM** | ❌ No | ✅ Yes (Syft) |
| **Integration** | Quay.io only | GitHub native |
| **Rescan on new CVEs** | ✅ Automatic | ❌ Manual |

**Best practice**: Use both for comprehensive coverage. Different scanners may detect different vulnerabilities.

## Troubleshooting

### Authentication Failed

**Error:** `unauthorized: access to the requested resource is not authorized`

**Cause:** Invalid credentials in GitHub secrets

**Fix:**
1. Verify robot account still exists:
   - Go to Quay.io → Repository Settings → Robot Accounts
   - Check your robot account is listed
2. Regenerate robot account token if needed:
   - Click on the robot account
   - Click "Regenerate Token"
   - Update `QUAY_IO_TOKEN` in GitHub secrets with new token
3. Ensure username includes the `+` prefix:
   - Format: `<your-quay-username>+<robot-name>`
   - Example: `johndoe+nfs_ganesha_ci` (not just `johndoe`)
4. Verify both secrets are set in GitHub Actions secrets

### Push Succeeds to ghcr.io but Fails to Quay.io

**Cause:** Quay.io authentication issue or network problem

**Fix:**
1. Check workflow logs for specific error:
   - Go to GitHub Actions
   - Click on the failed workflow run
   - Expand the "Build and push" step
2. Verify Quay.io is accessible (check status page)
3. Verify secrets are correctly named:
   - `QUAY_IO_USERNAME` (not QUAY_USERNAME)
   - `QUAY_IO_TOKEN` (not QUAY_TOKEN)
4. Try regenerating robot account credentials

### Security Scan Not Showing

**Cause:** Scan takes time to complete (2-10 minutes)

**Fix:** 
- Wait a few minutes and refresh the Quay.io page
- Clair scanner processes images in the background
- Check the repository "Builds and Scans" page for status

### Image Not Public

**Cause:** Repository visibility is private

**Fix:**
1. Go to your Quay.io repository: `quay.io/<your-quay-username>/<your-repo-name>`
2. Click **Settings** (gear icon)
3. Scroll to **Repository Visibility**
4. Select **Public**
5. Click **Save**

**Note**: Public repositories allow:
- Anyone can pull images (no authentication)
- Security scan results are visible
- Better for open source projects

## Testing the Setup

Before pushing a real release, test the setup. There are two ways:

### Method 1: Manual Workflow Trigger (Recommended)

The easiest way to test without creating tags:

1. **Verify secrets are set:**
   - Go to GitHub repository Settings → Secrets and variables → Actions
   - Confirm both `QUAY_IO_USERNAME` and `QUAY_IO_TOKEN` exist

2. **Trigger workflow manually:**
   - Go to GitHub repository → **Actions** tab
   - Click **"Release"** workflow in left sidebar
   - Click **"Run workflow"** button (top right)
   - Enter tag name: `test` (or any name like `test-quay`)
   - Click **"Run workflow"**

3. **Monitor workflow:**
   - Watch the workflow run in real-time
   - Check both login steps succeed (GitHub and Quay.io)
   - Verify build and push completes to both registries

4. **Verify images exist:**
   ```bash
   # Check GitHub Container Registry
   docker pull ghcr.io/<your-github-username>/<your-repo>:test
   
   # Check Quay.io
   docker pull quay.io/<your-quay-username>/<your-quay-repo>:test
   ```

5. **Check security scans:**
   - GitHub: Security → Code scanning
   - Quay.io: Repository → `test` tag → Security Scan

6. **Clean up test images (optional):**
   - GitHub: Packages → Select package → Delete tag `test`
   - Quay.io: Repository → Tags → Delete `test` tag

### Method 2: Test Tag

Alternatively, push a test tag:

1. **Create and push test tag:**
   ```bash
   git tag -a v1.0.3-test -m "Test Quay.io integration"
   git push origin v1.0.3-test
   ```

2. **Monitor and verify** (same as Method 1, steps 3-5)

3. **Clean up:**
   ```bash
   # Delete local tag
   git tag -d v1.0.3-test
   
   # Delete remote tag
   git push --delete origin v1.0.3-test
   ```

### Method 3: Local Test (Quick Auth Check)

Just test authentication without building:

```bash
# Test GitHub Container Registry login
echo $GITHUB_TOKEN | docker login ghcr.io -u <your-github-username> --password-stdin

# Test Quay.io login
docker login quay.io
Username: <your-quay-username>+<robot-name>
Password: <paste-robot-token>
# Should see: Login Succeeded for both
```

**Recommendation**: Use Method 1 (manual trigger) as it's cleanest and doesn't create git tags.

## Security Best Practices

### Robot Accounts

✅ **Do:**
- Use robot accounts for CI/CD (not personal credentials)
- Grant minimum required permissions (Write only)
- Rotate credentials periodically (every 6-12 months)
- Use descriptive names (`nfs_ganesha_ci`, not `robot1`)
- Document what each robot account is used for

❌ **Don't:**
- Use personal account credentials in CI/CD
- Share robot account tokens publicly
- Grant Admin permissions unless necessary
- Reuse robot accounts across projects

### Secrets Management

✅ **Do:**
- Store credentials in GitHub Secrets (encrypted at rest)
- Use repository secrets for single-repo access
- Document which secrets are required (this file!)
- Rotate secrets periodically

❌ **Don't:**
- Commit credentials to git
- Log credentials in workflows (`set -x` with secrets)
- Share secrets via insecure channels (email, Slack)
- Use same token for multiple services

## Documentation Updates

The following files have been updated to reflect Quay.io integration:

- ✅ `README.md` - Added Quay.io pull instructions for Docker and Podman
- ✅ `docs/cicd-setup.md` - Documented dual registry push and secrets
- ✅ `CLAUDE.md` - Added Quay.io to registry configuration section
- ✅ `.github/workflows/release.yml` - Configured multi-registry push

If you fork this repository, remember to:
1. Update `QUAY_IMAGE_NAME` in `.github/workflows/release.yml`
2. Add your Quay.io secrets (`QUAY_IO_USERNAME`, `QUAY_IO_TOKEN`)
3. Update documentation examples with your usernames

## Disabling Quay.io (Optional)

If you want to disable Quay.io pushes later:

**Option 1: Delete secrets (recommended)**
1. Go to GitHub → Settings → Secrets and variables → Actions
2. Delete `QUAY_IO_USERNAME`
3. Delete `QUAY_IO_TOKEN`
4. Workflow will fail at Quay login but continue with ghcr.io push

**Option 2: Revert workflow changes**
```bash
git revert <commit-hash-that-added-quay>
```

**Option 3: Comment out Quay.io steps**
- Edit `.github/workflows/release.yml`
- Comment out the "Log in to Quay.io" step
- Remove Quay.io from metadata images list

## References

- [Quay.io Documentation](https://docs.quay.io/)
- [Clair Security Scanner](https://quay.github.io/clair/)
- [Quay.io Robot Accounts](https://docs.quay.io/glossary/robot-accounts.html)
- [GitHub Actions Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)
- [Docker Multi-Registry Push](https://docs.docker.com/build/ci/github-actions/multi-platform/)

## Support

If you encounter issues:
1. Check this troubleshooting guide
2. Review GitHub Actions workflow logs
3. Check Quay.io status page
4. Open an issue on GitHub with error details
