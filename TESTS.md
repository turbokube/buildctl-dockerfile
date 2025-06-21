# buildctl-dockerfile Test Suite

This document contains the regression tests for the `buildctl-dockerfile` command implementation.

## Test Setup

```bash
# Create test directory with basic Dockerfile
mkdir -p /tmp/test-buildctl
echo "FROM alpine:latest" > /tmp/test-buildctl/Dockerfile

# Create custom Dockerfile for testing
echo "FROM alpine:latest" > /tmp/test-buildctl/custom.dockerfile

# Create directory without Dockerfile for error testing
mkdir -p /tmp/test-no-dockerfile
```

## Test Cases

### 1. Help Documentation Test
**Purpose**: Verify help output is displayed correctly and includes all options
```bash
node bin/buildctl-dockerfile --help
```
**Expected**: Should display complete help with all options including `--dry-run`

### 2. Basic Dry Run Test
**Purpose**: Test basic functionality with default Dockerfile
```bash
node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl
```
**Expected Output**: 
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker
```

### 3. Build Arguments and Tag Test
**Purpose**: Test build arguments and image tagging
```bash
node bin/buildctl-dockerfile --dry-run --build-arg NODE_VERSION=18 --build-arg ENV=prod -t myapp:latest /tmp/test-buildctl
```
**Expected Output**:
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt build-arg:NODE_VERSION=18 --opt build-arg:ENV=prod --output type=image,name=myapp:latest,push=false
```

### 4. Custom Dockerfile Test
**Purpose**: Test custom Dockerfile name handling
```bash
node bin/buildctl-dockerfile --dry-run -f /tmp/test-buildctl/custom.dockerfile /tmp/test-buildctl
```
**Expected Output**:
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt filename=custom.dockerfile --output type=docker
```

### 5. Passthrough Arguments Test
**Purpose**: Test passthrough arguments with -- separator
```bash
node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --progress=plain --no-cache
```
**Expected Output**:
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker --progress=plain --no-cache
```

### 6. Complex Passthrough Test
**Purpose**: Test passthrough with complex buildctl options
```bash
node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl -- --progress=plain --export-cache type=local,dest=/tmp/cache
```
**Expected Output**:
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=image,name=myapp:latest,push=false --progress=plain --export-cache type=local,dest=/tmp/cache
```

### 7. Passthrough Conflicts Test
**Purpose**: Test that -- properly separates conflicting arguments
```bash
node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --help
```
**Expected Output**:
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker --help
```

### 8. Error Handling Tests

#### 8.1 No Context Path
**Purpose**: Verify error handling when context is missing
```bash
node bin/buildctl-dockerfile --dry-run
```
**Expected**: Error message "Context path is required" + help display, exit code 1

#### 8.2 Non-existent Context Directory
**Purpose**: Verify error handling for invalid context path
```bash
node bin/buildctl-dockerfile --dry-run /tmp/nonexistent
```
**Expected**: Error message "Context path does not exist: /tmp/nonexistent", exit code 1

#### 8.3 Missing Dockerfile
**Purpose**: Verify error handling when Dockerfile doesn't exist
```bash
node bin/buildctl-dockerfile --dry-run /tmp/test-no-dockerfile
```
**Expected**: Error message "Dockerfile not found: /tmp/test-no-dockerfile/Dockerfile", exit code 1

## Running All Tests

```bash
#!/bin/bash
# Test setup
mkdir -p /tmp/test-buildctl
echo "FROM alpine:latest" > /tmp/test-buildctl/Dockerfile
echo "FROM alpine:latest" > /tmp/test-buildctl/custom.dockerfile
mkdir -p /tmp/test-no-dockerfile

echo "=== Testing Help ==="
node bin/buildctl-dockerfile --help

echo -e "\n=== Testing Basic Dry Run ==="
node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl

echo -e "\n=== Testing Build Args and Tag ==="
node bin/buildctl-dockerfile --dry-run --build-arg NODE_VERSION=18 --build-arg ENV=prod -t myapp:latest /tmp/test-buildctl

echo -e "\n=== Testing Custom Dockerfile ==="
node bin/buildctl-dockerfile --dry-run -f /tmp/test-buildctl/custom.dockerfile /tmp/test-buildctl

echo -e "\n=== Testing Error Cases ==="
echo "No context:"
node bin/buildctl-dockerfile --dry-run
echo -e "\nNon-existent context:"
node bin/buildctl-dockerfile --dry-run /tmp/nonexistent
echo -e "\nMissing Dockerfile:"
node bin/buildctl-dockerfile --dry-run /tmp/test-no-dockerfile

# Cleanup
rm -rf /tmp/test-buildctl /tmp/test-no-dockerfile
```

## Test Results Validation

- All tests should run without hanging or crashing
- Help output should include `--dry-run` option
- Dry run should output valid buildctl commands without executing them
- Error cases should exit with code 1 and show appropriate error messages
- Custom Dockerfile names should add `--opt filename=` parameter
- Build arguments should be prefixed with `build-arg:`
- Tags should use `type=image,name=...,push=false` format
- Default output without tag should use `type=docker`
