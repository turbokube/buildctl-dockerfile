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

## Test Runner Features

The test runner script `test-dockerfile.sh` supports:
- **Exit code validation**: Ensures commands exit with expected codes
- **Exact output matching**: Validates dry-run commands produce exact buildctl output
- **Error message validation**: Checks error scenarios return correct messages
- **Automatic cleanup**: Sets up and tears down test environment

### `run_test` Function Usage

```bash
run_test "Test Name" "command" [expected_exit_code] [expected_output]
```

- `expected_exit_code`: Default is 0 (success)
- `expected_output`: Optional exact string match for command output

## Test Cases

### 1. Help Documentation Test
**Purpose**: Verify help output is displayed correctly and includes all options
```bash
run_test "Help Documentation" "node bin/buildctl-dockerfile --help"
```
**Expected**: Should display complete help with all options including `--dry-run`

### 2. Basic Dry Run Test
**Purpose**: Test basic functionality with default Dockerfile
```bash
run_test "Basic Dry Run" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker"
```
### 3. Build Arguments and Tag Test
**Purpose**: Test build arguments and image tagging
```bash
run_test "Build Args and Tag" \
    "node bin/buildctl-dockerfile --dry-run --build-arg NODE_VERSION=18 --build-arg ENV=prod -t myapp:latest /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt build-arg:NODE_VERSION=18 --opt build-arg:ENV=prod --output type=image,name=myapp:latest,push=false"
```

### 4. Custom Dockerfile Test
**Purpose**: Test custom Dockerfile name handling
```bash
run_test "Custom Dockerfile" \
    "node bin/buildctl-dockerfile --dry-run -f /tmp/test-buildctl/custom.dockerfile /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt filename=custom.dockerfile --output type=docker"
```
```
buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt filename=custom.dockerfile --output type=docker
```

### 5. Passthrough Arguments Test
**Purpose**: Test passthrough arguments with -- separator
```bash
node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --progress=plain --no-cache
```
**Expected Output**:
### 5. Passthrough Arguments Test
**Purpose**: Test passthrough arguments with -- separator
```bash
run_test "Passthrough Arguments" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --progress=plain --no-cache" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker --progress=plain --no-cache"
```

### 6. Complex Passthrough Test
**Purpose**: Test passthrough with complex buildctl options
```bash
run_test "Complex Passthrough" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl -- --progress=plain --export-cache type=local,dest=/tmp/cache" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=image,name=myapp:latest,push=false --progress=plain --export-cache type=local,dest=/tmp/cache"
```

### 7. Passthrough Conflicts Test
**Purpose**: Test that -- properly separates conflicting arguments
```bash
run_test "Passthrough Conflicts" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --help" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker --help"
```

### 8. Output Override Tests

#### 8.1 Passthrough Output Override
**Purpose**: Test that --output in passthrough overrides default output
```bash
run_test "Passthrough Output Override" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --output type=registry,name=myregistry.com/image:latest,push=true" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=registry,name=myregistry.com/image:latest,push=true"
```

#### 8.2 Passthrough Output= Override
**Purpose**: Test that --output= syntax in passthrough works
```bash
run_test "Passthrough Output= Override" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --output=type=local,dest=/tmp/output" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output=type=local,dest=/tmp/output"
```

#### 8.3 Passthrough Override with Tag
**Purpose**: Test that passthrough --output overrides even when -t tag is specified
```bash
run_test "Passthrough Override with Tag" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl -- --output type=registry,name=override.com/image:v1,push=true" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=registry,name=override.com/image:v1,push=true"
```

### 9. Error Handling Tests

#### 9.1 No Context Path
**Purpose**: Verify error handling when context is missing
```bash
run_test "Error: No Context" \
    "node bin/buildctl-dockerfile --dry-run" \
    1
```
**Expected**: Error message "Context path is required" + help display, exit code 1

#### 9.2 Non-existent Context Directory
**Purpose**: Verify error handling for invalid context path
```bash
run_test "Error: Non-existent Context" \
    "node bin/buildctl-dockerfile --dry-run /tmp/nonexistent" \
    1 \
    "Error: Context path does not exist: /tmp/nonexistent"
```

#### 9.3 Missing Dockerfile
**Purpose**: Verify error handling when Dockerfile doesn't exist
```bash
run_test "Error: Missing Dockerfile" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-no-dockerfile" \
    1 \
    "Error: Dockerfile not found: /tmp/test-no-dockerfile/Dockerfile"
```
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
