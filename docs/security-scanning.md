# Security Scanning Guide

This document explains how container security scanning works in this project.

## Overview

All container images are automatically scanned for security vulnerabilities and dependency information using industry-standard tools:

- **[Anchore Syft](https://github.com/anchore/syft)** - Generates a Software Bill of Materials (SBOM)
- **[Anchore Grype](https://github.com/anchore/grype)** - Scans for known vulnerabilities (CVEs)

## When Scans Run

Security scans are triggered automatically:

| Event | Workflow | What Gets Scanned |
|-------|----------|-------------------|
| Pull Request | `test.yml` | Freshly built image from PR code |
| Push to master | `test.yml` | Freshly built image from master |
| Release tag push | `release.yml` | Published multi-arch image from registry |

## Where to Find Results

### Vulnerability Scan Results

**Location:** [Security → Code Scanning](https://github.com/mkletzan/docker-nfs-ganesha/security/code-scanning)

**What you'll see:**
- List of detected vulnerabilities (CVEs)
- Severity levels (Critical, High, Medium, Low)
- Affected packages and versions
- Remediation advice where available
- Historical trends

**Direct link:**
```
https://github.com/mkletzan/docker-nfs-ganesha/security/code-scanning
```

### SBOM (Software Bill of Materials)

**Location:** [Actions](https://github.com/mkletzan/docker-nfs-ganesha/actions) → Select workflow run → Artifacts

**How to download:**
1. Go to the "Actions" tab in GitHub
2. Click on a Test or Release workflow run
3. Scroll to the "Artifacts" section at the bottom
4. Download `sbom-spdx` (for test runs) or `sbom-spdx-release` (for releases)

**What's inside:**
- Complete list of all software packages in the container
- Package versions and licenses
- Dependency relationships
- SPDX 2.3 format (industry standard)

**Example use cases:**
- Compliance audits
- License verification
- Supply chain analysis
- Vulnerability correlation

## Scan Configuration

### Current Settings

| Setting | Value | Description |
|---------|-------|-------------|
| **Severity cutoff** | `medium` | Reports medium, high, and critical vulnerabilities |
| **Fail build** | `false` | Scans report findings but don't block builds |
| **Output format** | `sarif` | GitHub-compatible format for Security tab |
| **SBOM format** | `spdx-json` | SPDX 2.3 JSON format |
| **Retention** | 90 days | How long SBOM artifacts are kept |

### Changing Configuration

Edit `.github/workflows/security-scan.yml` to adjust defaults:

```yaml
with:
  image-ref: nfs-ganesha:scan
  artifact-name: sbom-spdx
  severity-cutoff: medium  # Change to: low, high, critical
  fail-build: false        # Set to true to fail builds on vulnerabilities
```

## How It Works

### Architecture

```
┌─────────────────┐
│ Test/Release    │
│ Workflow        │
└────────┬────────┘
         │
         ├─► Build/Pull Image
         │
         ├─► Save as tarball
         │
         ├─► Upload artifact
         │
         ▼
┌─────────────────┐
│ Security Scan   │
│ Workflow        │
│ (Reusable)      │
└────────┬────────┘
         │
         ├─► Download artifact
         │
         ├─► Load image
         │
         ├─► Syft: Generate SBOM
         │
         ├─► Grype: Scan for vulnerabilities
         │
         ├─► Upload SARIF → GitHub Security
         │
         └─► Upload SBOM → Artifacts
```

### Workflow Files

| File | Purpose |
|------|---------|
| `.github/workflows/security-scan.yml` | Reusable workflow - does the actual scanning |
| `.github/workflows/test.yml` | Builds image and calls security-scan |
| `.github/workflows/release.yml` | Pulls published image and calls security-scan |

## Interpreting Results

### Vulnerability Severity Levels

| Severity | Meaning | Action |
|----------|---------|--------|
| **Critical** | Actively exploited or easily exploitable | Fix immediately |
| **High** | Serious vulnerability, high risk | Fix in next release |
| **Medium** | Moderate risk | Fix when convenient |
| **Low** | Minor issue or hard to exploit | Review and decide |
| **Negligible** | Theoretical or minimal impact | Optional fix |

### Common False Positives

Some vulnerabilities may not apply to your use case:
- Vulnerabilities in packages not actually used
- Issues that require user interaction (not possible in containers)
- DOS vulnerabilities (if you control the environment)

You can suppress false positives by:
1. Adding a `.grype.yaml` configuration file
2. Documenting why certain CVEs don't apply

### Understanding SBOM

The SBOM contains:
- **Packages**: All installed software (RPMs, Python packages, etc.)
- **Files**: Important system files
- **Relationships**: Dependencies between components
- **Licenses**: Open source licenses for each package

Example SBOM snippet:
```json
{
  "name": "nfs-ganesha",
  "versionInfo": "3.0",
  "licenseConcluded": "LGPL-3.0",
  "supplier": "Organization: CentOS"
}
```

## Best Practices

### For Maintainers

1. **Review scan results regularly** - Check Security tab after each release
2. **Update base images** - Rebuild when CentOS Stream releases updates
3. **Fix critical vulnerabilities** - Prioritize based on severity
4. **Document suppressions** - If you suppress a CVE, explain why
5. **Keep scanning enabled** - Don't disable scans even if you get false positives

### For Users

1. **Check scan results before deploying** - Review Security tab for your version
2. **Subscribe to security alerts** - Watch the repository for security updates
3. **Report new vulnerabilities** - Use GitHub Security Advisories
4. **Verify SBOM** - Download and review for compliance requirements

## Troubleshooting

### No results in Security tab

**Possible causes:**
- Scans are still running (check Actions tab)
- Workflow permissions issue (needs `security-events: write`)
- No vulnerabilities found (good news!)

**Fix:** Check Actions tab for workflow run status and logs.

### SBOM artifact not available

**Possible causes:**
- Artifact retention expired (90 days)
- Workflow failed before SBOM upload
- Wrong workflow run selected

**Fix:** Check recent workflow runs or trigger a new build.

### Too many false positives

**Solution:** Create `.grype.yaml` in repository root:

```yaml
ignore:
  - vulnerability: CVE-2024-12345
    fix-state: wont-fix
    reason: "Not applicable - feature not used"
```

### Scans taking too long

**Normal:** Security scans add 2-5 minutes to workflow runs.

**If excessive:** Check if Grype database download is slow. This is cached between runs.

## References

- [Anchore Syft Documentation](https://github.com/anchore/syft)
- [Anchore Grype Documentation](https://github.com/anchore/grype)
- [SPDX Specification](https://spdx.dev/specifications/)
- [SARIF Format](https://docs.github.com/en/code-security/code-scanning/integrating-with-code-scanning/sarif-support-for-code-scanning)
- [GitHub Code Scanning](https://docs.github.com/en/code-security/code-scanning/automatically-scanning-your-code-for-vulnerabilities-and-errors/about-code-scanning)
