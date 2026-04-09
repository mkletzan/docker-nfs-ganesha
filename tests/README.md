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

Tests use NFSv4.1 as the best balance of features and compatibility.

## Troubleshooting

### Tests fail to run

**Problem:** docker-compose not found  
**Solution:** Install docker-compose or use `docker compose` (built-in plugin)

**Problem:** Permission denied errors  
**Solution:** Ensure Docker daemon is running and you have permissions to use it

### Tests fail

**Problem:** NFS mount fails  
**Solution:** 
- Check that the NFS-Ganesha container is running: `docker-compose -f tests/docker-compose.test.yml ps`
- Check logs: `docker-compose -f tests/docker-compose.test.yml logs nfs-ganesha`

**Problem:** Timeout waiting for server  
**Solution:** Increase sleep time in `run-tests.sh` if your system is slow

### Debugging

To debug a failing test:

1. Keep the test environment running:
   ```bash
   docker-compose -f tests/docker-compose.test.yml up -d
   ```

2. Enter the NFS server container:
   ```bash
   docker-compose -f tests/docker-compose.test.yml exec nfs-ganesha bash
   ```

3. Enter the test client container:
   ```bash
   docker-compose -f tests/docker-compose.test.yml exec test-runner bash
   ```

4. Clean up when done:
   ```bash
   docker-compose -f tests/docker-compose.test.yml down -v
   ```

## Test Development

### Adding New Tests

Edit `run-tests.sh` to add new test cases. Follow the existing pattern:

```bash
echo "→ Testing feature X..."
if ! command_to_test; then
    echo "❌ Feature X failed!"
    exit 1
fi
```

### Testing Environment Variables

To test different configurations, modify the `environment` section in `docker-compose.test.yml`:

```yaml
environment:
  - EXPORT_PATH=/custom/path
  - PROTOCOLS=3
  - VERBOSITY=NIV_DEBUG
```

Then verify the configuration is applied correctly in your test script.

## CI/CD

These tests run automatically in GitHub Actions on every push and pull request. See `.github/workflows/test.yml` for the CI configuration.

## License

Same as parent project.
