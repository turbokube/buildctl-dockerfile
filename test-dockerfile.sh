#!/bin/bash

# buildctl-dockerfile Test Runner
# Run all regression tests for the buildctl-dockerfile command

set -e

echo "=== buildctl-dockerfile Test Suite ==="
echo "Setting up test environment..."

# Test setup
mkdir -p /tmp/test-buildctl
echo "FROM alpine:latest" > /tmp/test-buildctl/Dockerfile
echo "FROM alpine:latest" > /tmp/test-buildctl/custom.dockerfile
mkdir -p /tmp/test-no-dockerfile

echo "✓ Test environment ready"
echo

# Function to run test and capture exit code
run_test() {
    local test_name="$1"
    local command="$2"
    local expected_exit_code="${3:-0}"
    local expected_output="$4"
    
    echo "--- $test_name ---"
    set +e
    local actual_output
    actual_output=$(eval "$command" 2>&1)
    local actual_exit_code=$?
    set -e
    
    # Check exit code
    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        echo "✓ Exit code: $actual_exit_code (expected: $expected_exit_code)"
    else
        echo "✗ Exit code: $actual_exit_code (expected: $expected_exit_code)"
        return 1
    fi
    
    # Check exact output if provided
    if [ -n "$expected_output" ]; then
        if [ "$actual_output" = "$expected_output" ]; then
            echo "✓ Output matches expected"
        else
            echo "✗ Output mismatch"
            echo "Expected: $expected_output"
            echo "Actual:   $actual_output"
            return 1
        fi
    else
        # Show output for manual verification if no exact match specified
        echo "$actual_output"
    fi
    echo
}

# Run tests
echo "Running tests..."
echo

run_test "Help Documentation" "node bin/buildctl-dockerfile --help"

run_test "Basic Dry Run" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker"

run_test "Build Args and Tag" \
    "node bin/buildctl-dockerfile --dry-run --build-arg NODE_VERSION=18 --build-arg ENV=prod -t myapp:latest /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt build-arg:NODE_VERSION=18 --opt build-arg:ENV=prod --output type=image,name=myapp:latest,push=false"

run_test "Custom Dockerfile" \
    "node bin/buildctl-dockerfile --dry-run -f /tmp/test-buildctl/custom.dockerfile /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --opt filename=custom.dockerfile --output type=docker"

run_test "Passthrough Arguments" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --progress=plain --no-cache" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker --progress=plain --no-cache"

run_test "Complex Passthrough" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl -- --progress=plain --export-cache type=local,dest=/tmp/cache" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=image,name=myapp:latest,push=false --progress=plain --export-cache type=local,dest=/tmp/cache"

run_test "Passthrough Conflicts" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --help" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=docker --help"

run_test "Error: No Context" \
    "node bin/buildctl-dockerfile --dry-run" \
    1

run_test "Error: Non-existent Context" \
    "node bin/buildctl-dockerfile --dry-run /tmp/nonexistent" \
    1 \
    "Error: Context path does not exist: /tmp/nonexistent"

run_test "Error: Missing Dockerfile" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-no-dockerfile" \
    1 \
    "Error: Dockerfile not found: /tmp/test-no-dockerfile/Dockerfile"

echo "=== Cleanup ==="
rm -rf /tmp/test-buildctl /tmp/test-no-dockerfile
echo "✓ Test environment cleaned up"

echo
echo "=== All Tests Completed Successfully ==="
