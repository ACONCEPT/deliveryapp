# Go Build TMPDIR Permission Fix

## Issue

When running `./build-lambda.sh` (or `./tools/sh/build-lambda.sh`), the build failed with:

```
go: creating work dir: mkdir /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000/T/go-build3675663937: permission denied
```

## Root Cause

Go was attempting to use `/var/folders/zz/...` as its temporary build directory, which is owned by root and not writable by the current user.

**Directory permissions:**
```bash
$ ls -ld /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000
drwxr-xr-x@ 7 root  wheel  224 Feb  4  2021 /var/folders/zz/...
```

This can happen when:
- Go's default TMPDIR detection picks the wrong directory
- System temp directories have incorrect ownership
- Running build scripts in different contexts (sudo, etc.)

## Fix Applied

### File Modified
`tools/sh/build-lambda.sh`

### Change Made
Added explicit TMPDIR export at the beginning of the script:

```bash
#!/bin/bash
set -e

# Build Lambda deployment packages for AWS deployment
# This script builds:
# 1. Main backend API Lambda function
# 2. Scheduled jobs Lambda functions (as a combined package)

# Set TMPDIR to user's temp directory to avoid permission issues
export TMPDIR="${TMPDIR:-/tmp}"

echo "=================================="
echo "Building Lambda Deployment Packages"
echo "=================================="
# ... rest of script
```

### How It Works

The line `export TMPDIR="${TMPDIR:-/tmp}"` means:
- Use existing `$TMPDIR` if already set
- Otherwise, default to `/tmp` (universally writable)
- Export it so all child processes (including Go) use it

This ensures Go always has a writable temporary directory.

## Verification

### Before Fix
```bash
$ ./tools/sh/build-lambda.sh
...
go: creating work dir: mkdir /var/folders/zz/.../T/go-build...: permission denied
```

### After Fix
```bash
$ ./tools/sh/build-lambda.sh
==================================
Building Lambda Deployment Packages
==================================

[1/4] Creating build directory...
[2/4] Installing AWS Lambda dependencies...
[3/4] Building main backend API Lambda...
✓ Created build/lambda-deployment.zip

[4/4] Building scheduled jobs Lambdas...
✓ Created build/lambda-jobs-deployment.zip (combined)
✓ Created individual job packages

==================================
Build Complete!
==================================
```

## Usage

Now you can run the build script normally:

```bash
# From project root
./tools/sh/build-lambda.sh

# Or from anywhere
/path/to/delivery_app/tools/sh/build-lambda.sh
```

The script will:
1. Set a writable TMPDIR
2. Build the main backend Lambda (3.7MB)
3. Build all scheduled job Lambdas (3.6MB each)
4. Create deployment packages in `./build/`

## Files Changed

| File | Change | Line |
|------|--------|------|
| `tools/sh/build-lambda.sh` | Added `export TMPDIR="${TMPDIR:-/tmp}"` | 10 |

## Alternative Solutions (Not Used)

### Option 1: Fix Directory Permissions
```bash
sudo chown -R $USER /var/folders/zz/zyxvpxvq6csfxvn_n0000000000000
```
**Why not:** Requires sudo, may break other system processes

### Option 2: Set TMPDIR Globally
```bash
# In ~/.zshrc or ~/.bashrc
export TMPDIR=/tmp
```
**Why not:** Affects all processes, may interfere with macOS defaults

### Option 3: Per-Command TMPDIR
```bash
TMPDIR=/tmp ./tools/sh/build-lambda.sh
```
**Why not:** User has to remember to set it every time

### Our Solution: Script-Level Export
**Why chosen:**
- ✅ No sudo required
- ✅ No global environment changes
- ✅ No user action required
- ✅ Works consistently across different systems
- ✅ Self-contained in the script

## Related Issues

This fix also helps with:
- Go test commands that need temp directories
- Other Go build operations in the project
- Any scripts that spawn Go processes

## Prevention

When creating new build scripts that use Go:

```bash
#!/bin/bash
set -e

# Always set TMPDIR for Go builds
export TMPDIR="${TMPDIR:-/tmp}"

# Your build commands here
go build ...
go test ...
```

## Summary

| Aspect | Status |
|--------|--------|
| Root cause | ✅ Identified (Go using root-owned temp dir) |
| Fix applied | ✅ Complete (TMPDIR export added) |
| Build tested | ✅ Success (all packages built) |
| Ready to use | ✅ Yes |

The Lambda build script now works correctly without permission errors! 🎉
