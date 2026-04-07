# NFS-Ganesha Container Tests

This directory contains functional tests for the NFS-Ganesha Docker container.

## Test Structure

We use a single-layer functional testing approach:

- **docker-compose.test.yml** - Test environment orchestration
- **run-tests.sh** - Shell script that performs actual NFS testing

## What Gets Tested

The test suite verifies:

- ✅ NFS server responds to `showmount`
- ✅ Client can mount the NFS export
- ✅ Client can write files to the export
- ✅ Client can read files from the export
- ✅ Client can modify file permissions
- ✅ Client can delete files
- ✅ Environment variables configure the server correctly

## Prerequisites

**Required on your machine:**
- Docker
- docker-compose (or `docker compose` plugin)

**That's it!** All test tools run inside containers.

## Running Tests

### Quick Start

From the project root:

```bash
make test              # Quiet mode - shows only test output
make test-verbose      # Verbose mode - shows all container logs
```

The default `make test` will:
1. Build the NFS-Ganesha container image
2. Start the test environment with docker-compose (detached)
3. Run the test script inside a client container
4. Show only test-runner output (clean, readable)
5. Clean up after tests complete

Use `make test-verbose` when debugging to see full NFS-Ganesha logs.

### Individual Steps

Build the image:
```bash
make build
```

Run tests:
```bash
make test
```

Clean up:
```bash
make clean
```

## Test Environment

The test environment consists of two containers:

1. **nfs-ganesha** - The NFS server being tested
   - Minimal capabilities (DAC_OVERRIDE, DAC_READ_SEARCH)
   - Exposes NFS export at `/data/nfs`
   - Supports NFSv4.0 and NFSv4.1

2. **test-runner** - NFS client that runs tests
   - Privileged mode (required for mounting NFS)
   - Uses NFSv4.1 protocol
   - Executes `run-tests.sh`
   - Reports pass/fail

### NFSv4 Version Compatibility

Tested protocol versions:
- ✅ NFSv4.0 - Works
- ✅ NFSv4.1 - Works (default for tests)
- ❌ NFSv4.2 - Not supported (mount fails with I/O error)

