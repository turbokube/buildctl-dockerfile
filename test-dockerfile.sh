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
    
    echo "--- $test_name ---"
    set +e
    eval "$command"
    local actual_exit_code=$?
    set -e
    
    if [ "$actual_exit_code" -eq "$expected_exit_code" ]; then
        echo "✓ Exit code: $actual_exit_code (expected: $expected_exit_code)"
    else
        echo "✗ Exit code: $actual_exit_code (expected: $expected_exit_code)"
        return 1
    fi
    echo
}

# Run tests
echo "Running tests..."
echo

run_test "Help Documentation" "node bin/buildctl-dockerfile --help"

run_test "Basic Dry Run" "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl"

run_test "Build Args and Tag" "node bin/buildctl-dockerfile --dry-run --build-arg NODE_VERSION=18 --build-arg ENV=prod -t myapp:latest /tmp/test-buildctl"

run_test "Custom Dockerfile" "node bin/buildctl-dockerfile --dry-run -f /tmp/test-buildctl/custom.dockerfile /tmp/test-buildctl"

run_test "Error: No Context" "node bin/buildctl-dockerfile --dry-run" 1

run_test "Error: Non-existent Context" "node bin/buildctl-dockerfile --dry-run /tmp/nonexistent" 1

run_test "Error: Missing Dockerfile" "node bin/buildctl-dockerfile --dry-run /tmp/test-no-dockerfile" 1

echo "=== Cleanup ==="
rm -rf /tmp/test-buildctl /tmp/test-no-dockerfile
echo "✓ Test environment cleaned up"

echo
echo "=== All Tests Completed Successfully ==="
