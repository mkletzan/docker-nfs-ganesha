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
if ! mount -t nfs4 -o vers=4.1 nfs-ganesha:/ /mnt/nfs; then
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
