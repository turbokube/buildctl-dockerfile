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

run_test "Passthrough Output Override" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --output type=registry,name=myregistry.com/image:latest,push=true" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=registry,name=myregistry.com/image:latest,push=true"

run_test "Passthrough Output= Override" \
    "node bin/buildctl-dockerfile --dry-run /tmp/test-buildctl -- --output=type=local,dest=/tmp/output" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output=type=local,dest=/tmp/output"

run_test "Error: Tag and Passthrough Output Name Conflict" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl -- --output type=registry,name=override.com/image:v1,push=true" \
    1 \
    "Error: Cannot specify both -t/--tag and name= in passthrough --output"

run_test "Push with Tag" \
    "node bin/buildctl-dockerfile --dry-run -t myregistry.com/myapp:latest --push /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=image,name=myregistry.com/myapp:latest,push=true"

run_test "Tag without Push" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=image,name=myapp:latest,push=false"

run_test "Error: Push without Tag" \
    "node bin/buildctl-dockerfile --dry-run --push /tmp/test-buildctl" \
    1 \
    "Error: --push requires -t/--tag or --output in passthrough arguments"

run_test "Error: Tag and Output Name Conflict" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest /tmp/test-buildctl -- --output type=image,name=conflict:tag,push=true" \
    1 \
    "Error: Cannot specify both -t/--tag and name= in passthrough --output"

run_test "Error: Push and Output Push Conflict" \
    "node bin/buildctl-dockerfile --dry-run -t myapp:latest --push /tmp/test-buildctl -- --output type=image,push=false" \
    1 \
    "Error: Cannot specify both --push and push= in passthrough --output"

run_test "Push Merge with Passthrough Output" \
    "node bin/buildctl-dockerfile --dry-run --push /tmp/test-buildctl -- --output type=registry,name=merged.com/image:latest" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output type=registry,name=merged.com/image:latest,push=true"

run_test "Push Merge with Passthrough Output= Format" \
    "node bin/buildctl-dockerfile --dry-run --push /tmp/test-buildctl -- --output=type=registry,name=merged.com/image:v2,annotation=test=value" \
    0 \
    "buildctl build --frontend dockerfile.v0 --local context=/tmp/test-buildctl --local dockerfile=/tmp/test-buildctl --output=type=registry,name=merged.com/image:v2,annotation=test=value,push=true"

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
